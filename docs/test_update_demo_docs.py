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
    assert matlab_argv("matlab") == ["matlab", "-batch", MATLAB_CAPTURE_COMMAND]


def test_matlab_argv_uses_batch_flag_and_given_command():
    assert matlab_argv("/opt/matlab/bin/matlab", "run_all('x')") == [
        "/opt/matlab/bin/matlab", "-batch", "run_all('x')"
    ]


def test_matlab_capture_command_targets_run_all_and_shadow_path():
    # The command must put the input() shadow on the path and call run_all.
    assert "addpath('capture/matlab')" in MATLAB_CAPTURE_COMMAND
    assert "run_all('build/capture')" in MATLAB_CAPTURE_COMMAND
