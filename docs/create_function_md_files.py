# -*- coding: utf-8 -*-
"""
Create one placeholder .md file per MATLAB function, for mkdocstrings-matlab.

Each placeholder holds nothing but a "::: <name>" directive; mkdocstrings pulls the
docstring out of the .m file at build time. The pages also give the autolinks plugin
a target, so that a "See also" line can link to a function by name.

Two folders under src are skipped. Demos have their own pages, rendered when they are
captured (see docs/render_demo_pages.py), and a second page per demo would make links
by name ambiguous. Tests are not public API.

The output folder is cleared first, so that renaming or deleting a function leaves no
page behind. Only the .md files this script owns are removed: docs/mfiles/demos holds
the committed demo pages and is left alone.

Run from the repository root:

    python docs/create_function_md_files.py

@author: G. Aguilar - Feb 2026
"""

from pathlib import Path

SRC_DIR = Path("src")
OUTPUT_DIR = Path("docs", "mfiles")

# Folders under src whose .m files get no function page. Compared in lower case,
# since Windows preserves whatever case the folder was created with.
EXCLUDE_DIRS = ("demos", "tests")

# Files that document a folder or the project rather than a function.
EXCLUDE_STEMS = ("contents", "readme")


def source_files(src_dir=SRC_DIR, exclude_dirs=EXCLUDE_DIRS, exclude_stems=EXCLUDE_STEMS):
    """
    Return the .m files that get a page, sorted by path.

    Args:
        src_dir: the source root to scan, one level deep as before: src/*.m and
            src/*/*.m.
        exclude_dirs: names of subfolders of src_dir to skip.
        exclude_stems: file names, lower case and without extension, to skip.

    Returns:
        A list of Path.
    """
    src_dir = Path(src_dir)
    found = list(src_dir.glob("*.m"))
    for subfolder in sorted(p for p in src_dir.glob("*") if p.is_dir()):
        if subfolder.name.lower() in exclude_dirs:
            continue
        found.extend(subfolder.glob("*.m"))

    return sorted(p for p in found if p.stem.lower() not in exclude_stems)


def page_text(stem):
    """Return the mkdocstrings directive that makes up one placeholder page."""
    return f"::: {stem}\n    options:\n      heading_level: 1\n"


def clear_pages(output_dir=OUTPUT_DIR):
    """
    Delete the placeholder pages of a previous run.

    Only .md files directly inside output_dir are removed, never the demo pages in
    its demos subfolder, which are committed content.

    Args:
        output_dir: the folder holding the placeholder pages.

    Returns:
        The number of files removed.
    """
    output_dir = Path(output_dir)
    if not output_dir.is_dir():
        return 0

    removed = 0
    for stale in output_dir.glob("*.md"):
        stale.unlink()
        removed += 1
    return removed


def write_pages(src_dir=SRC_DIR, output_dir=OUTPUT_DIR):
    """
    Regenerate every placeholder page.

    Args:
        src_dir: the source root to scan.
        output_dir: the folder to write into; cleared first.

    Returns:
        A list of the written page paths.
    """
    output_dir = Path(output_dir)
    removed = clear_pages(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    written = []
    for input_path in source_files(src_dir):
        output_path = (output_dir / input_path.name).with_suffix(".md")
        output_path.write_text(page_text(input_path.stem), encoding="utf-8",
                               newline="\n")
        written.append(output_path)

    print(f"[create-function-md-files] removed {removed} page(s), "
          f"wrote {len(written)} page(s) to {output_dir}")
    return written


if __name__ == "__main__":
    write_pages()

# EOF
