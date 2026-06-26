% rs_vara_coordsets_test: test rs_vara_coordsets (and rs_align_coordsets)
%
%  See also:  RS_VARA_COORDSETS, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='vara_coordsets';
%
%section to force btc defaults, even if rs_aux_defaults.mat has been created or modified
if ~exist('aux_force_filename') aux_force_filename='rs_aux_defaults_btc.mat'; end
auxs_force=struct;
opts_needed={'opts_read','opts_rays','opts_check','opts_align','opts_import','opts_qpred','opts_vara'};
for k=1:length(opts_needed)
    auxs_force.(opts_needed{k})=rs_aux_force(opts_needed{k},[],aux_force_filename);
end
%
ntests=1;
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
%
test_descs=cell(1,ntests);
filenames_examples=cell(1,ntests);
auxs=cell(1,ntests);
signflips=cell(1,ntests);
aux_ins=cell(1,ntests);
data_reads=cell(1,ntests);
aux_reads=cell(1,ntests);
data_aligns=cell(1,ntests);
aux_aligns=cell(1,ntests);
opts_used=cell(1,ntests);
%
groupings=cell(1,ntests);
vara_stats=cell(1,ntests);
%
test_descs{1}='btc, 6 std and 5 br judgments, exhaustive shuffles, reduced';
filenames_examples{1}={...
    './samples/bwtextures/bgca3pt_coords_SN_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_NF_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_NF-br_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_ZK-br_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_SAW_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_ZK_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat'};
auxs{1}=auxs_force;
aux_ins{1}=auxs_force;
aux_ins{1}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{1}.nsets=11;
groupings{1}.gps=[1 1 2 2 2 2 2 1 1 1 1];
%
% Enter datasets for group 1 (range: 1 to 11):[1 2 8 9 10 11]
% Enter 11 tags (range: 1 to 11):[1 2 1 2 3 4 5 6 5 3 4]
% Enter 1 to reduce exhaustive shuffles by considering groups of same size (and tag counts) to be equivalent (range: 0 to 1):1
% list (reduced) will have         32 shuffles; max allowed for exhaustive list:    1000000
% Enter 1 for exhaustive shuffles, 0 for random (range: 0 to 1):1
%  created    32 shuffles for  11 datasets
% 
% 
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
    if ~(strcmp(test_descs{itest},'replot'))
        aux_ins{itest}.opts_read.if_log=0;
        [data_reads{itest},aux_reads{itest}]=rs_get_coordsets(filenames_examples{itest},aux_ins{itest});
        %
        auxs{itest}.opts_align.if_log=1;
        [data_aligns{itest},aux_aligns{itest}]=rs_align_coordsets(data_reads{itest},auxs{itest});
        %
        auxs{itest}.opts_vara.if_log=1;
        [vara_stats{itest},aux_outs{itest}]=rs_vara_coordsets(data_aligns{itest},groupings{itest},auxs{itest});
        if aux_outs{itest}.opts_vara.if_plot
            set(gcf,'Name',sprintf('scenario %1.0f',itest));
        end
    %
    else
        % %replot, two rows, different quantiles
        % auxs{itest}.knit_stats=aux_outs{itest-1}.knit_stats;
        % auxs{itest}.knit_stats_setup=aux_outs{itest-1}.knit_stats_setup;
        % auxs{itest}.knit_stats_setup.fig_handle=figure;
        % set(gcf,'NumberTitle','off');
        % set(gcf,'Position',[100 100 1400 750]);
        % set(gcf,'Name','replot');
        % auxs{itest}.knit_stats_setup.dataset_labels={'set A','set B'};
        % auxs{itest}.knit_stats_setup.nrows=2;
        % auxs{itest}.knit_stats_setup.row=1;
        % [data_outs{itest},aux_outs{itest}]=rs_knit_coordsets(data_aligns{itest-1},auxs{itest});
        % auxs{itest}.knit_stats_setup.shuff_quantiles=[0.1 0.9];
        % auxs{itest}.knit_stats_setup.row=2;
        % [data_outs{itest},aux_outs{itest}]=rs_knit_coordsets(data_aligns{itest-1},auxs{itest});
    end
    fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
end
if if_save_and_close
    rs_save_figs('./tests/rs_vara_coordsets_test','all',setfield(struct(),'if_log',1));
else
    getinp('1 when ready to close and compare','d',[1 1],1);
end
close all;
for itest=1:ntests
    s=struct;
    s.vara_stats=vara_stats{itest};
    s.aux_out=aux_outs{itest};
    rs_save_mat(cat(2,'tests',filesep,fns{itest}),s);
end
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
for itest=1:ntests
    if ~isempty(vara_stats{itest})
        disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
        [ifdif{itest},opts_used{itest}]=rs_benchmark_compare(fns{itest},setfield(struct,'signflips',signflips{itest}));
        if ~(strcmp(test_descs{itest},'replot'))
            if ~isempty(aux_reads{itest}.warnings)
                disp('warnings encountered during reading:')
                disp(aux_reads{itest}.warnings)
            end
            if ~isempty(aux_aligns{itest}.warnings)
                disp('warnings encountered during alignment:')
                disp(aux_aligns{itest}.warnings)
            end
        end
        if ~isempty(aux_outs{itest}.warnings)
            disp('warnings encountered during vara:')
            disp(aux_outs{itest}.warnings)
        end
    end
end
