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

# Capture directives are trailing (or whole-line) comments that drive capture:
#
#   %#demo-input: <answer>    the answer to a scripted input() or getinp() call
#   %#demo-snapshot           export the current figure again after this chunk
#   %#demo-snapshot: all      export every figure left open by earlier chunks
#
# A directive counts only at the end of a code line or alone on its own line. In
# a prose comment ("% add %#demo-snapshot to ...") it is just text, so that a
# demo can explain the directives without triggering them.
#
# They must never appear in the rendered code, so they are stripped from every
# source line before the line is classified as comment or code. Input answers
# are read from the raw source by demo_capture, and snapshot requests are
# recorded on the code block by parse_blocks, so removing them loses nothing.
_DIRECTIVE_INLINE = re.compile(r"\s*%#demo-(?:input:|snapshot\b).*$")
_SNAPSHOT = re.compile(r"%#demo-snapshot\b(?::(.*))?$")

# Snapshot modes, as written into the capture spec. An empty string means the
# chunk asks for no snapshot.
SNAPSHOT_NONE = ""
SNAPSHOT_CURRENT = "current"
SNAPSHOT_ALL = "all"


def is_prose_comment(line: str) -> bool:
    """
    True for a comment line that is prose, where directives are plain text.

    A line starting with "%" is prose unless it starts with a directive, which
    is how a whole-line directive is written.
    """
    stripped = line.lstrip()
    return stripped.startswith("%") and not stripped.startswith("%#demo-")


def _strip_demo_directive(line: str) -> str:
    """Remove a capture directive (%#demo-input, %#demo-snapshot) from a line."""
    if is_prose_comment(line):
        return line
    return _DIRECTIVE_INLINE.sub("", line)


def snapshot_mode(line: str, line_number: int = 0) -> str:
    """
    Return the snapshot mode requested on one source line.

    Args:
        line: a raw source line.
        line_number: its 1-based number, only used in the error message.

    Returns:
        SNAPSHOT_NONE when the line has no %#demo-snapshot directive,
        SNAPSHOT_CURRENT for a bare directive, SNAPSHOT_ALL for ": all".

    Raises:
        ValueError: for any other argument, so a typo fails the capture instead
            of silently exporting nothing.
    """
    match = None if is_prose_comment(line) else _SNAPSHOT.search(line)
    if not match:
        return SNAPSHOT_NONE
    argument = (match.group(1) or "").strip().lower()
    if argument == "":
        return SNAPSHOT_CURRENT
    if argument == SNAPSHOT_ALL:
        return SNAPSHOT_ALL
    raise ValueError(
        f"line {line_number}: unknown %#demo-snapshot argument {argument!r}; "
        "use '%#demo-snapshot' or '%#demo-snapshot: all'"
    )


def _stronger_snapshot(first: str, second: str) -> str:
    """Combine two snapshot requests on one chunk: all > current > none."""
    order = (SNAPSHOT_NONE, SNAPSHOT_CURRENT, SNAPSHOT_ALL)
    return max(first, second, key=order.index)


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


def comment_indent(line: str) -> int:
    """
    Return the indentation of a source line, in columns.

    Tabs count as 4 columns, the MATLAB editor default.
    """
    expanded = line.expandtabs(4)
    return len(expanded) - len(expanded.lstrip())


