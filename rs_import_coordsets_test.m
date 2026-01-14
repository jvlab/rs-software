% rs_import_coordsets_test: test rs_import_coordsets
%
%  See also:  RS_IMPORT_COORDSETS, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='import_coordsets';
if ~exist('if_auto_skip') %set to 1 to skip non-interactive tests
    if_auto_skip=0;
end
%
ntests=1
%
test_descs=cell(1,ntests);
coords=cell(1,ntests);
auxs=cell(1,ntests);
opts_used=cell(1,ntests);
%
data_outs=cell(1,ntests);
aux_outs=cell(1,ntests);
%
test_descs{1}='basic import test, dims 1,2,4';
auxs{1}.opts_import=struct();
nstims=15;
colvec=[1:nstims]';
coords{1}={colvec,[colvec colvec.^2],[],colvec*[1:4]};
%
if if_auto_skip==0
    disp('Suggest ''enter'' to accept the default for interactive responses.');
    if_ok=0;
    while (if_ok==0)
        if_ok=getinp('1 if OK to proceed','d',[0 1],1);
    end
end
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    if (if_auto_skip==0)
        [data_outs{itest},aux_outs{itest}]=rs_import_coordsets(coords{itest},auxs{itest});
        fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
        s=struct;
        s.data_out=data_outs{itest};
        s.aux_out=aux_outs{itest};
        rs_save_mat(cat(2,'tests',filesep,fns{itest}),s);
    end
end
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
for itest=1:ntests
    if ~isempty(data_outs{itest})
        disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
        [ifdif{itest},opts_used{itest}]=rs_benchmark_compare(fns{itest});
        if ~isempty(aux_outs{itest}.warnings)
            disp('warnings encountered during test:')
            disp(aux_outs{itest}.warnings)
        end
    end
end
