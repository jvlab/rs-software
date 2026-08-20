# -*- coding: utf-8 -*-
"""
Unit tests for update_demo_docs, written as plain functions.

The orchestration runs subprocesses, but the command construction is pure and
testable from first principles: a known executable and command map to a known
argument list.
"""

import sys

from update_demo_docs import (
    MATLAB_CAPTURE_COMMAND,
    SPEC_SCRIPT,
    matlab_argv,
    specs_argv,
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


def test_matlab_argv_omits_nodisplay_on_windows():
    # Windows MATLAB rejects -nodisplay, and renders correctly without it.
    assert matlab_argv("matlab.exe", "run_all('x')", platform="win32") == [
        "matlab.exe", "-batch", "run_all('x')"
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
