# function_links.py
"""
List of links to use for the documentation. 
This list is read by mkdocs while building, to set the links correctly.

First are MATLAB function defined and their links to official MATLAB documentation.


@author: G. Aguilar - Feb 2026
"""

# Manually maintained MATLAB builtins → MathWorks documentation URLs
MATLAB_BUILTINS = {
   "procrustes":   "https://mathworks.com/help/stats/procrustes.html",
   "graph":        "https://mathworks.com/help/matlab/ref/graph.html",
   "conncomp":     "https://mathworks.com/help/matlab/ref/graph.conncomp.html",
   "isgraph":      "https://mathworks.com/help/matlab/ref/isgraph.html",
   "struct":       "https://mathworks.com/help/matlab/ref/struct.html",
   "cell":         "https://mathworks.com/help/matlab/ref/cell.html",
   "cell array":   "https://mathworks.com/help/matlab/ref/cell.html",
   "int":          "https://www.mathworks.com/help/matlab/matlab_prog/integers.html",
    # add more as needed...
}

OWN_DATATYPES = {
    # Custom data types (link to your own docs pages)
    "dataset structure":            "data_structures/#dataset-structure",
    "dataset structures":           "data_structures/#dataset-structure",
    "coordinate structure":         "data_structures/#coordinate-structure",
    "coordinate structures":        "data_structures/#coordinate-structure",
    "stimulus metadata structure":  "data_structures/#stimulus-metadata-structure",
    "stimulus metadata structures": "data_structures/#stimulus-metadata-structure",
    "set metadata structure":       "data_structures/#set-metadata-structure",
    "set metadata structures":      "data_structures/#set-metadata-structure",
    "ray structure":                "data_structures/#ray-structure",
    "ray structures":               "data_structures/#ray-structure",
    "transformation structure":     "data_structures/#transformation-structure",
    "transformation structures":    "data_structures/#transformation-structure",
    "ray structure":   	            "data_structures/#ray-structure",
    "ray structures":               "data_structures/#ray-structure",
    "stimulus coordinates":         "data_structures/#stimulus-coordinates",
    "setup metadata":	            "data structures/#setup-metadata",
    "binary texture domain":        "data_structures/#binary-texture-domain",
    "binary texture":               "data_structures/#binary-texture-domain",
    "binary textures":              "data_structures/#binary-texture-domain",
    "animal domain":                "data_structures/#animal-domain",
    "MPI faces domain":             "data_structures/#mpi-faces-domain",
    "MPI faces":                    "data_structures/#mpi-faces-domain",
    "coordinate file":              "data_structures/#coordinate file",
    "coordinate files":             "data_structures/#coordinate file",
    "choice file":                  "data_structures/#choice file",
    "choice files":                 "data_structures/#choice file",
    "quadratic form model":         "data_structures/#quadratic form model",
    "qudaratic form models":        "data structures/#quadratic form models",
    # add more as needed...
}






# ---------------------------------------------------------------------------
# Build the merged FUNCTION_LINKS dictionary used by all hooks.
#
# Keys in the source dictionaries (MATLAB_BUILTINS, OWN_DATATYPES) may be
# written in any case for readability (e.g. "MPI faces domain"). All hook
# code looks them up using `key.lower().strip()`, so we normalize the keys
# here, once, at module load time. The normalization:
#   - lowercases the key,
#   - strips surrounding whitespace,
#   - collapses internal runs of whitespace to a single space.
#
# If two source keys collapse to the same normalized form (e.g. "Struct"
# and "struct") with different URLs, that is a configuration error and
# raises ValueError immediately so it is caught at build time rather than
# silently overwriting one entry with the other.
# ---------------------------------------------------------------------------

def _normalize_key(key: str) -> str:
    """Return the canonical lookup form of a dictionary key."""
    return " ".join(key.lower().split())


def _build_function_links(*sources: dict) -> dict:
    """Merge source dicts into one, normalizing keys and rejecting conflicts."""
    merged: dict = {}
    seen_originals: dict = {}  # normalized key --> original key, for error msg
    for source in sources:
        for original_key, url in source.items():
            norm = _normalize_key(original_key)
            if norm in merged and merged[norm] != url:
                raise ValueError(
                    f"function_links: conflicting entries for normalized key "
                    f"{norm!r}: {seen_originals[norm]!r} --> {merged[norm]!r}, "
                    f"and {original_key!r} --> {url!r}"
                )
            merged[norm] = url
            seen_originals[norm] = original_key
    return merged


FUNCTION_LINKS = _build_function_links(MATLAB_BUILTINS, OWN_DATATYPES)
