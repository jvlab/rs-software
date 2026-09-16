# -*- coding: utf-8 -*-
"""
Render captured demos into the markdown pages that mkdocs publishes.

Demos need MATLAB, so they are captured locally, on demand, whenever a demo file
changes. The pages this module writes, and the figures the capture produced, are
committed. A documentation build therefore needs nothing but Python, which is
why the mkdocs hooks no longer render demos.

    pages    docs/mfiles/demos/<demo>.md
    figures  docs/images/demos/<demo>_chunk<nn>_fig<n>.png
    index    capture/demo_capture_index.json

The index records, per demo, the SHA-256 of the source that was captured. That is
what docs/test_demo_captures_current.py compares against the demo files on disk,
so a demo edited without a fresh capture fails the tests rather than publishing
new code beside stale output.

Normally driven by docs/update_demo_docs.py. Standalone, it re-renders pages from
manifests that already exist, without running MATLAB:

    python docs/render_demo_pages.py                       # every captured demo
    python docs/render_demo_pages.py rs_knit_coordsets_demo

@author: G. Aguilar - Feb 2026
"""

import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_demo_specs import BUILD_DIR, FIG_DIR, demo_paths  # noqa: E402
from demo_capture import load_manifest  # noqa: E402
from function_registry import build as build_registry  # noqa: E402
from matlab_to_markdown import parse_matlab_to_markdown  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
PAGE_DIR = REPO_ROOT / "docs" / "mfiles" / "demos"
INDEX_PATH = REPO_ROOT / "capture" / "demo_capture_index.json"


def source_hash(demo_path):
    """Return the SHA-256 of a demo source file, as a hex string."""
    return hashlib.sha256(Path(demo_path).read_bytes()).hexdigest()


def figure_pattern(demo_name):
    """Return the glob matching every figure of one demo."""
    return f"{demo_name}_chunk*_fig*.png"


def clear_figures(demo_name, fig_dir=FIG_DIR):
    """
    Delete the figures of a previous capture of this demo.

    Called before capturing, so that a demo which now draws fewer figures, or
    names its chunks differently, leaves no orphan images behind.

    Args:
        demo_name: bare demo name, for example "rs_knit_coordsets_demo".
        fig_dir: directory holding the figures.

    Returns:
        The number of files removed.
    """
    removed = 0
    for stale in Path(fig_dir).glob(figure_pattern(demo_name)):
        stale.unlink()
        removed += 1
    return removed


def load_index(index_path=INDEX_PATH):
    """Return the capture index, or an empty one when it does not exist yet."""
    path = Path(index_path)
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def save_index(index, index_path=INDEX_PATH):
    """Write the capture index, sorted by demo name so diffs stay readable."""
    path = Path(index_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    ordered = {name: index[name] for name in sorted(index)}
    path.write_text(json.dumps(ordered, indent=2) + "\n", encoding="utf-8")


def index_entry(demo_path, manifest, captured_at=None):
    """
    Build the index entry describing one captured demo.

    Args:
        demo_path: path of the demo source that was captured.
        manifest: the loaded manifest, chunk index --> entry.
        captured_at: ISO timestamp; defaults to now, in UTC.

    Returns:
        A dict with the source hash, the capture time, how many figures the
        capture produced, and the first error the demo hit, or None.
    """
    errors = [entry.get("error") for entry in manifest.values() if entry.get("error")]
    figures = sum(len(entry.get("figures", [])) for entry in manifest.values())
    if captured_at is None:
        captured_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    return {
        "source_sha256": source_hash(demo_path),
        "captured_at": captured_at,
        "figures": figures,
        "error": errors[0] if errors else None,
    }


def render_demo(demo_path, registry, page_dir=PAGE_DIR, build_dir=BUILD_DIR):
    """
    Render one demo to its markdown page, splicing in its capture manifest.

    Args:
        demo_path: path of the demo source file.
        registry: function registry used to linkify "See also" lines.
        page_dir: directory the page is written to.
        build_dir: directory holding the capture manifests.

    Returns:
        A (page_path, manifest) tuple. The manifest is empty when the demo has
        not been captured, in which case the page carries code only.
    """
    demo_path = Path(demo_path)
    manifest = load_manifest(Path(build_dir) / f"{demo_path.stem}.manifest.json")

    markdown = parse_matlab_to_markdown(
        demo_path.read_text(encoding="utf-8"), registry, manifest
    )

    page_path = Path(page_dir) / f"{demo_path.stem}.md"
    page_path.parent.mkdir(parents=True, exist_ok=True)
    page_path.write_text(markdown, encoding="utf-8")
    return page_path, manifest


def render(names=(), page_dir=PAGE_DIR, build_dir=BUILD_DIR, index_path=INDEX_PATH):
    """
    Render the named demos and update the capture index.

    Demos outside 'names' keep their existing index entries, so capturing one
    demo does not disturb the record of the others.

    Args:
        names: demo names to render; empty means every demo.
        page_dir: directory the pages are written to.
        build_dir: directory holding the capture manifests.
        index_path: path of the capture index.

    Returns:
        The list of rendered page paths.
    """
    registry = build_registry()
    index = load_index(index_path)
    pages = []

    for demo_path in demo_paths(names):
        page_path, manifest = render_demo(demo_path, registry, page_dir, build_dir)
        pages.append(page_path)

        name = Path(demo_path).stem
        if manifest:
            index[name] = index_entry(demo_path, manifest)
            status = index[name]["error"] or f"{index[name]['figures']} figure(s)"
        else:
            index.pop(name, None)
            status = "no capture found, page has code only"
        print(f"[render-demo-pages] {name}: {status}")

    save_index(index, index_path)
    return pages


def main(argv=None):
    names = list(sys.argv[1:] if argv is None else argv)
    pages = render(names)
    print(f"[render-demo-pages] wrote {len(pages)} page(s) to {PAGE_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
