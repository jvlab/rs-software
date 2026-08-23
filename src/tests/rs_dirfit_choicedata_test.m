% rs_dirfit_choicedata_test: test rs_dirfit_choicedata
% 
%  Compares with benchmarks
%
%  See also:  RS_DIRFIT_CHOICEDATA, RS_READ_CHOICEDATA, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='dirfit_choicedata';
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
data_comps=cell(1,ntests);
auxs=cell(1,ntests);
choices=cell(1,ntests);
dirfits=cell(1,ntests);
aux_dirfits=cell(1,ntests);
%
test_descs{1}='reading triadic choice file, animal-domain';
filenames_examples{1}={'./samples/animals/image_choices_S3.mat'};
auxs{1}=auxs_force;
auxs{1}.opts_read=setfields(auxs_force.opts_read,{'if_log'},{1});
aux_dirfits{1}=struct;
%
test_descs{2}='reading triadic choice file, bgca stimulus set';
filenames_examples{2}={'./samples/bwtextures/bgca3pt_choices_MC_sess01_10.mat'};
auxs{2}=auxs_force;
auxs{2}.opts_read=setfields(auxs_force.opts_read,{'if_log'},{1});
aux_dirfits{2}=struct;
%
test_descs{3}='reading triadic choice file, bgca stimulus set, do stats';
filenames_examples{3}=filenames_examples{2};
auxs{3}=auxs{2};
aux_dirfits{3}=struct;
aux_dirfits{3}.opts_dirfit.if_stats=1;
%
test_descs{4}='reading triadic choice file, bgca stimulus set, with discrete part';
filenames_examples{4}=filenames_examples{2};
auxs{4}=auxs{2};
aux_dirfits{4}=struct;
aux_dirfits{4}.opts_dirfit.if_discrete=1;
%
%
test_descs{5}='reading triadic choice file, bgca stimulus set, with discrete part and stats';
filenames_examples{5}=filenames_examples{2};
auxs{5}=auxs{2};
aux_dirfits{5}=struct;
aux_dirfits{5}.opts_dirfit.if_discrete=1;
aux_dirfits{5}.opts_dirfit.if_stats=1;
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
    [data_comps{itest},aux_reads{itest}]=rs_read_choicedata(filenames_examples{itest},auxs{itest});
    choices{itest}=data_comps{itest}(:,[end-1:end]);
    [dirfits{itest},aux_dirfit_outs{itest}]=rs_dirfit_choicedata(choices{itest},aux_dirfits{itest});
    fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
    %
    s=struct;
    s.data_out=data_comps{itest};
    s.aux_out=aux_reads{itest};
    s.dirfit=dirfits{itest};
    s.aux_dirfit_out=aux_dirfit_outs{itest};
    rs_save_mat(cat(2,'tests',filesep,fns{itest}),s);
end
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
for itest=1:ntests
    if ~isempty(data_comps{itest})
        disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
        [ifdif{itest},opts_used{itest}]=rs_benchmark_compare(fns{itest});
        if ~isempty(aux_reads{itest}.warnings)
            disp('warnings encountered during test, reading:')
            disp(aux_reads{itest}.warnings)
        end
        if ~isempty(aux_dirfit_outs{itest}.warnings)
            disp('warnings encountered during fits:')
            disp(aux_dirfit_outs{itest}.warnings)
        end
    end
end

