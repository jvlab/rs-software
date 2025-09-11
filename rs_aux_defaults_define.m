%rs_aux_defaults_define
%define the defaults for auxiliary parameters
%This file is appropriate for binary texture data.
% 
%output should be saved as rs_aux_defaults.mat
%
generic=struct; %subfields will be applied to auxiliary parameters for all function calls
%
generic.opts_read.if_debug=0; %1 to enable debugging
generic.opts_read.if_uselocal=0; %1 to enable psg_localopts to define local options
generic.opts_read.if_gui=1; %1 to use gui, 0 not

generic.opts_read.input_types={'experimental data','qform model'}; %omit qform_model if no quadratic modelling
generic.opts_read.if_log=1;
generic.opts_read.if_warn=1;
generic.opts_read.nfiles_max=100;
generic.opts_read.input_type=0;
generic.opts_read.data_fullnames=cell(0);
generic.opts_read.setup_fullnames=cell(0);
generic.opts_read.if_auto=0;
generic.opts_read.if_data_only=0;
generic.opts_read.ui_filter='*coords*.mat';
generic.opts_read.if_symaug=0;
generic.opts_read.sym_apply='full';
generic.opts_read.if_symaug_log=0;
generic.opts_read.if_uselocal=1; %rs package will typically set this to zero
%
generic.opts_qpred.qform_datafile_def='../stim/btc_allraysfixedb_avg_100surrs_madj.mat'; %ignored if no quadratic modeling
generic.opts_qpred.qform_modeltype=12; %index into substructure of above; full symmetry assumed, ignored if no quadratic modeling
%
generic.opts_test.param1=pi;
generic.opts_test.param2='param2string';
generic.opts_test.param3='maybe overridden';
%
%these options override generic defaults when rs_aux_customize is called by a specific function
%
specific=struct;  %subfields will be applied to auxiliary parameters when called by a specific function
specific.rs_get_coordsets=struct;
%
specific.rs_dummy=struct;
specific.rs_dummy.opts_test.param3='overridden';
%
disp('Remember to save workspace as rs_aux_defaults.mat.')