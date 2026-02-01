% rs_import_coordsets_test: test rs_import_coordsets
%
%  See also:  RS_IMPORT_COORDSETS, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='import_coordsets';
if ~exist('if_auto_skip') %set to 1 to skip non-interactive tests
    if_auto_skip=0;
end
%
ntests=6;
%
test_descs=cell(1,ntests);
coords=cell(1,ntests);
auxs=cell(1,ntests);
opts_used=cell(1,ntests);
%
data_outs=cell(1,ntests);
aux_outs=cell(1,ntests);
%
test_descs{1}='basic import test with all defaults, dims 1,2,4';
nstims=15;
auxs{1}.opts_import=struct();
colvec=[1:nstims]';
coords{1}={colvec,[colvec colvec.^2],[],colvec*[1:4]};
%
test_descs{2}='basic import test with non-default sas metadata, dims 3,4,5';
nstims=11;
auxs{2}.opts_import=struct();
auxs{2}.opts_import.nstims=nstims;
auxs{2}.opts_import.type_coords=reshape(sqrt(1:2*nstims),nstims,2); %make a 2-column set of stimulus coordinates 
auxs{2}.opts_import.typenames={'abc','bcd','ef0','004','ax','hij','b252','agag_g','uvwz','3abc','*va&'}';
colvec=[1:nstims]';
coords{2}={[],[],colvec*[1:3],[colvec colvec.^(1/2) colvec.^(1/3) colvec.^(1/4)],colvec*sqrt([1:5])};
%
test_descs{3}='basic import test with non-default sas metadata, dims 3,4,5, bad number of coords';
auxs{3}=auxs{2};
coords{3}=coords{2};
coords{3}{4}=coords{3}{5};
%
test_descs{4}='basic import test with non-default sas metadata, dims 3,4,5, bad number of stimuli';
auxs{4}=auxs{2};
auxs{4}.opts_import.nstims=10;
coords{4}=coords{2};
%
test_descs{5}='basic import test with type_coords_def=ones and nondefault sets metadata, dims 1,2,4';
nstims=15;
auxs{5}=auxs{1};
auxs{5}.opts_import.type_coords_def='ones';
auxs{5}.opts_import.paradigm_type='color';
auxs{5}.opts_import.paradigm_name='saturation series';
auxs{5}.opts_import.subj_id='subj123';
auxs{5}.opts_import.label_long='homedir/datadir/s123_data';
auxs{5}.opts_import.label='s123_data';
auxs{5}.opts_import.extra='01Jan26';
coords{5}=coords{1};
%
test_descs{6}='basic import test with identity as type_coords values';
nstims=11;
auxs{6}=auxs{2};
coords{6}=coords{2};
auxs{6}.opts_import=rmfield(auxs{6}.opts_import,'type_coords');
auxs{6}.opts_import.type_coords_def='eye';
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
    [data_outs{itest},aux_outs{itest}]=rs_import_coordsets(coords{itest},auxs{itest});
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
    if ~isempty(data_outs{itest})
        disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
        [ifdif{itest},opts_used{itest}]=rs_benchmark_compare(fns{itest});
        if ~isempty(aux_outs{itest}.warnings)
            disp('warnings encountered during test:')
            disp(aux_outs{itest}.warnings)
        end
    end
end
