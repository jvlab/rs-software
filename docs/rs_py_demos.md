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

## Entry Points

The `rs_py` package can be used at three stages of the analysis pipeline.

### Step 1: Raw Rankings to Detailed Choice File

Use `write_choice_file_detailed`.

**Input:** Raw ranking data (CSV files) collected using the Waraich & Victor paradigm.

**Output:** A detailed choice file:

```text
*_detailed_choices_<subject>.mat
```

This file contains trial-by-trial similarity judgments. Each row corresponds to a single comparison made during a trial, along with metadata describing the experiment.

**Associated Demo:** `demo_detailed_choices.py`

If you are new to the package, we recommend running the demo first using the sample data included with the repository. See the **Demos** section for a complete walkthrough.

**Note:** This step is specific to the ranking paradigm described in Waraich & Victor (2022, 2024). If your data come from a different paradigm, you should typically start at Step 2 or Step 3 instead.

---

### Step 2: Detailed Choice File to Combined Choice File

Use `write_choice_file_combined`.

**Input:** A detailed choice file.

**Output:** A combined choice file:

```text
*_combined_choices_<subject>.mat
```

This step aggregates repeated occurrences of the same comparison across trials and sessions. The resulting file contains unique comparisons along with the number of times each judgment was observed.

Think of this as converting trial-by-trial data into summary statistics that are ready for model fitting.

**Associated Demo:** `demo_combined_choices.py`

The demo can be run using the sample detailed choice file produced in Step 1. See the **Demos** section for details.

---

### Step 3: Combined Choice File to Geometric Model

Use `run_model_fitting`.

**Input:** A combined choice file.

**Output:**

* Stimulus coordinates
* Model likelihoods
* A summary `.mat` file containing model results

This step fits geometric models that explain the observed similarity judgments. The model searches for coordinates such that distances between points best account for the observed choice probabilities.

The resulting coordinates can be interpreted as a geometric representation of the perceptual space underlying the behavioral data.

**Associated Demo:** `demo_fit_euclidean.py`

The demo can be run using the sample combined choice file produced in Step 2. See the **Demos** section for details.

## Demos (Run Everything End-to-End)

If you are new to `rs_py`, we recommend starting with the demos. The demos use sample data included with the repository and illustrate the three stages of the pipeline:

Raw ranking data
        ↓
Detailed choice file
        ↓
Combined choice file
        ↓
Geometric model

Each demo corresponds to one of the three entry points described above.

### Demo 1: Raw Rankings → Detailed Choice File

This demo converts raw ranking responses collected using the Waraich & Victor paradigm into a detailed choice file.

#### Run the demo

From the terminal:

```bash
cd rs-software
python -m src.rs_py.demos.demo_detailed_choices.py
```

---

#### Inputs

The demo will prompt you for the following:

