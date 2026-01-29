% rs_geofit_test: test rs_geofit
%
%  See also:  RS_GEOFIT, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='geofit';
if ~exist('if_auto_skip') %set to 1 to skip non-interactive tests
    if_auto_skip=0;
end
%
ntests=5;
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
rs=cell(1,ntests);
xs=cell(1,ntests);
aux_geofits=cell(1,ntests);
%
opts_used=cell(1,ntests);
signflips=cell(1,ntests);
%
test_descs{1}='transforming one animal-domain files to two other domains, all models, no nesting';
filenames_in{1}={'./samples/animals/intermediate_texture_coords_S5.mat'};
aux_ins{1}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{1}.nsets=1;
filenames_out{1}={'./samples/animals/image_coords_S5.mat','./samples/animals/word_coords_S5.mat'};
aux_outs{1}=aux_ins{1};
aux_outs{1}.nsets=2;
auxs{1}.opts_geof.model_list=getfield(psg_geomodels_define(),'model_types');
auxs{1}.opts_geof.if_nestbymodel=0;
%
test_descs{2}='transforming three binary texture coordinate files to three others, mean, bogus,and procrustes models, maximal nesting';
filenames_in{2}={'./samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN_sess01_10.mat'};
aux_ins{2}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{2}.nsets=3;
filenames_out{2}={'./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
aux_outs{2}=aux_ins{2};
auxs{2}.opts_geof.model_list={'mean','bogus','procrustes_noscale_nooffset','procrustes_scale_nooffset','procrustes_noscale_offset','procrustes_scale_offset'};
auxs{2}.opts_geof.if_nestbymodel=-1;
%
test_descs{3}='transforming three binary texture coordinate files to three others, standard models, all nesting';
filenames_in{3}={'./samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN_sess01_10.mat'};
aux_ins{3}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{3}.nsets=3;
filenames_out{3}={'./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
aux_outs{3}=aux_ins{3};
%
test_descs{4}='unequal number of stimuli';
filenames_in{4}={'./samples/animals/intermediate_texture_coords_S5.mat'};
aux_ins{4}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{4}.nsets=1;
filenames_out{4}={'./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat'};
aux_outs{4}=aux_ins{4};
%
test_descs{5}='different stimulus names';
filenames_in{5}={'./samples/bwtextures/dgea3pt_coords_MC_sess01_10.mat'};
aux_ins{5}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{5}.nsets=1;
filenames_out{5}={'./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat'};
aux_outs{5}=aux_ins{5};
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    if ((aux_ins{itest}.opts_read.if_auto==1) | (if_auto_skip==0))
        disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
        %read the input and output data structures
        aux_ins{itest}.opts_read.if_log=0;
        [data_ins{itest},aux_ins{itest}]=rs_get_coordsets(filenames_in{itest},aux_ins{itest});
        %
        aux_outs{itest}.opts_read.if_log=0;
        [data_outs{itest},aux_outs{itest}]=rs_get_coordsets(filenames_out{itest},aux_outs{itest});
        %
        [rs{itest},xs{itest},aux_geofits{itest}]=rs_geofit(data_ins{itest},data_outs{itest},auxs{itest});
        %
        fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
        s=struct;
        s.data_in=data_outs{itest};
        s.data_out=data_outs{itest};
        s.aux_ins=aux_ins{itest};
        s.aux_outs=aux_ins{itest};
        s.rs=rs{itest};
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
        if ~isempty(aux_outs{itest}.warnings)
            disp('warnings encountered during test:')
            disp(aux_outs{itest}.warnings)
        end
    end
end
