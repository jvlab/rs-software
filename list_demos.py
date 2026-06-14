#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
List all demos from src/demos in markdown file docs/demos.md

@author: G. Aguilar - Feb 2026
"""
import os
import re

DEMOS_DIR = "src/demos"
OUTPUT_FILE = "docs/demos.md"
OUTPUT_DIR = "mfiles/demos"

def get_matlab_description(filepath):
    """Extract the short description from the first comment line of a MATLAB file."""
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or re.match(r"^(function|classdef)\b", line):
                continue
            if line.startswith("%"):
                comment = line.lstrip("%").strip()
                # Take only the part after the first colon
                if ":" in comment:
                    return comment.split(":", 1)[1].strip()
                return comment
            break
    return "No description available."

def generate_demo_list():
    matlab_files = sorted([
        f for f in os.listdir(DEMOS_DIR) if f.endswith(".m")
    ])

    lines = [
        "# Demos\n",
        "The library contains several demos that show its functionality. They are located in folder `src/demos`.\n",
        "",
    ]

    for filename in matlab_files:
        fnamestem = filename.split('.m')[0]
        filepath = os.path.join(DEMOS_DIR, filename)
        name = os.path.splitext(filename)[0]
        description = get_matlab_description(filepath)
        lines.append(f"- [`{name}`]({OUTPUT_DIR}/{fnamestem}.md) - {description}")

    # make sure the output directory exists before writing
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Written {len(matlab_files)} demos to {OUTPUT_FILE}")

if __name__ == "__main__":
    generate_demo_list()

