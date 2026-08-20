# -*- coding: utf-8 -*-
"""
Update the demo documentation capture.

Builds the capture specs and runs the local MATLAB capture, so the demo pages
have fresh console output and figures. It does NOT build or serve the site; run
mkdocs yourself afterwards (for example "mkdocs serve") to view the result.

Stages:
    1. build the capture specs   (docs/build_demo_specs.py)
    2. run the MATLAB capture    (capture/matlab/run_all.m)

Usage, from the repository root:

    python docs/update_demo_docs.py

The MATLAB executable defaults to "matlab" on PATH. If it is installed
elsewhere, set the MATLAB environment variable to its full path.

This is for local use. In CI the same two stages run as separate workflow
steps, using matlab-actions instead of a local MATLAB, so this script is not
called there.

@author: G. Aguilar - Feb 2026
"""

import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SPEC_SCRIPT = "docs/build_demo_specs.py"
MATLAB_CAPTURE_COMMAND = "addpath('capture/matlab'); run_all('build/capture')"
CAPTURE_TIMEOUT_SECONDS = 30 * 60


def specs_argv(python_executable=sys.executable):
    """Return the command that builds the capture specs."""
    return [python_executable, SPEC_SCRIPT]


def matlab_argv(matlab_executable, command=MATLAB_CAPTURE_COMMAND):
    """Return the command that runs the MATLAB capture in batch mode."""
    return [matlab_executable, "-batch", command]


def build_specs():
    print("[update-demo-docs] building capture specs ...")
    subprocess.run(specs_argv(), cwd=REPO_ROOT, check=True)


def run_capture(matlab_executable):
    """Run the MATLAB capture; return the process exit code (nonzero on failure)."""
    print(f"[update-demo-docs] running MATLAB capture with '{matlab_executable}' ...")
    try:
        result = subprocess.run(
            matlab_argv(matlab_executable),
            cwd=REPO_ROOT, timeout=CAPTURE_TIMEOUT_SECONDS,
        )
    except FileNotFoundError:
        print(f"[update-demo-docs] MATLAB executable '{matlab_executable}' not "
              "found. Set the MATLAB env var to its full path.")
        return 1
    except subprocess.TimeoutExpired:
        print("[update-demo-docs] MATLAB capture timed out.")
        return 1
    return result.returncode


def main():
    build_specs()
    exit_code = run_capture(os.environ.get("MATLAB", "matlab"))
    if exit_code == 0:
        print("[update-demo-docs] done. Run 'mkdocs serve' to preview the pages.")
    else:
        print("[update-demo-docs] capture finished with problems; see output above.")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
