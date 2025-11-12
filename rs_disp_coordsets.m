function aux_out=rs_disp_coordsets(data_in,aux)
% aux_out==rs_disp_coordsets(data_in,aux) displays one or more views of a set of coordinates
%
% data_in.ds{k},sas{k},sets{k}: the structures of coordinates (ds) and metadata (sas,sets)
%   These are typically read by rs_get_coordsests, or created:
%    as data_out from rs_align_coordsets,
%    as aux_out.components from rs_knit_coordsets
%    as data_out from rs_knit_coordsets
%    as data_out from rs_xform_apply
%
%  Multiple views can be plotted in subplots of the same figure.
%  Subplots are in 'hold on' state, so that one can add to the plots
%  
% aux:
%  aux.opts_disp
%   if_warn: 1 to display warnings
%   fig_handle: handle to figure, will be created if empty or not provided
%   fig_position: position params for new figure to be created
%   fig_name: title for figure 
%   axis_handles: handle to axes, one for each subplot, will be created if not supplied
%   set_select: datasets to show, defaults to [1:length(data_in.da)]
%   dim_select: dimension to display, i.e., data_in.ds{set_select}{dim_select}, defaults to 3, must be at least 2
%   coord_group_size: number of coords to display together, in range [2 3], defaults to min(dim_select,3)
%   coord_group_method: method of selecting coordinates (corresponds to opts_vis.which_dimcombs in psg_visualize)
%      'all': (default) plot all combinations
%      'keeplow': keep all but one dimensions low and only step the highest; [dim_select,coord_group_size]=[5,3] yields [1 2 3],[1 2 4],[1 2 5]
%      'keepone': keep one dimension and step the rest;                      [dim_select,coord_group_size] yields [1 2 3],[1 2 4],[1 2 5],[1 3 4],[1 3 5],[1 4 5]
%      'rolling': rolling contiguous subsets;                                [dim_select,coord_group_size]yields [1 2 3],[2 3 4],[3 4 5],[4 5 1],[5 1 2]
%      'onlylowest': only the lowest dimensions                              [dim_select,coord_group_size] yields [1 2 3]
%      'list': specify a list in opts_disp.coord_groups
%      By default, each dataset is plotted with its own style, with points disconnected.
%      Styles are specified as follows, indexed by the position of the set data_in.  Values are cycled through.
%      set_markers, set_markersizes should be singletons or vectors, set_[colors|markers|linestyles] should be 1-d cell arrays.
%      If set_[colors|markers|linestyles] are not cells, they will be converted to cells.
%   set_colors: color assigned to each set, defaults to {'k','b','c','m','r',[0.5 0.5 0],'g'};, can be rgb triplet
%   set_markers marker assigned to each set, defaults to {'.'};
%   set__markersizes: marker assigned to each set, defaults to 8
%   set_linewidths: line widths assigned to each set, defaults to 1
%   set_linestyles: line styles assigned to each set, defaults to {'.'} (disconnected)
%
%  aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
% 
% aux_out: auxiliary outputs and parameter values used
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%
%  See also: RS_CHECK_COORDSETS, RS_GET_COORDSETS, RS_ALIGN_COORDSETS, RS_KNIT_COORDSETS, RS_XFORM_APPLY,
%     PSG_VISUALIZE, PSG_PLOTCOORDS.
%
if (nargin<=1)
    aux=struct;
