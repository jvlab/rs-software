function psg_align_vara_util(results,gp_reorder,tags)
%labeling utilty for plots in psg_align_vara_demo
%results: results structure
%gp_reorder: ordering of datasets in plot, use [1:nsets] to avoid reordering
%tags: if non-empty, dataset tags
%
% 30Jun26: set interpreter to none
%
%  See also: PSG_ALIGN_VARA_DEMO.
%
if nargin<=2
    tags=[];
end
for iset=1:results.nsets %add group number
    text(iset-0.5,1,sprintf('%1.0f',results.gps(gp_reorder(iset))));
end
if ~isempty(tags)
    for iset=1:results.nsets %add group number
        text(iset-0.5,2,sprintf('%1.0f',tags(gp_reorder(iset))));
    end
end
%use length of gp_reorder, not ngps, to determine whether to draw
%cursors between groups
for igp=1:length(results.nsets_gp)-1 %separate the groups
    plot(repmat(sum(results.nsets_gp(1:igp)),[1 2])+0.5,[0 results.dim_max]+0.5,'k-');
end        
xlabel('dataset');
set(gca,'XTick',1:results.nsets);
set(gca,'XTickLabel',results.dataset_labels(gp_reorder));
set(gca,'TickLabelInterpreter','none');
ylabel('dim');
set(gca,'YTick',1:results.dim_max);
return
