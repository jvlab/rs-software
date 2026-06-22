## Install the files

Ensure that MATLAB or Octave is installed. MATLAB versions 2023 and later have been tested.

Clone or download GitHub repositories from [https://github.com/jvlab/rs-software](https://github.com/jvlab/rs-software)
and [https://github.com/jvlab/perceptual_space_geometry](https://github.com/jvlab/perceptual_space_geometry).
Set the path.  All directories in `rs-software` should have precedence over directories in `perceptual_space_geometry`.

* If using MATLAB: add all folders to the search path except src/octave_compat from `rs-software`. If you have downloaded a static copy, you may delete  `src/octave_compat`.
* If using Octave: add all folders to the search path.

## Verify the install

Navigate to `/rs_software/src`, clear the workspace, set `if_auto_skip=1`, and run `rs_auto_test`.

* This will exercise several modules, produce fig and mat files, and place them in `/tests`; it will take several minutes.
* Early in the process, you will be asked to respond to several keyboad prompts.  If a default is supplied, then accept it (Enter key); if confirmation is requested, confirm by entering a 1.

After execution, the fig files and mat files in `/tests` will be compared with files in `/benchmarks` that were downloaded from the repository.

* Differences, in comparison to the benchmarks, will be summarized and can be inspected in the fields of `r_diffs`.
* Some differences may be present, as there are hardware differences in how principal components are computed.  The supplied benchmarks were generated with MATLAB 2023b on a Windows 11 desktop, 64-bit OS,  Intel(R) Xeon(R) W-2102 CPU.

Copy all the fig files and mat files from `/tests` to `/benchmarks` for future use.

Clear the workspace and rerun run `rs_auto_test`.  No differences should be encountered, and the final output should look like this:

```
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
results of comparisons with benchmarks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

date: 03-Jun-2026
working directory: C:\Users\jdvicto\Documents\jv\EY7977\rs\src
C:\Users\jdvicto\Documents\jv\EY7977\rs\src
---

MATLAB Version: 23.2.0.2459199 (R2023b) Update 5
MATLAB License Number: 79639
Operating System: Microsoft Windows 11 Enterprise Version 10.0 (Build 22631)
Java Version: Java 1.8.0_202-b08 with Oracle Corporation Java HotSpot(TM) 64-Bit Server VM mixed mode
---

MATLAB                                                Version 23.2        (R2023b)
Deep Learning Toolbox                                 Version 23.2        (R2023b)
Image Processing Toolbox                              Version 23.2        (R2023b)
Optimization Toolbox                                  Version 23.2        (R2023b)
Parallel Computing Toolbox                            Version 23.2        (R2023b)
R Connectivity Tools                                  Version 1.0         (R14)  
Signal Processing Toolbox                             Version 23.2        (R2023b)
Statistics and Machine Learning Toolbox               Version 23.2        (R2023b)
System Identification Toolbox                         Version 23.2        (R2023b)
aux_customize:         0 tests of   2 show differences (  0 skipped in auto mode)
get_coordsets:         0 tests of   4 show differences (  1 skipped in auto mode)
read_coorddata:        0 tests of   5 show differences (  0 skipped in auto mode)
import_coordsets:      0 tests of   7 show differences (  0 skipped in auto mode)
align_coordsets:       0 tests of   5 show differences (  1 skipped in auto mode)
knit_coordsets:        0 tests of   5 show differences (  0 skipped in auto mode)
xform_specify:         0 tests of   8 show differences (  0 skipped in auto mode)
xform_specify_apply:   0 tests of  16 show differences (  0 skipped in auto mode)
geofit:                0 tests of   9 show differences (  0 skipped in auto mode)
plot_style:            0 tests of   1 show differences (  0 skipped in auto mode)
disp_coordsets1:       0 tests of   1 show differences (  0 skipped in auto mode)
disp_coordsets2:       0 tests of   1 show differences (  0 skipped in auto mode)
disp_coordsets3:       0 tests of   1 show differences (  0 skipped in auto mode)
run with if_auto_skip=1, if_ignore_svdambig=0, if_save_and_close=1
total number of tests with differences:    0
```



## Customize

This step enables setting of various global defaults, such as file name templates, and may be skipped or carried out at a later date.
Edit the desired entries in `rs_aux_defaults_define`.

* A spare copy of the original `rs_aux_defaults_define` is in the repository as `rs_aux_defaults_define_dist`, but you may want to keep your own spares or versions.
* Typical fields customized may be found by searching for `'\['`.
* The value of `overall.if_warn_traceback` can be changed to `1` from its default of `0`, to show tracebacks when warnings have been issued.

When done with editing, execute `rs_aux_defaults_define` in a clear workspace, and then save the workspace as `rs_aux_defaults.mat`.

* `rs_aux_defaults.mat` is used at run-time to set global defaults.
* A spare copy created with the distributed version of original  `rs_aux_defaults_define` is in the repository as  `rs_aux_defaults_std.mat`.

Optionally, edit `rs_graphic_hints`, setting parameter values to `0` or `1` based on known graphical capabilities.

Rerun the verification step.

* You may instead set `if_auto_skip=0` (or not set it at all; default value is `0`) to skip the modules that require interactive input.
* There should be no differences encountered, other than those due to altered default values that you have customized.


## Setting up your environment for `rs_py`
The above steps are sufficient if you only intend to use the **Tools for Manipulating Representational Spaces**, which are written in MATLAB. 

If you would also like to make use of the **Tools for creating representational spaces from perceptual judgments**, which are contained in `rs_py` and written in Python, 
then please also complete the following steps. 

### 1. Create a virtual environment

We recommend using a virtual environment when working with the scripts in `rs_py`.
Throughout this guide we use **conda**, but other tools such as `venv` can be used instead. 
You may also install the required dependencies into your global Python environment, although this is generally not recommended.

If you do not already have conda installed, see the official documentation [here](https://docs.conda.io/projects/conda/en/latest/index.html):

Create a conda environment with Python 3.10 or higher:
```commandline
conda create -n rs_env python=3.10
```

### 2. Install dependencies using pip
While in your new conda environment, type the following in your terminal to install required packages:
```commandline
pip install numpy scipy pandas
```

### 3. Get path to environment
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

Before you call a script from `rs_py` (see [Entry Points](rs-software/rs-py-overview/#entry-points) to get started), just activate this environment as follows:

```commandline
conda activate rs_env
```
If you do not intend to run `rs_py` scripts from MATLAB, you may skip the next step.


### 4. Set up MATLAB environment
We assume MATLAB R2024a or R2024b is being used. Other versions may also work with Python 3.10, but compatibility should be verified by the user. If you are able to complete this step, then there is no compatibility issue. 

1. Open MATLAB. 
2. Navigate to the `rs-software` folder and make sure `src` has been added to the path.
3. In the MATLAB console, set the python environment by entering the path to your own conda environment from the previous step, as follows: 

```matlab
pyenv(Version='/Users/suniyya/miniconda3/envs/rs_env');
```
Ensure you replace the above path with what you copied in the previous step. 

Now, you should be able to import python modules and run them. See [Running python inside MATLAB](rs-software/python-matlab-octave/#running-python-inside-matlab) for details. 

