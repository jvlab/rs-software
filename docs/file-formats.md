# File formats

## Detailed choice file

A `detailed choice file` is a .mat file that contains a set of similarity comparisons, typically collected in a psychophysical experiment.  Each line of the file corresponds to a single judgment.
It contains three variables: 'stim\_list', 'responses', and 'responses_colnames'.  'stim\_list' is a character array in which each row is a unique stimulus label.

File names should contain the string `_detailed_choices_`, preceded by a designation of the domain or paradigm, and followed by an identifier for the subject or data source.

* triadic comparisons

    * Column 1 of 'responses' is the 1-based trial number
    * Columns 2-4 of 'responses' are the 1-based indices into stim\_list of the reference stimulus and two comparison stimuli (s1 and s2).
    * Column 5 of 'responses' is 1 if s1 is judged more dis-similar to the reference than s2, and 0 otherwise
    * 'responses_colnames' are text strings that label these columns

See `rs_py/samples/choice_files/*_detailed_choices_S*.mat` for examples.

## Choice file

A `choice file` (also called a `combined choice file`) is a .mat file that contains a set of similarity comparisons, typically collected in a psychophysical experiment. In contrast to a `detailed choice file`, judgments from repeated presentations of the same stimuli are combined.  The file contains three variables: 'stim\_list', 'responses', and 'responses_colnames'.  'stim\_list' is a character array in which each row is a unique stimulus label.

File names should contain the string `_choices_`, preceded by a designation of the domain or paradigm, and followed by an identifier for the subject or data source.

Two options are available for 'responses' and 'responses_colnames':

* triadic comparisons

    * Columns 1-3 of 'responses' are the 1-based indices into stim\_list of the reference stimulus and two comparison stimuli (s1 and s2).
    * Column 4 of 'responses' is the number of times that s1 is judged more dis-similar to the reference than s2
    * Column 5 of 'responses' is the number of times the triad is presented
    * 'responses_colnames' are text strings that label these columns

* tetradic comparisons

    * Columns 1-4 of 'responses' are the 1-based indices into stim\_list for the stimuli s1, s2, s3, and s4 in the comparison
    * Column 5 of 'responses' is the number of times that s1 and s2 are judged more dis-similar than s3 and s4
    * Column 6 of 'responses' is the number of times the tetrad is presented
    * 'responses_colnames' are text strings that label these columns

See `samples/animals/image_choices_S*.mat` or `samples/bwtextures/bgca3pt_choices_*_sess01_10.mat` for examples of triadic comparisons, and see `samples/bwtextures/bgca3pt_choices_*-gp_sess01_20.mat` for examples of tetradic comparisons.

## Coordinate file

A `coordinate file` is a .mat file that contains sets of coordinates for the elements of a representational space. It contains a variable 'stim\_labels', a character array in which each row is a unique stimulus label. This corresponds to the 'stim\_list' variable in a `choice file`, but the stimuli need not be listed in the same order. A `coordinate file` also contains one or more variables with names such as 'dim1', 'dim2', ..., 'dim10'. 'dim[k]' specifies the k-dimensional representational space:  each row corresponds to a stimulus in `stim\_labels`; the k columns are the k coordinate values.

File names should contain the string '\_coords\_', preceded by a designation of the domain or paradigm, and followed by an identifier for the subject or data source.

Optional variables (produced by the modeling of choice data by this package but not required) are:

* rawLLs: log(2) likelihood of the observed responses for each of k-dimensional models, uncorrected for overfitting
* bestModelLL: log(2) likelihood of the observed responses, given a model that exactly matches the observed choice probabilities but is geometrically unconstrained
* debiasedRelativeLL: relative log(2) likelihood, compared to bestModelLL, after correction for overfitting: debiasedRelativeLL = (rawLLs + biasEstimate) - bestModelLL
* biasEstimate: overfitting bias estimate
* metadata: summary of the above description

See `samples/animals/image_coords_S*.mat` for examples that contain these optional variables, and `samples/bwtextures/bgca3pt_cooords_*_sess01_10.mat` for examples that do not.



## Setup metadata file

A setup file can be used to hold metadata that determines `stimulus coordinates`.  This is intended primarily for the 'binary texture' domain demos, and for users who want to carry out or reproduce studies in this domain.
For general use of rs-software, it is recommended NOT to use setup files, and instead to specify `stimulus coordinates` directly,  (see 'opposite_coords' in `rs_read_coorddata_demo_opposites`).  

Setup files contain the following fields in a variable 's', and may contain others:

* nstims: the number of stimuli
* typenames: a cell array containing stimulus labels
* for 'binary texture' domains, btc_augcoords and btc_specoords, arrays with nstims rows, to specify the stimulus coordinates

The default distribution package, with rs_aux_defaults_define_dist.m, is configured so that NO setup files are used. (Demos involving setup files will still work, since they use `rs_aux_force` to override with options from rs_aux_defaults_define_btc.mat, created by rs_aux_default_define_pvt.m).

To make use of setup files, edit `rs_aux_defaults_define.m` to set `generic.opts_read.need_setup_file=1`.  With this setting (which is the setting in `rs_aux_default_define_pvt.m`), the domains that use setup files are determined as follows (logic in `psg_coorddata_parsename`):  

*  The domain name is extracted from the `coordinate file` name, as the string preceding '_coords'.  Then:
*  If the domain name is one of 'faces_mpi', 'irgb', 'mater', then a setup file is used. (This takes care of the `faces_mpi` domain).
*  If not, but the domain name is generic.opts_read.type_class_aux, then NO setup file is used. This is distributed as empty ([]) and may be edited during installation or specified dynamically when invoking `rs_get_coordsets` or `rs_read_coorddata` by setting aux.opts_read.type_class_aux.
*  If not, but the domain name is in a specific list, then NO setup file is used.  The list defaults to generic.opts_read.domain_list_def, distributed as {'cars','tools','dwellings'}. It may be edited during installation or specified dynamically when invoking `rs_get_coordsets` or `rs_read_coorddata` by setting aux.opts_read.domain_list_def. See for example `rs_read_coorddata_demo_cars` and `rs_read_coorddata_demo_opposites`, which ensure that NO setup file is used.
*  Otherwise, a setup file IS used (this takes care of the `binary texture` domain, in which `coordinate file` names may begin with a variety of strings).

The name of the setup file is determine from the domain name, as extracted above, followed by the string in generic.opts_read.setup_suffix, which is distributed as '[S]'.  The setup file is assumed to be in the same path as the `coordinate file`.

When a `coordinate file` is written by `rs_write_coorddata`, the default (which can be overridden with opts_write.if_embed=0) is to write the setup metadata into the variable `setup`.  When a `coordinate file` with embedded setup data is read, the `setup file` is not used.


