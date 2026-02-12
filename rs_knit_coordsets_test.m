% rs_knit_coordsets_test: test rs_knit_coordsets (and rs_align_coordsets)
%
%  See also:  RS_KNIT_COORDSETS, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='knit_coordsets';
%
ntests=5;
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
data_outs=cell(1,ntests);
aux_outs=cell(1,ntests);
%
test_descs{1}='non-interactive reading of three binary texture coordinate files, second file is a model, logging';
filenames_examples{1}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_NF-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
auxs{1}=struct;
aux_ins{1}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{[1 2],1,1});
aux_ins{1}.nsets=3;
auxs{1}.nsets=3;
signflips{1}={{'data_out','ds'}};
%
test_descs{2}='non-interactive reading of four animal-domain files';
filenames_examples{2}={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S4','./samples/animals/image_coords_S5','./samples/animals/image_coords_S6'};
auxs{2}=struct;
aux_ins{2}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{2}.nsets=4;
%
test_descs{3}='non-interactive reading of two binary texture coordinate files, stimuli disagree, logging, keep only if stimuli present in either, do stats and plot';
filenames_examples{3}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat'};
auxs{3}=struct;
auxs{3}.opts_align.min=1;
auxs{3}.opts_knit.if_stats=1;
auxs{3}.opts_knit.nshuffs=10;
auxs{3}.opts_knit.shuff_quantiles=[0.25 0.5 0.75];
aux_ins{3}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{3}.nsets=2;
%
test_descs{4}='replot';
auxs{4}=auxs{3};
aux_ins{4}=aux_ins{3};
%
%
test_descs{5}='non-interactive reading of two binary texture coordinate files, stimuli disagree, logging, keep only if stimuli present in either, do stats and plot, pca after consensus';
filenames_examples{5}=filenames_examples{3};
auxs{5}=auxs{3};
auxs{5}.opts_knit.if_pca=1;
aux_ins{5}=aux_ins{3};
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
        auxs{itest}.opts_knit.if_log=1;
        [data_outs{itest},aux_outs{itest}]=rs_knit_coordsets(data_aligns{itest},auxs{itest});
    %
    else
        %replot, two rows, different quantiles
        auxs{itest}.knit_stats=aux_outs{itest-1}.knit_stats;
        auxs{itest}.knit_stats_setup=aux_outs{itest-1}.knit_stats_setup;
        auxs{itest}.knit_stats_setup.fig_handle=figure;
        set(gcf,'NumberTitle','off');
        set(gcf,'Position',[100 100 1400 750]);
        set(gcf,'Name','replot');
        auxs{itest}.knit_stats_setup.dataset_labels={'set A','set B'};
        auxs{itest}.knit_stats_setup.nrows=2;
        auxs{itest}.knit_stats_setup.row=1;
        [data_outs{itest},aux_outs{itest}]=rs_knit_coordsets(data_aligns{itest-1},auxs{itest});
        auxs{itest}.knit_stats_setup.shuff_quantiles=[0.1 0.9];
        auxs{itest}.knit_stats_setup.row=2;
        [data_outs{itest},aux_outs{itest}]=rs_knit_coordsets(data_aligns{itest-1},auxs{itest});
    end
    fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
end
if if_save_and_close
    rs_save_figs('./tests/rs_knit_coordsets_test','all',setfield(struct(),'if_log',1));
else
    getinp('1 when ready to close and compare','d',[1 1],1);
end
close all;
for itest=1:ntests
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
        [ifdif{itest},opts_used{itest}]=rs_benchmark_compare(fns{itest},setfield(struct,'signflips',signflips{itest}));
        if ~isempty(aux_outs{itest}.warnings)
            disp('warnings encountered during test:')
            disp(aux_outs{itest}.warnings)
        end
    end
end
