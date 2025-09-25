% rs_read_coorddata_test: test rs_read_coorddata
%
%  See also:  RS_READ_COORDSETS, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='read_coorddata';
%
ntests=4;
%
test_descs=cell(1,ntests);
filenames_examples=cell(1,ntests);
auxs=cell(1,ntests);
opts_used=cell(1,ntests);
%
data_outs=cell(1,ntests);
aux_outs=cell(1,ntests);
%
test_descs{1}='reading binary texture coordinate file, bcpm stimulus set';
filenames_examples{1}={'./samples/bwtextures/bcpm3pt_coords_BL_sess01_10.mat'};
auxs{1}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,0});
%
test_descs{2}='reading binary texture coordinate file, bcpp55q stimulus set';
filenames_examples{2}={'./samples/bwtextures/bcpp55qpt_coords_BL_sess01_10.mat'};
auxs{2}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,0});
%
test_descs{3}='reading binary texture coordinate file, bcpm24 stimulus set';
filenames_examples{3}={'./samples/bwtextures/bcpm24pt_coords_BL_sess01_10.mat'};
auxs{3}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,0});
%
test_descs{4}='reading animal-domain file';
filenames_examples{4}={'./samples/animals/image_coords_S3'};
auxs{4}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,0});
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
    [data_outs{itest},aux_outs{itest}]=rs_read_coorddata(filenames_examples{itest},auxs{itest});
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
