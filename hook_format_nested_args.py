# hook_format_nested_args.py
"""
MkDocs hook: reformat nested argument lists in mkdocstrings-matlab output.

Finds plain-text nested <ul> lists inside .doc-md-description divs and
reformats items matching "name (type): description" to match the bold/monospace
style of top-level arguments.

It also links the data types to the either official MATLAB documentation
or to custom data structures. URLs need to be edited in function_links.py

It also formats any appereance of data structures (in the form `xxx`)
and links it with the definitions in function_links.py.

Category headers can be added inside nested argument lists using the
**Category name** syntax (bold text, no type/description pattern).
These are rendered as collapsible <details> sections grouping the
parameters that follow them.

"""

from __future__ import annotations
import re
import logging
from html.parser import HTMLParser

import hook_site_config as site_config
from function_links import FUNCTION_LINKS

log = logging.getLogger("mkdocs.hooks_format_nested_args")
#log.setLevel(logging.DEBUG)

# ---------------------------------------------------------------------------
# HTML tree builder
# ---------------------------------------------------------------------------

class Node:
    """A simple HTML tree node."""
    def __init__(self, tag: str, attrs: list):
        self.tag = tag
        self.attrs = dict(attrs)
        self.children: list[Node | str] = []
        self.parent: Node | None = None

    def get_class(self) -> str:
        return self.attrs.get("class", "")

    def __repr__(self):
        return f"<Node {self.tag} class={self.get_class()!r} children={len(self.children)}>"


class HTMLTreeBuilder(HTMLParser):
    """
    Parses HTML into a tree of Node objects.
    Tracks a virtual root node; self.root.children are the top-level nodes.
    """

    # Tags that are self-closing and never have children
    VOID_TAGS = {
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    }

    def __init__(self):
        super().__init__(convert_charrefs=False)
        self.root = Node("__root__", [])
        self._stack: list[Node] = [self.root]

    def _current(self) -> Node:
        return self._stack[-1]

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs)
        node.parent = self._current()
        self._current().children.append(node)
        if tag not in self.VOID_TAGS:
            self._stack.append(node)

    def handle_endtag(self, tag):
        # Pop stack until we find matching tag (handles malformed HTML)
        for i in range(len(self._stack) - 1, 0, -1):
            if self._stack[i].tag == tag:
                self._stack = self._stack[:i]
                return

    def handle_data(self, data):
        self._current().children.append(data)

    def handle_entityref(self, name):
        self._current().children.append(f"&{name};")

    def handle_charref(self, name):
        self._current().children.append(f"&#{name};")

    def handle_comment(self, data):
        self._current().children.append(f"<!--{data}-->")


# ---------------------------------------------------------------------------
# Tree → HTML serializer
# ---------------------------------------------------------------------------

def serialize(node: Node | str) -> str:
    """Serialize a node (or string) back to HTML."""
    if isinstance(node, str):
        return node

    # Serialize attributes
    attrs = ""
    for k, v in node.attrs.items():
        if v is None:
            attrs += f" {k}"
        else:
            attrs += f' {k}="{v}"'

    if node.tag == "__root__":
        return "".join(serialize(c) for c in node.children)

    if node.tag in HTMLTreeBuilder.VOID_TAGS:
        return f"<{node.tag}{attrs}>"

    inner = "".join(serialize(c) for c in node.children)
    return f"<{node.tag}{attrs}>{inner}</{node.tag}>"


# ---------------------------------------------------------------------------
# Argument pattern matchers
# ---------------------------------------------------------------------------

# Matches: "name (type): description"  or  "name (type or type): description"
_ARG_RE = re.compile(
    r'^([A-Za-z][A-Za-z0-9_.]*)'   # name
    r'\s*\(([^)]+)\)\s*:\s*'        # (type):
    r'(.+)$',                        # description
    re.DOTALL,
)

# Matches a category header rendered from **Category name** markdown,
# i.e. a <li> whose text content is purely a <strong> or <b> element.
_CATEGORY_RE = re.compile(
    r'^\s*<(?:strong|b)>(.+?)</(?:strong|b)>:?\s*$',
    re.DOTALL,
)


# ---------------------------------------------------------------------------
# Category grouping into collapsible <details> blocks
# ---------------------------------------------------------------------------

