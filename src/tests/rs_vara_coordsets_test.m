% rs_vara_coordsets_test: test rs_vara_coordsets
%
%  See also:  RS_VARA_COORDSETS, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='vara_coordsets';
%
%section to force btc defaults, even if rs_aux_defaults.mat has been created or modified
if ~exist('aux_force_filename') aux_force_filename='rs_aux_defaults_btc.mat'; end
auxs_force=struct;
opts_needed={'opts_read','opts_rays','opts_check','opts_import','opts_qpred','opts_vara'};
for k=1:length(opts_needed)
    auxs_force.(opts_needed{k})=rs_aux_force(opts_needed{k},[],aux_force_filename);
end
%
ntests=9;
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
opts_used=cell(1,ntests);
%
groupings=cell(1,ntests);
vara_stats=cell(1,ntests);
%
test_descs{1}='btc, 6 std and 5 br judgments, exhaustive shuffles, tagged';
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
aux_ins{1}=auxs_force;
aux_ins{1}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{1}.nsets=11;
auxs{1}=auxs_force;
auxs{1}.opts_vara.dim_max_in=4;
auxs{1}.opts_vara.max_niters=50; %fewer iterations for Procrustes consensus
groupings{1}.gps=[1 1 2 2 2 2 2 1 1 1 1];
groupings{1}.tags=[1 2 1 2 3 4 5 6 5 3 4];
%
test_descs{3}='btc, 6 std and 5 br judgments, random shuffles, tagged';
filenames_examples{2}=filenames_examples{1};
aux_ins{2}=aux_ins{1};
auxs{2}=auxs{1};
auxs{2}.opts_vara.nshuffs=10;
auxs{2}.opts_vara.if_exhaust=0;
groupings{2}=groupings{1};
%
test_descs{3}='btc, 6 std and 5 br judgments, exhaustive, untagged';
filenames_examples{3}=filenames_examples{1};
aux_ins{3}=aux_ins{1};
auxs{3}=auxs{1};
auxs{3}.opts_vara.if_exhaust=1;
groupings{3}=rmfield(groupings{1},'tags');
%
test_descs{4}='btc, 6 std and 5 br judgments, attempt exhaustive but limit reached, untagged';
filenames_examples{4}=filenames_examples{1};
aux_ins{4}=aux_ins{1};
auxs{4}=auxs{1};
auxs{4}.opts_vara.if_exhaust=1;
auxs{4}.opts_vara.nshuffs_max=50; %limit for exhaustive shuffles
auxs{4}.opts_vara.nshuffs=30;
groupings{4}=rmfield(groupings{1},'tags');
%
test_descs{5}='btc, 6 std and 5 br judgments, user-supplied permutations';
filenames_examples{5}=filenames_examples{1};
aux_ins{5}=aux_ins{1};
auxs{5}=auxs{1};
auxs{5}.opts_vara.nshuffs_max=50; %limit for exhaustive shuffles
auxs{5}.opts_vara.nshuffs=30;
rng('default');
auxs{5}.opts_vara.shuffs_supplied=zeros(auxs{5}.opts_vara.nshuffs,aux_ins{5}.nsets);
for ishuff=1:auxs{5}.opts_vara.nshuffs
    auxs{5}.opts_vara.shuffs_supplied(ishuff,:)=randperm(aux_ins{5}.nsets);
end
groupings{5}=groupings{1};
%
test_descs{6}='btc, 6 std and 5 br judgments, exhaustive shuffles, tagged, group 1 has partial overlaps';
filenames_examples{6}={...
    './samples/bwtextures/bgca3pt_coords_SN_sess01_10.mat',...
    './samples/bwtextures/bdce3pt_coords_NF_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_NF-br_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_ZK-br_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_SAW_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_ZK_sess01_10.mat',...
    './samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat',...
    './samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat'};
auxs{6}=auxs{1};
aux_ins{6}=aux_ins{1};
groupings{6}=groupings{1};
%
test_descs{7}='btc, 6 std and 5 br judgments, group 1 has partial overlaps, no shuffles';
filenames_examples{7}=filenames_examples{6};
aux_ins{7}=aux_ins{1};
auxs{7}=auxs{1};
auxs{7}.opts_vara.nshuffs=0;
groupings{7}=groupings{1};
%
test_descs{8}='btc, 6 std and 5 br judgments, group 1 has partial overlaps, shuffles, dim_aug=1; dim_list used';
filenames_examples{8}=filenames_examples{6};
aux_ins{8}=aux_ins{1};
auxs{8}=auxs{1};
auxs{8}.opts_vara=rmfield(auxs{8}.opts_vara,'dim_max_in');
auxs{8}.opts_vara.dim_list_in=[2 3 5];
auxs{8}.opts_vara.dim_aug=1;
groupings{8}=groupings{1};
%
test_descs{9}='replot'
auxs{9}=auxs{8};
groupings{9}=groupings{8};
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
    if ~(strcmp(test_descs{itest},'replot'))
        aux_ins{itest}.opts_read.if_log=0;
        [data_reads{itest},aux_reads{itest}]=rs_get_coordsets(filenames_examples{itest},aux_ins{itest});
        %
        [vara_stats{itest},aux_outs{itest}]=rs_vara_coordsets(data_reads{itest},groupings{itest},auxs{itest});
        if aux_outs{itest}.opts_vara.if_plot
            set(gcf,'Name',sprintf('scenario %1.0f',itest));
        end
    %
    else
        %replot, two rows, different quantiles
        auxs{itest}.vara_stats=vara_stats{itest-1};
        auxs{itest}.vara_stats_setup=aux_outs{itest-1}.vara_stats_setup;
        auxs{itest}.vara_stats_setup.fig_handle=figure;
        set(gcf,'NumberTitle','off');
        set(gcf,'Position',[100 100 1400 750]);
        set(gcf,'Name','replot');
        auxs{itest}.vara_stats_setup.nrows=2;
        auxs{itest}.vara_stats_setup.row=1;
        [vara_stats{itest},aux_outs{itest}]=rs_vara_coordsets(data_reads{itest-1},groupings{itest-1},auxs{itest});
        auxs{itest}.vara_stats_setup.shuff_quantiles=[0.1 0.9];
        auxs{itest}.vara_stats_setup.row=2;
        [data_outs{itest},aux_outs{itest}]=rs_vara_coordsets(data_reads{itest-1},groupings{itest-1},auxs{itest});
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
        end
        if ~isempty(aux_outs{itest}.warnings)
            disp('warnings encountered during vara:')
            disp(aux_outs{itest}.warnings)
        end
    end
end
