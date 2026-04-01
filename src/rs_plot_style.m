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
%   plotstyle.linewidth: 1, applies both to marker edge and to lines
%   plotstyle.color: 'k' (can also be an [r,g,b] triple, or any other Matlab color specification)
%   plotstyle.color_fill: color for inside of marker, if marker is filled in, defaults to plotstyle_color
%   plotstyle.filled: 0 (1 to fill in)
%   plotstyle.alpha: 1
% opts: options, intended for hints for how to resolve conflicts
%   opts.if_alpha_color_line: 1 if line color property allows for alpha as fourth component, 0 if not, 
%    -1 (default) to determine from rs_graphic_hints.m if present, and if not, from exist('alpha')
%   opts.if_alpha_color_line_marker: 1 if marker edge color property allows for alpha as fourth component, 0 if not
%    -1 (default) to determine from rs_graphic_hints.m if present, and if not, from exist('alpha')
%   opts.if_alpha_scatter_marker_[edge|face]:  1 if Marker[Edge|Face]Alpha is a property of Scatter, 0 if not,
%    -1 (default) to determine from rs_graphic_hints.m if present, and if not, from exist('alpha')
%  If any of these capabilities are attempted and fail, then they are set to zero in opts_used 
%
% handles: handles to the plot and components
%    handles.legend: handle appropriate for the legend
%  and one or more of the following, if the components exist
%    handles.line
%    handles.markers
%    handles.scatter
% plotstyles_used: plot styles with defaults filled in
% opts_used: options used, has a msgs field
% 
% plot status is hold on at exit
% if coords is empty, no handles are created
%
%   See also:  RS_PLOT_STYLE_TEST, RS_GRAPHIC_HINTS
%
if (nargin<=2)
    opts=struct;
end
if exist('rs_graphic_hints','file')
    rs_graphic_hint_def=rs_graphic_hints();
end
if ~exist('rs_graphic_hints_def')
    rs_graphic_hints_def=struct;
end
opts=rs_plot_style_sethint(opts,'if_alpha_color_line',rs_graphic_hints_def); %line color allows for alpha
opts=rs_plot_style_sethint(opts,'if_alpha_color_line_marker',rs_graphic_hints_def); %MarkerEdgeColor and MarkerFaceColor on a line allow for alpha
opts=rs_plot_style_sethint(opts,'if_alpha_scatter_marker_edge',rs_graphic_hints_def); %MarkerEdgeAlpha is a property of Scatter
opts=rs_plot_style_sethint(opts,'if_alpha_scatter_marker_face',rs_graphic_hints_def); %MarkerEdgeAlpha is a property of Scatter
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
plotstyle=filldefault(plotstyle,'color_fill',plotstyle.color);
plotstyle=filldefault(plotstyle,'filled',plotstyle_def.filled);
plotstyle=filldefault(plotstyle,'alpha',1);
plotstyles_used=plotstyle;
handles=[];
opts_used=opts;
opts_used.msgs=[];
%
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
        set(hp,'MarkerFaceColor',plotstyle.color_fill);
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
    %alpha for line but not marker
    if if_alpha_line & ~if_alpha_marker
        [hp,opts_used]=rs_plot_style_line(coords,plotstyle,plotstyle_def,opts_used);
        handles=rs_plot_style_sethandles(handles,hp,{'legend','line'});
    end 
    %
    %alpha requested for marker but not line
    if ~if_alpha_line & if_alpha_marker
        [hp,opts_used]=rs_plot_style_scatter(coords,plotstyle,plotstyle_def,opts_used);
        handles=rs_plot_style_sethandles(handles,hp,{'legend','scatter','markers'});
    end %alpha requested for marker but not line
    %
    %alpha requested for line and marker
    if if_alpha_line & if_alpha_marker
        %first plot line with no markers
        [hp,opts_used]=rs_plot_style_line(coords,setfield(plotstyle,'marker','none'),plotstyle_def,opts_used);
        handles=rs_plot_style_sethandles(handles,hp,{'line'});
        %then plot markers without line, and use this for legend handle
        [hp,opts_used]=rs_plot_style_scatter(coords,plotstyle,plotstyle_def,opts_used);
        handles=rs_plot_style_sethandles(handles,hp,{'legend','scatter','markers'});
    end
end
return
end

function handles=rs_plot_style_sethandles(h,hp,fields)
handles=h;
for k=1:length(fields)
    handles.(fields{k})=hp;
end
return
end

function opts_new=rs_plot_style_sethint(opts,hint,rs_graphic_hints_def)
opts=filldefault(opts,hint,-1);
if opts.(hint)==-1
    if isfield(rs_graphic_hints_def,hint)
        opts.(hint)=rs_graphic_hints_def.(hint);
    else
        opts.(hint)=double(exist('alpha')>=2);
    end
end
opts_new=opts;
return
end

function [hp,opts_new]=rs_plot_style_line(coords,plotstyle,plotstyle_def,opts)
 %attempt to plot an alpha-blended line
hp=rs_plot_style_do(coords,'Line');
set(hp,'Color',plotstyle.color);
set(hp,'LineStyle',plotstyle.linestyle);
set(hp,'LineWidth',plotstyle.linewidth);
c3=get(hp,'Color');
if opts.if_alpha_color_line
    success=1;
    try
        set(hp,'Color',[c3, plotstyle.alpha]);
    catch
        success=0;
    end
else
    success=0;
end
if (success==0)
    opts.if_alpha_color_line=0;
    opts.msgs=strvcat(opts.msgs,'Cannot apply alpha-blending to Line objects');
end
opts_new=opts;
return
end

function [hp,opts_new]=rs_plot_style_scatter(coords,plotstyle,plotstyle_def,opts) 
%attempt to plot a scatter object with a given style
hp=rs_plot_style_do(coords,'Scatter');
set(hp,'Marker',plotstyle.marker);
set(hp,'MarkerEdgeColor',plotstyle.color);
set(hp,'LineWidth',plotstyle.linewidth);
if opts.if_alpha_scatter_marker_edge
    success=1;
    try 
        set(hp,'MarkerEdgeAlpha',plotstyle.alpha);
    catch
        success=0;
    end
else
    success=0;
end
if (success==0)
    opts.if_alpha_scatter_marker_edge=0;
    opts.msgs=strvcat(opts.msgs,'Cannot apply alpha-blending to Scatter marker edges');
end
if plotstyle.filled
    set(hp,'MarkerFaceColor',plotstyle.color_fill);
    if opts.if_alpha_scatter_marker_face
        success=1;
        try
            set(hp,'MarkerFaceAlpha',plotstyle.alpha);
        catch
            success=0;
        end
    else
        success=0;
    end
    if (success==0)
        opts.if_alpha_scatter_marker_face=0;
        opts.msgs=strvcat(opts.msgs,'Cannot apply alpha-blending to Scatter marker faces');               
    end
end
if plotstyle.markersize~=plotstyle_def.markersize
    opts.msgs='Cannot customize marker size while using Scatter objects for alpha-blending';
end
opts_new=opts;
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
