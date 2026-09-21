# -*- coding: utf-8 -*-
"""
Unit tests for matlab_to_markdown, written as plain functions.
"""

import pytest

from matlab_to_markdown import (
    SNAPSHOT_ALL,
    SNAPSHOT_CURRENT,
    SNAPSHOT_NONE,
    code_chunk_snapshots,
    code_chunk_texts,
    is_prose_comment,
    parse_blocks,
    parse_matlab_to_markdown,
    process_first_line,
    render_capture,
    snapshot_mode,
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


# --- %#demo-snapshot -----------------------------------------------------

def test_snapshot_mode_of_a_line_without_directive_is_none():
    assert snapshot_mode("plot(x, y);") == SNAPSHOT_NONE


def test_bare_snapshot_directive_means_current_figure():
    assert snapshot_mode("plot(x, y);   %#demo-snapshot") == SNAPSHOT_CURRENT


def test_snapshot_all_argument_ignores_case_and_spaces():
    assert snapshot_mode("title('t');  %#demo-snapshot:  ALL ") == SNAPSHOT_ALL


def test_snapshot_with_unknown_argument_is_an_error():
    with pytest.raises(ValueError, match="line 7"):
        snapshot_mode("plot(x);  %#demo-snapshot: everything", line_number=7)


def test_similar_word_is_not_a_snapshot_directive():
    # \b in the pattern: a longer word is not the directive
    assert snapshot_mode("x = 1;  %#demo-snapshots") == SNAPSHOT_NONE


def test_snapshot_directive_is_stripped_from_rendered_code():
    source = "% t: d\nplot(1:3);   %#demo-snapshot: all\n"
    md = parse_matlab_to_markdown(source, REG)
    assert "demo-snapshot" not in md
    assert "plot(1:3);" in md


def test_snapshot_is_recorded_on_its_chunk_only():
    source = (
        "% t: d\n"
        "figure; plot(1:3);\n"
        "% draw on it\n"
        "hold on; plot(3:-1:1);   %#demo-snapshot\n"
        "% and once more\n"
        "title('t');   %#demo-snapshot: all\n"
    )
    blocks = parse_blocks(source)
    assert code_chunk_snapshots(blocks) == [SNAPSHOT_NONE, SNAPSHOT_CURRENT,
                                            SNAPSHOT_ALL]


def test_snapshots_and_chunks_have_the_same_length():
    source = "% t: d\nx = 1;\n%\n\n%\ny = 2;   %#demo-snapshot\n"
    blocks = parse_blocks(source)
    assert len(code_chunk_snapshots(blocks)) == len(code_chunk_texts(blocks)) == 2


def test_all_wins_over_current_within_one_chunk():
    source = "% t: d\nx = 1;   %#demo-snapshot\ny = 2;   %#demo-snapshot: all\n"
    assert code_chunk_snapshots(parse_blocks(source)) == [SNAPSHOT_ALL]


def test_whole_line_snapshot_inside_code_attaches_to_that_code():
    source = "% t: d\nx = 1;\n%#demo-snapshot\ny = 2;\n"
    blocks = parse_blocks(source)
    assert code_chunk_snapshots(blocks) == [SNAPSHOT_CURRENT]
    assert code_chunk_texts(blocks) == ["x = 1;\n\ny = 2;"]


def test_whole_line_snapshot_after_a_comment_is_an_error():
    # It would belong to no chunk, and silently exporting nothing is worse.
    source = "% t: d\nx = 1;\n% a comment\n%#demo-snapshot\ny = 2;\n"
    with pytest.raises(ValueError, match="line 4"):
        parse_blocks(source)


def test_snapshot_does_not_leak_into_the_next_chunk():
    source = "% t: d\nx = 1;   %#demo-snapshot\n% next\ny = 2;\n"
    assert code_chunk_snapshots(parse_blocks(source)) == [SNAPSHOT_CURRENT,
                                                          SNAPSHOT_NONE]


def test_directive_mentioned_in_prose_stays_in_the_text():
    source = (
        "% t: d\n"
        "x = 1;\n"
        "% end a code line with %#demo-snapshot to export the figure again\n"
        "y = 2;\n"
    )
    blocks = parse_blocks(source)
    md = parse_matlab_to_markdown(source, REG)

    assert code_chunk_snapshots(blocks) == [SNAPSHOT_NONE, SNAPSHOT_NONE]
    assert "with %#demo-snapshot to export the figure again" in md


def test_is_prose_comment_tells_prose_from_whole_line_directives():
    assert is_prose_comment("% some prose")
    assert is_prose_comment("   % indented prose with %#demo-snapshot inside")
    assert not is_prose_comment("%#demo-snapshot")
    assert not is_prose_comment("plot(x);   % a trailing comment")
