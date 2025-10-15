% rs_knit_coordsets_demo: demonstrate knitting across datasets with partially overlapping stimuli
%
%  See also:  RS_KNIT_COORDSETS, RS_ALIGN_COORDSETS
%
filenames={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat','./samples/bwtextures/dgea3pt_coords_MC_sess01_10.mat'};
nsets=length(filenames);
aux=struct;
aux.nsets=nsets;
aux.opts_align.min=1;
aux.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
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
fields_expand={'opts','file_list','sets','sets_combined'};
disp('%%%%%%%%%%%%%%%%%%%');
disp('pipeline for knitted dataset, no scaling');
rs_showpipeline(data_knit.sets{1}.pipeline,setfield(struct(),'fields_expand',fields_expand));
disp('%%%%%%%%%%%%%%%%%%%');
disp('pipeline for knitted dataset, scaling');
rs_showpipeline(data_knit_allowscale.sets{1}.pipeline,setfield(struct(),'fields_expand',fields_expand));
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
