% rs: Representational space software
%
% Data input and output
%   rs_get_coordsets: get one or more dataset structures (coordinates and metadata) from a file
%   rs_get_coordsets_test: test for above
%   rs_import_coordsets: import a dataset structure from coordinates
%   rs_import_coordsets_test: test for above
%   rs_read_coorddata: read one dataset structure from a file
%   rs_read_coorddata_test: test for above
%   rs_save_figs: save one or more figure files
%   rs_save_mat: save a mat-file
%   rs_showpipeline: show the processing pipeline for a coordinate dataset
%   rs_write_coordsets: write a coordinate dataset
%
% Data processing: coordinates
%   rs_align_coordsets: align multiple coordinate files with non-identical stimuli
%   rs_align_coordsets_test: test for above
%   rs_check_coordsets: check consistency of a dataset structure
%   rs_concat_coordsets: concatenate dataset structures
%   rs_extract_coordsets: extract a subset of dataset structures
%   rs_geofit: fit geometrical models
%   rs_knit_coordsets: find consensus coordinates across coordinate files with non-identical stimuli
%   rs_knit_coordsets_test: test for above
%   rs_xform_specify: specify a transformation (rotation and translation)
%   rs_xform_specify_test: test rs_xform_specify
%   rs_xform_apply: apply a transformation from rs_xform_specify
%   rs_xform_specify_apply_test: test rs_xform_[specify|apply]
%
% Visualization
%   rs_disp_coordsets: display one or more sets of coordinates
%   rs_disp_coordsets_test1: test rs_disp_coordsets: rotations, data selection, connections, offsets, labels, callouts
%   rs_disp_coordsets_test2: test rs_disp_coordsets: synthetic data, alpha blending
%   rs_disp_coordsets_test3: test rs_disp_coordsets: rays, rings, neighbors (via rs_disp_enh_coordsets)
%   rs_disp_enh_coordsets: display coordinate sets, enhanced by coloring rays, rings, etc.
%   rs_disp_geofit: display goodness of fit and statistics of geometrical models
%   rs_findrays: find rays from coordinates

% Customization, version dependence, benchmarks
%   rs_auto_test: run all tests ion automatic mode
%   rs_aux_customize: customize defaults for auxiliary inputs
%   rs_aux_customize_test: test for above
%   rs_aux_defaults_define: set up a file with default values for auxiliary parameters
%   rs_benchmark_compare: compare a test output with benchmarks
%   rs_typenames2colors: convert a stimulus type to a clor and symbolfor plotting
%   rs_plot_style: plot a line and points, customizing marker, color, alpha, style
%   rs_plot_style_test: test rs_plot_style
%   rs_template: a template for modules with an input and an output
%   rs_warning: a standard display and tallying warnings
%
% Documentation
%   rs_docs_installation: getting started and installation
%   rs_docs_demos: overview of the demos
%   rs_docs_structures: key structures
% 
%   Copyright (c) 2025, 2026 by J. Victor
