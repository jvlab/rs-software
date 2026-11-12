## Install the files

Ensure that MATLAB or Octave is installed. MATLAB versions 2023 and later have been tested.

Clone or download the GitHub repository [https://github.com/jvlab/rs-software](https://github.com/jvlab/rs-software).

* If using MATLAB: add all folders to the search path except src/octave_compat from `rs-software`. If you have downloaded a static copy, you may delete  `src/octave_compat`.
* If using Octave: add all folders to the search path.

## Verify the install

Navigate to `/rs_software/src`, clear the workspace, set `if_auto_skip=1`, and run `rs_auto_test`.

* This will exercise several modules, produce fig and mat files, and place them in `/tests`; it will take several minutes.
* Early in the process, you will be asked to respond to several keyboard prompts.  If a default is supplied, then accept it (Enter key); if confirmation is requested, confirm by entering a 1.

After execution, the fig files and mat files in `/tests` will be compared with files in `/benchmarks` that were downloaded from the repository.

* The supplied benchmarks were generated with MATLAB 2023b on a Windows 11 desktop, 64-bit OS,  Intel(R) Xeon(R) W-2102 CPU.

* Some differences in the comparison to benchmarks may be present with other processors or other MATLAB versions, as these variations may change how principal components are computed.  This produces sign flips and, in some cases, exchanges in the order of principal components that have nearly identical weights.  Differences are known to occur in the test modules knit_coordsets, xform_specify, xform_specify_apply, geofit, and disp_coordsets3.  As an example, the following is the last portion of the output with MATLAB Version: 26.2.0.3433840 (R2026b) Update 1 on a Windows 11 desktop, 64-bit OS,  Intel(R) Xeon(R) W-2102 CPU:

```
%%%%%%%%%%%%%%%%%%%%%%
summary of differences
%%%%%%%%%%%%%%%%%%%%%%
      knit_coordsets:   1 tests of   5 show differences (  0 skipped in auto mode)
       xform_specify:   3 tests of   8 show differences (  0 skipped in auto mode)
 xform_specify_apply:   6 tests of  16 show differences (  0 skipped in auto mode)
              geofit:   5 tests of   9 show differences (  0 skipped in auto mode)
     disp_coordsets3:   1 tests of   1 show differences (  0 skipped in auto mode)
Consider re-running with if_ignore_svdambig=1 to ignore differences related to implementations of singular value decomposition
Consider re-running with diff_maxchars or diff_maxlines set to larger values (currently:   70 and    3 ) to show more differences
Look in r_diffs for details of differences
         knit_coordsets: [1×1 struct]
          xform_specify: [1×1 struct]
    xform_specify_apply: [1×1 struct]
                 geofit: [1×1 struct]
        disp_coordsets3: [1×1 struct]
```

* The recommendations to re-run or to inspect the fields of `r_diffs` can be ignored; this is for maintenance purposes.

Copy all the fig files and mat files from `/tests` to `/benchmarks` for future use.

Clear the workspace and rerun run `rs_auto_test`. This should generate NO differences, and a log whose end is similar to what is shown below. 

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

## Verify the install: optional step

This is an optional step that verifies installation of several computationally-intensive modules related to analysis of choice data, and may take 15 to 30 min to run.

Navigate to `/rs_software/src`, clear the workspace, set `if_auto_skip=1`, and run `rs_auto_choice_test`.

* This will exercise several modules, produce fig and mat files, and place them in `/tests`; it may take 15 to 30 min to run.

* The supplied benchmarks were generated with MATLAB 2026b on a Windows 11 desktop, 64-bit OS,  Intel(R) Xeon(R) W-2102 CPU, and match exactly those generated with MATLAB 2023b on the same system.

* At the conclusion, you should see something like this:

```
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
results of comparisons with benchmarks: choice analyses
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
date: 12-Nov-2026
working directory: C:\Users\jdvicto\Documents\jv\EY7977\rs\src
C:\Users\jdvicto\Documents\jv\EY7977\rs\src
----------------------------------------------------------------------------
MATLAB Version: 26.2.0.3433840 (R2026b) Update 1
MATLAB License Number: 79639
Operating System: Microsoft Windows 11 Enterprise Version 10.0 (Build 26200)
Java Version: Java is not loaded
----------------------------------------------------------------------------
MATLAB                                                Version 26.2        (R2026b)
Image Processing Toolbox                              Version 26.2        (R2026b)
Optimization Toolbox                                  Version 26.2        (R2026b)
Parallel Computing Toolbox                            Version 26.2        (R2026b)
R Connectivity Tools                                  Version 1.0         (R14)   
Signal Processing Toolbox                             Version 26.2        (R2026b)
Statistics and Machine Learning Toolbox               Version 26.2        (R2026b)
System Identification Toolbox                         Version 26.2        (R2026b)
     read_choicedata:   0 tests of   5 show differences (  0 skipped in auto mode)
   symumi_choicedata:   0 tests of   4 show differences (  0 skipped in auto mode)
  addtree_choicedata:   0 tests of   3 show differences (  0 skipped in auto mode)
run with if_auto_skip=1, if_ignore_svdambig=0, if_save_and_close=1
total number of tests with differences:    0
```

* If differences are encountered, copy all fig files and mat files with names containing `choice` from `/tests` to `/benchmarks` to for future use. You will see a recommendation to inspect the fields of `r_diffs`; this will indicate the extent of differences. 

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

