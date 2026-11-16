# -*- coding: utf-8 -*-
"""
Unit tests for create_function_md_files, written as plain functions.

Each test builds its own source tree and output folder in a tmp_path, so nothing
depends on the state of src or docs/mfiles.
"""

from create_function_md_files import (
    clear_pages,
    page_text,
    source_files,
    write_pages,
)


def build_src(tmp_path):
    """Create a source tree shaped like src, and return its path."""
    src = tmp_path / "src"
    (src / "utils").mkdir(parents=True)
    (src / "demos").mkdir()
    (src / "tests").mkdir()

    (src / "rs_geofit.m").write_text("function rs_geofit()\n")
    (src / "Contents.m").write_text("% rs: contents\n")
    (src / "utils" / "grmscmdt.m").write_text("function grmscmdt()\n")
    (src / "utils" / "Contents.m").write_text("% utils: contents\n")
    (src / "demos" / "rs_toygeom_sim.m").write_text("% a demo\n")
    (src / "tests" / "rs_geofit_test.m").write_text("% a test\n")
    return src


def test_source_files_finds_functions_at_both_levels(tmp_path):
    src = build_src(tmp_path)
    names = [p.name for p in source_files(src)]
    assert names == ["rs_geofit.m", "grmscmdt.m"]


def test_source_files_skips_demos_and_tests(tmp_path):
    # A demo has its own page, rendered from its capture, and a second page would
    # make links by name ambiguous. Tests are not public API.
    src = build_src(tmp_path)
    names = [p.name for p in source_files(src)]
    assert "rs_toygeom_sim.m" not in names
    assert "rs_geofit_test.m" not in names


def test_source_files_skips_excluded_folders_whatever_their_case(tmp_path):
    # Windows keeps the case a folder was created with, and matching is case
    # insensitive there, so a checkout could present "Demos" rather than "demos".
    src = tmp_path / "src"
    (src / "Demos").mkdir(parents=True)
    (src / "TESTS").mkdir()
    (src / "rs_geofit.m").write_text("function rs_geofit()\n")
    (src / "Demos" / "rs_toygeom_sim.m").write_text("% a demo\n")
    (src / "TESTS" / "rs_geofit_test.m").write_text("% a test\n")

    assert [p.name for p in source_files(src)] == ["rs_geofit.m"]


def test_source_files_skips_contents_files(tmp_path):
    src = build_src(tmp_path)
    assert not any(p.stem.lower() == "contents" for p in source_files(src))


def test_page_text_is_the_mkdocstrings_directive():
    assert page_text("rs_geofit") == (
        "::: rs_geofit\n"
        "    options:\n"
        "      heading_level: 1\n"
    )


def test_clear_pages_removes_pages_of_a_previous_run(tmp_path):
    out = tmp_path / "mfiles"
    out.mkdir()
    (out / "rs_geofit.md").write_text("x")
    (out / "rs_gone.md").write_text("x")

    assert clear_pages(out) == 2
    assert list(out.glob("*.md")) == []


def test_clear_pages_leaves_the_committed_demo_pages(tmp_path):
    out = tmp_path / "mfiles"
    (out / "demos").mkdir(parents=True)
    (out / "rs_geofit.md").write_text("x")
    demo_page = out / "demos" / "rs_toygeom_sim.md"
    demo_page.write_text("committed")

    clear_pages(out)

    assert demo_page.read_text() == "committed"


def test_clear_pages_on_a_missing_folder(tmp_path):
    assert clear_pages(tmp_path / "absent") == 0


def test_write_pages_creates_one_page_per_function(tmp_path):
    src = build_src(tmp_path)
    out = tmp_path / "mfiles"

    written = write_pages(src, out)

    assert sorted(p.name for p in written) == ["grmscmdt.md", "rs_geofit.md"]
    assert (out / "rs_geofit.md").read_text() == page_text("rs_geofit")


def test_write_pages_drops_the_page_of_a_deleted_function(tmp_path):
    src = build_src(tmp_path)
    out = tmp_path / "mfiles"
    write_pages(src, out)

    (src / "rs_geofit.m").unlink()
    write_pages(src, out)

    assert not (out / "rs_geofit.md").exists()
    assert (out / "grmscmdt.md").exists()


def test_write_pages_is_repeatable(tmp_path):
    src = build_src(tmp_path)
    out = tmp_path / "mfiles"

    first = {p.name: p.read_text() for p in write_pages(src, out)}
    second = {p.name: p.read_text() for p in write_pages(src, out)}

    assert first == second
