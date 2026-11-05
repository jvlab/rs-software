# -*- coding: utf-8 -*-
"""
Update the demo documentation capture.

Builds the capture specs, runs the local MATLAB capture, and renders the demo
pages from the result. It does NOT build or serve the site; run mkdocs yourself
afterwards (for example "mkdocs serve") to view the result.

Stages:
    1. build the capture specs   (docs/build_demo_specs.py)
    2. run the MATLAB capture    (capture/matlab/run_all.m)
    3. render the demo pages     (docs/render_demo_pages.py)

The pages and figures it writes are committed, because the documentation build
has no MATLAB. Commit them together with the demo you changed; the tests in
docs/test_demo_captures_current.py fail when they drift apart.

Usage, from the repository root:

    python docs/update_demo_docs.py                        # the demos that changed
    python docs/update_demo_docs.py rs_knit_coordsets_demo # just this one
    python docs/update_demo_docs.py --all                  # every demo

With no argument, only the demos whose source changed since their last capture
are captured: those with no entry in capture/demo_capture_index.json, or whose
source hash (which covers the scripts they include) differs from the recorded
one. That is the set docs/test_demo_captures_current.py complains about. When
nothing changed, MATLAB is not started at all.

Re-capturing an unchanged demo is avoided on purpose: MATLAB writes PNGs whose
bytes differ from run to run even when the plots are identical, so a full run
dirties every figure and, if committed, adds them all to the git history again.
Use --all only when something outside src/demos changed what demos print or
plot, such as a toolbox function or the capture itself.

Naming demos captures exactly those, changed or not. The demos that are not
captured keep the output captured for them earlier.

The MATLAB executable defaults to "matlab" on PATH. If it is installed
elsewhere, set the MATLAB environment variable to its full path.

On Linux and macOS the capture runs with -nodisplay. Without it, a MATLAB
started while an X display is present tries to use hardware OpenGL, fails to
create a GL context in batch mode, and exports every figure as a solid black
image without failing. -nodisplay renders in software instead, which is also
what a headless CI runner does.

On Windows the capture runs with -wait, because the matlab command there returns
to the caller as soon as MATLAB has started. That flag is not trusted either:
run_all writes a marker file when it reaches the end, and this script waits for
that marker before rendering. Without it the pages are rendered from manifests
the capture has not written yet, and come out with code and no output.

This is for local use only: CI has no MATLAB, and builds the site from the pages
and figures committed here. See capture/README.md.

@author: G. Aguilar - Feb 2026
"""

import os
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_demo_specs import BUILD_DIR, demo_paths  # noqa: E402
from render_demo_pages import clear_figures, render, stale_demos  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
SPEC_SCRIPT = "docs/build_demo_specs.py"
MATLAB_CAPTURE_COMMAND = "addpath('capture/matlab'); run_all('build/capture')"

# Written by run_all.m when it reaches the end of the capture; see done_path().
DONE_NAME = "run_all.done"

