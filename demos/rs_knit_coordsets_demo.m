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
imagesc(aux_knit.coords_havedata');
colormap gray;
nstims=data_knit.sas{1}.nstims;
typenames=data_knit.sas{1}.typenames;
xlabel('stimuli');
set(gca,'XTick',[1:nstims]);
set(gca,'XTickLabel',typenames);
ylabel('paradigms');
set(gca,'YTick',[1:nsets]);
set(gca,'YTickLabel',paradigm_names);
%
%also knit with allowing a scaling between datasets
aux_allowscale=aux;
aux_allowscale.opts_knit.allow_scale=1;
aux_allowscale.opts_knit.if_normscale=1;
[data_knit_allowscale,aux_knit_allowscale]=rs_knit_coordsets(data_align,aux_allowscale);

%retrieve and plot scaling
scalings=cell(1,max(dim_list));
niters=zeros(1,max(dim_list));
for idim=dim_list
    details=aux_knit_allowscale.details{idim};
    niters(idim)=length(details.ts_cum);
    scalings{idim}=ones(nsets,niters(idim));
    for iter=1:niters(idim)
        for iset=1:nsets
            scalings{idim}(iset,iter)=details.ts_cum{iter}{iset}.scaling;
        end
    end
end
figure;
set(gcf,'Position',[100 100 1200 800]);
for idim=dim_list
    subplot(max(dim_list),1,idim)
    plot(scalings{idim}');
    set(gca,'XLim',[0 max(niters)]);
    title(sprintf(' dim %1.0f',idim));
end
%%%show scaling and how it progresses over time
% aux_knit.details{3}.ts_cum{4}
% ans =
%   1×3 cell array
%     {1×1 struct}    {1×1 struct}    {1×1 struct}
% aux_knit.details{3}.ts_cum{4}{1}
% ans = 
%   struct with fields:
% 
%         scaling: 1
%          orthog: [3×3 double]
%     translation: [0.3063 0.2145 0.1489]
% aux_knit.details{3}.ts_cum{end}{1}
% ans = 
%   struct with fields:
% 
%         scaling: 1
%          orthog: [3×3 double]
%     translation: [0.3823 0.2738 0.2724]
% aux_knit_allowscale.details{3}.ts_cum{end}{1}
% ans = 
%   struct with fields:
% 
%         scaling: 1.0971
%          orthog: [3×3 double]
%     translation: [0.3804 0.2652 0.2848]
