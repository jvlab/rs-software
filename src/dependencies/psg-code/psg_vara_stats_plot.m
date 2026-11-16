function figh=psg_vara_stats_plot(vs,vs_setup)
% figh=psg_vara_stats_plot(vs,vs_setup) plots the results of rs_vara_coordsets
%
% vs: results structure from ra_vara_coordsets
% vs_setup: analysis setup, see ra_vara_coordsets
%   vs_setup.nshuffs: number of shuffles
%   vs_setup.dim_list_in_max: maximum input dimension
%     optional:
%   vs_setup.dataset_labels: labels for each dataset
%   vs_setup.stimulus_labels: labels for each stimulus
%   vs_setup.dim_list_in: list of input dimensions to plot, defaults to [1:vs_setup.dim_list_in_max]
%   vs_setup.dim_list_out: list of output dimensions, defaults to 1:vs_setup.dim_list_in
%   vs_setup.shuff_quantiles: quantiles to plot
%   vs_setup.figh: figure handle to use; if empty, figure will be opened
%   vs_setup.row: row to plot, defaults to 1
%   vs_setup.nrows: number of rows, defaults to max(1,vs_setup.row)
%   vs_setup.range_equalize: 1 (default) to equalize the ranges across rows, active only if setup.row=setup.nrows
%
%   See also: PSG_ALIGN_STATS, PSG_ALIGN_STATS_DEMO, PSG_KNIT_STATS_PLOT.
%
%
%  See also: PSG_ALIGN_VARA_PLOT.
%

vs_setup=filldefault(vs_setup,'dataset_labels',[]);
vs_setup=filldefault(vs_setup,'stimulus_labels',[]);
vs_setup=filldefault(vs_setup,'dim_list_in',[1:vs_setup.dim_list_in_max]);
vs_setup=filldefault(vs_setup,'dim_list_out',vs_setup.dim_list_in);
vs_setup=filldefault(vs_setup,'figh',[]);
vs_setup=filldefault(vs_setup,'row',1);
vs_setup=filldefault(vs_setup,'nrows',max(1,vs_setup.row));
vs_setup=filldefault(vs_setup,'range_equalize',1);
vs_setup=filldefault(vs_setup,'shuff_quantiles',[0.01 0.05 0.5 0.95 0.99]);
vs_setup=filldefault(vs_setup,'if_debug',0);
vs_setup=filldefault(vs_setup,'plot_max_factor',1);
%
if isempty(vs_setup.figh)
    figh=figure;
    set(gcf,'NumberTitle','off');
    set(gcf,'Name','variance analysis');
    set(gcf,'Position',[100 100 1400 800]);
else
    figh=figure(vs_setup.figh);
end
%
tags=vs.groupings.tags;
ncols=3+vs_setup.if_debug;
%
rms_plot_max1=max(abs(vs.rmsdev_overall(:)));
rms_plot_max2=max(abs(vs.rmsdev_grpwise(:)));
if vs.nshuffs>0
    rms_plot_max2=max([rms_plot_max2,max(abs(vs.rmsdev_grpwise_shuff(:)))]);
end
rms_plot_max=vs_setup.plot_max_factor*max(rms_plot_max1,rms_plot_max2);
if isfield(vs.opts_multi_used,'if_exhaust')
    if vs.opts_multi_used.if_exhaust==1
        shuff_desc_string='exhaustive';
    else
        shuff_desc_string='random';
    end
else
    shuff_desc_string='custom';
end
if vs_setup.opts_vara.allow_scale==0
    scale_string='no scaling';
else
    scale_string='scaling';
end
if vs_setup.opts_vara.if_normscale
    scale_string=cat(2,scale_string,'+norm');
end
dim_max=max(vs_setup.dim_list_out);
%concatenate groups, and set up pointers for reordering
rmsdev_setwise_gp_concat=zeros(dim_max,0);
gp_reorder=[];
for igp=1:vs.groupings.ngps
    rmsdev_setwise_gp_concat=cat(2,rmsdev_setwise_gp_concat,vs.rmsdev_setwise_gp(:,[1:vs.groupings.nsets_gp(igp)],igp));
    gp_reorder=[gp_reorder,vs.groupings.gp_list{igp}];
end
%
vsu=vs; %versionfor psg_align_vara_util
vsu=setfield(vsu,'nsets',vs_setup.nsets);
vsu=setfield(vsu,'gps',vs.groupings.gps);
vsu=setfield(vsu,'nsets_gp',vs.groupings.nsets_gp);
vsu=setfield(vsu,'dataset_labels',vs_setup.dataset_labels);
vsu=setfield(vsu,'dim_max',dim_max);
if vs_setup.if_debug %rms dev from global, by set, native order
    subplot(vs_setup.nrows,ncols,ncols*(vs_setup.row-1)+ncols);
    imagesc(vs.rmsdev_setwise,[0 rms_plot_max]);
    hold on;
 %       psg_align_vara_util(setfield(results,'nsets_gp',results.nsets),[1:results.nsets],tags);
    psg_align_vara_util(setfield(vsu,'nsets_gp',vs_setup.nsets),[1:vs_setup.nsets],tags);
    title(cat(2,'rms dev fr gbl, ',scale_string));
