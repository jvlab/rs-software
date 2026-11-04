# -*- coding: utf-8 -*-
"""
Paste shared demo scripts into the demos that call them.

Some demos are a parameter set followed by calls to shared scripts: the
rs_toygeom_scenario* demos set parameters, then run rs_toygeom_sim and
rs_toygeom_disp. Keeping one copy of the shared code and still publishing
self-contained pages is done with two directives:

    rs_toygeom_sim;   %#demo-include

on the calling line asks for the called script to be pasted in its place on the
page and in the capture, and

    %#demo-include-only

alone on a line of the shared script says that it is not a demo of its own: it
gets no page and no capture, and is published only inside the demos that
include it.

In MATLAB both directives are plain comments, so a demo that includes a script
still runs unchanged: it calls the script. Only the documentation pipeline
expands the call.

The expansion is textual. The calling line is replaced by the included file,
itself expanded, between marker lines that the parser turns into blocks:

    %#demo-include-begin: rs_toygeom_sim
    <the header comment of rs_toygeom_sim.m>
    %#demo-include-body: rs_toygeom_sim
    <the rest of rs_toygeom_sim.m>
    %#demo-include-end: rs_toygeom_sim

The header is the leading run of comment lines, up to the first blank or code
line; the renderer folds it into a collapsed block. Because everything
downstream (chunks, scripted answers, the source hash) works on the expanded
text, an edit to an included script marks every demo that includes it as
needing a fresh capture.

@author: G. Aguilar - Nov 2026
"""

import re
from pathlib import Path

# A call to be expanded: an unindented line that only calls a script, with the
# directive at its end. Indentation is refused because the call would then sit
# inside a control block, which the pasted code would split.
_INCLUDE_CALL = re.compile(r"^([A-Za-z]\w*)\s*;?\s*%#demo-include\s*$")
_INCLUDE_ANYWHERE = re.compile(r"%#demo-include(?![-\w])")
_INCLUDE_ONLY = re.compile(r"^\s*%#demo-include-only\s*$", re.MULTILINE)

# Marker lines written by the expansion and read by matlab_to_markdown.
MARKER = re.compile(r"^%#demo-include-(begin|body|end): (\w+)\s*$")
BEGIN, BODY, END = "begin", "body", "end"


def read_source(path):
    """
    Read a MATLAB source file as text, with line endings normalized to \\n.

    Args:
        path: path of the file.

    Returns:
        str: the file content.
    """
    return Path(path).read_bytes().replace(b"\r\n", b"\n").decode("utf-8")


def is_include_only(source):
    """True if the source carries a %#demo-include-only line."""
    return _INCLUDE_ONLY.search(source) is not None


def split_header(source):
    """
    Split a script into its header comment and the rest.

    The header is the leading run of comment lines, ended by the first blank
    line or code line. MATLAB ends a help block at the same place.

    Args:
        source: the script text.

    Returns:
        A (header_lines, rest_lines) tuple of line lists, without line ends.
    """
    lines = source.splitlines()
    count = 0
    for line in lines:
        if not line.strip().startswith("%") or line.strip().startswith("%#demo-"):
            break
        count += 1
    return lines[:count], lines[count:]


def _included_call(line, line_number, name):
    """
    Return the script name a line asks to include, or None.

    Raises:
        ValueError: for a %#demo-include directive on a line that is not a
            bare, unindented script call.
    """
    stripped = line.lstrip()
    if stripped.startswith("%") and not stripped.startswith("%#demo-"):
        return None     # a directive mentioned in prose is only text
    if not _INCLUDE_ANYWHERE.search(line):
        return None
    match = _INCLUDE_CALL.match(line.rstrip())
    if not match:
        raise ValueError(
            f"{name}, line {line_number}: %#demo-include must end an unindented "
            "line that only calls a script, as in 'rs_toygeom_sim; %#demo-include'"
        )
    return match.group(1)


def expand_includes(source, search_dir, stack=()):
    """
    Replace every %#demo-include call in source by the included script.

    Args:
        source: the text of a demo, with \\n line endings.
        search_dir: directory in which included scripts are looked up.
        stack: names of the files being expanded, outermost first, used to
            detect cycles and to name the file in error messages.

    Returns:
        str: the expanded text. Source without includes is returned unchanged,
        so its hash is the same as before includes existed.

    Raises:
        ValueError: for a malformed directive, a missing script, or a script
            that includes itself, directly or not.
    """
    name = stack[-1] if stack else "<source>"
    pieces = []
    changed = False
    for line_number, line in enumerate(source.splitlines(keepends=True), start=1):
        included = _included_call(line.rstrip("\n"), line_number, name)
        if included is None:
            pieces.append(line)
            continue

        if included in stack:
            chain = " --> ".join(list(stack) + [included])
            raise ValueError(f"{name}, line {line_number}: include cycle: {chain}")
        path = Path(search_dir) / f"{included}.m"
        if not path.is_file():
            raise ValueError(
                f"{name}, line {line_number}: included script {path} not found"
            )

        body = expand_includes(read_source(path), search_dir, tuple(stack) + (included,))
        header, rest = split_header(body)
        pieces.extend(
            [f"%#demo-include-begin: {included}\n"]
            + [h + "\n" for h in header]
            + [f"%#demo-include-body: {included}\n"]
            + [r + "\n" for r in rest]
            + [f"%#demo-include-end: {included}\n"]
        )
        changed = True
    return "".join(pieces) if changed else source


def expanded_source(demo_path):
    """
    Return a demo's text with every include expanded.

    Included scripts are looked up beside the demo.

    Args:
        demo_path: path of the demo file.

    Returns:
        str: the expanded text, with \\n line endings.
    """
    demo_path = Path(demo_path)
    return expand_includes(read_source(demo_path), demo_path.parent, (demo_path.stem,))


def included_names(expanded):
    """
    Return the names of the scripts pasted into an expanded source, in order.

    Nested includes are listed too; a script included twice is listed once.

    Args:
        expanded: text returned by expand_includes or expanded_source.

    Returns:
        list of str.
    """
    names = []
    for line in expanded.splitlines():
        match = MARKER.match(line)
        if match and match.group(1) == BEGIN and match.group(2) not in names:
            names.append(match.group(2))
    return names
