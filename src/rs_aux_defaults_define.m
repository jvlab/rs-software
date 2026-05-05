%rs_aux_defaults_define_dist
%This script defines the defaults for auxiliary parameters.
%It should be run once in a clean workspace, and the resulting workspace saved as rs_aux_defaults.mat.
%It is read by rs_aux_customize and used to set defaults for many of the auxiliary inputs.
%
%This version of the file is intended for distribution and customization.
%Search for '[' to find typical fields to be customized
%
%Values below are appropriate for binary texture psychophysical data, and have an option to customize for hlid (calcium imaging) data.
%
overall=struct;
overall.warn_leadin='##### rs_warning: ';
overall.if_warn_traceback=0; %set to 1 to show a traceback with each warning
overall.default_file_version='dist_v0';
%
generic=struct; %subfields will be applied to auxiliary parameters for all function calls
%
generic.opts_read.if_debug=0; %1 to enable debugging 
generic.opts_read.if_uselocal=0; %1 to enable psg_localopts to define local options
generic.opts_read.if_gui=1; %1 to use gui, 0 not
%
%typically first used in rs_get_coordsets
%
generic.opts_read.input_types={'experimental data','qform model'}; %omit qform_model if no quadratic modelling of binary texture experiments
generic.opts_read.if_log=1;
generic.opts_read.if_warn=1;
generic.opts_read.nfiles_max=100;
generic.opts_read.input_type=0;
generic.opts_read.data_fullnames=cell(0);
generic.opts_read.setup_fullnames=cell(0);
generic.opts_read.if_auto=0;
generic.opts_read.if_data_only=0;
generic.opts_read.ui_filter='*_coords*.mat'; %token in gui for file input
generic.opts_read.if_gui=1; % 1 to use graphical interface to get files if file names are not supplied (default), 0 to use console
generic.opts_read.if_symaug=0; 
generic.opts_read.sym_apply='full';
generic.opts_read.if_symaug_log=0;
%
%entries only relevant for quadratic modeling
%
generic.opts_qpred.qform_datafile_def='./[path and file name for quadratic form model].mat'; %default model parameter file
generic.opts_qpred.qform_modeltype=[1];%offset; %index into substructure of above; typically 1
%
%do not remove; to verify installation
%
generic.opts_test.param1=pi;
generic.opts_test.param2='param2string';
generic.opts_test.param3='maybe overridden';
%
%typically first used in rs_read_coorddata
%
generic.opts_read.data_fullname_def='[path and file name for the default coordinate dataset file to read].mat'; %default full file name for a coordinate dataset, typically [paradigm_name]_coords_[subjID].mat
generic.opts_read.setup_fullname_def='[path and file name for the default setup file].mat'; %default full file name for a setup file, can be ignored if no setup files are used
generic.opts_read.need_setup_file=[0]; %1 if a setup file is to be used
generic.opts_read.setup_suffix='[S]'; %suffix to convert a data file into a setup file
generic.opts_read.if_justsetup=0; %do not modify (1 causes rs_read_coorddata to only read the setup file)
generic.opts_read.permutes_ok=1; %do not modify (this enables a stable order of rays)
generic.opts_read.coord_string='_coords'; %token in coord file name that follows the string to be used for setup file name
generic.opts_read.type_class_aux=[];
%next entries only relevant for faces experiments
generic.opts_read.faces_mpi_atten_indiv=1; %factor to attenuate "indiv" by in computing faces_mpi coords
generic.opts_read.faces_mpi_atten_age=1; %factor to attenuate "age" by in computing faces_mpi coords
generic.opts_read.faces_mpi_atten_gender=1; %factor to attenuate "gender" by in computing faces_mpi coords
generic.opts_read.faces_mpi_atten_emo=1; %factor to attenuate "emo" by in computing faces_mpi coords
generic.opts_read.faces_mpi_atten_set=0.2; %factor to attenuate "set" by in computing faces_mpi coords
%
generic.opts_read.type_class_def='btc'; % default type class, if domain list not found
generic.opts_read.paradigm_type_def='thing'; %default paradigm type
%dlist of paradigm names 
generic.opts_read.domain_list_def={'cars','tools','dwellings'}; %paradigm names
generic.opts_read.domain_sigma=struct; % [if individual subjects are modeled with noise params not equal to 1, then the structure should have fields for these subjects and the value of the noise parameter
%e.g., domain_sigma.XZ=0.3 means that subject XZ was modeled with a noise parameter of 0.3
%
%typically first used in rs_import_coorddata
%
generic.opts_import.typename_prefix='type_'; %default prefix for typenames
generic.opts_import.typename_ndigits=2; %number of digits in an auto-generated typename
generic.opts_import.type_coords_def='none';%default conceptual coordinates
generic.opts_import.paradigm_type='unknown'; %default paradigm type
generic.opts_import.subj_id='unknown'; %default subject ID
generic.opts_import.label_long='unknown'; %default label
%
%typically first used in rs_write_coorddata
%
generic.opts_write.if_uselocal=0; %1 to enable psg_localopts to define local options
generic.opts_write.coord_data_fullname_write_def='[path and file name for the default coordinate dataset file to write].mat'; %default full file name to write a coordinate dataset
generic.opts_write.if_log=1;
generic.opts_write.ui_filter='*_coords*.mat'; %token in gui for file output
generic.opts_write.if_gui=1; % 1 to use graphical interface to get files if file names are not supplied (default), 0 to use console
%
%typically first used in rs_disp_coorddata
%
generic.opts_disp.fig_position=[100 100 1200 800]; %default position for figures
generic.opts_disp.axis_font_size=8; %font size for figure labels
generic.opts_disp.axis_label_prefix='coord'; %prefix for axis label
%
%typically first used in rs_findrays
%
generic.opts_rays.ray_reorder_ring=1; %standardize ray order
generic.opts_rays.ray_plane_jit=10^-3; %standardize collapse of cycle to plane
%
%typically first used in rs_geofit
%
generic.opts_geof.model_list_default={'procrustes_scale_offset','affine_offset','projective'}; %models to fit
%
%these options override generic defaults when rs_aux_customize is called by a specific function
%
specific=struct;  %subfields will be applied to auxiliary parameters when called by a specific function
specific.rs_get_coordsets=struct;
%
specific.rs_dummy=struct; %for maintenance; do not remove
specific.rs_dummy.opts_test.param3='overridden';
%
disp('Remember to save workspace as rs_aux_defaults.mat.')