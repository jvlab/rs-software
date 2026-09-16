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

    python docs/update_demo_docs.py                        # every demo
    python docs/update_demo_docs.py rs_knit_coordsets_demo # just this one

Naming demos captures only those, which is what you want while iterating: a full
run is as slow as the slowest demo. The demos that are not named keep the output
captured for them earlier.

The MATLAB executable defaults to "matlab" on PATH. If it is installed
elsewhere, set the MATLAB environment variable to its full path.

On Linux and macOS the capture runs with -nodisplay. Without it, a MATLAB
started while an X display is present tries to use hardware OpenGL, fails to
create a GL context in batch mode, and exports every figure as a solid black
image without failing. -nodisplay renders in software instead, which is also
what a headless CI runner does.

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


def specs_argv(python_executable=sys.executable, demos=()):
    """Return the command that builds the capture specs for the named demos."""
    return [python_executable, SPEC_SCRIPT, *demos]


def matlab_argv(matlab_executable, command=MATLAB_CAPTURE_COMMAND,
                platform=sys.platform):
    """
    Return the command that runs the MATLAB capture in batch mode.

    Args:
        matlab_executable: the MATLAB binary to run.
        command: the MATLAB command to pass to -batch.
        platform: sys.platform value to decide on -nodisplay; Windows MATLAB
            does not accept that flag and does not need it.

    Returns:
        The argument list, as a list of str.
    """
    argv = [matlab_executable]
    if platform != "win32":
        argv.append("-nodisplay")   # otherwise figures export as solid black
    argv.extend(["-batch", command])
    return argv


def build_specs(demos=()):
    print("[update-demo-docs] building capture specs ...")
    subprocess.run(specs_argv(demos=demos), cwd=REPO_ROOT, check=True)


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


def main(argv=None):
    demos = list(sys.argv[1:] if argv is None else argv)
    build_specs(demos)
    exit_code = run_capture(os.environ.get("MATLAB", "matlab"))
    if exit_code == 0:
        print("[update-demo-docs] done. Run 'mkdocs serve' to preview the pages.")
    else:
        print("[update-demo-docs] capture finished with problems; see output above.")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
