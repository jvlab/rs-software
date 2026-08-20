# -*- coding: utf-8 -*-
"""
Capture support for MATLAB demos.

Bridges the Python side (which owns demo segmentation) and the MATLAB side
(which executes demos and reports results). Three responsibilities:

    extract_demo_inputs()  read the scripted input() answers from a demo
    build_spec()           write the JSON spec that run_capture.m consumes
    load_manifest()        read back the JSON manifest run_capture.m produces,
                           keyed by code-chunk index for the renderer

A demo-input directive is an inline comment supplying the answer for a
scripted getinp()/input() call, so interactive demos run unattended:

    verbosity = getinp('display verbosity', 'd', [0 2], 0);   %#demo-input: 0

An empty answer (nothing after the colon) means "press enter for the default".
Answers are collected in source order, which is the order the prompts are
reached during linear execution.

@author: G. Aguilar - Feb 2026
"""

import json
import re
from pathlib import Path

from matlab_to_markdown import parse_blocks, code_chunk_texts

_DIRECTIVE = re.compile(r"%#demo-input:(.*)$", re.MULTILINE)

# Demos reference data files by paths relative to the src folder, e.g.
# load('demos/opposites_coords_FG'), so they must run with src as the working
# directory.
DEFAULT_WORKDIR = "src"


def extract_demo_inputs(source):
    """
    Return the ordered list of demo-input answers found in source.

    Args:
        source: the full text of a MATLAB demo file.

    Returns:
        A list of answer strings, one per directive, in source order. An empty
        string represents "press enter for the default".
    """
    return [match.group(1).strip() for match in _DIRECTIVE.finditer(source)]


def build_spec(demo_path, fig_dir, spec_path, manifest_path,
               seed=0, workdir=DEFAULT_WORKDIR):
    """
    Build and write the capture spec for one demo.

    The spec lists the demo's code chunks (using the same segmentation the
    renderer uses, so chunk ids line up with manifest keys), the scripted
    answers, and where the MATLAB driver should write figures and the manifest.

    Args:
        demo_path: path to the demo .m file.
        fig_dir: directory where figures should be written (absolute is safest,
            because the driver may run with a different working directory).
        spec_path: where to write this spec JSON.
        manifest_path: where the driver should write the manifest JSON.
        seed: rng seed for reproducible output and figures; use None to skip.
        workdir: working directory the demo should run in.

    Returns:
        The spec dict that was written.
    """
    demo_path = Path(demo_path)
    source = demo_path.read_text(encoding="utf-8")
    chunks = code_chunk_texts(parse_blocks(source))
    answers = extract_demo_inputs(source)

    spec = {
        "name": demo_path.stem,
        "workdir": str(workdir),
        "fig_dir": str(fig_dir),
        "manifest": str(manifest_path),
        "answers": answers,
        "chunks": [{"id": index, "code": code} for index, code in enumerate(chunks)],
    }
    if seed is not None:
        spec["seed"] = seed

    spec_path = Path(spec_path)
    spec_path.parent.mkdir(parents=True, exist_ok=True)
    spec_path.write_text(json.dumps(spec, indent=2), encoding="utf-8")
    return spec


def load_manifest(manifest_path):
    """
    Load a capture manifest, keyed by code-chunk index.

    The manifest is the JSON array produced by run_capture.m, one entry per
    chunk. MATLAB's jsonencode emits a single object (not an array) when there
    is exactly one entry, so both shapes are accepted. A missing manifest
    yields an empty mapping, so rendering falls back to code-only pages.

    Args:
        manifest_path: path to the manifest JSON.

    Returns:
        A dict mapping int chunk index to the entry dict.
    """
    path = Path(manifest_path)
    if not path.exists():
        return {}

    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        data = [data]

    manifest = {}
    for entry in data:
        entry_id = entry.get("id")
        # A well-formed id is an int. MATLAB may emit [] (an empty list) for an
        # unassigned slot; skip anything that is not a plain integer index.
        if isinstance(entry_id, bool) or not isinstance(entry_id, (int, float)):
            continue
        manifest[int(entry_id)] = entry
    return manifest
