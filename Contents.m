% rs: Representational space software
%
% Data input and output
%   rs_get_coordsets: read one or more coordinate sets or models from file
%   rs_get_coordsets_test: test for above
%   rs_read_coorddata: read one coordinate set from a file
%   rs_read_coorddata_test: test for above
%   rs_save_mat: save a mat-file
%   rs_showpipeline: show the processing pipeline for a coordinate dataset
%   rs_write_coordsets: write a coordinate dataset
%
% Data processing: coordinates
%   rs_align_coordsets: align multiple coordinate files with non-identical stimuli
%   rs_align_coordsets_test: test for above
%   rs_findrays: find rays from coordinates
%   rs_knit_coordsets: find consensus coordinates across coordinate files with non-identical stimuli
%   rs_knit_coordsets_test: test for above
%
% Customization and testing
%   rs_auto_test: run all tests ion automatic mode
%   rs_aux_customize: customize defaults for auxiliary inputs
%   rs_aux_customize_test: test for above
%   rs_aux_defaults_define: set up a file with default values for auxiliary parameters
%   rs_benchmark_compare: compare a test output with benchmarks
%   rs_check_coordsets: check consistency among several coordinate sets
%   rs_template: a template for modules with an input and an output
% 
%   Copyright (c) 2025 by J. Victor
