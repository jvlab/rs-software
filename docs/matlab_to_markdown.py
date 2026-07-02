# -*- coding: utf-8 -*-
"""
Parse matlab demo files to markdown.

It reads every .m file in folder "src/demos", and converts
every line of comment in markdown text, and every line of code
as markdown code blocks. The entry function is parse_matlab_to_markdown(),
called by the pre-build hook, which needs to run before building with mkdocs.

Parsing happens in two stages so that a capture manifest (console output and
figures produced by running the demo) can be spliced in under the matching
code block:

    parse_blocks()   splits the source into ordered text and code blocks
    render_blocks()  turns those blocks into markdown, optionally inserting
                     captured output and figures after each code block

parse_matlab_to_markdown() keeps its original signature and, with no manifest,
produces exactly the same markdown as before.

@author: G. Aguilar - Feb 2026
"""

import re
import sys
from pathlib import Path

# A demo-input directive is a trailing (or whole-line) comment that drives
# capture. It must never appear in the rendered code, so it is stripped from
# every source line before the line is classified as comment or code. The
# answers themselves are read from the raw source by demo_capture, so removing
# the directive here does not lose them.
_DEMO_INPUT_INLINE = re.compile(r"\s*%#demo-input:.*$")


def _strip_demo_directive(line: str) -> str:
    """Remove a %#demo-input directive from a source line."""
    return _DEMO_INPUT_INLINE.sub("", line)


def process_first_line(line: str) -> str:
    """
    Detect the 'FunctionName: Description' pattern on the first comment line
    and convert it to a Markdown H1 heading followed by a description
    paragraph.

    Example input:  "myScript: computes the FFT of an input signal"
    Example output: "# myScript\nComputes the FFT of an input signal"
    """
    match = re.match(r"^(\w+)\s*:\s*(.+)$", line)
    if not match:
        return line

    name = match.group(1)
    description = match.group(2).strip()
    description = description[0].upper() + description[1:]
    return f"# {name}\n{description}"


def process_see_also(line, FUNCTION_REGISTRY) -> str:
    """
    Detect a 'See also:' line and convert the listed function names into
    relative Markdown links pointing to other .md files in the same directory.

    Example input:  "See also: zeros, ones, eye"
    Example output: "See also: [zeros](zeros.md), [ones](ones.md), [eye](eye.md)"
    """
    match = re.match(r"^\s*(See also:\s*)(.+)$", line, re.IGNORECASE)
    if not match:
        return line

    prefix = match.group(1)
    functions_part = match.group(2)

    func_names = [f.strip().rstrip(".") for f in re.split(r"[,\s]+", functions_part) if f.strip()]

    links = []
    for fn in func_names:
        if fn.lower() in FUNCTION_REGISTRY:
            links.append(f"[{fn.lower()}]({fn.lower()}.md)")
        else:
            links.append(fn.lower())

    return prefix + ", ".join(links)


def parse_blocks(matlab_code):
    """
    Split MATLAB source into an ordered list of blocks.

    Each block is a dict with:
        kind   "text" for comment runs, "code" for code runs
        lines  the raw lines of the block, in order (blank lines kept). For
               text blocks the leading "% " has already been stripped; for
               code blocks the original source lines are kept verbatim.

    The splitting mirrors the original single-pass state machine: a run of
    comment lines becomes one text block, a run of code lines (including any
    interleaved blank lines) becomes one code block, and blank lines outside
    any run are dropped.
    """
    blocks = []
    code_buffer = []
    comment_buffer = []

    def flush_code():
        if code_buffer:
            blocks.append({"kind": "code", "lines": list(code_buffer)})
            code_buffer.clear()

    def flush_comments():
        if comment_buffer:
            blocks.append({"kind": "text", "lines": list(comment_buffer)})
            comment_buffer.clear()

    for raw in matlab_code.splitlines():
        line = _strip_demo_directive(raw)
        stripped = line.strip()

        if stripped == "":
            if comment_buffer:
                comment_buffer.append("")
            elif code_buffer:
                code_buffer.append("")
            continue

        if stripped.startswith("%"):
            flush_code()
            comment_text = re.sub(r"^%\s?", "", stripped)
            comment_buffer.append(comment_text)
        else:
            flush_comments()
            code_buffer.append(line)

    flush_code()
    flush_comments()
    return blocks


def code_chunk_texts(blocks):
    """
    Return the non-empty, stripped code strings in order.

    This is the definition of a "chunk": the exact text that appears inside a
    ```matlab fence. The capture spec builder and the renderer both derive
    chunks from this function, so chunk indices line up with manifest keys.
    """
    chunks = []
    for block in blocks:
        if block["kind"] != "code":
            continue
        stripped = "\n".join(block["lines"]).strip()
        if stripped:
            chunks.append(stripped)
    return chunks


def render_capture(entry) -> str:
    """
    Render one manifest entry (console output and figures for a single chunk)
    as markdown to place directly under its code block.

    The manifest entry is a dict with keys "text", "figures", and "error".
    Figure paths are written relative to a demo page at docs/mfiles/demos/,
    which sits two levels below docs/, hence the "../../images/demos/" prefix.
    """
    parts = []

    text = (entry.get("text") or "").strip("\n")
    if text.strip():
        parts.append("Output:\n\n```text\n" + text + "\n```")

    error = (entry.get("error") or "").strip()
    if error:
        parts.append("Error:\n\n```text\n" + error + "\n```")

    for fname in entry.get("figures") or []:
        parts.append(f"![{Path(fname).stem}](../../images/demos/{fname})")

    return "\n\n".join(parts)


def render_blocks(blocks, FUNCTION_REGISTRY, manifest=None) -> str:
    """
    Render parsed blocks to markdown.

    Args:
        blocks: output of parse_blocks().
        FUNCTION_REGISTRY: mapping used to linkify "See also" lines.
        manifest: optional mapping from code-chunk index (int) to a capture
            entry. When given, each chunk's captured output and figures are
            inserted after its code block. When None, output is identical to
            the original parser.
    """
    output = []
    first_comment_seen = False
    chunk_index = 0

    for block in blocks:
        if block["kind"] == "text":
            processed = []
            for line in block["lines"]:
                if not first_comment_seen:
                    processed.append(process_first_line(line))
                    first_comment_seen = True
                else:
                    processed.append(process_see_also(line, FUNCTION_REGISTRY))
            text = "\n".join(processed).strip()
            if text:
                output.append(text)
        else:
            stripped = "\n".join(block["lines"]).strip()
            if stripped:
                output.append(f"```matlab\n{stripped}\n```")
                if manifest is not None:
                    entry = manifest.get(chunk_index)
                    if entry:
                        rendered = render_capture(entry)
                        if rendered:
                            output.append(rendered)
                chunk_index += 1

    return "\n\n".join(output)


def parse_matlab_to_markdown(matlab_code, FUNCTION_REGISTRY, manifest=None) -> str:
    """Parse MATLAB source to markdown, optionally splicing a capture manifest."""
    blocks = parse_blocks(matlab_code)
    return render_blocks(blocks, FUNCTION_REGISTRY, manifest)


def main():
    if len(sys.argv) < 2:
        print("Usage: python matlab_to_markdown.py <input.m> [output.md]")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else input_path.with_suffix(".md")

    matlab_code = input_path.read_text(encoding="utf-8")
    markdown = parse_matlab_to_markdown(matlab_code, {})
    output_path.write_text(markdown, encoding="utf-8")
    print(f"Written to {output_path}")


if __name__ == "__main__":
    main()
