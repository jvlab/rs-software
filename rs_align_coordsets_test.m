% rs_align_coordsets_test: test rs_align_coordsets
%
%  See also:  RS_ALIGN_COORDSETS, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='align_coordsets';
%
ntests=6;
%
test_descs=cell(1,ntests);
filenames_examples=cell(1,ntests);
auxs=cell(1,ntests);
aux_ins=cell(1,ntests);
data_reads=cell(1,ntests);
aux_reads=cell(1,ntests);
opts_used=cell(1,ntests);
%
data_outs=cell(1,ntests);
aux_outs=cell(1,ntests);
%
test_descs{1}='non-interactive reading of three binary texture coordinate files, no logging';
filenames_examples{1}={'./samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_NF_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_SN_sess01_10.mat'};
aux_ins{1}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,0});
auxs{1}=struct;
aux_ins{1}.nsets=3;
%
test_descs{2}='non-interactive reading of three binary texture coordinate files, second file is a model, logging';
filenames_examples{2}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_NF-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
auxs{2}=struct;
aux_ins{2}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{[1 2],1,1});
aux_ins{2}.nsets=3;
%
test_descs{3}='non-interactive reading of two binary texture coordinate files, stimuli disagree, logging, keep only if stimuli present in both';
filenames_examples{3}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat'};
auxs{3}=struct;
auxs{3}.opts_align.min=2;
aux_ins{3}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{3}.nsets=2;
%
test_descs{4}='non-interactive reading of four animal-domain files';
filenames_examples{4}={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S4','./samples/animals/image_coords_S5','./samples/animals/image_coords_S6'};
auxs{4}=struct;
aux_ins{4}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{4}.nsets=4;
%
test_descs{5}='interactive reading of one coordinate file';
filenames_examples{5}={};
auxs{5}=struct;
aux_ins{5}.opts_read=setfields(struct(),{'input_type','if_auto','if_log','if_gui'},{1,0,1,0});
aux_ins{5}.nsets=1;
%
test_descs{6}='non-interactive reading of two binary texture coordinate files, stimuli disagree, logging, keep only if stimuli present in either';
filenames_examples{6}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat'};
auxs{6}=struct;
auxs{6}.opts_align.min=1;
aux_ins{6}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{6}.nsets=2;
%
disp('Suggest ''enter'' to accept the default for interactive responses.');
if_ok=0;
while (if_ok==0)
    if_ok=getinp('1 if OK to proceed','d',[0 1],1);
end
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    [data_reads{itest},aux_read{itest}]=rs_get_coordsets(filenames_examples{itest},aux_ins{itest});
    %
    [data_outs{itest},aux_outs{itest}]=rs_align_coordsets(data_reads{itest},auxs{itest});
    %
    fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
    s=struct;
    s.data_out=data_outs{itest};
    s.aux_out=aux_outs{itest};
    rs_save_mat(cat(2,'tests',filesep,fns{itest}),s);
end
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
for itest=1:ntests
    disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
    [ifdif{itest},opts_used{itest}]=rs_benchmark_compare(fns{itest});
end
