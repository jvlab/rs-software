# Python - MATLAB/Octave


## Running python inside MATLAB

[The following needs to be edited, example needs to be added, and it needs to be verified again. ]
### Using MATLAB to run `rs_py`

```MATLAB
params = py.dict(pyargs( ...
    "input_path", "/path/to/input", ...
    "output_dir", "/path/to/output", ...
    "comparison_type", "triadic" ...
));

meta = py.dict(pyargs( ...
    "subject", "S4", ...
    "exp_name", "demo_experiment", ...
    "num_trials", double(1110), ...
    "num_sessions", double(10) ...
));

params{"metadata"} = meta;

mod = py.importlib.import_module("src.rs_py.scripts.write_choice_file_detailed");
mod.run(params);

```


```MATLAB
json_str = '{"input_path":"/path/to/input","output_dir":"/path/to/output","comparison_type":"triadic","metadata":{"subject":"S4","exp_name":"demo_experiment","num_trials":1110,"num_sessions":10}}';

mod = py.importlib.import_module("src.rs_py.scripts.write_choice_file_detailed");
mod.run(json_str);
```


## Dependencies for MATLAB environment

Create a conda environment with Python 3.10 or higher. 
```commandline
conda create -n rs_env python=3.10
```

Install required packages into the environment via pip
```commandline
pip install numpy scipy pandas
```

Find the path to your virtual environment
```commandline
conda env list
```
You may see output resembling the following:
```commandline
# conda environments:
#
# * -> active
# + -> frozen
                         /Users/suniyya/fsl
base                     /Users/suniyya/miniconda3
matlab_env           *   /Users/suniyya/miniconda3/envs/rs_env
mkdocs_env               /Users/suniyya/miniconda3/envs/mkdocs_env

```

Download rs-software from Github. 
Make sure that src in added to their path. 

Open the MATLAB console and set the environment as follows:
from inside rs-software 

Set python env
```matlab
pyenv(Version='/Users/suniyya/miniconda3/envs/rs_env');
```

import module. 3 modules to choose. 

**Add a field to coords file to inlcude used params eg iterations etc.**

JSON example first time around. But otherwise pydict. 

TEST to see if missingh options fail from None. in MATLAB.

## Running MATLAB inside python


