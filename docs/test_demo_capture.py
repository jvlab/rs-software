# -*- coding: utf-8 -*-
"""
Unit tests for demo_capture, written as plain functions.

Cases are derived from first principles: a known demo snippet or manifest maps
to a known, hand-computed result.
"""

import json

from demo_capture import build_spec, extract_demo_inputs, load_manifest


# --- extract_demo_inputs -------------------------------------------------

def test_no_directives_returns_empty_list():
    source = "x = 1 + 1;\ndisp(x)\n"
    assert extract_demo_inputs(source) == []


def test_single_answer():
    source = "n = getinp('choice', 'd', [1 3], 1);   %#demo-input: 2\n"
    assert extract_demo_inputs(source) == ["2"]


def test_empty_answer_means_default():
    source = "k = getinp('bins', 'd', [0 99]);   %#demo-input:\n"
    assert extract_demo_inputs(source) == [""]


def test_answers_returned_in_source_order():
    source = (
        "a = getinp('first', 'd', [0 9], 0);    %#demo-input: 0\n"
        "b = getinp('second', 'd', [0 1]);      %#demo-input: 1\n"
        "c = getinp('third', 'd', [0 9], 3);    %#demo-input:\n"
    )
    assert extract_demo_inputs(source) == ["0", "1", ""]


def test_surrounding_whitespace_is_stripped():
    source = "x = getinp('v', 'd', [0 99]);   %#demo-input:    42   \n"
    assert extract_demo_inputs(source) == ["42"]


def test_plain_comment_mentioning_input_is_not_matched():
    source = "% the user will input a number here\n"
    assert extract_demo_inputs(source) == []


def test_vector_answer_is_returned_verbatim():
    source = "v = getinp('dims', 'd', [2 3], 3);   %#demo-input: [2 3]\n"
    assert extract_demo_inputs(source) == ["[2 3]"]


# --- build_spec ----------------------------------------------------------

def _write_demo(tmp_path, text):
    demo = tmp_path / "mydemo.m"
    demo.write_text(text, encoding="utf-8")
    return demo


def test_build_spec_lists_chunks_and_answers(tmp_path):
    demo = _write_demo(
        tmp_path,
        "% mydemo: a tiny demo\n"
        "x = 1 + 1;\n"
        "%\n"
        "n = getinp('choice', 'd', [1 3], 1);   %#demo-input: 2\n"
        "disp(n)\n",
    )
    spec_path = tmp_path / "mydemo.spec.json"
    spec = build_spec(
        demo,
        fig_dir=tmp_path / "figs",
        spec_path=spec_path,
        manifest_path=tmp_path / "mydemo.manifest.json",
        seed=0,
    )

    assert spec["name"] == "mydemo"
    assert spec["answers"] == ["2"]
    assert spec["seed"] == 0
    # Two code runs separated by the "%" comment become two chunks, indexed 0,1.
    assert [c["id"] for c in spec["chunks"]] == [0, 1]
    assert spec["chunks"][0]["code"] == "x = 1 + 1;"
    assert "getinp" in spec["chunks"][1]["code"]
    # The file was actually written and is valid JSON.
    assert json.loads(spec_path.read_text(encoding="utf-8"))["name"] == "mydemo"


def test_build_spec_omits_seed_when_none(tmp_path):
    demo = _write_demo(tmp_path, "% d: x\nx = 1;\n")
    spec = build_spec(
        demo,
        fig_dir=tmp_path / "figs",
        spec_path=tmp_path / "d.spec.json",
        manifest_path=tmp_path / "d.manifest.json",
        seed=None,
    )
    assert "seed" not in spec


# --- load_manifest -------------------------------------------------------

def test_load_missing_manifest_returns_empty(tmp_path):
    assert load_manifest(tmp_path / "does_not_exist.json") == {}


def test_load_manifest_keys_by_int_index(tmp_path):
    manifest = tmp_path / "m.json"
    manifest.write_text(json.dumps([
        {"id": 0, "text": "out0", "figures": [], "error": ""},
        {"id": 1, "text": "", "figures": ["a.png"], "error": ""},
    ]), encoding="utf-8")
    loaded = load_manifest(manifest)
    assert set(loaded.keys()) == {0, 1}
    assert loaded[0]["text"] == "out0"
    assert loaded[1]["figures"] == ["a.png"]


def test_load_manifest_accepts_single_object(tmp_path):
    # MATLAB jsonencode emits a bare object, not an array, for one entry.
    manifest = tmp_path / "m.json"
    manifest.write_text(json.dumps(
        {"id": 0, "text": "only", "figures": [], "error": ""}
    ), encoding="utf-8")
    loaded = load_manifest(manifest)
    assert loaded[0]["text"] == "only"


def test_load_manifest_skips_malformed_id(tmp_path):
    # MATLAB can emit an unassigned slot as {"id": [], ...}; it must be skipped,
    # not crash the loader.
    manifest = tmp_path / "m.json"
    manifest.write_text(json.dumps([
        {"id": 0, "text": "ok", "figures": [], "error": ""},
        {"id": [], "text": [], "figures": [], "error": []},
        {"id": 2, "text": "also ok", "figures": [], "error": ""},
    ]), encoding="utf-8")
    loaded = load_manifest(manifest)
    assert set(loaded.keys()) == {0, 2}
    assert loaded[2]["text"] == "also ok"
