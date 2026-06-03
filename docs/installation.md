## Install the files

Ensure that MATLAB or Octave is installed. MATLAB versions 2023 and later have been tested.

Clone or download GitHub repositories from https://github.com/jvlab/rs-software and https://github.com/jvlab/perceptual\_space\_geometry.
If using MATLAB:  remove the folder src/octave\_compat.
Add all folders to the path.

## Initial verification

In a clear workspace, set if\_auto\_skip=1 and run rs\_auto\_test.

* This will take several minutes, exercising the modules, producing fig and mat files, placing them in /tests.
* You will be asked to respond to several keyboad prompts.  If a default is supplied, then accept it (Enter key); if confirmation is requested, confirm by entering a 1.

After execution, the fig files and mat files will be compared with files in /benchmarks that were in the repo.

* Differences, in comparison to the benchmarks, will be summarized and can be inspected in the fields of r\_diffs.
* Some differences may be present, as there are hardware differences in how principal components are computed.  The supplied benchmarks were generated with MATLAB 2023b on a Windows 11 desktop, 64-bit OS,  Intel(R) Xeon(R) W-2102 CPU.

Copy all the fig files and mat files from /tests to /benchmarks for future use.

## Customization

This step enables setting of various global defaults, such as file name templates, and may be skipped or carried out at a later date.
Edit the desired entries in rs\_aux\_defaults\_define.m.

* A spare copy of the original rs\_aux\_defaults\_define.m is in the repo as rs\_aux\_defaults\_define\_dist, but you may want to keep your own spares or versions.
* Typical fields customized may be found by searching for '\['.
* You may also want change the value of overall.if\_warn\_traceback to 1 from its default of 0, to show tracebacks when warnings have been issued.

When done with editing, execute rs\_aux\_defaults\_define in a clear workspace, and then save the workspace as rs\_aux\_defaults.mat.

* rs\_aux\_defaults.mat is used at run-time to set global defaults.
* A spare copy created with the distributed version of original  rs\_aux\_defaults\_define.m is in the repo as  rs\_aux\_defaults\_std.mat.

Optionally, edit rs\_graphic\_hints.m, setting parameter values to 0 or 1 based on known graphical capabilities.

Rerun the verification step.

* You may instead set if\_auto\_skip=0 (or simply not set it at all) to skip the modules that require interactive input.
* There should be no differences encountered, other than those due to altered default values that you have customized.

