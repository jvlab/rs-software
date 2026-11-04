# -*- coding: utf-8 -*-
"""
Unit tests for the %#demo-include directive, written as plain functions.

Each test writes small demo and script files into a tmp_path, so the expected
expansion can be stated line by line.
"""

import json

import pytest

from build_demo_specs import demo_paths
from demo_capture import build_spec, extract_demo_inputs
from demo_include import (
    expand_includes,
    expanded_source,
    included_names,
    is_include_only,
    split_header,
)
from matlab_to_markdown import code_chunk_texts, parse_blocks, parse_matlab_to_markdown
from render_demo_pages import source_hash

SHARED = """%shared_sim: a shared simulation step
% explains the parameters
%   See also: RS_GEOFIT.

%#demo-include-only

%build the data
x = a + 1;
%show it
disp(x)
"""

DEMO = """%scenario_one: a scenario
%
clear;
a = 1;
shared_sim; %#demo-include
%after the simulation
disp('done')
"""


def write_files(directory, files):
    directory.mkdir(parents=True, exist_ok=True)
    for name, text in files.items():
        (directory / f"{name}.m").write_text(text)
    return directory


# --- recognizing the directives -----------------------------------------------

def test_include_only_is_found_alone_on_a_line():
    assert is_include_only(SHARED)
    assert not is_include_only(DEMO)


def test_include_only_mentioned_in_prose_does_not_count():
    assert not is_include_only("% add %#demo-include-only to a shared script\nx=1;\n")


def test_source_without_includes_is_returned_unchanged(tmp_path):
    source = "%a: b\nx = 1; % a comment\n\n"
    assert expand_includes(source, tmp_path) is source


def test_include_mentioned_in_prose_is_not_expanded(tmp_path):
    source = "% write 'name; %#demo-include' to paste a script\nx = 1;\n"
    assert expand_includes(source, tmp_path) == source


@pytest.mark.parametrize("line", [
    "  shared_sim; %#demo-include",          # indented, inside a block
    "x = shared_sim; %#demo-include",        # not a bare call
    "shared_sim(3); %#demo-include",         # a function call with arguments
])
def test_malformed_include_line_is_refused(tmp_path, line):
    write_files(tmp_path, {"shared_sim": SHARED})
    with pytest.raises(ValueError, match="only calls a script"):
        expand_includes(line + "\n", tmp_path, ("demo",))


def test_include_without_semicolon_is_accepted(tmp_path):
    write_files(tmp_path, {"shared_sim": SHARED})
    expanded = expand_includes("shared_sim %#demo-include\n", tmp_path)
    assert "x = a + 1;" in expanded


def test_missing_included_script_is_reported(tmp_path):
    with pytest.raises(ValueError, match="not found"):
        expand_includes("nowhere; %#demo-include\n", tmp_path, ("demo",))


def test_include_cycle_is_reported(tmp_path):
    write_files(tmp_path, {
        "one": "%one: x\n\ntwo; %#demo-include\n",
        "two": "%two: x\n\none; %#demo-include\n",
    })
    with pytest.raises(ValueError, match="one --> two --> one"):
        expanded_source(tmp_path / "one.m")


# --- the expansion --------------------------------------------------------------

def test_split_header_stops_at_the_first_blank_line():
    header, rest = split_header(SHARED)
    assert header == [
        "%shared_sim: a shared simulation step",
        "% explains the parameters",
        "%   See also: RS_GEOFIT.",
    ]
    assert rest[0] == ""


def test_split_header_stops_at_code():
    header, rest = split_header("%a: b\nx = 1;\n")
    assert header == ["%a: b"]
    assert rest == ["x = 1;"]


def test_expansion_wraps_the_script_in_markers(tmp_path):
    write_files(tmp_path, {"shared_sim": SHARED, "scenario_one": DEMO})
    lines = expanded_source(tmp_path / "scenario_one.m").splitlines()

    begin = lines.index("%#demo-include-begin: shared_sim")
    body = lines.index("%#demo-include-body: shared_sim")
    end = lines.index("%#demo-include-end: shared_sim")
    assert lines[begin - 1] == "a = 1;"
    assert lines[begin + 1:body] == SHARED.splitlines()[:3]
    assert lines[body + 1:end] == SHARED.splitlines()[3:]
    assert lines[end + 1] == "%after the simulation"
    assert "shared_sim; %#demo-include" not in lines


def test_crlf_files_expand_like_lf_files(tmp_path):
    lf = write_files(tmp_path / "lf", {"shared_sim": SHARED, "scenario_one": DEMO})
    crlf = tmp_path / "crlf"
    crlf.mkdir()
    for name, text in {"shared_sim": SHARED, "scenario_one": DEMO}.items():
        (crlf / f"{name}.m").write_bytes(text.replace("\n", "\r\n").encode())
    assert expanded_source(crlf / "scenario_one.m") == expanded_source(lf / "scenario_one.m")


def test_nested_includes_are_expanded_and_listed(tmp_path):
    write_files(tmp_path, {
        "inner": "%inner: x\n%#demo-include-only\ny = 2;\n",
        "outer": "%outer: x\n%#demo-include-only\ninner; %#demo-include\n",
        "demo": "%demo: x\nouter; %#demo-include\nouter; %#demo-include\n",
    })
    expanded = expanded_source(tmp_path / "demo.m")
    assert expanded.count("y = 2;") == 2
    assert included_names(expanded) == ["outer", "inner"]