end
%set up sub-structure options
aux=filldefault(aux,'opts_disp',struct); %options for this module (psg_template)
aux.opts_disp=filldefault(aux.opts_disp,'fig_handle',[]);
aux.opts_disp=filldefault(aux.opts_disp,'fig_position',[100 100 1200 700]);
aux.opts_disp=filldefault(aux.opts_disp,'axis_handles',[]);
%
aux.opts_disp=filldefault(aux.opts_disp,'set_colors',{'k','b','c','m','r','y','g'});
aux.opts_disp=filldefault(aux.opts_disp,'set_markers',{'.'});
aux.opts_disp=filldefault(aux.opts_disp,'set_markersizes',8);
aux.opts_disp=filldefault(aux.opts_disp,'set_linewidths',1);
aux.opts_disp=filldefault(aux.opts_disp,'set_linestyles',{'.'});
%
aux.opts_disp=filldefault(aux.opts_disp,'if_warn',1);
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_disp_coordsets');
%
aux_out=struct;
%
%check consistency and get available stimuli, dimensions, typenames
%
check=rs_check_coordsets(data_in,aux.opts_check);
aux_out.warnings=check.warnings;
aux_out.warn_bad=check.warn_bad;
nsets=check.nsets;
nstims_each=check.nstims_each;
dim_list_each=check.dim_list_each;
dim_list_union=check.dim_list_union;
dim_list_inter=check.dim_list_inter;
typenames_each=check.typenames_each;
typenames_union=check.typenames_union;
typenames_inter=check.typenames_inter;
%
coords_together_allowed=[2 3];
%
aux.opts_disp=filldefault(aux.opts_disp,'set_select',[1:nsets]);
aux.opts_disp=filldefault(aux.opts_disp,'dim_select',max(intersect(coords_together_allowed,dim_list_inter)));
aux.opts_disp=filldefault(aux.opts_disp,'coord_group_size',min(aux.opts_disp.dim_select,max(coords_together_allowed)));
aux.opts_disp=filldefault(aux.opts_disp,'coord_group_method','all');
aux.opts_disp=filldefault(aux.opts_disp,'fig_name',sprintf('dimension %2.0f',aux.opts_disp.dim_select));
%
wmsg_all=[];
%
%determine coordinate groups
%
x=aux.opts_disp; %for convenience
switch x.coord_group_method
    case 'all'
        x.coord_groups=nchoosek([1:x.dim_select],x.coord_group_size);
    case 'keeplow'
        x.coord_groups=[repmat([1:x.coord_group_size-1],x.dim_select-x.coord_group_size+1,1),[x.coord_group_size:x.dim_select]'];
    case 'keepone'
        coords_group_list_hi=nchoosek([2:x.dim_select],x.coord_group_size-1);
        x.coord_groups=[ones(size(coords_group_list_hi,1),1) coords_group_list_hi];
    case 'rolling'
        x.coord_groups=mod(repmat([0:x.coord_group_size-1],x.dim_select,1)+repmat([0:x.dim_select-1]',1,x.coord_group_size),x.dim_select)+1;
    case 'onlylowest'
        x.coord_groups=[1:x.coord_group_size];
    case 'list'
    otherwise
        wmsg=sprintf('grouping method (%s) not recognized; only lowest coords shown',x.coord_group_method);
        x.coord_groups=[1:x.coord_group_size];
        wmsg_all=strvcat(wmsg_all,wmsg);
end
if x.coord_group_size~=size(x.coord_groups,2)
    wmsg=sprintf('specified coordinate group size (%3.0f) and list of coord groups is inconsistent',x.coord_group_size);
    wmsg_all=strvcat(wmsg_all,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;  
end
if ~ismember(x.coord_group_size,coords_together_allowed)
    wmsg=sprintf('cannot plot groups of %3.0f coordinates on same axis',x.coord_group_size);
    wmsg_all=strvcat(wmsg_all,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;  
end
if any(x.coord_groups(:)<=0) | any(x.coord_groups(:)>x.dim_select)
    wmsg=sprintf('some specified dimensions are out of bounds for the dimension plotted (%2.0f)',x.dim_select);
    wmsg_all=strvcat(wmsg_all,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;
end
aux.opts_disp=x;
ngroups=size(x.coord_groups,1);
%
naxis_handles=length(aux.opts_disp.axis_handles);
if naxis_handles>0 & naxis_handles~=ngroups
    wmsg=sprintf('number of axes (subplots) supplied (%3.0f) does not match number of groups (%3.0f)',naxis_handles,ngroups);
    wmsg_all=strvcat(wmsg_all,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;
end
%
aux_out.warnings=strvcat(aux_out.warnings,wmsg_all);
if ~isempty(wmsg_all)
    if aux.opts_disp.if_warn
        for k=1:size(wmsg_all,1)
            warning(wmsg_all(k,:));
        end
    end
end
%
if aux_out.warn_bad==0
    if isempty(x.fig_handle)
        x.fig_handle=figure;
        set(gcf,'Position',x.fig_position);
        set(gcf,'NumberTitle','off');
        set(gcf,'Name',x.fig_name);
    end
    if naxis_handles==0
        fig_posit=get(gcf,'Position');
        [nrows,ncols]=nicesubp(ngroups,fig_posit(4)/fig_posit(3)); %find an arrangement of rows and columns that fits the aspect ratio
        for igp=1:ngroups
            x.axis_handles{igp}=subplot(nrows,ncols,igp);
        end
    end
    for igp=1:ngroups
        subplot(nrows,ncols,igp);
        for isetptr=1:length(x.set_select)
            k=x.set_select(isetptr);
            hline=rs_disp_doplot(data_in.ds{k}{x.dim_select}(:,x.coord_groups(igp,:)),k,x,'data_points');
        end
        %set up view, scale, axis labels
    end
end
% options from psg_plotcoords 
% opts=filldefault(opts,'line_width',1); %0 to omit lines
% opts=filldefault(opts,'line_width_ring',1);
% opts=filldefault(opts,'line_type',[]); %line type
% opts=filldefault(opts,'line_type_connect_neg','--'); %line type for negative directions for connections
% opts=filldefault(opts,'line_type_ring',':');
% opts=filldefault(opts,'marker_sign','*+'); %symbols for negative and postive values on rays
% opts=filldefault(opts,'marker_origin','o'); %symbol for origin
% opts=filldefault(opts,'marker_noray','.'); %symbol if no ray
% opts=filldefault(opts,'marker_size',8); %marker size
% opts=filldefault(opts,'color_rays',{[.3 .3 .3],[1 0 0],[0 .7 0],[0 0 1]}); %colors to cycle through for each ray, supplanted by psg_typenames2colors
% opts=filldefault(opts,'color_origin',[0 0 0]); %color used for origin
% opts=filldefault(opts,'color_nearest_nbr',[0 0 0]); %color for interconnections of nearest-neighbor points in same datset
% opts=filldefault(opts,'color_ring',[0 0 0]);
% opts=filldefault(opts,'noray_connect',1); %connect points not on rays (ray indicator=NaN) to each other

%
%labels
%connections withn and between sets
%legends
%figure label on figure
%view
%
aux_out.opts_disp=aux.opts_disp;
return
end
% 
% aux.opts_disp=filldefault(aux.opts_disp,'set_colors',{'k','b','c','m','r','y','g'});
% aux.opts_disp=filldefault(aux.opts_disp,'set_markers',{'.'});
% aux.opts_disp=filldefault(aux.opts_disp,'set_markersizes',8);
% aux.opts_disp=filldefault(aux.opts_disp,'set_linewidths',1);
% aux.opts_disp=filldefault(aux.opts_disp,'set_linestyles',{'.'});

function hline=rs_disp_doplot(coords,index,opts,tag)
%plot the data (rows of coords) into the current plot, using index into
%opts.set* to determine the style, and giving the line a tag
switch size(coords,2)
    case 2
        hline=plot(coords(:,1),coords(:,2),'k.');
    case 3
        hline=plot3(coords(:,1),coords(:,2),coords(:,3),'k.');
end
hold on;
index_color=mod(index-1,length(opts.set_colors))+1;
set(hline,'Color',opts.set_colors{index});
return
end
