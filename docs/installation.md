## Install the files

Ensure that MATLAB or Octave is installed. MATLAB versions 2023 and later have been tested.

Clone or download GitHub repositories from https://github.com/jvlab/rs-software and https://github.com/jvlab/perceptual\_space\_geometry.
If using MATLAB:  remove the folder src/octave\_compat.
Add all folders to the path.

## Verify the install

Navigate to /rs/src, clear the workspace, set if\_auto\_skip=1, and run rs\_auto\_test.

* This will take several minutes, exercising the modules, producing fig and mat files, placing them in /tests.
* You will be asked to respond to several keyboad prompts.  If a default is supplied, then accept it (Enter key); if confirmation is requested, confirm by entering a 1.

After execution, the fig files and mat files in /tests will be compared with files in /benchmarks that were downloaded from the repository.

* Differences, in comparison to the benchmarks, will be summarized and can be inspected in the fields of r\_diffs.
* Some differences may be present, as there are hardware differences in how principal components are computed.  The supplied benchmarks were generated with MATLAB 2023b on a Windows 11 desktop, 64-bit OS,  Intel(R) Xeon(R) W-2102 CPU.

Copy all the fig files and mat files from /tests to /benchmarks for future use.

Clear the workspace and rerun run rs\_auto\_test.  No differences should be encountered, and the final output should look like this:

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
    Java Version: Java 1.8.0\_202-b08 with Oracle Corporation Java HotSpot(TM) 64-Bit Server VM mixed mode
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
    aux\_customize:   0 tests of   2 show differences (  0 skipped in auto mode)
    get\_coordsets:   0 tests of   4 show differences (  1 skipped in auto mode)
    read\_coorddata:   0 tests of   5 show differences (  0 skipped in auto mode)
    import\_coordsets:   0 tests of   7 show differences (  0 skipped in auto mode)
    align\_coordsets:   0 tests of   5 show differences (  1 skipped in auto mode)
    knit\_coordsets:   0 tests of   5 show differences (  0 skipped in auto mode)
    xform\_specify:   0 tests of   8 show differences (  0 skipped in auto mode)
    xform\_specify\_apply:   0 tests of  16 show differences (  0 skipped in auto mode)
    geofit:   0 tests of   9 show differences (  0 skipped in auto mode)
    plot\_style:   0 tests of   1 show differences (  0 skipped in auto mode)
    disp\_coordsets1:   0 tests of   1 show differences (  0 skipped in auto mode)
    disp\_coordsets2:   0 tests of   1 show differences (  0 skipped in auto mode)
    disp\_coordsets3:   0 tests of   1 show differences (  0 skipped in auto mode)
    run with if\_auto\_skip=1, if\_ignore\_svdambig=0, if\_save\_and\_close=1
    total number of tests with differences:    0


## Customize

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

* You may instead set if\_auto\_skip=0 (or not set it at all; default value is 0) to skip the modules that require interactive input.
* There should be no differences encountered, other than those due to altered default values that you have customized.

