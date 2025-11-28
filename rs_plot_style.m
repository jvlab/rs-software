function [handles,plotstyles_used,opts_used]=rs_plot_style(coords,plotstyle,opts)
% [handles,plotstyles_used,opts_used]=rs_plot_style(coords,plotstyle,opts) is a utility plotting
% routine that handles marker type, marker size, line style, line
% thickness, alpha blending, and possible conflicts or unsupported properties
%
% coords: a set of values to plot, either 2 or 3 columns
%    If coords is empty, no handles are created
% plotstyle: structure with any of the following fields (empty fields have indicated defaults)
%   plotstyle.marker: '.'
%   plotstyle.markersize: 6
%   plotstyle.linestyle: 'none'
%   plotstyle.linewidth: 1
%   plotstyle.color: 'k' (can also be an [r,g,b] triple)
%   plotstyle.filled: 0 (1 to fill in)
%   plotstyle.alpha: 1
% opts: options, intended for hints for how to resolve conflicts
%   opts.if_alpha_color_line: 1 (default) if line color property allows for alpha, 0 if not, -1 to determine from exist('alpha')
%   opts.if_alpha_color_marker: 1 if marker edge color property allows for alpha, 0 (default) if not, -1 to determine from exist('alpha')

%
% handles: handle(s) to the plot, may include any of the following
%    handles.line
%    handles.markers
%    handles.scatter
%  Also includes handles.legend, the recommended handle for legends
% plotstyles_used: plot styles used for any of the components, as well as plotstyles_used.orig, 
%    which is plotstyles_used with defaults filled inb
% opts_used: options used, has a msgs field
% 
% plot status is hold on at exit
% if coords is empty, no handles are created
%
%   See also:  RS_PLOT_STYLE_TEST
%
if (nargin<=2)
    opts=struct;
end
%line color allows for alpha, but markeredgecolor and markerfacecolor do not have alpha
opts=filldefault(opts,'if_alpha_color_line',1);
if opts.if_alpha_color_line==-1
    opts.if_alpha_color_line=double(exist('alpha')>=2);
end
opts=filldefault(opts,'if_alpha_color_marker',0);
if opts.if_alpha_color_marker==-1
    opts.if_alpha_color_marker=double(exist('alpha')>=2);
end
%
plotstyle_def=struct;
plotstyle_def.marker='.';
plotstyle_def.markersize=6;
plotstyle_def.filled=0;
%
plotstyle=filldefault(plotstyle,'marker',plotstyle_def.marker);
plotstyle=filldefault(plotstyle,'markersize',plotstyle_def.markersize);
plotstyle=filldefault(plotstyle,'linestyle','none');
plotstyle=filldefault(plotstyle,'linewidth',1);
plotstyle=filldefault(plotstyle,'color','k');
plotstyle=filldefault(plotstyle,'filled',plotstyle_def.filled);
plotstyle=filldefault(plotstyle,'alpha',1);
plotstyles_used=struct;
plotstyles_used.orig=plotstyle;
handles=[];
opts_used=opts;
opts_used.msgs=[];
nds=size(coords,2);
if ~ismember(nds,[0 2 3])
    return
end
%
handles.legend=[];
handles.line=[];
handles.markers=[];
handles.scatter=[];
%
if plotstyle.alpha==1
    hp=rs_plot_style_do(coords,'Line');
    set(hp,'Color',plotstyle.color);
    set(hp,'Marker',plotstyle.marker);
    set(hp,'MarkerSize',plotstyle.markersize);
    set(hp,'MarkerEdgeColor',plotstyle.color);
    if plotstyle.filled
        set(hp,'MarkerFaceColor',plotstyle.color);
    end
    set(hp,'LineStyle',plotstyle.linestyle);
    set(hp,'LineWidth',plotstyle.linewidth);
    handles=rs_plot_style_sethandles(handles,hp,{'legend','line','markers'});
    return
%now deal with alpha
else
    %
    if_alpha_marker=~strcmp(plotstyle.marker,'none');
    if_alpha_line=~strcmp(plotstyle.linestyle,'none');
    %
    if if_alpha_line & ~if_alpha_marker %alpha requested for line but not marker
        hp=rs_plot_style_do(coords,'Line');
        set(hp,'Color',plotstyle.color);
        set(hp,'LineStyle',plotstyle.linestyle);
        set(hp,'LineWidth',plotstyle.linewidth);
        if opts.if_alpha_color_line
            c3=get(hp,'Color');
            set(hp,'Color',[c3 plotstyle.alpha]);
        else
            opts_used.msgs='Cannot apply alpha-blending to Line objects';
        end
        handles=rs_plot_style_sethandles(handles,hp,{'legend','line'});
    end
    if ~if_alpha_line & if_alpha_marker %alpha requested for marker but not line
        hp=rs_plot_style_do(coords,'Scatter');
        set(hp,'Marker',plotstyle.marker);
        set(hp,'MarkerEdgeColor',plotstyle.color);
        set(hp,'MarkerEdgeAlpha',plotstyle.alpha);
        if plotstyle.filled
            set(hp,'MarkerFaceColor',plotstyle.color);
            set(hp,'MarkerFaceAlpha',plotstyle.alpha);
        end
        if (~strcmp(plotstyle.marker,plotstyle_def.marker) | (plotstyle.markersize~=plotstyle_def.markersize))
            opts_used.msgs='Cannot customize marker or marker size while using Scatter objects for alpha-blending';
        end
        handles=rs_plot_style_sethandles(handles,hp,{'legend','scatter','markers'});
    end

end
return
end
function hp=rs_plot_style_do(coords,plot_type)
switch plot_type
    case 'Line'
        switch size(coords,2)
            case 2
                hp=plot(coords(:,1),coords(:,2));
            case 3
                hp=plot3(coords(:,1),coords(:,2),coords(:,3));
        end       
        set(hp,'Marker','none');
        set(hp,'LineStyle','none');
    case 'Scatter'
        switch size(coords,2)
            case 2
                hp=scatter(coords(:,1),coords(:,2));
            case 3
                hp=scatter3(coords(:,1),coords(:,2),coords(:,3));
        end
end
hold on;
return
end
%
function handles=rs_plot_style_sethandles(h,hp,fields)
handles=h;
for k=1:length(fields)
    handles.(fields{k})=hp;
end
return
end

% [hplot,msg]=rs
% 
% 
% function hline=rs_disp_doplot(coords,index,opts)
% %plot the data (rows of coords) into the current plot, using index into opts.set* to determine the style
% switch size(coords,2)
%     case 2
%         hline=plot(coords(:,1),coords(:,2),'k.');
%     case 3
%         hline=plot3(coords(:,1),coords(:,2),coords(:,3),'k.');
% end
% hold on;
% index_color=1+mod(index-1,length(opts.colors));
% set(hline,'Color',opts.colors{index_color});
% %
% index_marker=1+mod(index-1,length(opts.markers));
% set(hline,'Marker',opts.markers{index_marker});
% %
% index_markersize=1+mod(index-1,length(opts.markersizes));
% set(hline,'MarkerSize',opts.markersizes(index_markersize));
% %
% index_linestyle=1+mod(index-1,length(opts.linestyles));
% set(hline,'LineStyle',opts.linestyles{index_linestyle});
% %
% index_linewidth=1+mod(index-1,length(opts.linewidths));
% set(hline,'LineWidth',opts.linewidths(index_linewidth));
% %
% return
% end
