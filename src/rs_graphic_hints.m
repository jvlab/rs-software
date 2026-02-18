%rs_graphic_hints.m
%this file, provides hints for how alpha blending should be implemented
%
%  See also:  RS_PLOT_STYLE.
%
rs_graphic_hints_def=struct;
%
rs_graphic_hints_def.if_alpha_color_line=1; %set if line color property allows for alpha as fourth component
rs_graphic_hints_def.if_alpha_color_line_marker=0; %set if marker edge color property on a line allows for alpha as a fourth component
rs_graphic_hints_def.if_alpha_scatter_marker_edge=1; %set if MarkerEdgeAlpha is a property of Scatter
rs_graphic_hints_def.if_alpha_scatter_marker_face=1; %set if MarkerFaceAlpha is a property of Scatter


