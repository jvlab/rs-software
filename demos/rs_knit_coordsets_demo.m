% rs_knit_coordsets_demo: demonstrate knitting across datasets with partially overlapping stimuli
% calculation of statistics, with and without scaling
% plotting two sets of stats on same figure, tweaking stimulus names
%
%  See also:  RS_KNIT_COORDSETS, RS_ALIGN_COORDSETS
%
verbosity=getinp('pipeline display verbosity','d',[0 2],0);
if_write=getinp('1 to write the knitted sets','d',[0 1]);
nshuffs=getinp('number of shuffles for statistics (0 for none)','d',[0 1000],10);
%
filenames={'./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat','./samples/bwtextures/dgea3pt_coords_MC_sess01_10.mat'};
nsets=length(filenames);
aux=struct;
aux.nsets=nsets;
aux.opts_align.min=1;
aux.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux.opts_knit.keep_details=1;
%
%read the data
[data_read,aux_read]=rs_get_coordsets(filenames,aux);
%align
[data_align,aux_align]=rs_align_coordsets(data_read,aux);
%knit
[data_knit,aux_knit]=rs_knit_coordsets(data_align,aux);
%also knit with allowing a scaling between datasets
aux_allowscale=aux;
aux_allowscale.opts_knit.allow_scale=1;
aux_allowscale.opts_knit.if_normscale=1;
[data_knit_allowscale,aux_knit_allowscale]=rs_knit_coordsets(data_align,aux_allowscale);
%
%show pipelines, also expanding the contents of sets and sets_combined
%
if verbosity<=1
    fields_expand={};
else
    fields_expand={'opts','file_list','sets','sets_combined'};
end
disp('%%%%%%%%%%%%%%%%%%%');
disp('pipeline for knitted dataset, no scaling');
rs_showpipeline(data_knit.sets{1}.pipeline,setfields(struct(),{'fields_expand','verbosity'},{fields_expand,verbosity}));
disp('%%%%%%%%%%%%%%%%%%%');
%
disp('pipeline for knitted dataset, scaling');
rs_showpipeline(data_knit_allowscale.sets{1}.pipeline,setfields(struct(),{'fields_expand','verbosity'},{fields_expand,verbosity}));
disp('%%%%%%%%%%%%%%%%%%%');
%
dim_list=data_knit.sets{1}.dim_list; %list of dimensions of coordinate sets
paradigm_names=cell(1,nsets); %retrieve paradigm names
for iset=1:nsets
    paradigm_names{iset}=data_read.sets{iset}.paradigm_name;
end
%
%show which paradigms contain which stimuli
%
figure;
spy(aux_knit.coords_havedata');
nstims=data_knit.sas{1}.nstims;
typenames=data_knit.sas{1}.typenames;
xlabel('stimuli');
set(gca,'XTick',[1:nstims]);
set(gca,'XTickLabel',typenames);
ylabel('paradigms');
set(gca,'YTick',[1:nsets]);
set(gca,'YTickLabel',paradigm_names);
drawnow;
%
%retrieve and plot convergence and scaling
%
scalings=cell(1,max(dim_list));
rmsdev=cell(2,max(dim_list)); %d1 is 1 for standard, 2 for allow scale
niters=zeros(2,max(dim_list));
for idim=dim_list
    details=aux_knit.details{idim};
    details_as=aux_knit_allowscale.details{idim};
    niters(1,idim)=length(details.ts_cum);
    niters(2,idim)=length(details_as.ts_cum);
    rmsdev{1,idim}=details.rms_dev;
    rmsdev{2,idim}=details_as.rms_dev;
    scalings{idim}=ones(nsets,niters(idim));
    for iter=1:niters(2,idim)
        for iset=1:nsets           
            scalings{idim}(iset,iter)=details_as.ts_cum{iter}{iset}.scaling;
        end
    end
end
figure;
set(gcf,'Position',[100 100 1200 900]);
ncols=3;
ias_label={'no scaling','scaling'};
for idim=dim_list
    %
    for ias=1:2
        subplot(max(dim_list),3,ncols*(idim-1)+ias)
        plot(rmsdev{ias,idim}');
        xlabel('iter');
        set(gca,'XLim',[0 max(niters(:))]);
        ylabel('rms dev');
        set(gca,'YLim',[0 max(max(rmsdev{1,idim}(:)),max(rmsdev{2,idim}(:)))]);
        title(sprintf('rms dev, %s, dim %1.0f',ias_label{ias},idim));
        legend(paradigm_names,'Location','NorthEast');
    end
    subplot(max(dim_list),3,ncols*(idim-1)+3)
    plot(scalings{idim}');
    xlabel('iter');
    set(gca,'XLim',[0 max(niters(:))]);
    ylabel('scale factor');
    set(gca,'YLim',[0.5 1.5]);
    hold on;
    plot([0 max(niters(:))],[1 1],'k');
    title(sprintf('scale factors, dim %1.0f',idim));
end
drawnow;
%
%do statistics?
%
if nshuffs>0
    aux_stats=aux;
    aux_stats.sa_pooled=aux_align.sa_pooled;
    aux_stats.data_align=data_align;
    %
    aux_stats.opts_knit.if_stats=1;
    aux_stats.opts_knit.nshuffs=nshuffs;
    aux_stats.opts_knit.if_plot=0; %plot locally
    %
    [data_knit_stats,aux_knit_stats]=rs_knit_coordsets(data_align,aux_stats); %compute stats
    %
    knit_stats=aux_knit_stats.knit_stats;
    knit_stats_setup=aux_knit_stats.knit_stats_setup;
    knit_stats_setup.dataset_labels=paradigm_names;
%    strrep(knit_stats_setup.dataset_labels,'samples/bwtextures/',''); %shorten dataset labels
    for k=1:length(knit_stats_setup.stimulus_labels) %thin stimulus labels
        if mod(k,3)~=1
            knit_stats_setup.stimulus_labels{k}='';
        end
    end
    knit_stats_setup.nrows=2; %reserve two rows
    knit_stats_setup.row=1; %plot in row 1
    figh_stats=psg_knit_stats_plot(knit_stats,knit_stats_setup);
    %
    aux_allowscale_stats=aux_stats;
    aux_allowscale_stats.opts_knit.allow_scale=1;
    aux_allowscale_stats.opts_knit.if_normscale=1;
    %
    [data_knit_allowscale_stats,aux_knit_allowscale_stats]=rs_knit_coordsets(data_align,aux_allowscale_stats);
    %
    knit_allowscale_stats=aux_knit_allowscale_stats.knit_stats;
    knit_stats_setup.row=2;
    knit_stats_setup.figh=figh_stats;
    psg_knit_stats_plot(knit_allowscale_stats,knit_stats_setup); %plot allowscale stats in second row
end %nshuffs
%
%write datasets if requested
%
if if_write
    aux.opts_write=struct;
    aux.opts_write.if_gui=0;
    aux_out_write=rs_write_coorddata('./demos/gbcdea3pt_coords_MC_noscale',data_knit,aux);
    %
    aux_allowscale.opts_write=struct;
    aux_allowscale.opts_write.if_gui=0;
    aux_allowscale_out_write=rs_write_coorddata('./demos/gbcdea3pt_coords_MC_scale',data_knit_allowscale,aux_allowscale);
end
