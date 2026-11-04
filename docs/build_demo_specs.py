# -*- coding: utf-8 -*-
"""
Build capture specs for every demo.

Run this before the MATLAB capture step:

    python docs/build_demo_specs.py                       # every demo
    python docs/build_demo_specs.py rs_knit_coordsets_demo  # just this one

For each demo it writes build/capture/<name>.spec.json, which the MATLAB
executor (run_all.m) consumes. Naming demos limits the run to those demos:
run_all executes every spec it finds in the directory, so the stale specs of
a previous run are cleared first. Manifests are left in place, so the demos
that were not rebuilt keep the output captured for them earlier.

Figure and manifest paths are absolute so the executor can change working
directory to run the demos without affecting where output lands.

This is a standalone step, separate from the mkdocs hook, so that in CI the
order is: build specs, run MATLAB (which writes manifests and figures), then
mkdocs build (whose hook reads the manifests). Locally, run these three the
same way; if you skip the MATLAB step the pages simply render code only.

@author: G. Aguilar - Feb 2026
"""

import sys
from glob import glob
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from demo_capture import build_spec  # noqa: E402
from demo_include import expanded_source, included_names, is_include_only, read_source  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = REPO_ROOT / "build" / "capture"
DEMO_DIR = REPO_ROOT / "src" / "demos"
FIG_DIR = REPO_ROOT / "docs" / "images" / "demos"
SEED = 0


def scan_demos(demo_dir=DEMO_DIR):
    """
    Sort the scripts of a demo folder into demos and include-only scripts.

    Args:
        demo_dir: directory holding the demo files.

    Returns:
        A (demos, include_only) tuple: a dict from demo name to its path, in
        path order, and the set of names of the include-only scripts.
    """
    demos = {}
    include_only = set()
    for demo in sorted(glob(str(Path(demo_dir) / "*.m"))):
        name = Path(demo).stem
        if name.lower() == "contents":
            continue
        if is_include_only(read_source(demo)):
            include_only.add(name)
        else:
            demos[name] = demo
    return demos, include_only


def demo_paths(names=(), demo_dir=DEMO_DIR):
    """
    Return the demo files to build specs for, sorted by path.

    Scripts marked %#demo-include-only are not demos: they are published only
    inside the demos that include them. Naming one selects those demos instead,
    since they are what has to be captured again after it changes.

    Args:
        names: demo names to keep, given as bare names, file names or paths;
            empty means every demo.
        demo_dir: directory holding the demo files.

    Returns:
        A list of demo file paths.

    Raises:
        SystemExit: if a requested name matches no demo file.
    """
    found, include_only = scan_demos(demo_dir)

    if not names:
        return list(found.values())

    selected = []
    missing = []
    for name in (Path(name).stem for name in names):
        if name in found:
            chosen = [name]
        elif name in include_only:
            chosen = [demo for demo in found
                      if name in included_names(expanded_source(found[demo]))]
        else:
            missing.append(name)
            continue
        selected.extend(demo for demo in chosen if demo not in selected)
    if missing:
        raise SystemExit(
            f"[build_demo_specs] no such demo: {', '.join(missing)}"
        )
    return [found[name] for name in selected]


def clear_specs():
    """Remove the specs of a previous run, so run_all only sees the new ones."""
    for stale in BUILD_DIR.glob("*.spec.json"):
        stale.unlink()


def main(argv=None):
    names = list(sys.argv[1:] if argv is None else argv)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    demos = demo_paths(names)
    clear_specs()

    count = 0
    for demo in demos:
        name = Path(demo).stem
        build_spec(
            demo,
            fig_dir=FIG_DIR,
            spec_path=BUILD_DIR / f"{name}.spec.json",
            manifest_path=BUILD_DIR / f"{name}.manifest.json",
            seed=SEED,
        )
        count += 1

    print(f"[build_demo_specs] wrote {count} spec(s) to {BUILD_DIR}")


if __name__ == "__main__":
    main()