def _group_into_details(ul_node: Node) -> None:
    """
    If a <ul> contains category-header <li> items (class="doc-param-category"),
    restructure the list into <details><summary> collapsible groups.
    Items appearing before the first category header are left as-is.
    """
    has_categories = any(
        isinstance(c, Node) and c.tag == "li"
        and "doc-param-category" in c.attrs.get("class", "")
        for c in ul_node.children
    )
    if not has_categories:
        return

    new_children: list[Node | str] = []
    current_inner_ul: Node | None = None

    for child in ul_node.children:
        if not (isinstance(child, Node) and child.tag == "li"):
            # Whitespace or text nodes — attach to current context
            if current_inner_ul is not None:
                current_inner_ul.children.append(child)
            else:
                new_children.append(child)
            continue

        is_category = "doc-param-category" in child.attrs.get("class", "")

        if is_category:
            # Build: <details open class="doc-param-group">
            #            <summary>…label…</summary>
            #            <ul class="doc-param-group-items">…</ul>
            #        </details>
            summary_html = "".join(serialize(c) for c in child.children)
            details_node = Node("details", [("class", "doc-param-group")])
            summary_node = Node("summary", [])
            b = HTMLTreeBuilder()
            b.feed(summary_html)
            summary_node.children = list(b.root.children)
            current_inner_ul = Node("ul", [("class", "doc-param-group-items")])
            details_node.children = [summary_node, current_inner_ul]
            new_children.append(details_node)
        else:
            if current_inner_ul is not None:
                current_inner_ul.children.append(child)
            else:
                # Item before any category header — keep at top level
                new_children.append(child)

    ul_node.children = new_children


# ---------------------------------------------------------------------------
# <li> reformatter
# ---------------------------------------------------------------------------

def _reformat_li(li_node: Node) -> None:
    """
    If a <li> node's text content matches "name (type): description",
    replace its children with formatted bold/monospace markup.
    Recurses into any nested <ul> children, then groups them into
    collapsible <details> sections if category headers are present.
    """
    # First recurse into any nested <ul> children
    for child in li_node.children:
        if isinstance(child, Node) and child.tag == "ul":
            for nested_li in child.children:
                if isinstance(nested_li, Node) and nested_li.tag == "li":
                    _reformat_li(nested_li)
            # After all <li> in this <ul> have been classified, group them
            _group_into_details(child)

    # Collect the text content of this <li>, excluding nested <ul> blocks
    text_parts = []
    nested_uls = []
    p_node = None

    for child in li_node.children:
        if isinstance(child, str):
            text_parts.append(child)
        elif isinstance(child, Node):
            if child.tag == "ul":
                nested_uls.append(child)
            elif child.tag == "p":
                # <p> wrapper: get its text content (excluding nested <ul>)
                p_node = child
                for pc in child.children:
                    if isinstance(pc, str):
                        text_parts.append(pc)
                    elif isinstance(pc, Node) and pc.tag != "ul":
                        text_parts.append(serialize(pc))
                    elif isinstance(pc, Node) and pc.tag == "ul":
                        nested_uls.append(pc)
            else:
                text_parts.append(serialize(child))

    text = "".join(text_parts).strip()

    # Check for category header BEFORE trying _ARG_RE.
    # Category headers come from **Bold text** in the docstring, which
    # renders as <strong>…</strong> with no (type): description pattern.
    match_cat = _CATEGORY_RE.match(text)
    if match_cat:
        li_node.attrs["class"] = "doc-param-category"
        return  # leave content unchanged; _group_into_details will wrap it

    # Try to match "name (type): description"
    match = _ARG_RE.match(text)
    if not match:
        return  # leave unchanged

    name = match.group(1)
    typ  = match.group(2).strip()
    desc = match.group(3).strip()

    # Build new children: formatted text + preserved nested <ul> blocks
    formatted_html = (
        f'<b><code>{name}</code></b> '
        f'(<code>{_linkify_type(typ)}</code>) &ndash; '
        f'{desc}'
    )

    # Parse the formatted HTML into nodes
    builder = HTMLTreeBuilder()
    builder.feed(formatted_html)
    new_children: list[Node | str] = list(builder.root.children)

    # Add back nested <ul> blocks (already recursively reformatted above)
    new_children.extend(nested_uls)

    # Update the li node's class and children
    li_node.attrs["class"] = "doc-section-item field-body"
    li_node.children = new_children


# ---------------------------------------------------------------------------
# Tree walkers
# ---------------------------------------------------------------------------

