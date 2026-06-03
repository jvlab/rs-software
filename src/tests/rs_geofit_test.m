% rs_geofit_test: test rs_geofit
%
%  See also:  RS_GEOFIT, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='geofit';
if ~exist('if_auto_skip') %set to 1 to skip non-interactive tests
    if_auto_skip=0;
end
%
%section to force btc defaults, even if rs_aux_defaults.mat has been created or modified
if ~exist('aux_force_filename') aux_force_filename='rs_aux_defaults_btc.mat'; end
auxs_force=struct;
opts_needed={'opts_read','opts_rays','opts_check','opts_geof','opts_qpred'};
for k=1:length(opts_needed)
    auxs_force.(opts_needed{k})=rs_aux_force(opts_needed{k},[],aux_force_filename);
end
%
ntests=9;
%
test_descs=cell(1,ntests);
filenames_in=cell(1,ntests);
filenames_out=cell(1,ntests);
aux_ins=cell(1,ntests);
aux_outs=cell(1,ntests);
data_ins=cell(1,ntests);
data_outs=cell(1,ntests);
%
auxs=cell(1,ntests);
gfs=cell(1,ntests);
xs=cell(1,ntests);
aux_geofits=cell(1,ntests);
%
opts_used=cell(1,ntests);
signflips=cell(1,ntests);
%
test_descs{1}='transforming one animal-domain files to two other domains, all models to in dim 3, out dim 4, no shuffles, no nesting';
filenames_in{1}={'./samples/animals/intermediate_texture_coords_S5.mat'};
auxs{1}=auxs_force;
aux_ins{1}=auxs_force;
aux_ins{1}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{1}.nsets=1;
filenames_out{1}={'./samples/animals/image_coords_S5.mat','./samples/animals/word_coords_S5.mat'};
aux_outs{1}=aux_ins{1};
aux_outs{1}.nsets=2;
auxs{1}.opts_geof.model_list=getfield(psg_geomodels_define(),'model_types');
auxs{1}.opts_geof.if_stats=0;
auxs{1}.opts_geof.dimpairs_method='all';
auxs{1}.opts_geof.dim_max_in=3;
auxs{1}.opts_geof.dim_max_out=4;
%
test_descs{2}='transforming three binary texture coordinate files to three others, mean, bogus,and procrustes models, maximal nesting, explicit dimensions';
filenames_in{2}={'./samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN_sess01_10.mat'};
auxs{2}=auxs_force;
aux_ins{2}=auxs_force;
aux_ins{2}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{2}.nsets=3;
filenames_out{2}={'./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
aux_outs{2}=aux_ins{2};
auxs{2}.opts_geof.model_list={'mean','bogus','procrustes_noscale_nooffset','procrustes_scale_nooffset','procrustes_noscale_offset','procrustes_scale_offset'};
auxs{2}.opts_geof.if_stats=1;
auxs{2}.opts_geof.if_nestbymodel=-1;
auxs{2}.opts_geof.if_nestbydim=-1; %nest by dimension, with pca
auxs{2}.opts_geof.dimpairs_method='list';
auxs{2}.opts_geof.dimpairs_list=[2 2;2 3;2 4;3 2;3 3;3 4;4 3;3 3;4 5];
auxs{2}.opts_geof.nshuffs=3;
%    
test_descs{3}='transforming three binary texture coordinate files to three others, standard models, standard nesting, leteq dims';
filenames_in{3}={'./samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN_sess01_10.mat'};
auxs{3}=auxs_force;
aux_ins{3}=auxs_force;
aux_ins{3}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{3}.nsets=3;
filenames_out{3}={'./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
aux_outs{3}=aux_ins{3};
auxs{3}.opts_geof.dimpairs_method='din_lteq_dout';
auxs{3}.opts_geof.if_stats=1;
auxs{3}.opts_geof.nshuffs=3;
%
test_descs{4}='unequal number of stimuli';
filenames_in{4}={'./samples/animals/intermediate_texture_coords_S5.mat'};
auxs{4}=auxs_force;
aux_ins{4}=auxs_force;
aux_ins{4}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{4}.nsets=1;
filenames_out{4}={'./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat'};
aux_outs{4}=aux_ins{4};
%
test_descs{5}='different stimulus names, just nest by dim, not pca';
filenames_in{5}={'./samples/bwtextures/dgea3pt_coords_MC_sess01_10.mat'};
auxs{5}=auxs_force;
aux_ins{5}=auxs_force;
aux_ins{5}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{5}.nsets=1;
filenames_out{5}={'./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat'};
aux_outs{5}=aux_ins{5};
auxs{5}.opts_geof.if_stats=1;
auxs{5}.opts_geof.if_nestbymodel=0;
auxs{5}.opts_geof.if_nestbydim=1; %nest by dimension, not pca
auxs{5}.opts_geof.dim_max_in=5;
auxs{5}.opts_geof.nshuffs=3;
%
test_descs{6}='different stimulus names, just nest by dim, not pca, all dim pairs';
filenames_in{6}=filenames_in{5};
auxs{6}=auxs_force;
aux_ins{6}=aux_ins{5};
filenames_out{6}=filenames_out{5};
aux_outs{6}=aux_ins{5};
auxs{6}=auxs{5};
auxs{6}.opts_geof.dim_max_in=3;
auxs{6}.opts_geof.nshuffs=10;
auxs{6}.opts_geof.dimpairs_method='all';
%
test_descs{7}='transforming one binary texture coordinate file to one other, mean, procrustes, affine, explicit dimensions, all nestings no pca';
filenames_in{7}={'./samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat'};
auxs{7}=auxs_force;
aux_ins{7}=aux_ins{2};
aux_ins{7}.nsets=1;
filenames_out{7}={'./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat'};
aux_outs{7}=aux_ins{2};
aux_outs{7}.nsets=1;
auxs{7}.opts_geof.model_list={'mean','procrustes_noscale_nooffset','procrustes_scale_nooffset','affine_offset'};
auxs{7}.opts_geof.if_stats=1;
auxs{7}.opts_geof.if_nestbymodel=1;
auxs{7}.opts_geof.if_nestbydim=1; %nest by dimension, no pca
auxs{7}.opts_geof.dimpairs_method='list';
auxs{7}.opts_geof.dimpairs_list=[1 1;1 2;1 4; 1 6;3 1;3 2;3 4;3 6;5 1;5 2;5 4;5 6;7 1;7 2;7 4]; %input dims: 1,3,5,7; output dims 1 2,4,6, all pairs except (7,6)
auxs{7}.opts_geof.nshuffs=5;
%
test_descs{8}='transforming one binary texture coordinate file to one other, mean, procrustes, affine, explicit dimensions, only nest by input dim, with pca';
filenames_in{8}={'./samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat'};
auxs{8}=auxs_force;
aux_ins{8}=aux_ins{2};
aux_ins{8}.nsets=1;
filenames_out{8}={'./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat'};
aux_outs{8}=aux_ins{2};
aux_outs{8}.nsets=1;
auxs{8}=auxs{7};
auxs{8}.opts_geof.if_nestbymodel=0;
auxs{8}.opts_geof.if_nestbydim_in=-1; %nest by dimension, with pca
auxs{8}.opts_geof.if_nestbydim_out=0;
%
test_descs{9}='transforming one binary texture coordinate file to one other, mean, procrustes, affine, explicit dimensions, only nest by output dim, with pca';
filenames_in{9}={'./samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat'};
auxs{9}=auxs_force;
aux_ins{9}=aux_ins{2};
aux_ins{9}.nsets=1;
filenames_out{9}={'./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat'};
aux_outs{9}=aux_ins{2};
aux_outs{9}.nsets=1;
auxs{9}=auxs{7};
auxs{9}.opts_geof.if_nestbymodel=0;
auxs{9}.opts_geof.if_nestbydim_in=0;
auxs{9}.opts_geof.if_nestbydim_out=-1; %nest by dim, with pca
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    if ((aux_ins{itest}.opts_read.if_auto==1) | (if_auto_skip==0))
        disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
        %read the input and output data structures
        aux_ins{itest}.opts_read.if_log=0;
        [data_ins{itest},aux_read_ins{itest}]=rs_get_coordsets(filenames_in{itest},aux_ins{itest});
        %
        aux_outs{itest}.opts_read.if_log=0;
        [data_outs{itest},aux_read_outs{itest}]=rs_get_coordsets(filenames_out{itest},aux_outs{itest});
        %
        [gfs{itest},xs{itest},aux_geofits{itest}]=rs_geofit(data_ins{itest},data_outs{itest},auxs{itest});
        %
        fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
        s=struct;
        s.data_in=data_outs{itest};
        s.data_out=data_outs{itest};
        s.aux_ins=aux_ins{itest};
        s.aux_outs=aux_ins{itest};
        s.gfs=gfs{itest};
        s.xs=xs{itest};
        s.aux_geofits=aux_geofits{itest};
        %
        rs_save_mat(cat(2,'tests',filesep,fns{itest}),s);
    end
end
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
for itest=1:ntests
    if ~isempty(data_outs{itest})
        disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
        [ifdif{itest},opts_used{itest}]=rs_benchmark_compare(fns{itest},setfield(struct,'signflips',signflips{itest}));
        if ~isempty(aux_read_ins{itest}.warnings)
            disp('warnings encountered during reading of input data:')
            disp(aux_read_ins{itest}.warnings)
        end
        if ~isempty(aux_read_outs{itest}.warnings)
            disp('warnings encountered during reading of output data:')
            disp(aux_read_outs{itest}.warnings)
        end
        if ~isempty(aux_geofits{itest}.warnings)
            disp('warnings encountered during geofit:')
            disp(aux_geofits{itest}.warnings)
        end
        
    end
end
