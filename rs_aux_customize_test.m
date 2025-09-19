%rs_aux_customize_test: test rs_aux_customize
%
%  See also:  RS_AUX_CUSTOMIZE, RS_AUX_DEFAULTS_DEFINE, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
%
rs_module='aux_customize';
%
ntests=2;
%
test_descs=cell(1,ntests);
auxs=cell(1,ntests);
callers=cell(1,ntests);
%
test_descs{1}='some options overridden';
auxs{1}.opts_test.param1=7;
callers{1}='rs_dummy';
%
test_descs{2}='empty opts_read in rs_get_coordsets';
auxs{2}.opts_read=struct;
callers{2}='rs_get_coordsets';
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    aux_out=rs_aux_customize(auxs{itest},callers{itest});
    fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
    s=struct;
    s.aux_out=aux_out;
    rs_save_mat(cat(2,'tests',filesep,fns{itest}),s,setfield(struct,'ver',[]));
end
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
for itest=1:ntests
    disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
    ifdif{itest}=rs_benchmark_compare(fns{itest});
end