ALL_FLAG = "--all"


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
        platform: sys.platform value to pick the platform-specific flags.

    Returns:
        The argument list, as a list of str.

    Notes:
        - Off Windows: -nodisplay, or figures export as solid black.
        - On Windows: -wait. The matlab command there starts MATLAB and returns
          to the caller immediately, so without it this script would render
          pages from the previous capture while the new one is still running.
          Windows MATLAB neither accepts nor needs -nodisplay.
    """
    argv = [matlab_executable]
    if platform == "win32":
        argv.append("-wait")        # otherwise matlab returns before it is done
    else:
        argv.append("-nodisplay")   # otherwise figures export as solid black
    argv.extend(["-batch", command])
    return argv


def build_specs(demos=()):
    print("[update-demo-docs] building capture specs ...")
    subprocess.run(specs_argv(demos=demos), cwd=REPO_ROOT, check=True)


def clear_stale_figures(demos=()):
    """
    Delete the figures of the demos about to be captured.

    A demo that now draws fewer figures would otherwise leave images of its
    previous capture behind, and those would be committed along with the rest.

    Args:
        demos: demo names to clear; empty means every demo.

    Returns:
        The number of image files removed.
    """
    removed = sum(clear_figures(Path(demo).stem) for demo in demo_paths(demos))
    if removed:
        print(f"[update-demo-docs] removed {removed} figure(s) of a previous capture")
    return removed


def done_path(build_dir=BUILD_DIR):
    """
    Return the path of the capture completion marker.

    run_all.m deletes it when it starts and writes it when it has run every
    spec, so its presence means that MATLAB finished, whatever the process that
    started MATLAB reported.
    """
    return Path(build_dir) / DONE_NAME


def clear_done(build_dir=BUILD_DIR):
    """Delete the marker of a previous capture. True if one was there."""
    path = done_path(build_dir)
    if path.exists():
        path.unlink()
        return True
    return False


def capture_finished(build_dir=BUILD_DIR):
    """True when the running capture has written its completion marker."""
    return done_path(build_dir).exists()


def wait_for_capture(build_dir=BUILD_DIR, poll_seconds=5.0, heartbeat_polls=12,
                     sleep=time.sleep):
    """
    Block until the capture writes its completion marker.

    Needed when the process that started MATLAB returns while MATLAB is still
    running, which is what the Windows matlab command does when -wait has no
    effect. Rendering at that moment finds no manifests and produces pages with
    code and no output, which is the failure this waits out.

    There is no time limit, for the same reason the capture itself has none: a
    single demo with statistics can run for half an hour, and this runs locally
    and attended. Interrupt with Ctrl-C if MATLAB is no longer running.

    Args:
        build_dir: directory holding the marker.
        poll_seconds: how long to sleep between checks.
        heartbeat_polls: print a still-waiting line every this many polls.
        sleep: sleep function, injectable for the tests.

    Returns:
        The number of polls waited; 0 when the capture had already finished.
    """
    if capture_finished(build_dir):
        return 0

    print("[update-demo-docs] MATLAB returned before the capture finished, so it "
          "is still running in the background. Waiting for it to write "
          f"{DONE_NAME}; interrupt with Ctrl-C if MATLAB is no longer running.")
    polls = 0
    while not capture_finished(build_dir):
        sleep(poll_seconds)
        polls += 1
        if heartbeat_polls and polls % heartbeat_polls == 0:
            print(f"[update-demo-docs] still waiting, {polls * poll_seconds:.0f} s ...")
    print("[update-demo-docs] capture finished.")
    return polls


def run_capture(matlab_executable):
    """
    Run the MATLAB capture; return the process exit code (nonzero on failure).

    The capture is left to run for as long as it takes. A demo with statistics can
    take half an hour on its own, and this runs locally and attended, so a wall
    clock limit would only ever cut a healthy run short. Interrupt it with Ctrl-C
    if it goes wrong. A prompt with no demo-input directive does not hang: the
    input() shadow raises democapture:tooFewAnswers when its answers run out.
    """
    print(f"[update-demo-docs] running MATLAB capture with '{matlab_executable}' ...")
    try:
        result = subprocess.run(matlab_argv(matlab_executable), cwd=REPO_ROOT)
    except FileNotFoundError:
        print(f"[update-demo-docs] MATLAB executable '{matlab_executable}' not "
              "found. Set the MATLAB env var to its full path.")
        return 1
    return result.returncode


def choose_demos(args, stale):
    """
    Decide which demos to capture from the command-line arguments.

    Args:
        args: the arguments: demo names, or ALL_FLAG alone, or nothing.
        stale: the names of the demos whose capture is out of date.

    Returns:
        The list of demo names to capture. An empty list means every demo, as
        it does for build_specs, clear_stale_figures and render, and is only
        returned for ALL_FLAG; with no arguments and nothing stale, None.

    Raises:
        SystemExit: when ALL_FLAG is combined with demo names.
    """
    if ALL_FLAG in args:
        if len(args) > 1:
            raise SystemExit(f"[update-demo-docs] {ALL_FLAG} takes no demo names")
        return []
    if args:
        return list(args)
    return list(stale) or None


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    stale = [] if args else stale_demos()
    demos = choose_demos(args, stale)
    if demos is None:
        print("[update-demo-docs] every demo matches its capture; nothing to do. "
              f"Name demos, or pass {ALL_FLAG}, to capture anyway.")
        return 0
    if not args:
        print(f"[update-demo-docs] capturing the demos that changed: {', '.join(demos)}")

    build_specs(demos)
    clear_stale_figures(demos)
    clear_done()
    exit_code = run_capture(os.environ.get("MATLAB", "matlab"))

    if not capture_finished():
        if exit_code != 0:
            print(f"[update-demo-docs] MATLAB exited with code {exit_code} without "
                  "finishing the capture; see output above. Nothing was rendered, "
                  "so the demo pages are as they were.")
            return exit_code
        # Exit code 0 and no marker: MATLAB was started and the caller was handed
        # back control while it runs, as the Windows matlab command does.
        wait_for_capture()

    if exit_code != 0:
        print(f"[update-demo-docs] MATLAB exited with code {exit_code}; see output "
              "above. Rendering what the capture did produce.")

    # Render even when a demo errored: the manifest records the error, and the
    # page shows it where it happened, which is how the failure stays visible.
    render(demos)
    print("[update-demo-docs] done. Run "'mkdocs serve'" to preview the changes.")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
