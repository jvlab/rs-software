# Demo 3: Combined Choice File → Geometric model

This demo fits Euclidean geometric models to the similarity judgments in a
combined choice file. It estimates perceptual spaces of different dimensions,
compares each model to random and best-case baselines, and saves both a CSV
summary and a `.mat` file containing the fitted coordinates and likelihoods.

For a quick test that the script runs, you can set `max_iterations` to a low
value such as `100`. When running the model properly, set `max_iterations`
to several thousand or more. The fitting step can take a while to run.

#### Run the demo

```bash
cd rs-software
python -m src.rs_py.demos.demo_fit_euclidean
```

#### Inputs

| Prompt                                                        | What the parameter is                        | Example input                   |
| ------------------------------------------------------------- | -------------------------------------------- | ------------------------------- |
| Path to the combined choices file for a participant           | Input `.mat` file produced by Demo 2         | `/path/to/image_choices_S4.mat` |
| Experiment name                                               | Used when naming output files                | `image`                         |
| Subject name or ID                                            | Used when naming output files                | `S4`                            |
| Output directory                                              | Directory where output files will be written | `/path/to/output`               |
| Dimensionality of models to fit                               | Comma-separated list of model dimensions     | `1,3,5`                         |
| Noise level                                                   | Standard deviation of comparison noise       | `1`                             |
| Maximum number of triadic judgments to use                    | Use `0` to use all data                      | `0`                             |
| Maximum number of iterations before returning the final model | Optimization stopping limit                  | `100` for a quick test          |
| Learning rate                                                 | Step size for minimization                   | `0.05`                          |
| Tolerance                                                     | Stopping criterion for optimization          | `1e-6`                          |
| Minimization algorithm                                        | `nelder-mead` or `gradient-descent`          | `gradient-descent`              |

To use the sample data included with the repository, enter:
```commandline
0
```
for the required file/path prompts.

For the optional prompts, you can press
Enter to accept the defaults, or enter values like the examples shown above.

#### What you will see when you run the demo
Let's say we use all default options, but set `max_iterations` to 100,
and `model_dimensions` to `1,3,5` to get 1D, 3D and 5D coordinates respectively.
```
Path to the combined choices file for a participant:
>> 
Experiment name:
>> 
Subject name or ID:
>> 
Output directory :
>> 
The following arguments are optional. 
    Enter the dimensionality of models to fit in a comma separated list.
    Default: [1, 2, 3, 4, 5]
>>1,3,5
    Enter a noise level to model error in comparing distances:
    Default: 1
>>
    Enter the maximum number of triadic judgments to use. Enter 0 to use all data:
    Default: 'uses all
>>'
    Enter the maximum number of iterations before returning the final model:
    Default: 50000
>>100
    Enter learning rate to use for minimization:
    Default: 0.05
>>
    Enter acceptable tolerance for difference between iterations (stopping criterion):
    Default: 1e-6
>>
    Enter minimization algorithm (opts: nelder-mead, gradient-descent)
    Default: gradient-descent
>>
```

#### Example terminal output as demo runs
First setting used are printed out:
```
======================================================================
GEOMETRIC MODEL FIT DEMO
======================================================================
DATA
----------------------------------------------------------------------
Filepath:            /Users/suniyya/Dropbox/Research/Thesis_Work/Side_Projects/rs-software/src/rs_py/samples/choice_files/image_choices_S4.mat
Experiment:          image
Subject:             S4
Output directory:    /Users/suniyya/Dropbox/Research/Thesis_Work/Side_Projects/rs-software/src/rs_py/samples/outputs
Max trials used:     inf

OPTIMIZATION SETTINGS
----------------------------------------------------------------------
Max iterations:      100
Learning rate:       0.05
Tolerance:           1e-06

NOISE PARAMETERS
----------------------------------------------------------------------
Sigma (compare):     1.000000
======================================================================
```
Then, updates are provided as the demo progresses
```
Loaded pairwise judgments
------------------------------------------------------------
Number of unique comparisons: 5994
Total triads (including repeats): 31080
------------------------------------------------------------

============================================================
FITTING 1D EUCLIDEAN MODEL
============================================================
...
Negative Log Likelihood per triad of the model: -0.6405

============================================================
FITTING 3D EUCLIDEAN MODEL
============================================================
...
Negative Log Likelihood per triad of the model: -0.5668

============================================================
FITTING 5D EUCLIDEAN MODEL
============================================================
...
Negative Log Likelihood per triad of the model: -0.5670
```
When all geometric models have been fit, the best (upper bound) 
and random (lower bound) models are evaluated. 
```
============================================================
BASELINE COMPARISON
============================================================
Best possible model LL:   -0.1864
Random choice model LL:   -1.0000
============================================================

FINAL MODEL COMPARISON
============================================================
 Model  Log Likelihood  number of points Experiment Subject
    1D       -0.640481                37      image      S4
    3D       -0.566755                37      image      S4
    5D       -0.566969                37      image      S4
  best       -0.186397                37      image      S4
random       -1.000000                37      image      S4
============================================================
Saved: /Users/suniyya/Dropbox/Research/Thesis_Work/Side_Projects/rs-software/src/rs_py/samples/outputs/image_coords_S4.mat
```

#### Output files

This demo writes two output files.

The first is a CSV summary of the fitted models. It includes the log
likelihood for each fitted dimension, plus the best-case and random-choice
baselines. These are the raw model likelihood values from the fit, without
debiasing correction.

The second, and more important, output is the `.mat` file containing the fitted
coordinates and likelihoods. This file is intended for downstream analysis and
includes the model embeddings for each fitted dimension, the raw likelihoods,
the debiased relative likelihoods, the bias estimate, and the baseline model
likelihoods. For more on debiasing, see [What is Debiasing?](#what-is-debiasing)

#### Output .mat file

For the sample data, the saved file is:
```commandline
image_coords_S4.mat
```

The file contains a MATLAB struct with the following fields:
```
dim1                    # model coordinates for the 1D model, each row is a stimulus
dim3                    # model coordinates for the 3D model...
dim5                    # model coordinates for the 5D model...
rawLLs                  # an array with LLs for each model
debiasedRelativeLL      # an array with the same LLs after debiasing relative to best model  
biasEstimate            # estimate bias of the best model 
bestModelLL             
randModelLL             
readme                  # a reminder of what debiasedRelativeLL is in a string
stim_list               # names of stimuli in the order they appear in dim1, dim3 etc.
```

#### Next step

The output of this demo can be used for modules for [manipulating representational spaces](/rs-software/rs-ml-overview/) in the rs-software/src.

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

### What is Debiasing?
Debiasing is needed because when a judgment is hard, the two distances may be nearly equal, so the true choice probability may be around $\frac{1}{2}$. But with the experiment repeated only 5 times, the empirical probability can only be $\frac{2}{5}$ or $\frac{3}{5}$, never exactly $\frac{1}{2}$. So the best-case model will match those empirical proportions exactly by definition, even if the true underlying model is already correct. That means the best LL will look better than a ground-truth model simply because it is overfitting to the observed data. Debiasing corrects for this, so model fits can be compared more fairly.

The debiased likelihood corrects the raw model likelihood by adding the estimated median bias before comparing it to the best-case baseline. The estimated median bias of the geometrically unconstrained model depends on the ratio of the observed RMS distance to the noise parameter. See Waraich and Victor (2024) for details.
