# -*- coding: utf-8 -*-
"""
Registry of the MATLAB functions in this repository.

Maps a function name to the dotted identifier mkdocstrings-matlab publishes it
under, so that "See also" lines and code spans can be turned into links.

Two callers build the same registry: the mkdocs hooks, which linkify pages as
they are rendered to HTML, and the demo page renderer, which runs outside mkdocs
when demos are captured locally. Keeping the scan here means both see exactly
the same set of names.

@author: G. Aguilar - Feb 2026
"""

from __future__ import annotations

from pathlib import Path

# Source roots scanned for .m files, relative to the repository root.
SOURCE_ROOTS = ["src"]

# Files whose name carries no API, so they are not registered.
SKIP_STEMS = ("contents", "readme")


def matlab_identifier(relative_path: Path) -> str:
    """
    Compute the dotted MATLAB identifier for a source file, given its path
    relative to a source root.

    Only path parts beginning with "+" or "@" become namespace components, with
    the leading marker stripped. Plain folder parts are dropped.

    Args:
        relative_path (Path): path of the .m file relative to the source root,
            for example Path("utils/grmscmdt.m"), Path("rs_geofit.m"), or
            Path("+pkg/foo.m").

    Returns:
        str: the dotted identifier, for example "grmscmdt", "rs_geofit", or
        "pkg.foo".
    """
    namespace_parts = []
    for part in relative_path.parts[:-1]:
        if part.startswith(("+", "@")):
            namespace_parts.append(part[1:])
    namespace_parts.append(relative_path.stem)
    return ".".join(namespace_parts)


def build(source_roots=None, registry=None):
    """
    Scan source roots for .m files and return the function registry.

    Args:
        source_roots: iterable of directories to scan; defaults to SOURCE_ROOTS.
            Missing directories are skipped.
        registry: dict to fill in place; a new one is created when omitted.

    Returns:
        dict: name in lower case --> dotted identifier. Both the bare stem and
        the dotted identifier are registered as keys, so either spelling in a
        "See also" line resolves.
    """
    if source_roots is None:
        source_roots = SOURCE_ROOTS
    if registry is None:
        registry = {}

    for source_root in source_roots:
        root = Path(source_root)
        if not root.is_dir():
            continue
        for filepath in sorted(root.rglob("*.m")):
            if filepath.stem.lower() in SKIP_STEMS:
                continue
            full_id = matlab_identifier(filepath.relative_to(root))
            registry[filepath.stem.lower()] = full_id
            registry[full_id.lower()] = full_id

    return registry
