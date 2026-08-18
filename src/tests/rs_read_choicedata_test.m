% rs_read_coorddata_test: test rs_read_choicedata
%
%  Compares with benchmarks
%
%  See also:  RS_READ_CHOICEDATA, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='read_choicedata';
%
%section to force btc defaults, even if rs_aux_defaults.mat has been created or modified
if ~exist('aux_force_filename') aux_force_filename='rs_aux_defaults_btc.mat'; end
auxs_force=struct;
opts_needed={'opts_read','opts_check'};
for k=1:length(opts_needed)
    auxs_force.(opts_needed{k})=rs_aux_force(opts_needed{k},[],aux_force_filename);
end
%
ntests=5;
%
test_descs=cell(1,ntests);
filenames_examples=cell(1,ntests);
auxs=cell(1,ntests);
opts_used=cell(1,ntests);
%
data_outs=cell(1,ntests);
aux_outs=cell(1,ntests);
%
test_descs{1}='reading triadic choice file, animal-domain';
filenames_examples{1}={'./samples/animals/image_choices_S3.mat'};
auxs{1}=auxs_force;
auxs{1}.opts_read=setfields(auxs_force.opts_read,{'if_log'},{1});
%
test_descs{2}='reading triadic choice file, bgca stimulus set';
filenames_examples{2}={'./samples/bwtextures/bgca3pt_choices_MC_sess01_10.mat'};
auxs{2}=auxs_force;
auxs{2}.opts_read=setfields(auxs_force.opts_read,{'if_log'},{1});
%
test_descs{3}='reading triadic choice file, bgca stimulus set, no consolidation';
filenames_examples{3}={'./samples/bwtextures/bgca3pt_choices_MC_sess01_10.mat'};
auxs{3}=auxs_force;
auxs{3}.opts_read=setfields(auxs_force.opts_read,{'if_log','if_consolidate'},{1,0});
%
test_descs{4}='reading tetradic choice file, coordinate file, bgca-gm stimulus set';
filenames_examples{4}={'./samples/bwtextures/bgca3pt_choices_MC-gm_sess01_10.mat'};
auxs{4}=auxs_force;
auxs{4}.opts_read=setfields(auxs_force.opts_read,{'if_log'},{1});
%
test_descs{5}='reading tetradic choice file, coordinate file, bgca-gm stimulus set, no consolidation';
filenames_examples{5}={'./samples/bwtextures/bgca3pt_choices_MC-gm_sess01_10.mat'};
auxs{5}=auxs_force;
auxs{5}.opts_read=setfields(auxs_force.opts_read,{'if_log','if_consolidate'},{1,0});
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
    [data_outs{itest},aux_outs{itest}]=rs_read_choicedata(filenames_examples{itest},auxs{itest});
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

