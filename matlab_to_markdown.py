# -*- coding: utf-8 -*-
"""
Parse matlab demo files to markdown.

It reads every .m file in folder "src/demos", and converts
every line of comment in markdown text, and every line of code
as markdown code blocks. The entry function is parse_matlab_to_markdown(),
called by script parse_all_demos_to_markdown.py, which needs to be executed
before building with mkdocs.

@author: G. Aguilar - Feb 2026
"""

import re
import sys
from pathlib import Path

global FUNCTION_REGISTRY

    
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


def parse_matlab_to_markdown(matlab_code, FUNCTION_REGISTRY) -> str:
    lines = matlab_code.splitlines()
    output = []
    code_buffer = []
    comment_buffer = []
    first_comment_seen = False

    def flush_code():
        if code_buffer:
            stripped = "\n".join(code_buffer).strip()
            if stripped:
                output.append(f"```matlab\n{stripped}\n```")
            code_buffer.clear()

    def flush_comments():
        if comment_buffer:
            text = "\n".join(comment_buffer).strip()
            if text:
                output.append(text)
            comment_buffer.clear()

    for line in lines:
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
            if not first_comment_seen:
                comment_text = process_first_line(comment_text)
                first_comment_seen = True
            else:
                comment_text = process_see_also(comment_text, FUNCTION_REGISTRY)
            comment_buffer.append(comment_text)

        else:
            flush_comments()
            code_buffer.append(line)

    flush_code()
    flush_comments()

    return "\n\n".join(output)


def main():
    if len(sys.argv) < 2:
        print("Usage: python matlab_to_markdown.py <input.m> [output.md]")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else input_path.with_suffix(".md")

    matlab_code = input_path.read_text(encoding="utf-8")
    markdown = parse_matlab_to_markdown(matlab_code)
    output_path.write_text(markdown, encoding="utf-8")
    print(f"Written to {output_path}")


if __name__ == "__main__":
    main()
