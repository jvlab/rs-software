# hook_collapse_details.py
"""
MkDocs hook: collapse selected <details> blocks by default.

mkdocstrings-matlab emits each docstring section (Notes, See Also, custom
section headers, etc.) as a <details ... open> block inside
<div class="doc doc-contents">. Having every block expanded on page load
makes long function pages noisy.

This hook walks the rendered HTML and removes the boolean ``open``
attribute from any <details> whose class name contains "note" or
"see-also" (case-insensitive). All other <details> blocks are left
untouched (e.g. argument groups, function-section blocks like
"aux", "coords", "verify-the-installation", admonition "quote" blocks).

The match rule deliberately uses substring containment so that all of
the following are caught:
    note, notes, general-notes, note-regarding-anything, see-also.

Run order: this hook should be registered AFTER
``hook_format_nested_args.py`` in mkdocs.yml so that the argument-group
<details> elements (class "doc-param-group") have already been emitted
and are not affected here. (They wouldn't match the rule anyway, but
keeping a clear order avoids surprises.)
"""

from __future__ import annotations

import logging
import re

log = logging.getLogger("mkdocs.hooks_collapse_details")


# ---------------------------------------------------------------------------
# Class-name rule
# ---------------------------------------------------------------------------

# Substrings (lowercase) that mark a <details> as one we want collapsed.
COLLAPSE_KEYWORDS: tuple[str, ...] = ("note", "see-also")


def should_collapse(class_attr: str) -> bool:
    """
    Return True if the given HTML class attribute value indicates
    a <details> block that should start collapsed.

    A <details> is collapsed if any of its space-separated class tokens
    contains any of COLLAPSE_KEYWORDS as a substring (case-insensitive).

    Examples that match:
        "note", "notes", "general-notes", "note-regarding-rays",
        "see-also", "Note Regarding Foo".
    Examples that do not match:
        "aux", "coords", "doc-param-group", "quote", "verify-the-installation".
    """
    if not class_attr:
        return False
    lowered = class_attr.lower()
    tokens = lowered.split()
    return any(
        any(keyword in token for keyword in COLLAPSE_KEYWORDS)
        for token in tokens
    )


# ---------------------------------------------------------------------------
# HTML rewriting
# ---------------------------------------------------------------------------

# Captures opening <details ...> tags. We rewrite each match individually
# rather than parsing the whole document for speed and minimal disturbance.
_DETAILS_OPEN_TAG_RE = re.compile(
    r"<details\b([^>]*)>",
    re.IGNORECASE,
)

# Extract a class attribute value from a tag's attribute string.
# Handles class="..." and class='...' (no unquoted form is emitted by
# mkdocstrings or python-markdown, so we don't need to support that).
_CLASS_ATTR_RE = re.compile(
    r"""\bclass\s*=\s*("([^"]*)"|'([^']*)')""",
    re.IGNORECASE,
)

# Match a standalone boolean ``open`` attribute (with optional ="" or ='').
# The lookahead allows whitespace, end-of-string, or the closing > as
# valid right boundaries. This way the regex works both on full tags
# ('<details ... open>') and on bare attribute strings ('class="..." open').
_OPEN_ATTR_RE = re.compile(
    r"""\s+open(?:\s*=\s*(?:"[^"]*"|'[^']*'))?(?=\s|>|/>|\Z)""",
    re.IGNORECASE,
)


def _extract_class(attrs_str: str) -> str:
    """Return the class attribute value from a tag's attribute string, or ''."""
    m = _CLASS_ATTR_RE.search(attrs_str)
    if not m:
        return ""
    return m.group(2) if m.group(2) is not None else (m.group(3) or "")


def _strip_open_attr(attrs_str: str) -> str:
    """Remove the boolean ``open`` attribute from a tag attribute string."""
    return _OPEN_ATTR_RE.sub("", attrs_str)


def collapse_details_in_html(html: str) -> str:
    """
    Return ``html`` with the ``open`` attribute removed from every
    <details> tag whose class attribute satisfies ``should_collapse``.

    Pure function: no I/O, safe to unit-test in isolation.
    """
    if "<details" not in html.lower():
        return html

    def _rewrite(match: re.Match) -> str:
        attrs_str = match.group(1)
        class_value = _extract_class(attrs_str)
        if not should_collapse(class_value):
            return match.group(0)
        new_attrs = _strip_open_attr(attrs_str)
        return f"<details{new_attrs}>"

    return _DETAILS_OPEN_TAG_RE.sub(_rewrite, html)


# ---------------------------------------------------------------------------
# MkDocs hook entry point
# ---------------------------------------------------------------------------

def on_page_content(html: str, page, config, files) -> str:
    """
    Called by MkDocs once a page's Markdown has been rendered to HTML.
    Removes the ``open`` attribute from selected <details> blocks so they
    start collapsed in the browser.
    """
    try:
        return collapse_details_in_html(html)
    except Exception as exc:
        log.warning(f"[collapse_details] FAILED: {exc}")
        return html
