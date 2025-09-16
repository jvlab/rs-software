% rs_get_coordsets_test: test rs_get_coordsets
%
%  See also:  RS_GET_COORDSETS, RS_BENCHMARK_COMPARE.
%
rs_module='get_coordsets';
%
ntests=2;
%
test_descs=cell(1,ntests);
filenames_examples=cell(1,ntests);
auxs=cell(1,ntests);
%
test_descs{1}='non-interactive reading of three binary texture coordinate files, no logging';
filenames_examples{1}={'./samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_NF_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_SN_sess01_10.mat'};
auxs{1}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,0});
auxs{1}.nsets=3;
%
test_descs{2}='non-interactive reading of three binary texture coordinate files, second file is a model, logging';
filenames_examples{2}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_NF-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
auxs{2}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{[1 2],1,1});
auxs{2}.nsets=3;
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    [data_out,aux_out]=rs_get_coordsets(filenames_examples{itest},auxs{itest});
    fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
    save(cat(2,'tests',filesep,fns{itest}),'data_out','aux_out');
end
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
for itest=1:ntests
    disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
    ifdif{itest}=rs_benchmark_compare(fns{itest});
end
%data and model
%
%animals
%
