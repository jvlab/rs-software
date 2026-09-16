# -*- coding: utf-8 -*-
"""
Unit tests for render_demo_pages, written as plain functions.

Each test builds its own demo source, manifest and output directories in a
tmp_path, so nothing depends on a MATLAB run having happened.
"""

import hashlib
import json

from render_demo_pages import (
    clear_figures,
    figure_pattern,
    index_entry,
    load_index,
    render_demo,
    save_index,
    source_hash,
)

DEMO_SOURCE = """%demo_name: a demo used by the tests
%
% first comment
disp('one')
% second comment
disp('two')
"""


def write_manifest(build_dir, name, entries):
    build_dir.mkdir(parents=True, exist_ok=True)
    (build_dir / f"{name}.manifest.json").write_text(json.dumps(entries))


def test_source_hash_matches_sha256_of_the_file(tmp_path):
    demo = tmp_path / "demo.m"
    demo.write_text(DEMO_SOURCE)
    assert source_hash(demo) == hashlib.sha256(DEMO_SOURCE.encode()).hexdigest()


def test_source_hash_changes_when_the_demo_changes(tmp_path):
    demo = tmp_path / "demo.m"
    demo.write_text(DEMO_SOURCE)
    before = source_hash(demo)
    demo.write_text(DEMO_SOURCE + "disp('three')\n")
    assert source_hash(demo) != before


def test_source_hash_ignores_line_endings(tmp_path):
    # A Windows checkout has CRLF where Linux and macOS have LF, and the same
    # demo must hash the same either way, or the freshness gate fires on every
    # demo after a capture made on the other platform.
    lf = tmp_path / "lf.m"
    crlf = tmp_path / "crlf.m"
    lf.write_bytes(DEMO_SOURCE.encode())
    crlf.write_bytes(DEMO_SOURCE.replace("\n", "\r\n").encode())

    assert source_hash(crlf) == source_hash(lf)


def test_source_hash_still_sees_a_real_edit_in_a_crlf_file(tmp_path):
    original = tmp_path / "a.m"
    edited = tmp_path / "b.m"
    original.write_bytes(DEMO_SOURCE.replace("\n", "\r\n").encode())
    edited.write_bytes((DEMO_SOURCE + "disp('x')\n").replace("\n", "\r\n").encode())

    assert source_hash(edited) != source_hash(original)


def test_pages_and_index_are_written_with_unix_line_endings(tmp_path):
    demo = tmp_path / "my_demo.m"
    demo.write_text(DEMO_SOURCE)
    build_dir = tmp_path / "build"
    write_manifest(build_dir, "my_demo", [
        {"id": 0, "text": "one\n", "figures": [], "error": ""},
    ])
    index_path = tmp_path / "index.json"

    page_path, _ = render_demo(demo, {}, tmp_path / "pages", build_dir)
    save_index({"my_demo": {"figures": 0}}, index_path)

    assert b"\r\n" not in page_path.read_bytes()
    assert b"\r\n" not in index_path.read_bytes()


def test_figure_pattern_matches_this_demo_only():
    pattern = figure_pattern("rs_knit_coordsets_demo")
    assert pattern == "rs_knit_coordsets_demo_chunk*_fig*.png"


def test_clear_figures_removes_only_this_demos_images(tmp_path):
    keep = tmp_path / "other_demo_chunk01_fig1.png"
    drop = tmp_path / "mine_chunk01_fig1.png"
    also_drop = tmp_path / "mine_chunk07_fig3.png"
    for path in (keep, drop, also_drop):
        path.write_bytes(b"png")

    removed = clear_figures("mine", fig_dir=tmp_path)

    assert removed == 2
    assert keep.exists()
    assert not drop.exists()
    assert not also_drop.exists()


def test_clear_figures_on_a_demo_with_no_images(tmp_path):
    assert clear_figures("never_captured", fig_dir=tmp_path) == 0


def test_index_entry_records_hash_figures_and_no_error(tmp_path):
    demo = tmp_path / "demo.m"
    demo.write_text(DEMO_SOURCE)
    manifest = {
        0: {"id": 0, "text": "", "figures": ["a.png", "b.png"], "error": ""},
        1: {"id": 1, "text": "out", "figures": ["c.png"], "error": ""},
    }

    entry = index_entry(demo, manifest, captured_at="2026-09-16T00:00:00+00:00")

    assert entry["source_sha256"] == source_hash(demo)
    assert entry["figures"] == 3
    assert entry["error"] is None
    assert entry["captured_at"] == "2026-09-16T00:00:00+00:00"


def test_index_entry_keeps_the_first_error(tmp_path):
    demo = tmp_path / "demo.m"
    demo.write_text(DEMO_SOURCE)
    manifest = {
        0: {"id": 0, "text": "", "figures": [], "error": "first failure"},
        1: {"id": 1, "text": "", "figures": [], "error": "later failure"},
    }

    assert index_entry(demo, manifest)["error"] == "first failure"


def test_index_round_trips_and_is_sorted(tmp_path):
    index_path = tmp_path / "index.json"
    save_index({"zebra": {"figures": 1}, "alpha": {"figures": 2}}, index_path)

    assert list(load_index(index_path)) == ["alpha", "zebra"]
    assert list(json.loads(index_path.read_text())) == ["alpha", "zebra"]


def test_load_index_of_a_missing_file_is_empty(tmp_path):
    assert load_index(tmp_path / "absent.json") == {}


def test_render_demo_splices_captured_output_and_figures(tmp_path):
    demo = tmp_path / "my_demo.m"
    demo.write_text(DEMO_SOURCE)
    build_dir = tmp_path / "build"
    write_manifest(build_dir, "my_demo", [
        {"id": 0, "text": "one\n", "figures": ["my_demo_chunk01_fig1.png"],
         "error": ""},
    ])

    page_path, manifest = render_demo(demo, {}, tmp_path / "pages", build_dir)
    page = page_path.read_text()

    assert page_path.name == "my_demo.md"
    assert manifest
    assert "one" in page
    assert "my_demo_chunk01_fig1.png" in page


def test_render_demo_without_a_manifest_writes_a_code_only_page(tmp_path):
    demo = tmp_path / "my_demo.m"
    demo.write_text(DEMO_SOURCE)

    page_path, manifest = render_demo(demo, {}, tmp_path / "pages",
                                      tmp_path / "build")
    page = page_path.read_text()

    assert manifest == {}
    assert "disp('one')" in page
    assert "images/demos" not in page


def test_render_demo_reports_an_error_from_the_capture(tmp_path):
    demo = tmp_path / "my_demo.m"
    demo.write_text(DEMO_SOURCE)
    build_dir = tmp_path / "build"
    write_manifest(build_dir, "my_demo", [
        {"id": 0, "text": "", "figures": [], "error": "Undefined function 'foo'."},
    ])

    page_path, _ = render_demo(demo, {}, tmp_path / "pages", build_dir)

    assert "Undefined function 'foo'." in page_path.read_text()