def parse_blocks(matlab_code):
    """
    Split MATLAB source into an ordered list of blocks.

    Each block is a dict with:
        kind      "text" for comment runs, "code" for code runs
        lines     the raw lines of the block, in order (blank lines kept). For
                  text blocks the leading "% " has already been stripped; for
                  code blocks the original source lines are kept verbatim.
        snapshot  code blocks only: the snapshot mode requested by any
                  %#demo-snapshot directive in the block, SNAPSHOT_NONE if none
        indent    text blocks only: the indentation of the comment lines, in
                  columns, so the renderer can indent the prose to match

    The splitting mirrors the original single-pass state machine: a run of
    comment lines becomes one text block, a run of code lines (including any
    interleaved blank lines) becomes one code block, and blank lines outside
    any run are dropped. A comment line with text at a different indentation
    from the text before it starts a new text block, so each block has one
    indentation. Empty comment lines ("%" alone, used as separators) take the
    indentation of the block they fall in. Text blocks never affect how code
    is split into chunks.

    Raises:
        ValueError: for a %#demo-snapshot directive with an unknown argument,
            or one that is not inside a run of code, where it would have no
            chunk to attach to.
    """
    blocks = []
    code_buffer = []
    comment_buffer = []
    comment_block_indent = None     # indentation of the buffered comment text
    code_snapshot = SNAPSHOT_NONE

    def flush_code():
        nonlocal code_snapshot
        if code_buffer:
            blocks.append({"kind": "code", "lines": list(code_buffer),
                           "snapshot": code_snapshot})
            code_buffer.clear()
        code_snapshot = SNAPSHOT_NONE

    def flush_comments():
        nonlocal comment_block_indent
        if comment_buffer:
            blocks.append({"kind": "text", "lines": list(comment_buffer),
                           "indent": comment_block_indent or 0})
            comment_buffer.clear()
        comment_block_indent = None

    for line_number, raw in enumerate(matlab_code.splitlines(), start=1):
        mode = snapshot_mode(raw, line_number)
        line = _strip_demo_directive(raw)
        stripped = line.strip()

        if mode != SNAPSHOT_NONE:
            if stripped == "" and not code_buffer:
                raise ValueError(
                    f"line {line_number}: %#demo-snapshot must follow code in the "
                    "same run, not a comment; put it at the end of a code line"
                )
            code_snapshot = _stronger_snapshot(code_snapshot, mode)

        if stripped == "":
            if comment_buffer:
                comment_buffer.append("")
            elif code_buffer:
                code_buffer.append("")
            continue

        if stripped.startswith("%"):
            flush_code()
            comment_text = re.sub(r"^%\s?", "", stripped)
            if comment_text.strip():
                indent = comment_indent(line)
                if comment_block_indent is not None and indent != comment_block_indent:
                    flush_comments()
                comment_block_indent = indent
            comment_buffer.append(comment_text)
        else:
            flush_comments()
            code_buffer.append(line)

    flush_code()
    flush_comments()
    return blocks


def code_block_text(lines):
    """
    Join the lines of a code block into the text shown in its fence.

    Blank lines at either end and trailing whitespace are dropped, but the
    indentation of the first line is kept. A plain strip() would remove it,
    and a block that starts inside a loop (because a comment split the loop)
    would show its first line flush left and the rest indented.
    """
    return "\n".join(lines).strip("\n").rstrip()


def code_chunk_texts(blocks):
    """
    Return the non-empty code strings in order, as code_block_text() gives them.

    This is the definition of a "chunk": the exact text that appears inside a
    ```matlab fence. The capture spec builder and the renderer both derive
    chunks from this function, so chunk indices line up with manifest keys.
    """
    chunks = []
    for block in blocks:
        if block["kind"] != "code":
            continue
        text = code_block_text(block["lines"])
        if text.strip():
            chunks.append(text)
    return chunks


def code_chunk_snapshots(blocks):
    """
    Return the snapshot mode of each chunk, aligned with code_chunk_texts().

    Uses the same filter as code_chunk_texts (a code block that is blank once
    stripped is not a chunk), so the two lists always have the same length.
    """
    return [
        block.get("snapshot", SNAPSHOT_NONE)
        for block in blocks
        if block["kind"] == "code" and "\n".join(block["lines"]).strip()
    ]


def indent_prose(text: str, indent: int) -> str:
    """
    Indent a paragraph of prose by 'indent' columns on the page.

    Markdown has no indented prose: leading spaces make a code block. So the
    text goes in an HTML block with a left margin in "ch", the width of one
    character, and markdown="1" keeps it rendered as markdown (md_in_html is
    enabled in mkdocs.yml). Unindented text is returned unchanged.
    """
    if indent <= 0:
        return text
    return (f'<div class="demo-indent" style="margin-left: {indent}ch" markdown="1">'
            f"\n\n{text}\n\n</div>")


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
                output.append(indent_prose(text, block.get("indent", 0)))
        else:
            text = code_block_text(block["lines"])
            if text.strip():
                output.append(f"```matlab\n{text}\n```")
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