def _process_doc_md_description(node: Node) -> None:
    """
    Walk the tree and reformat nested <ul> lists inside
    any div with class "doc-md-description".
    """
    if (isinstance(node, Node)
            and node.tag == "div"
            and "doc-md-description" in node.get_class()):
        # Reformat all <li> items in any <ul> directly inside this div
        for child in node.children:
            if isinstance(child, Node) and child.tag == "ul":
                for li in child.children:
                    if isinstance(li, Node) and li.tag == "li":
                        _reformat_li(li)
                _group_into_details(child)
        return  # don't recurse further into this div

    # Recurse into all children
    if isinstance(node, Node):
        for child in node.children:
            if isinstance(child, Node):
                _process_doc_md_description(child)


def _linkify_type(typ: str) -> str:
    url = FUNCTION_LINKS.get(typ.lower().strip())
    if url:
        full_url, target = _build_url(url)
        return f'<a href="{full_url}"{target}>{typ}</a>'
    return typ


def _linkify_toplevel_types(node: Node) -> None:
    if (isinstance(node, Node)
            and node.tag == "li"
            and "doc-section-item" in node.get_class()):

        children = node.children
        for i, child in enumerate(children):
            if not (isinstance(child, Node) and child.tag == "code"):
                continue

            prev = children[i - 1] if i > 0 else ""
            nxt  = children[i + 1] if i < len(children) - 1 else ""
            prev_text = prev if isinstance(prev, str) else ""
            next_text = nxt  if isinstance(nxt,  str) else ""

            if "(" not in prev_text or ")" not in next_text:
                continue

            typ = "".join(
                c if isinstance(c, str) else serialize(c)
                for c in child.children
            ).strip()

            url = FUNCTION_LINKS.get(typ.lower().strip())
            if not url:
                continue

            full_url, target = _build_url(url)
            link_builder = HTMLTreeBuilder()
            link_builder.feed(f'<a href="{full_url}"{target}>{typ}</a>')
            child.children = list(link_builder.root.children)

        return

    if isinstance(node, Node):
        for child in node.children:
            if isinstance(child, Node):
                _linkify_toplevel_types(child)


def _linkify_code_tags(node: Node) -> None:
    if isinstance(node, Node):
        if node.tag == "a":
            return
        if node.tag == "details" and "quote" in node.get_class():
            return
        if node.tag == "details" and "doc-param-group" in node.get_class():
            return
        if node.tag == "div" and "highlight" in node.get_class():
            return

        for i, child in enumerate(node.children):
            if (isinstance(child, Node)
                    and child.tag == "code"):

                typ = "".join(
                    c if isinstance(c, str) else serialize(c)
                    for c in child.children
                ).strip()

                url = FUNCTION_LINKS.get(typ.lower().strip())
                if url:
                    full_url, target = _build_url(url)
                    a_node = Node("a", [("href", full_url)] + ([("target", "_blank")] if target else []))
                    a_node.children = [child]
                    node.children[i] = a_node
                else:
                    _linkify_code_tags(child)
            elif isinstance(child, Node):
                _linkify_code_tags(child)


def _build_url(url: str) -> tuple[str, str]:
    """
    Returns (full_url, target_attr).
    External URLs are returned as-is with target="_blank".
    Internal paths get SITE_PREFIX prepended.
    """
    if url.startswith("http"):
        return url, ' target="_blank"'
    else:
        return f"{site_config.SITE_PREFIX}/{url}", ""


# ---------------------------------------------------------------------------
# MkDocs hook entry point
# ---------------------------------------------------------------------------

def on_page_content(html: str, page, config, files) -> str:
    """
    Called when page content is translated to HTML.

    It formats the tags for data structures first, anything that
    is rendered as `xxx` gets checked if there is a link to it in function_links.py
    (function _linkify_code_tags).

    Then it parses specifically the arguments, changing the format of
    second and third level description to match the automatic first-level description
    (function _process_doc_md_description). This function also
    includes links to the data types inside the parenthesis.
    Category headers (**Bold**) are detected and their sibling items
    are wrapped in collapsible <details> sections.

    Finally it does the same thing but for the first level arguments,
    putting a link in the data type. This is done in function
    _linkify_toplevel_types.
    """
    try:
        builder = HTMLTreeBuilder()
        builder.feed(html)
        _linkify_code_tags(builder.root)
        html = serialize(builder.root)
    except Exception as e:
        log.warning(f"[format_nested_args] pass1 FAILED: {e}")

    if "doc-md-description" not in html:
        return html

    try:
        builder = HTMLTreeBuilder()
        builder.feed(html)
        _process_doc_md_description(builder.root)
        _linkify_toplevel_types(builder.root)
        return serialize(builder.root)
    except Exception as e:
        log.warning(f"[format_nested_args] pass2 FAILED: {e}")
        return html
