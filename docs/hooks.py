# -*- coding: utf-8 -*-
"""
Hooks for mkdocs.

Two sets of hooks, pre-build and post-build

Pre-build: executed before calling mkdocs. Here python scripts are run which
- create dummy markdown files for each function
- create the demo markdown page listing all available demos

Then call to parse_all_demos_to_markdown(), which
creates .md files corresponding to demo files. These demo files
are MATLAB code (.m files) in which 
- comments (starting with the sign %) gets parsed as Markdown text
- code (all other lines) are parsed as blocks of code.


Post-build: after HTML rendering by mkdocs.

These put the links to all functions found in the docstrings section
"See Also". It skips demo files, as demos are handled by the pre-build
hook (matlab_to_markdown.py).


@author: G. Aguilar - Feb 2026
"""
from __future__ import annotations

from glob import glob
import sys
import re
import subprocess 
import logging
from pathlib import Path
from urllib.parse import urlparse

import hook_site_config as site_config
from function_links import FUNCTION_LINKS
from matlab_to_markdown import parse_matlab_to_markdown

scripts = ["docs/create_function_md_files.py",
           "docs/list_demos.py"]
           
log = logging.getLogger("mkdocs.hooks.seealso")

FUNCTION_REGISTRY: dict[str, str] = {}

# Matches: <details class="see-also" ...>...</details>
_DETAILS_SEEALSO_RE = re.compile(
    r'(<details[^>]*class="[^"]*see-also[^"]*"[^>]*>.*?</details>)',
    re.DOTALL | re.IGNORECASE,
)

# Matches: <p>See also: ...</p>
_INLINE_SEEALSO_RE = re.compile(
    r'(<p>\s*See also\s*:.*?</p>)',
    re.DOTALL | re.IGNORECASE,
)

# Matches a MATLAB identifier, optionally dot-separated
_IDENTIFIER_RE = re.compile(
    r'\b([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)*)\b'
)


def on_config(config):
    site_config.update_site_prefix(config)

    FUNCTION_REGISTRY.clear()
    for source_root in _get_matlab_paths(config):
        root = Path(source_root)
        if root.exists():
            _scan_directory(root, root)
        else:
            log.warning(f"[seealso] Path not found: {root}")

    log.info(f"[seealso] Registered {len(FUNCTION_REGISTRY)} project functions.")
    return config


def _get_matlab_paths(config) -> list[str]:
    return ["src"]  # ← hardcoded source path


def _scan_directory(directory: Path, root: Path):
    for entry in directory.iterdir():
        if entry.is_dir():
            _scan_directory(entry, root)
        elif entry.suffix == ".m":
            _register_matlab_file(entry, root)


def _register_matlab_file(filepath: Path, root: Path):
    stem = filepath.stem

    # Skip utility/demo files
    if stem.lower() in ("contents", "readme"):
        return

    relative = filepath.relative_to(root)
    identifier_parts = []
    for part in list(relative.parts)[:-1]:
        if part.startswith(("+", "@")):
            identifier_parts.append(part[1:])
        else:
            identifier_parts.append(part)
    identifier_parts.append(stem)

    full_id = ".".join(identifier_parts)
    FUNCTION_REGISTRY[stem.lower()] = full_id
    FUNCTION_REGISTRY[full_id.lower()] = full_id


def on_page_content(html, page, config, files):
    if not FUNCTION_REGISTRY and not FUNCTION_LINKS:
        return html

    html = _DETAILS_SEEALSO_RE.sub(
        lambda m: _linkify_block(m.group(1)), html
    )
    html = _INLINE_SEEALSO_RE.sub(
        lambda m: _linkify_block(m.group(1)), html
    )
    return html


def _linkify_block(block_html: str) -> str:
    # Only process text inside <p> tags, leave all other HTML untouched
    return re.sub(
        r'(<p>)(.*?)(</p>)',
        lambda m: m.group(1) + _linkify_text(m.group(2)) + m.group(3),
        block_html,
        flags=re.DOTALL,
    )


def _linkify_text(text: str) -> str:
    # Split on HTML tags, only process text nodes (even-indexed parts)
    parts = re.split(r'(<[^>]+>)', text)
    result = []
    for i, part in enumerate(parts):
        if i % 2 == 0:
            # Text node — apply identifier replacement
            result.append(_IDENTIFIER_RE.sub(lambda m: _make_link(m.group(1)), part))
        else:
            # HTML tag — leave untouched
            result.append(part)
    return "".join(result)


def _make_link(name: str) -> str:
    lower = name.lower()
    
    # Your own functions take priority
    if lower in FUNCTION_REGISTRY:
        full_id = FUNCTION_REGISTRY[lower]
        url = f"{site_config.SITE_PREFIX}/function-index/#{full_id}"
        return f'<a href="{url}">{full_id}</a>'

    # Fall back to MATLAB builtin
    if lower in FUNCTION_LINKS:
        url = FUNCTION_LINKS[lower]
        return f'<a href="{url}" target="_blank">{lower}</a>'

    return name


#######################################################################
### PRE-BUILD HOOKS
def parse_all_demos_to_markdown():
     
    # list of m-files inside demos
    list_mfiles = glob('src/demos/*.m')

    for f in list_mfiles:
        input_path = Path(f)
        output_path = (Path('docs', 'mfiles', 'demos') / input_path.name).with_suffix(".md")
       
        if 'Contents' in str(input_path.name):
            continue
        
        # reads source code file as text
        matlab_code = input_path.read_text(encoding="utf-8")
        
        # parse
        markdown = parse_matlab_to_markdown(matlab_code, FUNCTION_REGISTRY)
        
        # writes parsed text as markdown file
        output_path.write_text(markdown, encoding="utf-8")
        print(f"File {input_path} parsed to {output_path}")
    
def run_scripts(script_paths: list[str]) -> None:
    print(f"[PRE-BUILD] running pre-build custom python scripts.")
    for script in script_paths:
        path = Path(script)

        if not path.exists():
            print(f"[SKIP] '{script}' — file not found.")
            continue

        print(f"\n{'='*50}")
        print(f"[RUN] {script}")
        print("="*50)

        result = subprocess.run(
            [sys.executable, str(path)],
            text=True,
        )

        if result.returncode == 0:
            print(f"[DONE] '{script}' exited successfully.")
        else:
            print(f"[FAIL] '{script}' exited with code {result.returncode}.")

def on_pre_build(config):
    parse_all_demos_to_markdown()
    run_scripts(scripts)           
    
#######################################################################
