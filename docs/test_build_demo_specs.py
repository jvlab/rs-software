# -*- coding: utf-8 -*-
"""
Unit tests for build_demo_specs, written as plain functions.

The selection logic is pure: a set of demo files on disk plus a list of
requested names maps to a known list of paths.
"""

import pytest

import build_demo_specs
from build_demo_specs import clear_specs, demo_paths


def test_no_names_returns_every_demo_but_contents():
    demos = demo_paths()
    names = [path.rsplit("/", 1)[-1] for path in demos]
    assert "rs_knit_coordsets_demo.m" in names
    assert "Contents.m" not in names


def test_names_select_a_subset():
    selected = demo_paths(["rs_knit_coordsets_demo"])
    assert len(selected) == 1
    assert selected[0].endswith("rs_knit_coordsets_demo.m")
    assert selected[0] in demo_paths()


def test_name_may_be_given_as_a_path():
    by_name = demo_paths(["rs_knit_coordsets_demo"])
    by_path = demo_paths(["src/demos/rs_knit_coordsets_demo.m"])
    assert by_name == by_path


def test_names_are_returned_in_the_requested_order():
    wanted = ["rs_knit_coordsets_demo", "rs_disp_coordsets_demo"]
    got = demo_paths(wanted)
    assert [path.rsplit("/", 1)[-1] for path in got] == [
        f"{name}.m" for name in wanted
    ]


def test_unknown_name_is_an_error():
    with pytest.raises(SystemExit):
        demo_paths(["no_such_demo"])


def test_clear_specs_removes_only_specs(tmp_path, monkeypatch):
    monkeypatch.setattr(build_demo_specs, "BUILD_DIR", tmp_path)
    (tmp_path / "a.spec.json").write_text("{}")
    (tmp_path / "a.manifest.json").write_text("[]")
    clear_specs()
    assert not (tmp_path / "a.spec.json").exists()
    assert (tmp_path / "a.manifest.json").exists()