# --- parsing and rendering -------------------------------------------------------

def test_markers_become_include_blocks_and_carry_no_chunk(tmp_path):
    write_files(tmp_path, {"shared_sim": SHARED, "scenario_one": DEMO})
    blocks = parse_blocks(expanded_source(tmp_path / "scenario_one.m"))

    events = [(b["event"], b["name"]) for b in blocks if b["kind"] == "include"]
    assert events == [("begin", "shared_sim"), ("body", "shared_sim"), ("end", "shared_sim")]
    assert code_chunk_texts(blocks) == ["clear;\na = 1;", "x = a + 1;", "disp(x)", "disp('done')"]


def test_page_folds_the_header_and_shows_the_body(tmp_path):
    write_files(tmp_path, {"shared_sim": SHARED, "scenario_one": DEMO})
    page = parse_matlab_to_markdown(expanded_source(tmp_path / "scenario_one.m"), {})

    assert page.startswith("# scenario_one\nA scenario")
    assert "### Included script: `shared_sim`" in page
    assert "<summary>shared_sim: a shared simulation step</summary>" in page
    details = page[page.index("<details"):page.index("</details>")]
    assert "explains the parameters" in details
    assert "build the data" not in details
    assert "```matlab\nx = a + 1;\n```" in page
    assert "*End of included script `shared_sim`.*" in page
    assert "%#demo-include" not in page
    assert page.index("End of included") < page.index("after the simulation")


def test_manifest_entries_land_under_the_included_chunks(tmp_path):
    write_files(tmp_path, {"shared_sim": SHARED, "scenario_one": DEMO})
    manifest = {1: {"text": "     2\n", "figures": ["scenario_one_chunk01_fig1.png"]}}
    page = parse_matlab_to_markdown(expanded_source(tmp_path / "scenario_one.m"), {}, manifest)

    code = page.index("```matlab\nx = a + 1;\n```")
    output = page.index("Output:")
    figure = page.index("scenario_one_chunk01_fig1.png")
    assert code < output < figure < page.index("```matlab\ndisp(x)")


def test_header_without_body_lines_renders_a_bare_summary(tmp_path):
    write_files(tmp_path, {"tiny": "%tiny: does little\n\nz = 0;\n"})
    page = parse_matlab_to_markdown(expand_includes("%d: x\ntiny; %#demo-include\n", tmp_path), {})
    assert '<details class="demo-include" markdown="1">\n<summary>tiny: does little</summary>\n</details>' in page


# --- capture specs, hashes and demo selection --------------------------------------

def test_spec_holds_the_included_chunks_and_answers(tmp_path):
    shared = SHARED + "n = input('n? '); %#demo-input: 3\n"
    demo = DEMO + "m = input('m? '); %#demo-input: 4\n"
    write_files(tmp_path, {"shared_sim": shared, "scenario_one": demo})
    spec = build_spec(tmp_path / "scenario_one.m", tmp_path / "fig",
                      tmp_path / "s.json", tmp_path / "m.json")

    assert [chunk["code"] for chunk in spec["chunks"]][1:3] == [
        "x = a + 1;", "disp(x)\nn = input('n? ');"]
    assert spec["answers"] == ["3", "4"]
    assert json.loads((tmp_path / "s.json").read_text()) == spec
    assert extract_demo_inputs(expanded_source(tmp_path / "scenario_one.m")) == ["3", "4"]


def test_editing_an_included_script_changes_the_demo_hash(tmp_path):
    write_files(tmp_path, {"shared_sim": SHARED, "scenario_one": DEMO})
    before = source_hash(tmp_path / "scenario_one.m")
    write_files(tmp_path, {"shared_sim": SHARED + "disp(1)\n"})
    assert source_hash(tmp_path / "scenario_one.m") != before


def test_include_only_scripts_are_not_demos(tmp_path):
    write_files(tmp_path, {"shared_sim": SHARED, "scenario_one": DEMO, "Contents": "%x\n"})
    assert [p.rsplit("/", 1)[-1] for p in demo_paths(demo_dir=tmp_path)] == ["scenario_one.m"]


def test_naming_an_include_only_script_selects_its_includers(tmp_path):
    write_files(tmp_path, {
        "shared_sim": SHARED,
        "scenario_one": DEMO,
        "scenario_two": DEMO.replace("one", "two"),
        "unrelated": "%unrelated: x\ny = 1;\n",
    })
    selected = demo_paths(["shared_sim", "scenario_one"], demo_dir=tmp_path)
    assert [p.rsplit("/", 1)[-1] for p in selected] == ["scenario_one.m", "scenario_two.m"]


def test_script_without_header_gets_only_a_heading(tmp_path):
    write_files(tmp_path, {"bare": "z = 0;\n"})
    page = parse_matlab_to_markdown(expand_includes("%d: x\nbare; %#demo-include\n", tmp_path), {})
    assert "### Included script: `bare`\n\n```matlab\nz = 0;\n```" in page
    assert "<details" not in page


def test_page_registry_leaves_out_include_only_scripts(tmp_path):
    from render_demo_pages import page_registry
    write_files(tmp_path, {"rs_toygeom_scenarioA": DEMO, "rs_toygeom_sim": SHARED})
    registry = page_registry(tmp_path)
    assert "rs_toygeom_sim" not in registry
    assert "rs_geofit" in registry
