# -*- coding: utf-8 -*-
"""
Remove the folder-level docstring from mkdocstrings-matlab output.
This docstring comes from "Contents.m", which in our case is unwanted
as it does not render well and it is supposed to be read only by MATLAB.


mkdocstrings-matlab special-cases Contents.m as the folder-level docstring
source. It is rendered inside each folder object's ``doc-contents`` block, as
the prose nodes that appear *before* the nested ``doc-children`` block which
holds the actual function members. The ``filters`` and ``members`` options do
not suppress it.

Structure produced by the plugin:

    <div class="doc doc-object doc-folder">
      <h2 ...>/src</h2>
      <div class="doc doc-contents first">
        <p>... Contents.m docstring prose ...</p>   <-- remove these
        <details>...</details>                      <-- remove these
        ...
        <div class="doc doc-children"> ... </div>   <-- KEEP (the members)
      </div>
    </div>

This hook removes the folder docstring: the content of each folder's
``doc-contents`` block that appears before its nested ``doc-children`` block.
All function members and their own docstrings are preserved.

Implementation note
-------------------
This uses only the Python standard library (``html.parser``), so it adds no
extra dependency. ``html.parser`` is an event-based (SAX-style) parser, so the
hook tracks tag nesting depth by hand to know precisely which region to drop:

  - "folder" region: inside a <div class="doc doc-object doc-folder">.
  - "contents" region: inside that folder's direct-child doc-contents div.
  - The docstring is everything in the contents region emitted before the
    doc-children div opens. That span is suppressed; everything else is copied
    through verbatim.
"""
from html.parser import HTMLParser


def _has_class(attrs, name):
    """Return True if the tag's class attribute contains the given class name."""
    for key, value in attrs:
        if key == "class" and value is not None:
            return name in value.split()
    return False


def _is_div(tag):
    return tag == "div"


class _FolderDocstringStripper(HTMLParser):
    """Copy HTML through verbatim, dropping folder-level docstrings.

    State machine
    -------------
    depth
        Running count of open tags, used as a stable reference for nesting.
    folder_depth
        Depth at which the current folder object opened, or None when not
        inside a folder object.
    contents_depth
        Depth at which the current folder's doc-contents block opened, or None
        when not inside it. Set only for the folder's own (direct-child)
        contents block.
    suppressing
        True while emitting the folder docstring span (inside the contents
        block, before doc-children opens). While True, output is discarded.
    """

    def __init__(self):
        # convert_charrefs=False so entities and character references are
        # preserved exactly as written in the source, rather than decoded.
        super().__init__(convert_charrefs=False)
        self.out = []
        self.depth = 0
        self.folder_depth = None
        self.contents_depth = None
        self.suppressing = False

    # -- helpers -----------------------------------------------------------

    def _emit(self, text):
        if not self.suppressing:
            self.out.append(text)

    def get_html(self):
        return "".join(self.out)

    # -- tag handlers ------------------------------------------------------

    def handle_starttag(self, tag, attrs):
        self._handle_open(tag, attrs, self.get_starttag_text())

    def handle_startendtag(self, tag, attrs):
        # Self-closing tag (e.g. <br/>). It opens and closes at once, so it does
        # not change nesting depth and cannot itself be a region boundary.
        self._emit(self.get_starttag_text())

    def _handle_open(self, tag, attrs, raw):
        # Detect region entries BEFORE incrementing depth so the recorded depth
        # matches the matching close (handled symmetrically below).
        entering_folder = (
            self.folder_depth is None
            and _is_div(tag)
            and _has_class(attrs, "doc-folder")
        )
        entering_contents = (
            self.folder_depth is not None
            and self.contents_depth is None
            and _is_div(tag)
            and _has_class(attrs, "doc-contents")
        )
        entering_children = (
            self.contents_depth is not None
            and self.suppressing
            and _is_div(tag)
            and _has_class(attrs, "doc-children")
        )

        if entering_children:
            # Stop suppressing so the doc-children div and its members are kept.
            self.suppressing = False

        # Emit the start tag (unless currently suppressing docstring content).
        self._emit(raw)

        self.depth += 1

        if entering_folder:
            self.folder_depth = self.depth
        if entering_contents:
            self.contents_depth = self.depth
            # Begin suppressing: everything until doc-children opens is the
            # folder docstring.
            self.suppressing = True

    def handle_endtag(self, tag):
        closing_depth = self.depth
        self.depth -= 1

        # Emit the end tag first (respecting suppression), then update regions.
        self._emit("</%s>" % tag)

        if self.contents_depth is not None and closing_depth == self.contents_depth:
            # Left the folder's contents block.
            self.contents_depth = None
            self.suppressing = False
        if self.folder_depth is not None and closing_depth == self.folder_depth:
            # Left the folder object.
            self.folder_depth = None

    # -- character data handlers ------------------------------------------

    def handle_data(self, data):
        self._emit(data)

    def handle_entityref(self, name):
        self._emit("&%s;" % name)

    def handle_charref(self, name):
        self._emit("&#%s;" % name)

    def handle_comment(self, data):
        self._emit("<!--%s-->" % data)

    def handle_decl(self, decl):
        self._emit("<!%s>" % decl)

    def handle_pi(self, data):
        self._emit("<?%s>" % data)

    def unknown_decl(self, data):
        self._emit("<![%s]>" % data)


def strip_folder_docstrings(html):
    """Remove the folder-level docstring from each folder object.

    Parameters
    ----------
    html : str
        Rendered HTML for a page.

    Returns
    -------
    str
        HTML with each folder's own docstring removed. The nested doc-children
        block (the function members) is preserved.
    """
    parser = _FolderDocstringStripper()
    parser.feed(html)
    parser.close()
    return parser.get_html()


# MkDocs hook entry point.
def on_post_page(output, page=None, config=None, **kwargs):
    """MkDocs on_post_page hook: strip folder-level docstrings from the page."""
    if "doc-object doc-folder" not in output:
        return output
    return strip_folder_docstrings(output)

