function opts_local=psg_localopts()
% opts_local=psg_localopts() sets local options for file names, paradigm types, etc.
%  These are typically defaults for specific file names, parameters, infixes, etc.
%
% opts_local: local options
%
% See also:  PSG_DEFOPTS, PSG_GET_COORDSETS, PSG_READ_COORDDATA, PSG_WRITE_COORDDATA, PSG_READ_CHOICEDATA.
%
opts_local=struct;
opts_local.coord_data_fullname_def='./psg_data/bgca3pt_coords_BL_sess01_10.mat'; %default full file name for a coordinate dataset
opts_local.coord_data_fullname_write_def='./psg_data/bgca3pt_coords_QFM_sess01_01.mat'; %default full file name to write a coordinate dataset
opts_local.choice_data_fullname_def='./psg_data/bgca3pt_choices_BL_sess01_10.mat'; %default full file name for a choice dataset
opts_local.setup_fullname_def='./psg_data/bgca3pt9.mat'; %default full file name for a setup file
%
opts_local.setup_setup_suffix='9'; %suffix to convert a data file into a setup file
opts_local.type_class_def='btc'; % default type class
%
opts_local.model_filename_def='../stim/btc_allraysfixedb_avg_100surrs_madj.mat'; %default model full file name
opts_local.modeltype_def=12; %default model type parameter.  12->if_symm=1 (symmetrize around origin), if_axes=1 (symmetrize bc, de, tuvw); ifaug=1 (augmented coords)
%
%for domain experiments
opts_local.domain_list_def={'texture','intermediate_texture','intermediate_object','image','word'};
% sigma (std dev in the error model) 
% Coordinates in data file are relative to sigma. Per Suniyya Waraich:
% The first cohort (MC, BL, EFV, SJ, SAW, NK, YCL, SA and JF) were analyzed using sigma=0.18.
% The second cohort was analyzed after setting sigma=1. These participants were AJ, SN, CME and ZK.
opts_local.domain_sigma.MC=0.18;
opts_local.domain_sigma.BL=0.18;
opts_local.domain_sigma.EFV=0.18;
opts_local.domain_sigma.SJ=0.18;
opts_local.domain_sigma.SAW=0.18;
opts_local.domain_sigma.NK=0.18;
opts_local.domain_sigma.YCL=0.18;
opts_local.domain_sigma.SA=0.18;
opts_local.domain_sigma.JF=0.18;
opts_local.domain_sigma.AJ=1.0;
opts_local.domain_sigma.SN=1.0;
opts_local.domain_sigma.CME=1.0;
opts_local.domain_sigma.ZK=1.0;
return
