# -*- coding: utf-8 -*-
"""
Build capture specs for every demo.

Run this before the MATLAB capture step:

    python docs/build_demo_specs.py

For each demo it writes build/capture/<name>.spec.json, which the MATLAB
executor (run_all.m) consumes. Figure and manifest paths are absolute so the
executor can change working directory to run the demos without affecting where
output lands.

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

REPO_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = REPO_ROOT / "build" / "capture"
FIG_DIR = REPO_ROOT / "docs" / "images" / "demos"
SEED = 0


def main():
    demos = sorted(glob(str(REPO_ROOT / "src" / "demos" / "*.m")))
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    FIG_DIR.mkdir(parents=True, exist_ok=True)

    count = 0
    for demo in demos:
        name = Path(demo).stem
        if name.lower() == "contents":
            continue
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
