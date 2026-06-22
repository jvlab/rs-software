## Installation and Set-up
We recommend using Python 3.10 or higher and installing dependencies in a virtual environment.

If you plan to call `rs_py` from MATLAB, the required Python version may depend on your MATLAB version.
### 1. Download `rs-software` from GitHub
Clone the repository from GitHub by typing the following into your terminal.
```commandline
git clone https://github.com/jvlab/rs-software.git
```
Alternatively, download the zipped folder.

### 2. Create a virtual environment

Create a conda environment with Python 3.10 or higher. 
In your terminal, create a new environment as follows. 
```commandline
conda create -n rs_env python=3.10
```
If you do not already have conda you may have to install it, or you can use an alternate utility to create a virtual environment such as venv.

### 3. Install dependencies
While in your new conda environment, type the following in your terminal to install required packages:
```commandline
pip install numpy scipy pandas
```

### 4. Verify installation
Verify that the environment was created and note the path to it, by typing the following in the terminal:
```commandline
conda env list
```
You may see output resembling the following. Copy the path you see for the `rs_env` environment as it will be used when setting up MATLAB.
```commandline
# conda environments:
#
# * -> active
# + -> frozen
                         /Users/suniyya/fsl
base                     /Users/suniyya/miniconda3
rs_env           *   /Users/suniyya/miniconda3/envs/rs_env
```
### 4. Set up MATLAB environment
If you do not intend to run `rs_py` scripts from MATLAB, you can skip this step.

We assume MATLAB R2024a or R2024b is being used. Other versions may also work with Python 3.10, but compatibility should be verified by the user. If you are able to complete this step, then there is no compatibility issue. 

1. Open MATLAB. 
2. Navigate to the `rs-software` folder and make sure `src` has been added to the path.
3. Open the MATLAB console and set the python environment by typing the following: 
```matlab
pyenv(Version='/Users/suniyya/miniconda3/envs/rs_env');
```
Ensure you replace the above path with what you copied in the previous step. 

Now, you should be able to import python modules and run them. See section **Using MATLAB to run `rs_py`** for details. 




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
## Installation and Set-up
We recommend using Python 3.10 or higher and installing dependencies in a virtual environment.

If you plan to call `rs_py` from MATLAB, the required Python version may depend on your MATLAB version.
### 1. Download `rs-software` from GitHub
Clone the repository from GitHub by typing the following into your terminal.
```commandline
git clone https://github.com/jvlab/rs-software.git
```
Alternatively, download the zipped folder.

### 2. Create a virtual environment

Create a conda environment with Python 3.10 or higher. 
In your terminal, create a new environment as follows. 
```commandline
conda create -n rs_env python=3.10
```
If you do not already have conda you may have to install it, or you can use an alternate utility to create a virtual environment such as venv.

### 3. Install dependencies
While in your new conda environment, type the following in your terminal to install required packages:
```commandline
pip install numpy scipy pandas
```

### 4. Verify installation
Verify that the environment was created and note the path to it, by typing the following in the terminal:
```commandline
conda env list
```
You may see output resembling the following. Copy the path you see for the `rs_env` environment as it will be used when setting up MATLAB.
```commandline
# conda environments:
#
# * -> active
# + -> frozen
                         /Users/suniyya/fsl
base                     /Users/suniyya/miniconda3
rs_env           *   /Users/suniyya/miniconda3/envs/rs_env
```
### 4. Set up MATLAB environment
If you do not intend to run `rs_py` scripts from MATLAB, you can skip this step.

We assume MATLAB R2024a or R2024b is being used. Other versions may also work with Python 3.10, but compatibility should be verified by the user. If you are able to complete this step, then there is no compatibility issue. 

1. Open MATLAB. 
2. Navigate to the `rs-software` folder and make sure `src` has been added to the path.
3. Open the MATLAB console and set the python environment by typing the following: 
```matlab
pyenv(Version='/Users/suniyya/miniconda3/envs/rs_env');
```
Ensure you replace the above path with what you copied in the previous step. 

Now, you should be able to import python modules and run them. See section **Using MATLAB to run `rs_py`** for details. 




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