# -*- coding: utf-8 -*-
"""
Links that work wherever the site is served.

The hooks generate links to pages they do not own: function names point at the
MATLAB function index, and terms such as `dataset structure` point at the data
structures page. Those links used to be absolute, built from the path part of
site_url, which tied a build to the one URL it was built for. Unpacking the site
and opening it from disk, or serving it under a different prefix, broke every
generated link.

The helpers here turn a URL given relative to the site root into one relative to
the page being rendered, which holds in all of those cases.

@author: G. Aguilar - Feb 2026
"""


def root_relative_prefix(page) -> str:
    """
    Return the "../" chain leading from a page back to the site root.

    Args:
        page: the mkdocs page being rendered. Only its url is read, for example
            "mfiles/demos/rs_knit_coordsets_demo/" with directory urls, or
            "mfiles/demos/rs_knit_coordsets_demo.html" without them.

    Returns:
        str: "../" repeated once per directory level, so "../../../" for the
        example above, and "" for a page at the site root.
    """
    url = getattr(page, "url", "") or ""
    parts = [part for part in url.strip("/").split("/") if part]

    # Without directory urls the last part is the page file itself, not a folder.
    if parts and "." in parts[-1]:
        parts.pop()

    return "../" * len(parts)


def page_relative(url: str, page) -> str:
    """
    Return a site-root-relative url as a link relative to the page being rendered.

    Args:
        url: the target, relative to the site root, for example
            "function-index-matlab/#rs_geofit".
        page: the mkdocs page being rendered.

    Returns:
        str: the same target, reached from that page. External links and bare
        anchors are returned unchanged.
    """
    if url.startswith(("http://", "https://", "#", "/")):
        return url
    return root_relative_prefix(page) + url
