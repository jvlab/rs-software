# -*- coding: utf-8 -*-
"""
Creates .md files corresponding to all .m files found in the source code directory.

These .md files are needed as a placeholder so mkdocs can correctly pull out the 
docstring of each function.

@author: G. Aguilar - Feb 2026
"""

from glob import glob
from pathlib import Path

# folders where matlab files are located
list_mfiles1 = glob('src/*.m')
list_mfiles2 = glob('src/*/*.m')

list_mfiles = list_mfiles1 + list_mfiles2  # concatenate the two lists

for f in list_mfiles:
    input_path = Path(f)
    output_path = (Path('docs', 'mfiles') / input_path.name).with_suffix(".md")
        
    # skip files that are demos, contain "demo" in its filename
    if 'demo' in str(input_path.name):
        continue
        
    if 'Contents' in str(input_path.name):
        continue
    
    lines = [f"::: {input_path.stem}\n",
             f"    options:\n",
             "      heading_level: 1\n",
             ]
                 
    # make sure the output directory exists before writing
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # create md file with reference to function 
    with open(output_path, 'w') as f:
        f.writelines(lines)
                
    #
    print(f"Index md-file {output_path} created for m-file {input_path}")

# EOF