| Prompt                   | What the parameter is                                                  |
| ------------------------ |------------------------------------------------------------------------|
| Path to subject data     | Folder containing raw response CSV files from the Waraich and Victor paradigm |
| Output directory         | Directory where any output files will be written                       |
| Experiment/paradigm name | Name of the condition or experiment. It is used when naming output files |
| Subject ID               | Subject identifier, used when naming output files                      |
| Judgment type            | `triadic` or `tetradic` (see [Notes on Comparison Formats](#notes-on-comparison-formats)|                                   |
| Total number of trials   | Stored as metadata                                                     |
| Total number of sessions | Stored as metadata                                                     |

To use the sample data included with the repository, enter:

```text
0
```

for all prompts.

---


#### What the user sees

The script will display the following prompts:

```text
Path to subject data:
Output directory:
Experiment/paradigm name (for output filename):
Subject ID (for output filename):
Judgment type: (triadic or tetradic)
For metadata
    provide total number of trials (optional):
For metadata
    provide total number of sessions (optional):
```

---

#### Example terminal output

```text
Processing raw data...
  Input directory: /path/to/S4
  Output directory: /path/to/output
  Subject: S4
  Experiment: animals
  Types of judgments: triadic

Saved results to /path/to/output/animals_detailed_choices_S4.mat

Done.
```

---

#### Output file

```text
animals_detailed_choices_S4.mat
```

---

#### Contents of the output file

The file contains three fields:

```text
metadata
response_colnames
responses
```

##### metadata

Information describing the dataset:

```text
subject = S4
exp_name = animals
num_trials = 1110
num_sessions = 10
judgment_type = triadic
stim_list = [...]
```

##### response_colnames

```text
trial
ref
s1
s2
N(D(ref, s1) > D(ref, s2))
```

##### responses

For the sample dataset:

```text
31080 rows × 5 columns
```

Each row represents a single triadic comparison derived from a ranking response.

Example:

```text
trial   ref   s1   s2   N(D(ref,s1) > D(ref,s2))
1       16    3    13            1
```

The first column indicates the trial from which the comparison originated. In this example, both rows come from trial 1.

The stimulus IDs correspond to entries in:

```text
metadata.stim_list
```

In this example, the stimulus IDs correspond to these stimuli:
```text
3  = bear
7  = cow
13 = elephant
16 = giraffe
```

Thus the first row corresponds to the comparison:

```text
(ref, s1, s2)
(giraffe, bear, elephant)
```
The participant's response of 1 indicates that they considered 'giraffe' to be more similar 'elephant' than to 'bear.'
In other words, when asked to click the most similar stimulus to 'giraffe', they clicked on 'elephant' before clicking on 'bear'.

To determine the name associated with any stimulus ID, look it up in:

```text
metadata.stim_list
```

within the same file.

The output of this demo becomes the input to **Demo 2**, which aggregates repeated occurrences of the same comparison across trials and sessions.

---

#### Next step

The output of Demo 1 becomes the input to **Demo 2**, which aggregates repeated occurrences of the same comparison across trials and sessions.

### Demo 2: Detailed Choice File → Combined Choice File

This demo aggregates repeated comparisons from a detailed choice file into a combined choice file.

#### Run the demo

```bash
cd rs-software
python -m src.rs_py.demos.demo_combined_choices.py
```

#### Inputs

| Prompt                             | What the parameter is                             |
| ---------------------------------- | ------------------------------------------------- |
| Path to detailed choices .mat file | Output file produced by Demo 1                    |
| Output directory                   | Directory where the combined file will be written |
| Experiment/paradigm name           | Used when naming output files                     |
| Subject ID                         | Used when naming output files                     |

To use the sample data included with the repository, enter:

```text
0
```

for all prompts.

#### Example terminal output

```text
Combining trial wise judgments.
  Input detailed .mat: /path/to/animals_detailed_choices_S4.mat
  Output dir:         /path/to/output
  Exp name:           animals
  Subject:            S4

Writing combined file in three-column format (ref, s1, s2).
Saved results to /path/to/output/animals_combined_choices_S4.mat

Done.
```

#### Output file

```text
animals_combined_choices_S4.mat
```

#### Contents of the output file

The file contains:

```text
metadata
response_colnames
responses
```

The metadata field is carried over from Demo 1.

##### response_colnames

```text
ref
s1
s2
N(D(ref, s1) > D(ref, s2))
N_Repeats(D(ref, s1) > D(ref, s2))
```

##### responses

For the sample dataset:

```text
5994 rows × 5 columns
```

Unlike the detailed choice file, there is no `trial` column. Repeated occurrences of the same comparison have been combined into a single row.

Example:

```text
ref   s1   s2   N(D(ref,s1) > D(ref,s2))   N_Repeats(D(ref,s1) > D(ref,s2))
16     3   13              5                              5
```

Using `metadata.stim_list`:

```text
3  = bear
13 = elephant
16 = giraffe
```

This row corresponds to:

```text
(ref, s1, s2)
(giraffe, bear, elephant)
```

The final two columns indicate that this comparison appeared 5 times in the experiment and the same outcome was observed on all 5 occasions.

Compared to the detailed choice file, many repeated comparisons have been merged, reducing the number of rows from 31,080 to 5,994.

#### Next step

The output of this demo becomes the input to **Demo 3**, which fits geometric models to the similarity judgments.


### Scripts for demos
```python
src.rs_py.scripts.write_choice_file_detailed
src.rs_py.scripts.write_choice_file_combined
src.rs_py.scripts.run_model_fitting
```


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


### Notes on Comparison Formats

The Waraich & Victor paradigm produces **triadic judgments**, in which two stimuli are compared relative to a common reference:

```text
Is A more similar to ref than B is?
```
The same judgment can be stored in two formats.
##### Triadic format (recommended)
`(ref, A, B)`

Example:
`(cat, dog, wolf)`

corresponding to:
`D(cat,dog) > D(cat,wolf)`


This format is more compact and is the format used in the Waraich & Victor studies.

##### Tetradic format
`(ref, A, ref, B)`

Example:
`(cat, dog, cat, wolf)`

corresponding to:
`D(cat,dog) > D(cat,wolf)`


This contains the same information, but represents the judgment as a comparison between two stimulus pairs.

##### Which should I choose?

For most users, we recommend choosing `triadic.` Choose `tetradic` only if your downstream analysis expects comparisons between stimulus pairs or you need compatibility with another tetradic dataset.


### Note on optimization settings

The fitting procedure stops when either:

1. the maximum number of iterations is reached, or
2. the change between iterations falls below the tolerance threshold.

If you want a faster, rougher fit, you can try:

* increasing `learning_rate`
* increasing `tolerance`

If the fit stops too early or has not settled, you can:

* increase `max_iterations`
* decrease `tolerance`

The best settings will depend on your data. For the JNeurosci 2024 analysis, we used roughly 30,000 to 50,000 iterations for the main fits.


### References
Waraich, S. A., & Victor, J. D. (2022). A Psychophysics Paradigm for the Collection and Analysis of Similarity Judgments. Journal of Visualized Experiments, 181. https://doi.org/10.3791/63461

Waraich, S. A., & Victor, J. D. (2024). The Geometry of Low- and High-Level Perceptual Spaces. Journal of Neuroscience, 44(4), e1460232023–e1460232023. https://doi.org/10.1523/jneurosci.1460-23.2023