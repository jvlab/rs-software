# -*- coding: utf-8 -*-
"""
Hooks for mkdocs.

Two sets of hooks, pre-build and post-build

Pre-build: executed before calling mkdocs. Here python scripts are run which
- create dummy markdown files for each function
- create the demo markdown page listing all available demos

Demo pages are not built here: they are rendered by docs/render_demo_pages.py
when the demos are captured locally, and the pages and figures are committed.
That keeps MATLAB out of the documentation build. See capture/README.md.


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
import function_registry
from function_links import FUNCTION_LINKS

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

# Matches <code>identifier</code> not already inside an <a> tag
_CODE_TAG_RE = re.compile(r'<code>([A-Za-z][A-Za-z0-9_.]*)</code>')
_ANCHOR_RE   = re.compile(r'<a\b[^>]*>.*?</a>', re.DOTALL)


def on_config(config):
    site_config.update_site_prefix(config)

    FUNCTION_REGISTRY.clear()
    function_registry.build(registry=FUNCTION_REGISTRY)
    for source_root in function_registry.SOURCE_ROOTS:
        if not Path(source_root).is_dir():
            log.warning(f"[seealso] Path not found: {source_root}")

    log.info(f"[seealso] Registered {len(FUNCTION_REGISTRY)} project functions.")
    return config


def on_page_content(html, page, config, files):
    if not FUNCTION_REGISTRY and not FUNCTION_LINKS:
        return html

    # Linkify <code>funcname</code> anywhere on the page
    html = _linkify_code_in_content(html)
    
    # Likify "See also"
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
        url = f"{site_config.SITE_PREFIX}/function-index-matlab/#{full_id}"
        return f'<a href="{url}">{full_id}</a>'

    # Fall back to MATLAB builtin
    if lower in FUNCTION_LINKS:
        url = FUNCTION_LINKS[lower]
        return f'<a href="{url}" target="_blank">{lower}</a>'

    return name


def _linkify_code_in_content(html: str) -> str:
    """
    Wrap <code>funcname</code> with a link for any function name found
    in FUNCTION_REGISTRY. Skips occurrences already inside an <a> tag.
    """
    result = []
    last = 0
    for anchor in _ANCHOR_RE.finditer(html):
        # Process the segment *before* this <a>…</a> block
        segment = html[last:anchor.start()]
        result.append(_CODE_TAG_RE.sub(_replace_code_tag, segment))
        # Keep the <a>…</a> block completely untouched
        result.append(anchor.group(0))
        last = anchor.end()
    # Remaining tail after the last <a>
    result.append(_CODE_TAG_RE.sub(_replace_code_tag, html[last:]))
    return "".join(result)


def _replace_code_tag(match: re.Match) -> str:
    name  = match.group(1)
    lower = name.lower()
    if lower in FUNCTION_REGISTRY:
        full_id = FUNCTION_REGISTRY[lower]
        url = f"{site_config.SITE_PREFIX}/function-index-matlab/#{full_id}"
        return f'<a href="{url}"><code>{name}</code></a>'
    return match.group(0)   # leave unchanged
    
#######################################################################
### PRE-BUILD HOOKS
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
    # Demo pages are NOT generated here. They are rendered by
    # docs/render_demo_pages.py when a demo is captured locally, and the result
    # is committed, so that a build without MATLAB still publishes the console
    # output and figures of the last capture. See capture/README.md.
    run_scripts(scripts)           
    
#######################################################################
