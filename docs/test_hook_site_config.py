# -*- coding: utf-8 -*-
"""
Unit tests for hook_site_config, written as plain functions.

The helpers take an mkdocs page but read only its url, so a small stand-in is
enough. The expected values follow from counting directory levels: a page served
at mfiles/demos/x/ is three levels below the site root, so the root is ../../../
away from it.
"""

from types import SimpleNamespace

from hook_site_config import page_relative, root_relative_prefix


def page(url):
    """Stand in for an mkdocs page, which the helpers read the url of."""
    return SimpleNamespace(url=url)


def test_prefix_at_the_site_root_is_empty():
    assert root_relative_prefix(page("")) == ""


def test_prefix_counts_directory_levels():
    assert root_relative_prefix(page("data_structures/")) == "../"
    assert root_relative_prefix(page("mfiles/rs_geofit/")) == "../../"
    assert root_relative_prefix(page("mfiles/demos/rs_knit_coordsets_demo/")) == "../../../"


def test_prefix_ignores_the_page_file_when_urls_are_files():
    # Without use_directory_urls the last part is the page itself, not a folder.
    assert root_relative_prefix(page("index.html")) == ""
    assert root_relative_prefix(page("mfiles/demos/x.html")) == "../../"


def test_prefix_of_a_page_without_a_url():
    assert root_relative_prefix(SimpleNamespace()) == ""


def test_page_relative_prepends_the_prefix():
    target = "function-index-matlab/#rs_geofit"
    assert page_relative(target, page("")) == target
    assert page_relative(target, page("domains/")) == "../" + target
    assert page_relative(target, page("mfiles/demos/d/")) == "../../../" + target


def test_page_relative_leaves_external_links_alone():
    url = "https://www.mathworks.com/help/matlab/ref/zeros.html"
    assert page_relative(url, page("mfiles/demos/d/")) == url


def test_page_relative_leaves_anchors_and_absolute_paths_alone():
    assert page_relative("#section", page("mfiles/x/")) == "#section"
    assert page_relative("/rs-software/domains/", page("mfiles/x/")) == "/rs-software/domains/"


def test_a_link_from_a_deep_page_climbs_to_the_target():
    # Two levels down, the target is two levels up: the link resolves to the same
    # place from any page, which is the point of building it this way.
    deep = page_relative("domains/", page("mfiles/rs_geofit/"))
    assert deep == "../../domains/"
