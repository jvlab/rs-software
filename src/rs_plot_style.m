function [handles,plotstyles_used,opts_used]=rs_plot_style(coords,plotstyle,opts)
% [handles,plotstyles_used,opts_used]=rs_plot_style(coords,plotstyle,opts)
% plots a set of points into the current axis.
% 
% The data may be either 2D or 3D.  Plotting uses a specified marker type, marker size,
% line style, line thickness, and alpha blending, and handles possible conflicts or unsupported properties.
%
% Args:
%   coords (float 2-D array): data to plot, 2 columns for a 2D plot, 3 columns for a 3D plot
%
%   plotstyle (struct): specification of plotting style, may be omitted, with fields
%
%      - marker (char): marker type; one of {'.','o','x','+','*','s','d','v','^','<','>','p','h'}; default is '.'
%      - markersize (int): marker size; default is 6
%      - linestyle (char): line style; one of {'-',':','-.','--',','none'}; default is 'none'
%      - linewidth (int): width of lines and marker edges; default is 1
%      - color (char or float 1-D array): color of points, lines, and marker edges, can be any Matlab color specifier or an (r,g,b) triple; default is 'k' (black)
%      - color_fill (char or fload 1-D array): color of marker interior if marker is filled; default is plotstyle.color;
%      - filled (int): 1 to filled marker, 0 for unfilled; default is 0
%      - alpha (float): alpha-blending (transparency); defaults to 1 (opaque)
%
%   opts (struct): how to resolve conflicts (see note below regarding graphic hints), may be omitted, with fields
%
%      - if_alpha_color_line (int): 1 if line color property allows for alpha as fourth component, 0 if not, -1 to determine from hints; default is -1 
%      - if_alpha_color_line_marker (int): 1 if marker edge color property allows for alpha as fourth component, 0 if not, -1 to determine from hints; default is -1 
%      - if_alpha_scatter_marker_edge (int): 1 if MarkerEdgeAlpha is a property of Scatter, 0 if not, -1 to determine from hints; default is -1
%      - if_alpha_scatter_marker_face (int): 1 if MarkerFaceAlpha is a property of Scatter, 0 if not, -1 to determine from hints; default is -1
%
%
% Returns:
%   handles (struct): structure of handles to the plot and components, with fields
%
%     - line (struct): handle of the graphics line object used for the line connecting points; may be empty
%     - markers (struct): handle of the graphics object for the plotted points, may be a line or scatter object
%     - scatter (struct): handle of the graphics scatter object for the plotted points; may be empty
%     - legend (struct): handle to graphics object (line or scatter) that can be used for a legend; will be either handles.line or handles.scatter and will not be empty
% 
%   plotstyles_used (struct): plot styles with defaults filled in
% 
%   opts_used (struct): opts, with defaults filled in; see note below regarding graphic hints
% 
% General notes:
%    - Plotting will be into current axis if available; otherwise a new axis will be created.
%    - Axis hold state will be 'on' after plotting.
%
% Note regarding graphic hints:
%    - Capabilities for alpha-blending may be version-dependent, and should be indicated during installation by customizing `rs_graphic_hints`
%    - An entry of -1 (default) in 'opts' uses `rs_graphic_hints` to determine the capability.
%    - If `rs_graphic_hints` is absent, the present, and if not, by attempting to set an alpha property
%    - At run-time, these hints may be overrridden by a 1 (capability present) or a 0 (capability absent) in a field of 'opts'.
%    - If an attempt to use transparency fails, then the corresponding field of 'opts_used' is set to 0, and a essage is generated in opts_used.msgs
% 
%   See also:  RS_PLOT_STYLE_TEST, RS_GRAPHIC_HINTS.
%
if (nargin<=1)
    plotstyle=struct;
end
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
