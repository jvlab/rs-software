# Guide to `rs_py`

## Overview:
This package processes similarity judgments from behavioral experiments and fits geometric models to those judgments.

It is designed for experiments where participants make relative similarity judgments, such as:
> "Is stimulus A more similar to B or to C?"

### What the Pipeline Does

The pipeline transforms raw behavioral data into a geometric representation in three steps:

1. Convert ranking responses into pairwise comparisons
2. Aggregate those comparisons into choice probabilities
3. Fit a model where distances between stimuli explain those probabilities

> rank judgments &rarr; pairwise comparisons &rarr; choice probabilities &rarr; geometric models 

### The Final Output
* A geometric model of the perceptual space, i.e., coordinates for each stimulus 
  * closer points → more similar 
  * farther points → less similar 
* Log-likelihoods of each model, describing how well distances explain behavior

This is a simplified description. For full details, see:
* Waraich & Victor (2022)
* Waraich & Victor (2024)

The `rs_py` package is a more user-friendly version of the code used in these studies.

### Flexibility

You can enter the pipeline at any stage provided you have the correct inputs:
* raw data (Step 1)
* detailed choice file (Step 2)
* combined choice file (Step 3)

**NOTE:**

Step 1 requires that your data were collected using the ranking paradigm described in Waraich & Victor (2022, 2024).
If your data differ, you should start from Step 2 or Step 3.

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


## Quick Start (Run Everything End-to-End)

If you are new:

1. Complete the Installation and Set-up steps above
2. Run the following scripts in order

### Step 1. Create detailed choice file

In the terminal or your IDE, run the `demo_detailed_choice` file. Below, we provide instructions 
for the terminal.

```
python demo_detailed_choices.py
```
### Step 2. Create combined choice file
### Step 3. Fit geometric models


FOCUS ON ENTRY POINTS 
FROM TRIPLET DATA TO CHOICE PROB
FROM CHOICE PROB TO ..  headings 



Enter 0 for all prompts to use defaults.
4. 
5. Convert raw rank ordering judgments acquired using the Waraich and Victor (2022) paradigm into a tabular format in which every row contains the occurrence of a triadic comparison, (i.e., a comparison between the similarities of a reference stimulus to two other stimuli). 
* Tally the choices for repeated occurrences of the same traidic comparisons across all sessions of the experiment.
* From the above similarity judgments, estimate geometric models of the representational spaces in which distances between points best explain them.

There are three entry points that a user may find useful corresponding to the three steps above. They are in the scripts module. 
Below we describe their inputs and outputs and after that how to use them in Python or MATLAB.

```python
rs_py.scripts.write_choice_file_detailed
rs_py.scripts.write_choice_file_combined
rs_py.scripts.run_model_fitting
```

*detailed choice file script. lets say a diff paradigm, then better to enter at the next stage. Document this. *
What rules do you have to follow? Where is it flexible vs not.*

**Show how to use sample files to process the data to get the different outputs.** 
**some provision so it doesn't get overwritten when someone tries to run it. 
Should happen... with through both python and MATLAB.
If you have something like the binary texture exp you enter at the level of accumulated choice files which is the format we already have.** 
**JoVE procedure no need to generalize to our bw**

what these scripts can do and what they expect. What they take as input, what they return as output.
The key steps of this process are explained in the following demos.
A user may supply their files in the initial input form (needed by demo 1), or as intermediate form
as expected by demo 2 or demo 3 etc.

The first demo does X.

The second demo shows Y.

The demos build on each other.

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


#### Further Reading
Waraich, S. A., & Victor, J. D. (2022). A Psychophysics Paradigm for the Collection and Analysis of Similarity Judgments. Journal of Visualized Experiments, 181. https://doi.org/10.3791/63461

Waraich, S. A., & Victor, J. D. (2024). The Geometry of Low- and High-Level Perceptual Spaces. Journal of Neuroscience, 44(4), e1460232023–e1460232023. https://doi.org/10.1523/jneurosci.1460-23.2023