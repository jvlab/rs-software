# -*- coding: utf-8 -*-
"""
Unit tests for update_demo_docs, written as plain functions.

The orchestration runs subprocesses, but the command construction is pure and
testable from first principles: a known executable and command map to a known
argument list.
"""

import sys

import pytest

from update_demo_docs import (
    ALL_FLAG,
    DONE_NAME,
    MATLAB_CAPTURE_COMMAND,
    SPEC_SCRIPT,
    capture_finished,
    choose_demos,
    clear_done,
    done_path,
    matlab_argv,
    specs_argv,
    wait_for_capture,
)


def test_specs_argv_defaults_to_current_interpreter():
    assert specs_argv() == [sys.executable, SPEC_SCRIPT]


def test_specs_argv_uses_given_interpreter():
    assert specs_argv("python3") == ["python3", "docs/build_demo_specs.py"]


def test_matlab_argv_default_command():
    assert matlab_argv("matlab", platform="linux") == [
        "matlab", "-nodisplay", "-batch", MATLAB_CAPTURE_COMMAND
    ]


def test_matlab_argv_uses_batch_flag_and_given_command():
    assert matlab_argv("/opt/matlab/bin/matlab", "run_all('x')",
                       platform="linux") == [
        "/opt/matlab/bin/matlab", "-nodisplay", "-batch", "run_all('x')"
    ]


def test_matlab_argv_adds_nodisplay_on_macos():
    # Without it, an X display present at launch makes every figure export black.
    assert "-nodisplay" in matlab_argv("matlab", platform="darwin")


def test_matlab_argv_waits_and_omits_nodisplay_on_windows():
    # Windows MATLAB rejects -nodisplay and renders correctly without it, but
    # the matlab command returns before the capture finishes without -wait.
    assert matlab_argv("matlab.exe", "run_all('x')", platform="win32") == [
        "matlab.exe", "-wait", "-batch", "run_all('x')"
    ]


def test_matlab_argv_puts_flags_before_batch():
    # -batch consumes the rest of the command line, so flags must precede it.
    argv = matlab_argv("matlab", platform="linux")
    assert argv.index("-nodisplay") < argv.index("-batch")
    assert argv[-1] == MATLAB_CAPTURE_COMMAND


def test_matlab_capture_command_targets_run_all_and_shadow_path():
    # The command must put the input() shadow on the path and call run_all.
    assert "addpath('capture/matlab')" in MATLAB_CAPTURE_COMMAND
    assert "run_all('build/capture')" in MATLAB_CAPTURE_COMMAND


def test_specs_argv_appends_demo_names():
    assert specs_argv("python3", ["rs_knit_coordsets_demo"]) == [
        "python3", SPEC_SCRIPT, "rs_knit_coordsets_demo"
    ]


def test_specs_argv_keeps_demo_order():
    demos = ["rs_toygeom_scenarioA", "rs_knit_coordsets_demo"]
    assert specs_argv("python3", demos)[2:] == demos


def test_done_path_sits_next_to_the_manifests(tmp_path):
    assert done_path(tmp_path) == tmp_path / DONE_NAME


def test_capture_finished_follows_the_marker(tmp_path):
    assert not capture_finished(tmp_path)
    done_path(tmp_path).write_text("run_all finished 1 demo(s)\n")
    assert capture_finished(tmp_path)


def test_clear_done_removes_the_marker_of_a_previous_run(tmp_path):
    done_path(tmp_path).write_text("old run\n")

    assert clear_done(tmp_path) is True
    assert not capture_finished(tmp_path)


def test_clear_done_with_no_marker_reports_nothing_removed(tmp_path):
    assert clear_done(tmp_path) is False


def test_wait_for_capture_returns_at_once_when_already_finished(tmp_path):
    done_path(tmp_path).write_text("done\n")
    calls = []

    polls = wait_for_capture(tmp_path, sleep=calls.append)

    assert polls == 0
    assert calls == []


def test_wait_for_capture_polls_until_the_marker_appears(tmp_path):
    # This is the Windows case: MATLAB is still running, and rendering now would
    # write pages with code and no output.
    calls = []

    def sleep(seconds):
        calls.append(seconds)
        if len(calls) == 3:
            done_path(tmp_path).write_text("done\n")

    polls = wait_for_capture(tmp_path, poll_seconds=0.5, sleep=sleep)

    assert polls == 3
    assert calls == [0.5, 0.5, 0.5]


# --- choosing which demos to capture ----------------------------------------------

def test_no_arguments_capture_the_stale_demos():
    assert choose_demos([], ["b", "a"]) == ["b", "a"]


def test_no_arguments_and_nothing_stale_capture_nothing():
    assert choose_demos([], []) is None


def test_named_demos_are_captured_even_when_current():
    assert choose_demos(["x"], []) == ["x"]
    assert choose_demos(["x", "y"], ["z"]) == ["x", "y"]


def test_all_flag_captures_every_demo():
    # An empty list means every demo to build_specs, clear_stale_figures and render.
    assert choose_demos([ALL_FLAG], []) == []


def test_all_flag_refuses_demo_names():
    with pytest.raises(SystemExit, match="takes no demo names"):
        choose_demos([ALL_FLAG, "x"], [])


def test_main_with_nothing_stale_does_not_start_matlab(monkeypatch):
    import update_demo_docs
    monkeypatch.setattr(update_demo_docs, "stale_demos", lambda: [])
    monkeypatch.setattr(update_demo_docs, "build_specs",
                        lambda demos: pytest.fail("specs built with nothing to capture"))
    monkeypatch.setattr(update_demo_docs, "run_capture",
                        lambda matlab: pytest.fail("MATLAB started with nothing to capture"))
    assert update_demo_docs.main([]) == 0


def test_main_passes_only_the_stale_demos_on(monkeypatch):
    import update_demo_docs
    seen = {}
    monkeypatch.setattr(update_demo_docs, "stale_demos", lambda: ["a"])
    monkeypatch.setattr(update_demo_docs, "build_specs", lambda demos: seen.setdefault("specs", demos))
    monkeypatch.setattr(update_demo_docs, "clear_stale_figures", lambda demos: seen.setdefault("clear", demos))
    monkeypatch.setattr(update_demo_docs, "clear_done", lambda: None)
    monkeypatch.setattr(update_demo_docs, "run_capture", lambda matlab: 0)
    monkeypatch.setattr(update_demo_docs, "capture_finished", lambda: True)
    monkeypatch.setattr(update_demo_docs, "render", lambda demos: seen.setdefault("render", demos))
    assert update_demo_docs.main([]) == 0
    assert seen == {"specs": ["a"], "clear": ["a"], "render": ["a"]}
