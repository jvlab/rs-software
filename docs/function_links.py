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
    "binary texture domain":        "data_structures/#binary-texture-domain",
    "setup metadata":	            "data structures/#setup-metadata",
    # add more as needed...
}

# joints the two dictionaries
FUNCTION_LINKS = {**MATLAB_BUILTINS, **OWN_DATATYPES}
