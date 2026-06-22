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

We recommend using a virtual environment when working with the scripts in `rs_py`.
Throughout this guide we use **conda**, but other tools such as `venv` can be used instead. 
You may also install the required dependencies into your global Python environment, although this is generally not recommended.

If you do not already have conda installed, see the official documentation [here](https://docs.conda.io/projects/conda/en/latest/index.html):

Create a conda environment with Python 3.10 or higher:
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
