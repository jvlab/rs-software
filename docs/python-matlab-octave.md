# Python - MATLAB/Octave

## Functions that use Python

Two MATLAB functions call Python: `rs_subset_coordsets` (keep or drop stimuli in a `dataset structure`)
and `rs_subset_choicesets` (the same for choice data). They need Python 3 with `numpy` and `scipy`.
Nothing has to be installed with pip: they use the Python code in the folder `rs_tools` of this
repository.

* **MATLAB**: choose the Python to use, once per session, with `pyenv`, for example
  `pyenv('Version', '/path/to/python')` (the Python of a conda environment, see
  [Dependencies for MATLAB environment](#dependencies-for-matlab-environment) below). Typing `pyenv`
  shows the current choice; its `Version` must not be empty.
* **Octave**: `python3` must be on the system path; the functions call it on the command line. Another
  Python can be given with the option `python_executable`.

`rs_auto_test` runs the tests of these two functions (`rs_subset_coordsets_test`,
`rs_subset_choicesets_test`) when Python is available, and reports them as skipped otherwise.

> **numpy built with Intel's Math Kernel Library (MKL) can crash MATLAB.** By default, MATLAB runs Python inside its own process (`backend` `'auto'`, which is `'py'` in
> MATLAB). On Linux, if numpy was built with this library, as in anaconda's default channel, MATLAB can
> crash (segmentation violation) when numpy is loaded after MATLAB has done numerical work, because
> MATLAB's copy of the library and numpy's copy clash. numpy installed with pip, or from conda-forge, uses OpenBLAS and does
> not have this problem. To check, run `import numpy; numpy.show_config()` in that Python and look
> for `mkl`. Alternatives: call the functions with `opts_subset.backend='cli'`, which runs Python as a
> separate program, or call them before any other computation in the MATLAB session.

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


