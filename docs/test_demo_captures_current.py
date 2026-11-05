# -*- coding: utf-8 -*-
"""
Guard the committed demo captures against going stale.

Demos are captured locally, because they need MATLAB, and the resulting pages
and figures are committed so that the documentation builds anywhere. The risk
that creates is a demo edited without a fresh capture: the page would then show
the new code beside the output of the old one, and nothing in the build would
notice.

These tests compare every demo against capture/demo_capture_index.json and fail
with the command that refreshes it. They need no MATLAB and run in well under a
second, so they belong in the documentation workflow.

A demo whose capture ends in an error is fine here. The error is recorded in the
index and shown on the page; what is checked is that the record matches the
source on disk.
"""

from pathlib import Path
import re

from build_demo_specs import FIG_DIR, demo_paths
from render_demo_pages import INDEX_PATH, PAGE_DIR, figure_pattern, load_index, source_hash

REFRESH = "python docs/update_demo_docs.py"

# Markdown image references written by the renderer, for example
# ![](../../images/demos/rs_knit_coordsets_demo_chunk05_fig1.png)
_IMAGE_RE = re.compile(r"!\[[^\]]*\]\([^)]*images/demos/([^)\s]+)\)")


def demo_names():
    """Return the bare names of every demo, sorted."""
    return sorted(Path(demo).stem for demo in demo_paths())


def index():
    return load_index(INDEX_PATH)


def test_every_demo_has_an_index_entry():
    missing = [name for name in demo_names() if name not in index()]
    assert not missing, (
        f"demos never captured: {', '.join(missing)}. Run: {REFRESH} "
        f"{' '.join(missing)}"
    )


def test_no_index_entry_survives_a_deleted_demo():
    orphans = sorted(set(index()) - set(demo_names()))
    assert not orphans, (
        f"capture index still lists demos that no longer exist: "
        f"{', '.join(orphans)}. Remove their entries from {INDEX_PATH.name}, "
        "their pages and their figures."
    )


def test_every_demo_source_matches_its_capture():
    recorded = index()
    stale = [
        Path(demo).stem
        for demo in demo_paths()
        if Path(demo).stem in recorded
        and recorded[Path(demo).stem].get("source_sha256") != source_hash(demo)
    ]
    assert not stale, (
        f"demos changed since they were captured: {', '.join(stale)}. "
        f"Run: {REFRESH} {' '.join(stale)}"
    )


def test_every_demo_has_a_committed_page():
    missing = [
        name for name in demo_names() if not (PAGE_DIR / f"{name}.md").exists()
    ]
    assert not missing, (
        f"demo pages missing: {', '.join(missing)}. Run: {REFRESH} "
        f"{' '.join(missing)}"
    )


def test_no_page_survives_a_deleted_demo():
    orphans = sorted(
        path.stem for path in PAGE_DIR.glob("*.md")
        if path.stem not in demo_names()
    )
    assert not orphans, (
        f"pages of demos that no longer exist: {', '.join(orphans)}. "
        f"Delete them from {PAGE_DIR}."
    )


def test_every_figure_a_page_references_exists():
    missing = []
    for name in demo_names():
        page = PAGE_DIR / f"{name}.md"
        if not page.exists():
            continue
        for image in _IMAGE_RE.findall(page.read_text(encoding="utf-8")):
            if not (FIG_DIR / image).exists():
                missing.append(image)
    assert not missing, (
        f"figures referenced by a demo page but not committed: "
        f"{', '.join(missing)}. Run: {REFRESH}"
    )


def test_no_figure_survives_a_deleted_demo():
    known = set()
    for name in demo_names():
        known.update(path.name for path in FIG_DIR.glob(figure_pattern(name)))
    orphans = sorted(
        path.name for path in FIG_DIR.glob("*.png") if path.name not in known
    )
    assert not orphans, (
        f"figures of demos that no longer exist: {', '.join(orphans)}. "
        f"Delete them from {FIG_DIR}."
    )
