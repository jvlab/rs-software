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
%
%   fig_handle: handle to figure, will be created if empty or not provided
%   fig_position: position params for new figure to be created (modifiable in rs_aux_defaults_define)
%   fig_name: title for figure 
%
%   axis_handles: handle to axes, one for each subplot, will be created if not supplied
%   axis_font_size: font size, defaults to 8 (modifiable in rs_aux_defaults_define)
%   axis_label_prefix: prefix for axis label, defaults to 'dim' (modifiable in rs_aux_defaults_define)
%   axis_label_font_size: font size, defaults to axis_font_size
%   axis_view: 3-d view of axis, as cell array for each subplot, 2, 3 (default), or azimuth-elevation pair, where [AZ,EL=[-37.5,30] is the default 3-D view.
%   axis_equal: 1 (default) to set axes to have equal scales
%   axis_scale: 'tight' (default), 'auto' (Matlab's automatic scaling), or 'list;
%   axis_scales: a list of [low, high] values, one for each coordinate plotted; cycled through by rows if necessary
%
%   set_select: datasets to show, defaults to [1:length(data_in.da)
%   dim_select: dimension to display, i.e., data_in.ds{set_select}{dim_select}, defaults to 3 unless only two dims are available
%
%   coord_group_size: number of coords to display together, in range [2 3], defaults to min(dim_select,max(number of dimensions available in all sets)
%   coord_group_method: method of selecting coordinates (corresponds to opts_vis.which_dimcombs in psg_visualize)
%      'all': (default) plot all combinations
%      'keeplow': keep all but one dimensions low and only step the highest; [dim_select,coord_group_size]=[5,3] yields [1 2 3],[1 2 4],[1 2 5]
%      'keepone': keep one dimension and step the rest;                      [dim_select,coord_group_size] yields [1 2 3],[1 2 4],[1 2 5],[1 3 4],[1 3 5],[1 4 5]
%      'rolling': rolling contiguous subsets;                                [dim_select,coord_group_size]yields [1 2 3],[2 3 4],[3 4 5],[4 5 1],[5 1 2]
%      'onlylowest': only the lowest dimensions                              [dim_select,coord_group_size] yields [1 2 3]
%      'list': specify a list in opts_disp.coord_groups
%   By default, each dataset is plotted with its own style, with points disconnected.
%      Styles are specified as follows, indexed by the position of the set data_in.  Values are cycled through.
%      set_markers, set_markersizes should be singletons or vectors, set_[colors|markers|linestyles] should be 1-d cell arrays.
%      If set_[colors|markers|linestyles] are not cells, they will be converted to cells.
%
%   set_colors: color assigned to each set, defaults to {'k','b','c','m','r',[0.5 0.5 0],'g'};, can be rgb triplet
%   set_markers marker assigned to each set, defaults to {'.'};
%   set_markersizes: marker assigned to each set, defaults to 8
%   set_linestyles: line styles assigned to each set, defaults to {'none'} (disconnected)
%   set_linewidths: line widths assigned to each set, defaults to 1
%   set_labels: labels for each dataset, defaults to 'set 1', etc.
%
%   connect_method: 'none' (default), or any of the following: which pairs of datasets to connect
%      'all'-> all pairs, 'star' or 'star_first': all connect to 1; 'star_last': all connect to last set;
%      'chain' connects [1 2],[2 3],[3 4],...[nsets-1 nsets]; 'circuit' connects [1 2],[2 3],[3 4],...[nsets 1]
%      'list': pairs listed in connect_sets as a two-column array
%   connect_color_mode: 'first','last','split' (default),'list': how connection line is colored
%      %first uses first set of connection pair, last uses last set of
%      %pair, split uses half of each, list expects a list in connect_colors (cycled through if necessary)
%   connect_linestyles: line styles assigned to each set, defaults to '-'
%   connect_linewidths: line widths assigned to each set, defaults to 1
%
%   if_box: 1 (default) to include a box in a 3d plot
%   if_grid: 1 (default) to include the grid
%
%   if_warn: 1 to display warnings
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
% still to do:
% legend options (font size, where to position, which subplots)
% connections within a set
% labeling of points
% rays, i.e., choice of markers or colors depending on btc_coords, etc
% tetrahedral/bary centric plots
%
if (nargin<=1)
    aux=struct;
end
%fields that will be made into cells if singletons
make_cell={'set_colors','set_markers','set_linestyles','set_labels','axis_view','connect_linestyles','connect_colors'};
coords_together_allowed=[2 3]; %how many coords can be plotted together -eventually could include >=4
coords_together_default=[2 3]; %how many coords are plotted together by default\
xyzlim={'XLim','YLim','ZLim'};
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
%check consistency and get available stimuli, dimensions, typenames
%
aux_out=struct;
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
%set up sub-structure options
aux=filldefault(aux,'opts_disp',struct); %options for this module (psg_template)
aux.opts_disp=filldefault(aux.opts_disp,'if_warn',1);
%
aux.opts_disp=filldefault(aux.opts_disp,'fig_handle',[]);
aux.opts_disp=filldefault(aux.opts_disp,'axis_handles',[]);
aux.opts_disp=filldefault(aux.opts_disp,'axis_view',{3});
aux.opts_disp=filldefault(aux.opts_disp,'axis_equal',1);
aux.opts_disp=filldefault(aux.opts_disp,'axis_scale','tight');
aux.opts_disp=filldefault(aux.opts_disp,'axis_scales',[0 1]);
%
aux.opts_disp=filldefault(aux.opts_disp,'set_select',[1:nsets]);
aux.opts_disp=filldefault(aux.opts_disp,'dim_select',max(intersect(coords_together_default,dim_list_inter)));
%
aux.opts_disp=filldefault(aux.opts_disp,'coord_group_size',min(aux.opts_disp.dim_select,max(coords_together_default)));
aux.opts_disp=filldefault(aux.opts_disp,'coord_group_method','all');
aux.opts_disp=filldefault(aux.opts_disp,'fig_name',sprintf('dimension %2.0f',aux.opts_disp.dim_select));
%
aux.opts_disp=filldefault(aux.opts_disp,'set_colors',{'k','b','c','m','r','y','g'});
aux.opts_disp=filldefault(aux.opts_disp,'set_markers',{'.'});
aux.opts_disp=filldefault(aux.opts_disp,'set_markersizes',8);
aux.opts_disp=filldefault(aux.opts_disp,'set_linestyles',{'none'});
aux.opts_disp=filldefault(aux.opts_disp,'set_linewidths',1);
%
aux.opts_disp=filldefault(aux.opts_disp,'connect_method','none');
aux.opts_disp=filldefault(aux.opts_disp,'connect_sets',[]);
aux.opts_disp=filldefault(aux.opts_disp,'connect_linestyles','-');
aux.opts_disp=filldefault(aux.opts_disp,'connect_linewidths',1);
aux.opts_disp=filldefault(aux.opts_disp,'connect_color_mode','split');
aux.opts_disp=filldefault(aux.opts_disp,'connect_colors',[]);
%
aux.opts_disp=filldefault(aux.opts_disp,'if_box',1);
aux.opts_disp=filldefault(aux.opts_disp,'if_grid',1);
%
aux=rs_aux_customize(aux,'rs_disp_coordsets');
%quantities dependent omn overall defaults
aux.opts_disp=filldefault(aux.opts_disp,'axis_label_font_size',aux.opts_disp.axis_font_size);
%
wmsg_all=[];
%
%set up other defaults and check consistency
%
x=aux.opts_disp; %for convenience
switch x.coord_group_method %dertermine coordinate groups
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
%set up axis scale
switch x.axis_scale %check that it is 'tight','auto', or pairs of values
    case {'tight','auto'}
    case 'list'
        if (~isnumeric(x.axis_scales) | size(x.axis_scales,2)~=2)
            wmsg=sprintf('axis scale list must have two columns; tight scaling used');
            x.axis_scale='tight';
            x.axis_scales=[NaN NaN];
            wmsg_all=strvcat(wmsg_all,wmsg);
        end
    otherwise
        wmsg=sprintf('axis scale specifier (%s) not recognized, tight scaling used',x.axis_scale);
        x.axis_scale='tight';
        x.axis_scales=[NaN NaN];
        wmsg_all=strvcat(wmsg_all,wmsg);
end
%set up connect method
switch x.connect_method
    case 'none'
        x.connect_sets=[];
    case 'all'
        x.connect_sets=nchoosek([1:nsets],2);
    case 'chain'
        x.connect_sets=1+mod([[0:nsets-2];[1:nsets-1]],nsets)';
    case 'circuit'
        x.connect_sets=1+mod([[0:nsets-1];[1:nsets]],nsets)';
    case {'star','star_first'}
        x.connect_sets=[repmat(1,1,nsets-1);[2:nsets]]';
    case {'star_last'}
        x.connect_sets=[repmat(nsets,1,nsets-1);[1:nsets-1]]';
    case 'list'
    otherwise
        wmsg=sprintf('connect method (%s) not recognized, connections ignored',x.connect_method);
        x.connect_sets=[];
        wmsg_all=strvcat(wmsg_all,wmsg);
end
if size(x.connect_sets,1)>0
    if (size(x.connect_sets,2)~=2 | any(x.connect_sets(:))<=0 | any(x.connect_sets(:))>nsets)
        wmsg=sprintf('list of sets to connect exceeds bounds ([0 %1.0f]), or is not two columns, connections ignored',nsets);
        x.connect_sets=[];
        wmsg_all=strvcat(wmsg_all,wmsg);
    end
end
%set up labels
if ~isfield(x,'set_labels')
    x.set_labels=cell(nsets,1);
    for k=1:nsets
        x.set_labels{k}=sprintf('set %1.0f',k);
    end
end
%ensure that certain options are cells
for imc=1:length(make_cell)
    mc=make_cell{imc};
    if ~iscell(x.(mc))
        x.(mc)={x.(mc)};
    end
end
%set up connection colors
x.set_colors=x.set_colors(:);% ensure a column
if size(x.connect_sets,1)>0
    switch x.connect_color_mode
        case 'first'
            x.connect_colors=x.set_colors(x.connect_sets(:,1));
        case 'last'
            x.connect_colors=x.set_colors(x.connect_sets(:,2));
        case 'split'
            x.connect_colors=[x.set_colors(x.connect_sets(:,1)),x.set_colors(x.connect_sets(:,2))];
        case 'list'
        otherwise
            wmsg=sprintf('connect color mode (%s) not recognized, connections ignored',x.connect_method);
            x.connect_sets=[];
            wmsg_all=strvcat(wmsg_all,wmsg);
    end
else
    x.connect_sets=[];
end
%
ngroups=size(x.coord_groups,1);
%
naxis_handles=length(x.axis_handles);
if naxis_handles>0 & naxis_handles~=ngroups
    wmsg=sprintf('number of axes (subplots) supplied (%3.0f) does not match number of groups (%3.0f)',naxis_handles,ngroups);
    wmsg_all=strvcat(wmsg_all,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;
end
%
aux_out.warnings=strvcat(aux_out.warnings,wmsg_all);
if ~isempty(wmsg_all)
    if x.if_warn
        for k=1:size(wmsg_all,1)
            warning(wmsg_all(k,:));
        end
    end
end
%
if aux_out.warn_bad==0
    set_styles=struct;
    set_styles.colors=x.set_colors;
    set_styles.markers=x.set_markers;
    set_styles.markersizes=x.set_markersizes;
    set_styles.linestyles=x.set_linestyles;
    set_styles.linewidths=x.set_linewidths;
    %
    connect_styles=struct;
    connect_styles.colors={'k'};
    connect_styles.markers={'none'};
    connect_styles.markersizes=8;
    connect_styles.linestyles=x.connect_linestyles;
    connect_styles.linewidths=x.connect_linewidths;
    %
    if isempty(x.fig_handle)
        x.fig_handle=figure;
        set(gcf,'Position',x.fig_position);
        set(gcf,'NumberTitle','off');
        set(gcf,'Name',x.fig_name);
    else
        figure(x.fig_handle);
    end
    if naxis_handles==0
        fig_posit=get(gcf,'Position');
        [nrows,ncols]=nicesubp(ngroups,fig_posit(4)/fig_posit(3)); %find an arrangement of rows and columns that fits the aspect ratio
        for igp=1:ngroups
            x.axis_handles{igp}=subplot(nrows,ncols,igp);
        end
    end
    for igp=1:ngroups
 %       haxis=subplot(nrows,ncols,igp);
        haxis=x.axis_handles{igp};
        subplot(haxis);
        set(gca,'FontSize',x.axis_font_size);
        for isetptr=1:length(x.set_select)
            k=x.set_select(isetptr);
            hline=rs_disp_doplot(data_in.ds{k}{x.dim_select}(:,x.coord_groups(igp,:)),k,set_styles);
            set(hline,'Tag',sprintf('ds %2.0f',k));
            set(hline,'DisplayName',x.set_labels{k});
        end
        %set up view, box, grid, axis labels
        if x.coord_group_size<=3
            hl=xlabel(sprintf('%s %1.0f',x.axis_label_prefix,x.coord_groups(igp,1)));
            set(hl,'FontSize',x.axis_label_font_size);
            hl=ylabel(sprintf('%s %1.0f',x.axis_label_prefix,x.coord_groups(igp,2)));
            set(hl,'FontSize',x.axis_label_font_size);
        end
        if (x.coord_group_size==3)
            hl=zlabel(sprintf('%s %1.0f',x.axis_label_prefix,x.coord_groups(igp,3)));
            set(hl,'FontSize',x.axis_label_font_size);
            axis vis3d;
            index_view=1+mod(igp-1,length(x.axis_view));
            view(x.axis_view{index_view});
        end
        %connections between sets
        for ic=1:size(x.connect_sets,1)
            cset=x.connect_sets(ic,:);
            if all(ismember(cset,x.set_select))
                endpoints=cat(3,...
                    data_in.ds{cset(1)}{x.dim_select}(:,x.coord_groups(igp,:)),...
                    data_in.ds{cset(2)}{x.dim_select}(:,x.coord_groups(igp,:)));
                midpoints=mean(endpoints,3);
                if ~strcmp(x.connect_color_mode,'split')
                    connect_styles.colors=x.connect_colors;
                    for istim=1:min(nstims_each)
                        hconnect=rs_disp_doplot([endpoints(istim,:,1);endpoints(istim,:,2)],ic,connect_styles);
                    end
                else
                    for istim=1:min(nstims_each)
                        for iseg=1:2
                            hconnect=rs_disp_doplot([endpoints(istim,:,iseg);midpoints(istim,:)],ic,setfield(connect_styles,'colors',x.connect_colors(:,iseg)));
                        end %each segment
                    end %each stimulus
                end %split or not
            end %both sets are plotted
        end %each connection pair
        if (x.coord_group_size==3)
            if x.if_box
                box on;
            else
                box off;
            end
        end
        if x.if_grid
            grid on;
        else
            grid off;
        end
        if x.axis_equal
            axis equal;
        else
            axis normal;
        end
        switch x.axis_scale
            case 'tight'
                axis tight;
            case 'auto'
                axis auto;
            case 'list'
                for ic=1:x.coord_group_size
                    set(gca,xyzlim{ic},x.axis_scales(1+mod(x.coord_groups(igp,ic)-1,size(x.axis_scales,1)),:));
                end
        end
        %legend
        hc=get(haxis,'Children');
        hc_keeps=psg_legend_keep(hc);
        legend(hc(flipud(hc_keeps.ds)));  %flipud since children appear to be added in reverse order
    end
end
% options from psg_plotcoords 
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
%connections within sets
%legends
%figure label on figure
%
aux_out.opts_disp=x;
return
end

function hline=rs_disp_doplot(coords,index,opts)
%plot the data (rows of coords) into the current plot, using index into
%opts.set* to determine the style, and giving the line a tag
switch size(coords,2)
    case 2
        hline=plot(coords(:,1),coords(:,2),'k.');
    case 3
        hline=plot3(coords(:,1),coords(:,2),coords(:,3),'k.');
end
hold on;
index_color=1+mod(index-1,length(opts.colors));
set(hline,'Color',opts.colors{index_color});
%
index_marker=1+mod(index-1,length(opts.markers));
set(hline,'Marker',opts.markers{index_marker});
%
index_markersize=1+mod(index-1,length(opts.markersizes));
set(hline,'MarkerSize',opts.markersizes(index_markersize));
%
index_linestyle=1+mod(index-1,length(opts.linestyles));
set(hline,'LineStyle',opts.linestyles{index_linestyle});
%
index_linewidth=1+mod(index-1,length(opts.linewidths));
set(hline,'LineWidth',opts.linewidths(index_linewidth));
%
return
end
