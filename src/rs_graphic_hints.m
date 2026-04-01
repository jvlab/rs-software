function graphic_hints=rs_graphic_hints()
% graphic_hints=rs_graphic_hints() provides version-specific hints for graphics capabilities, including how alpha blending should be implemented
%
% Returns:
%   graphic_hints (struct): descriptor of version-specific graphics capabilities, with fields
%
%      - if_alpha_color_line (int): 1 if line color property allows for alpha as fourth component, otherwise 0
%      - if_alpha_color_line_marker (int): 1 if if marker edge color property on a line allows for alpha as a fourth component, otherwise 0
%      - if_alpha_scatter_marker_edge (int): 1 if MarkerEdgeAlpha is a property of Scatter, otherwise 0
%      - if_alpha_scatter_marker_face (int): 1 if MarkerFaceAlpha is a property of Scatter, otherwise 0
%
%  See also:  RS_PLOT_STYLE.
%
graphic_hints=struct;
%
graphic_hints.if_alpha_color_line=1; %set if line color property allows for alpha as fourth component
graphic_hints.if_alpha_color_line_marker=0; %set if marker edge color property on a line allows for alpha as a fourth component
graphic_hints.if_alpha_scatter_marker_edge=1; %set if MarkerEdgeAlpha is a property of Scatter
graphic_hints.if_alpha_scatter_marker_face=1; %set if MarkerFaceAlpha is a property of Scatter
return
end
