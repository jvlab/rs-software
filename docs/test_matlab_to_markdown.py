# -*- coding: utf-8 -*-
"""
Unit tests for matlab_to_markdown, written as plain functions.
"""

from matlab_to_markdown import (
    code_chunk_texts,
    parse_blocks,
    parse_matlab_to_markdown,
    process_first_line,
    render_capture,
)

REG = {"rs_knit_coordsets": "rs_knit_coordsets"}


def test_first_line_becomes_heading():
    assert process_first_line("mydemo: does a thing") == "# mydemo\nDoes a thing"


def test_parse_blocks_alternates_text_and_code():
    source = "% title: desc\nx = 1;\n% a comment\ny = 2;\n"
    kinds = [b["kind"] for b in parse_blocks(source)]
    assert kinds == ["text", "code", "text", "code"]


def test_code_chunks_are_maximal_runs_between_comments():
    source = "% t: d\na = 1;\nb = 2;\n% mid\nc = 3;\n"
    chunks = code_chunk_texts(parse_blocks(source))
    assert chunks == ["a = 1;\nb = 2;", "c = 3;"]


def test_blank_only_code_run_is_not_a_chunk():
    # A comment, then only blank lines, then a comment: no code chunk exists.
    source = "% one: d\n\n% two\n"
    assert code_chunk_texts(parse_blocks(source)) == []


def test_render_without_manifest_has_no_output_block():
    source = "% t: d\nx = 1;\n"
    md = parse_matlab_to_markdown(source, REG)
    assert "```matlab\nx = 1;\n```" in md
    assert "Output:" not in md


def test_manifest_splices_output_after_matching_chunk():
    source = "% t: d\na = 1;\n% mid\nb = 2;\n"
    manifest = {1: {"text": "hello\n", "figures": [], "error": ""}}
    md = parse_matlab_to_markdown(source, REG, manifest=manifest)
    # Output attaches to chunk 1 (b = 2;), not chunk 0 (a = 1;).
    assert "```matlab\nb = 2;\n```\n\nOutput:\n\n```text\nhello\n```" in md
    assert md.count("Output:") == 1


def test_render_capture_emits_output_error_and_figures():
    entry = {"text": "line1\n", "figures": ["f.png"], "error": "boom"}
    out = render_capture(entry)
    assert "```text\nline1\n```" in out
    assert "Error:" in out and "boom" in out
    assert "![f](../../images/demos/f.png)" in out


def test_render_capture_empty_entry_is_empty():
    assert render_capture({"text": "", "figures": [], "error": ""}) == ""


def test_demo_input_directive_is_stripped_from_code():
    source = "% t: d\nn = getinp('c', 'd', [1 3], 1);   %#demo-input: 2\n"
    md = parse_matlab_to_markdown(source, REG)
    assert "%#demo-input" not in md
    assert "getinp('c', 'd', [1 3], 1);" in md


def test_whole_line_directive_is_dropped_not_shown_as_text():
    source = "% t: d\nx = 1;\n%#demo-input: 9\ny = 2;\n"
    md = parse_matlab_to_markdown(source, REG)
    assert "demo-input" not in md
    # x and y still render as code
    assert "x = 1;" in md and "y = 2;" in md
