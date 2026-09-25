% rs_symumi_choicedata_test: test rs_symumi_choicedata
% 
%  Compares with benchmarks
%
%  See also:  RS_SYMUMI_CHOICEDATA, RS_READ_CHOICEDATA, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='symumi_choicedata';
%
%section to force btc defaults, even if rs_aux_defaults.mat has been created or modified
if ~exist('aux_force_filename') aux_force_filename='rs_aux_defaults_btc.mat'; end
auxs_force=struct;
opts_needed={'opts_read','opts_check'};
for k=1:length(opts_needed)
    auxs_force.(opts_needed{k})=rs_aux_force(opts_needed{k},[],aux_force_filename);
end
%
ntests=4;
%
if ~exist('if_save_and_close')
    if_save_and_close=0;
end
if if_save_and_close==0
    if_save_and_close=getinp('1 to save and close all figures','d',[0 1]);
end
if if_save_and_close
    close all;
end
if_replot=[0 0 0 3];
%
test_descs=cell(1,ntests);
filenames_examples=cell(1,ntests);
auxs=cell(1,ntests);
opts_used=cell(1,ntests);
%
data_comps=cell(1,ntests);
auxs=cell(1,ntests);
choices=cell(1,ntests);
sus=cell(1,ntests);
aux_symumis=cell(1,ntests);
aux_symumi_outs=cell(1,ntests);
%
test_descs{1}='triadic choice file, animal-domain';
filenames_examples{1}={'./samples/animals/image_choices_S3.mat'};
auxs{1}=auxs_force;
auxs{1}.opts_read=setfields(auxs_force.opts_read,{'if_log'},{1});
aux_symumis{1}=struct;
aux_symumis{1}.opts_symumi.if_plot=2; %detailed plots
%
test_descs{2}='triadic choice file, bgca';
filenames_examples{2}={'./samples/bwtextures/bgca3pt_choices_MC_sess01_10.mat'};
auxs{2}=auxs_force;
auxs{2}.opts_read=setfields(auxs_force.opts_read,{'if_log'},{1});
aux_symumis{2}=struct;
aux_symumis{2}.opts_symumi.if_plot=1; %standard plot only
%
test_descs{3}='triadic choice file, bc, include private, reduce h_fixlist, ntriplets_min=40';
filenames_examples{3}={'./samples/bwtextures/bc6pt_choices_MC_sess01_10.mat'};
auxs{3}=auxs_force;
auxs{3}.opts_read=setfields(auxs_force.opts_read,{'if_log'},{1});
aux_symumis{3}=struct;
aux_symumis{3}.opts_symumi.if_private=1;
aux_symumis{3}.opts_symumi.h_fixlist=[0 0.001 0.01];
aux_symumis{3}.opts_symumi.ntriplets_min=40;
aux_symumis{3}.opts_symumi.if_plot=0; %no plot
%
test_descs{4}='third scenario, replotted';
filenames_examples{4}=filenames_examples{1};
auxs{4}=auxs{3};
aux_symumis{4}=struct;
aux_symumis{4}.opts_symumi.if_plot=1; %standard plot
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
nfigs_all=0;
for itest=1:ntests
    nfigs=0;
    if if_replot(itest)>0
        aux_symumis{itest}.opts_symumi.su=sus{if_replot(itest)};
    end
    disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
    [data_comps{itest},aux_reads{itest}]=rs_read_choicedata(filenames_examples{itest},auxs{itest});
    [sus{itest},aux_symumi_outs{itest}]=rs_symumi_choicedata(data_comps{itest},aux_symumis{itest});
    %
    if isfield(aux_symumi_outs{itest},'fig_handles')
        for k=1:length(aux_symumi_outs{itest}.fig_handles)
            set(gcf,'Name',sprintf('scenario %1.0f plot %1.0f',itest,k));
            nfigs=nfigs+1;
        end
    end
    if isfield(aux_symumi_outs{itest},'fig_handle_detailed')
        set(gcf,'Name',sprintf('scenario %1.0f detailed',itest));
        nfigs=nfigs+1;
    end
    %
    fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
    %
    s=struct;
    s.data_out=data_comps{itest};
    s.aux_out=aux_reads{itest};
    s.symumi=sus{itest};
    s.aux_symumi_out=aux_symumi_outs{itest};
    if nfigs>0
        if if_save_and_close
            rs_save_figs(cat(2,'./tests/rs_symumi_choicedata_test_',sprintf('s%1.0f',itest)),'all',setfield(struct(),'if_log',1));
            close all
        end
    end
    rs_save_mat(cat(2,'tests',filesep,fns{itest}),s);
    nfigs_all=nfigs_all+nfigs;
end
if nfigs_all>0 & if_save_and_close==0
    getinp('1 when ready to close and compare','d',[1 1],1);
    close all;
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
        if ~isempty(aux_symumi_outs{itest}.warnings)
            disp('warnings encountered during fits:')
            disp(aux_symumi_outs{itest}.warnings)
        end
    end
end

