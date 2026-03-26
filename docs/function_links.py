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
    "dataset structure":          "data_structures/#dataset-structure",
    "coordinate structure":       "data_structures/#coordinate-structure",
    "stimulus metadata structure": "data_structures/#stimulus-metadata-structure",
    "set metadata structure":     "data_structures/#set-metadata-structure",
    "ray structure":              "data_structures/#ray-structure",
    # add more as needed...
}

# joints the two dictionaries
FUNCTION_LINKS = {**MATLAB_BUILTINS, **OWN_DATATYPES}