end
%
%rms dev from global, by set, group order
subplot(vs_setup.nrows,ncols,ncols*(vs_setup.row-1)+1);
imagesc(vs.rmsdev_setwise(:,gp_reorder),[0 rms_plot_max]);
hold on;
psg_align_vara_util(vsu,gp_reorder,tags);
title(cat(2,'rms dev fr gbl, ',scale_string));
%
%rms dev from its group, by set, group order
subplot(vs_setup.nrows,ncols,ncols*(vs_setup.row-1)+2);
imagesc(rmsdev_setwise_gp_concat,[0 rms_plot_max]);
hold on;
psg_align_vara_util(vsu,gp_reorder,tags);
title(cat(2,'rms dev fr grp, ',scale_string));
%
%     %compare global and group-wise rms devs
hl=cell(0);
if (vs.nshuffs>0)
    ht=strvcat('overall','within-group','shuff mean');
else
    ht=strvcat('overall','within-group');
end
d_plot=vs_setup.dim_list_in;
subplot(vs_setup.nrows,ncols,ncols*(vs_setup.row-1)+3);
hp=plot(d_plot,vs.rmsdev_overall(d_plot,1),'b');
hl=[hl;hp];
hold on;
hp=plot(d_plot,vs.rmsdev_grpwise(d_plot,1),'k');
hl=[hl;hp];
if vs.nshuffs>0
    hp=plot(d_plot,mean(vs.rmsdev_grpwise_shuff(d_plot,1,:,:),4),'r*');   
    hl=[hl;hp];
    quant_plot=quantile(reshape(vs.rmsdev_grpwise_shuff(:,1,:,:),[dim_max,vs.nshuffs]),vs_setup.shuff_quantiles,2);
    for iq=1:length(vs_setup.shuff_quantiles)
        switch sign(vs_setup.shuff_quantiles(iq)-0.5)
            case -1
                linetype=':';
            case 0
                linetype='';
            case 1
                linetype='--';
        end
        hp=plot(d_plot,quant_plot(d_plot,iq),cat(2,'r',linetype));
        if iq==round((1+length(vs_setup.shuff_quantiles))/2)
            hl=[hl;hp];
            ht=strvcat(ht,'shuff quantile');
        end
    end
end %shuff
xlabel('dim in');
ylabel('rms dev')
set(gca,'XTick',d_plot)
set(gca,'XTickLabel',d_plot);
set(gca,'XLim',0.5+[0 max(d_plot)]);
set(gca,'YLim',[0 rms_plot_max]);
title(cat(2,'rms dev, ',scale_string));
legend(hl,ht,'Location','Best','FontSize',7);
%
if (vs_setup.row==vs_setup.nrows)
    axes('Position',[0.01,0.04,0.01,0.01]); %for text
    text(0,0,'variance analysis','Interpreter','none','FontSize',8);
    axis off;
    %show input and output dimensions if they differ
    if ~all(vs_setup.dim_list_in==vs_setup.dim_list_out)
        dim_in_string=cat(2,'dim  in:',sprintf(' %1.0f',vs_setup.dim_list_in));
        dim_out_string=cat(2,'dim out:',sprintf(' %1.0f',vs_setup.dim_list_out));
    end
end
if (vs_setup.nshuffs>0)
    voff=(vs_setup.nrows-vs_setup.row)/vs_setup.nrows;
    axes('Position',[0.66,0.06+voff,0.01,0.01]); %for text
    text(0,0,cat(2,sprintf('quantiles from %5.0f %s shuffs: ',vs_setup.nshuffs,shuff_desc_string),sprintf('%6.4f ',vs_setup.shuff_quantiles)),...
        'FontSize',8);
    axis off;
    %show input and output dimensions if they differ
    if ~all(vs_setup.dim_list_in==vs_setup.dim_list_out)
        dim_in_string=cat(2,'dim  in:',sprintf(' %1.0f',vs_setup.dim_list_in));
        dim_out_string=cat(2,'dim out:',sprintf(' %1.0f',vs_setup.dim_list_out));
        axes('Position',[0.66,0.04+voff,0.01,0.01]); %for text
        text(0,0,dim_in_string,'FontSize',8);
        axis off;
        axes('Position',[0.66,0.02+voff,0.01,0.01]); %for text
        text(0,0,dim_out_string,'FontSize',8);
        axis off;
    end
end
if vs_setup.range_equalize & vs_setup.row==vs_setup.nrows
    %set equal scales on colorbars
    colorbar_cols=setdiff(1:ncols,3);
    for col=colorbar_cols
        cl=0;
        for row=1:vs_setup.nrows
            cl=max(cl,max(get(subplot(vs_setup.nrows,ncols,col+(row-1)*ncols),'Clim')));
        end
        for row=1:vs_setup.nrows
            set(subplot(vs_setup.nrows,ncols,col+(row-1)*ncols),'Clim',[0 cl]);
        end
    end
    %set equal scales on line plots
    for col=3
        cl=0;
        for row=1:vs_setup.nrows
            cl=max(cl,max(get(subplot(vs_setup.nrows,ncols,col+(row-1)*ncols),'YLim')));
        end
        for row=1:vs_setup.nrows
            set(subplot(vs_setup.nrows,ncols,col+(row-1)*ncols),'YLim',[0 cl]);
        end
    end
end
return
end
