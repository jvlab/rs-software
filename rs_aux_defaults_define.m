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
%
%typically first used in psg_get_coordsets
%
generic.opts_read.input_types={'experimental data','qform model'}; %omit qform_model if no quadratic modelling
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
generic.opts_qpred.qform_datafile_def='./samples/bwtextures/btc_allraysfixedb_avg_100surrs_madj.mat'; %ignored if no quadratic modeling
generic.opts_qpred.qform_modeltype=12; %index into substructure of above; full symmetry assumed, ignored if no quadratic modeling
%
%do not remove; to verify installation
%
generic.opts_test.param1=pi;
generic.opts_test.param2='param2string';
generic.opts_test.param3='maybe overridden';
%
%typically first used in psg_read_coorddata
%
generic.opts_read.if_justsetup=0;
generic.opts_read.data_fullname_def='./samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat'; %default full file name for a coordinate dataset
generic.opts_read.setup_fullname_def='./samples/bwtextures/bgca3pt9.mat'; %default full file name for a setup file
generic.opts_read.permutes_ok=1;
generic.opts_read.coord_string='_coords'; %token in coord file name that follows the string to be used for setup file name
generic.opts_read.type_class_aux=[];
generic.opts_read.setup_suffix='9'; %suffix to convert a data file into a setup file
generic.opts_read.faces_mpi_atten_indiv=1; %factor to attenuate "indiv" by in computing faces_mpi coords
generic.opts_read.faces_mpi_atten_age=1; %factor to attenuate "age" by in computing faces_mpi coords
generic.opts_read.faces_mpi_atten_gender=1; %factor to attenuate "gender" by in computing faces_mpi coords
generic.opts_read.faces_mpi_atten_emo=1; %factor to attenuate "emo" by in computing faces_mpi coords
generic.opts_read.faces_mpi_atten_set=0.2; %factor to attenuate "set" by in computing faces_mpi coords
generic.opts_read.need_setup_file=1; %assume need setup file
generic.opts_read.domain_list_def={'texture','intermediate_texture','intermediate_object','image','word'}; %domain names for animals experiment
generic.opts_read.type_class_def='btc'; % default type class
% sigma (std dev in the error model) for individual subjects in 5-domain animal experiments, anonymized
% Coordinates in data file are relative to sigma, which was 0.18 for first 5 subjects.
sigma_list=[repmat(0.18,1,5),repmat(1,1,8)];
for k=1:length(sigma_list)
    generic.opts_read.domain_sigma.(sprintf('S%1.0f',k))=sigma_list(k);
end
clear k sigma_list
%
%typically first used in psg_findrays
%
generic.opts_rays.ray_reorder_ring=1; %standardize ray order
generic.opts_rays.ray_plane_jit=10^-3; %standardize collapse of cycle to plane
%
%typically first used in psg_write_coorddata
%
generic.opts_write.coord_data_fullname_def='./samples/bgca3pt_coords_QFM_sess01_01.mat'; %default full file name to write a coordinate dataset
generic.opts_write.if_log=1;
generic.opts_write.ui_filter='*_coords*.mat'; %token in gui for file output
generic.opts_write.if_gui=1; % 1 to use graphical interface to get files if file names are not supplied (default), 0 to use console
%
%these options override generic defaults when rs_aux_customize is called by a specific function
%
specific=struct;  %subfields will be applied to auxiliary parameters when called by a specific function
specific.rs_get_coordsets=struct;
%
specific.rs_dummy=struct;
specific.rs_dummy.opts_test.param3='overridden';
%
%override with setups for hlid (Hong Lab Imaging Data) if requested
%
if getinp('1 to use hlid defaults','d',[0 1],0)
    h=hlid_setup_func;
    fns=fieldnames(h.opts_read);
    for ifn=1:length(fns)
        generic.opts_read.(fns{ifn})=h.opts_read.(fns{ifn});
    end
    fns=fieldnames(h.opts_plot);
    for ifn=1:length(fns)
        generic.opts_plot.(fns{ifn})=h.opts_plot.(fns{ifn});
    end
    fns=fieldnames(h.opts_multm_def);
    for ifn=1:length(fns)
        generic.opts_multm_def.(fns{ifn})=h.opts_multm_def.(fns{ifn});
    end
    generic.opts_write.coord_data_fullname_def='./*_coords*.mat';
    generic.hlid_opts=h.hlid_opts;
    generic.display_orders=h.display_orders;
    clear h fns ifn
end
%
disp('Remember to save workspace as rs_aux_defaults.mat.')