function aux_out=rs_disp_coordsets(data_in,aux)
% aux_out=rs_disp_coordsets(data_in,aux)  displays one or more views of the coordinaates in a `dataset structure`
%
% Multiple views can be plotted in subplots of the same figure. This is particularly helpful if the dimensionality
% of the coordinates is high:  each subplot could show a different combination of two or three coordinates.
% Subplots are left in the 'hold on' state.
%
% Args:
%   data_in (struct): `dataset structure` to be processed, with fields
%
%     - ds (cell array): `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas (cell array): `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets (cell array): `set metadata structure`, sets{k} is the response metadata for the kth record
%
%   aux (struct): auxiliary inputs, may be omitted, with fields
%
%     - opts_disp (struct): options for display, with fields
%
%         - **Data selection**
%         - set_select (int 1-D array): list of records to show; defaults is [1:length(data_in.ds)]
%         - dim_select (int): dimension to show; i.e., dim_select=k results in display of the coordinates in data_in.ds{set_select}{k}; default is 3 unless only two dimensions are available; must be at least 2
%         - coord_group_size (int): number of coordinates to display together, in range [2 3]; default is min(dim_select,number of dimensions available)
%         - coord_group_method (char): method of selecting coordinates
%
%             - 'all': (default) plot all combinations
%             - 'keeplow': keep all but one dimensions low and only step the highest; [dim_select,coord_group_size]=[5,3] yields [1 2 3],[1 2 4],[1 2 5]
%             - 'keepone': keep one dimension and step the rest;                      [dim_select,coord_group_size]=[5,3] yields [1 2 3],[1 2 4],[1 2 5],[1 3 4],[1 3 5],[1 4 5]
%             - 'rolling': rolling contiguous subsets;                                [dim_select,coord_group_size]=[5,3] yields [1 2 3],[2 3 4],[3 4 5],[4 5 1],[5 1 2]
%             - 'onlylowest': only the lowest dimensions;                             [dim_select,coord_group_size]=[5,3] yields [1 2 3]
%             - 'list': specify a list in opts_disp.coord_groups, as an
%             array with coord_group_size columns, e.g., opts_disp.coord_groups=[1 2 3;1 4 5;1 6 7] creates three subplots, with coordinates {1,2,3} in the
%             first, {1,4,5} in the second, {1,6,7} in the third
%
%         - coord_groups (int 2-D array): groups of coordinates to show together if coord_group_method='list', as rows of an integer array; each row will generate one subplot
%         - data_show_method (char): which data points to show, options are 'all', 'none', 'first', 'last', 'list'; default is 'all'
%         - data_show_list (int 1-D array): list of data points to show, if data_show_method='list';  points plotted are data_in.ds{set_select}{k}(data_show_list,:);
%
%         - **Figure and subplot control**
%         - fig_handle (handle): handle to figure; will be created if empty or not provided
%         - fig_position (int 1-D array): position parameters [left bottom width height] for figure to be created; see note below regarding customization
%         - fig_name (char): title for figure; default is list of dimensions shown
%         - axis_handles (cell array of handles): handle to axes, one for each subplot, will be created empty or not provided
%
%         - **Formatting: axis and views**
%         - axis_font_size (int): font size for axis; default is 8; see note below re customization
%         - axis_label_font_size (char): font size for axis labels; default is axis_font_size
%         - axis_label_prefix (char): prefix for axis label, default is 'dim'; see note below regarding customization
%         - axis_labels (cell array of char): cell array of strings, cycled through if necessary, with text for axis labels.  If empty, then axis labels are genrated from axis_label_prefix
%         - axis_view (int or float 1-D array or cell array): 3-D view descriptor, default is 3 (standard 3-d view), 2 is 2-d view; can also be azimuth-elevation pair; standard
%         3-d view is [-37.5 30]; can be also be cell array of view specifiers, is cycled through for each subplot
%         - axis_equal (int): 1 to set axes to have equal scales, 0 autoscales; default is 1
%         - axis_range (char): 'tight' to set axis range to limits of data, 'auto' for autoscaling, or 'list' to specify by axis_range_list; default is 'tight'
%         - axis_range_list (float 2-D array): axis range specification, as rows of [low, high] values, one for each coordinate plotted; cycled through by rows if necessary
%
%         - **Formatting: plot style**
%         - set_colors (color specifier or cell array of color specifiers): color assigned to each record; default is {'k','b','c','m','r',[0.5 0.5 0],'g'}; elements can be any valid color specifier; see note regarding plot formatting
%         - set_markers (char or cell array of char): marker for each record; defaults is {'.'}; see note regarding plot formatting
%         - set_markersizes (int 1-D array): marker size for each record; default is 8; see note regarding plot formatting
%         - set_filled (int 1-D array): 1 for records in which markers are filled, 0 for unfilled if possible; default is 0; note that only some marker, e.g., o,s,h,p can be unfilled
%         - set_colors_filled (color specifer or cell array of color specifiers): color for inside of filled symbols for each record, ignored if set_filled=0; default is set_colors
%         - set_alphas (float 1-D array): alpha blending for each record, default is 1 (opaque); note that alpha-blending (transparency) may not be availble on all systems
%
%         - **Formatting: positioning** 
%         - set_offsets (float 2-D array or char): this allows the data in each record to be offset by different amounts, so they don't overlap; default is no offset; specified by 0
%
%              - if an array, each row, of length dim_select (which wll be truncated or padded as needed) specifies the offset for the corresponding record in `data_in`
%              - 'margin_amount' puts a margin of set_offsets_margin_amount between each dataset and the next
%              - 'margin_fraction' puts a fractional margin of set_offsets_margin_fraction * average span of adjacent sets
%
%         - set_offsets_margin_amount (float): absolute margin between datasets if set_offsets='margin_amount; defaults to ones(1,dim_select); can be 0 or negative, truncated or padded to dim_select
%         - set_offsets_margin_fraction (float): fractional margin between datasets if set_offsets='margin_fraction; defaults to zeros(1,dim_select); can be 0 or negative, truncated or padded to dim_select
%         - set_offsets_coordchoices (int or char or cell array of char): if set_offsets='margin_amount' or 'margin_fraction', this specifies which coordinate is offset; can be 'first','last','all', or a subset of [1:dim_select]; can also be a cell array of subsets
%
%         - **Labels**
%         - set_labels (char or cell array of char): labels for each record that will appear in legend; defaults is 'set 1', etc.; see note regarding plot formatting
%         - data_label_setsel_method (char): selects which records to label individual points, options are 'all','none', 'first' , 'last', or 'list'; default is 'first'; note that 'all','first', and 'last' apply to the records shown
%         - data_label_setsel_list (int 1-D array): list of datasets to label, if data_label_setsel_method='list'
%         - data_label_method (char): selects which data points to label, options are 'all', 'none', 'first', 'last', 'list'; default is 'all'; labels are taken from data_in.sas{k}.typenames; note that 'all','first',and 'last' refer to data points shown
%         - data_label_list (int 1-D array): list of data points to label, if data_label_method='list'
%         - data_label_font_size (int): font size for data labels, default is axis_font_size
%         - data_label_interpreter (char): interpreter for labeling data, [] (default) uses system default, alternatively 'none','tex','latex'
%         - callout_amount (float): moves the position of a label away from the data point, specified in units of rms deviation of data from centroid; default is 0
%         - callout_colors (cell array of color specifiers): color for callout lines connecting labels and points; default is {'k'}; can also be 'set_colors' to match set_colors
%         - callout_linestyles (cell array of char): line styles for above callout lines; default is {'-.'}
%         - callout_linewidths (int 1-D array): line widths for above callout lines; default is 1
%
%   connect_data_method: which pairs of data points to connect within a set, 'none' (default), or any of the following:
%      'all'-> all pairs, 'star' or 'star_first': all connect to first; 'star_last': all connect to last set;
%      'chain' connects [first next ],[next second-next],,...[next-to-last last]; 'circuit' closes 'chain' to include [last first]
%      'list': pairs listed in connect_sets_list as a two-column array [first and last refer to the sets selected in set_select]
%   connect_data_list: two-column array of data points to connect (if data_connect_method='list')
%   connect_data_linestyles: line styles assigned to connections within each set, defaults to {'none'} (disconnected)
%   connect_data_linewidths: line widths assigned to connections within each set, defaults to 1
%
%   connect_sets_method: which sets to connect: 'none' (default), or any of the options in connect_data_method
%   connect_sets_list: two-column array of sets to connect, if connect_sets_method='list'
%   connect_sets_data_method: which data points to connect between sets, 'all' (default), or any of the options in data_label_method
%        or 'labeled': connects all data points that designated by data_label_method and data_label_list
%   connect_sets_data_list: list of data points to connect wbetween sets, if connect_sets_data_method='list'
%   connect_sets_color_mode: 'first','last','split' (default),'list': how connection line is colored
%      %first uses first set of connection pair, last uses last set of
%      %pair, split uses half of each, list expects a list in connect_sets_colors (cycled through if necessary)
%   connect_sets_linestyles: line styles assigned to each set, defaults to '-'
%   connect_sets_linewidths: line widths assigned to each set, defaults to 1
%
%   if_box: 1 (default) to include a box in a 3d plot
%   if_grid: 1 (default) to include the grid
%   if_legend: 1 (default) to include legend, 0 to omit, -1 to omit from all subplots but to add an extra
%     subplot mathcing the first, with a legend
%   legend_font_size: defaults to axis_font_size
%   legend_location: defaults to 'Best'
%   legend_interpreter: interpreter for set label in legend, empty (default) is system default, alternatively 'none','tex','latex'
%   legend_tags: cell array or single string that must be present for at start of a tag for inclusion in a legend, defaults to 'set',  text string or cell array of strings
%         - set_tags (char or cell array of char): the 'tags' field applied to the plot of each record, can be used for selecting items to appear in legend, defaults to 'set 1', etc.,
%
%   if_warn: 1 to display warnings related to plot configurations
%   if_finalize: 1 (default) to finalize axis, view, legend
%
%     - opts_check (struct): options for consistency checking, with field
%
%         - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
% 
% Returns:
%   aux_out: auxiliary outputs and parameter values used
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_disp (struct): aux.opts_disp, with defaults and overrides filled in, including fig_handle (handle to the figure) and axis_handles (handles to the subplot axes)
%
% Note regarding customization:
%     - The default figure position can be changed by editing the line containing generic.opts_disp.fig_position in `rs_aux_defaults_define`, running it once, and saving the workspace as rs_aux_defaults.mat.
%     - The default font size for axis labels can be changed by editing the line containing generic.opts_disp.axis_font_size in `rs_aux_defaults_define`, running it  once, and saving the workspace as rs_aux_defaults.mat.
%     - The default prefix for the axis label can be changed by editing the line containing generic.opts_disp.axis_label_prefix in `rs_aux_defaults_define`, running it  once, and saving the workspace as rs_aux_defaults.mat.
%
% Note regarding plot formatting:
%     - By default, each record is plotted with a different color, a solid dot marker, and no connecting lines. 
%     - These choices can be changed by 'set_colors', 'set_markers',  'set_markersizes', 'set_filled', 'set_colors_filled', 'set_alphas' (but alpha blending may not be availble on all systems).
%     - The above specifiers can be singletons or cell arrays, and are indexed by the record position in data_in.  If there are more records than specifiers, the specifiers are cycled.
%     - The data points of each record are, by default, not connected to each other. This can be changed with the 'connect_sets*' options.
%
%  See also: RS_CHECK_COORDSETS, RS_GET_COORDSETS, RS_ALIGN_COORDSETS, RS_KNIT_COORDSETS, RS_PLOT_STYLE.
%
if (nargin<=1)
    aux=struct;
end
%fields that will be made into cells if singletons
make_cell={'set_colors','set_colors_filled','set_markers','connect_data_linestyles','set_labels','set_tags','legend_tags','axis_view','connect_sets_linestyles','connect_sets_colors',...
    'callout_colors','callout_linestyles','axis_labels'};
trunc_pad={'set_offsets','set_offsets_margin_amount','set_offsets_margin_fraction'}; %fields that are truncated or padded to have dim 2 length = dim_select
coords_together_allowed=[2 3]; %how many coords can be plotted together -eventually could include >=4
coords_together_default=[2 3]; %how many coords are plotted together by default
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
nstims=min(nstims_each); %all nstims_each should be identical
%
%set up sub-structure options
aux=filldefault(aux,'opts_disp',struct); %options for this module (psg_template)
aux.opts_disp=filldefault(aux.opts_disp,'if_warn',1);
aux.opts_disp=filldefault(aux.opts_disp,'if_finalize',1);
%
aux.opts_disp=filldefault(aux.opts_disp,'fig_handle',[]);
aux.opts_disp=filldefault(aux.opts_disp,'axis_handles',[]);
aux.opts_disp=filldefault(aux.opts_disp,'axis_view',{3});
aux.opts_disp=filldefault(aux.opts_disp,'axis_equal',1);
aux.opts_disp=filldefault(aux.opts_disp,'axis_range','tight');
aux.opts_disp=filldefault(aux.opts_disp,'axis_range_list',[0 1]);
aux.opts_disp=filldefault(aux.opts_disp,'axis_labels',cell(0));
%
aux.opts_disp=filldefault(aux.opts_disp,'dim_select',max(intersect(coords_together_default,dim_list_inter)));
aux.opts_disp=filldefault(aux.opts_disp,'set_select',[1:nsets]);
aux.opts_disp=filldefault(aux.opts_disp,'set_offsets',zeros(1,aux.opts_disp.dim_select));
aux.opts_disp=filldefault(aux.opts_disp,'set_offsets_margin_amount',ones(1,aux.opts_disp.dim_select));
aux.opts_disp=filldefault(aux.opts_disp,'set_offsets_margin_fraction',zeros(1,aux.opts_disp.dim_select));
aux.opts_disp=filldefault(aux.opts_disp,'set_offsets_coordchoices','all');
%
aux.opts_disp=filldefault(aux.opts_disp,'coord_group_size',min(aux.opts_disp.dim_select,max(coords_together_default)));
aux.opts_disp=filldefault(aux.opts_disp,'coord_group_method','all');
aux.opts_disp=filldefault(aux.opts_disp,'fig_name',sprintf('dimension %2.0f',aux.opts_disp.dim_select));
%
aux.opts_disp=filldefault(aux.opts_disp,'set_colors',{'k','b','c','m','r','y','g'});
aux.opts_disp=filldefault(aux.opts_disp,'set_markers',{'.'});
aux.opts_disp=filldefault(aux.opts_disp,'set_markersizes',8);
aux.opts_disp=filldefault(aux.opts_disp,'set_filled',0);
aux.opts_disp=filldefault(aux.opts_disp,'set_colors_filled',aux.opts_disp.set_colors);
aux.opts_disp=filldefault(aux.opts_disp,'set_alphas',1);
%
aux.opts_disp=filldefault(aux.opts_disp,'data_show_method','all');
aux.opts_disp=filldefault(aux.opts_disp,'data_show_list',[]);
aux.opts_disp=filldefault(aux.opts_disp,'data_label_method','all');
aux.opts_disp=filldefault(aux.opts_disp,'data_label_list',[]);
aux.opts_disp=filldefault(aux.opts_disp,'data_label_setsel_method','first');
aux.opts_disp=filldefault(aux.opts_disp,'data_label_setsel_list',[]);
aux.opts_disp=filldefault(aux.opts_disp,'data_label_interpreter',[]);
%
aux.opts_disp=filldefault(aux.opts_disp,'callout_amount',0);
aux.opts_disp=filldefault(aux.opts_disp,'callout_colors',{'k'});
aux.opts_disp=filldefault(aux.opts_disp,'callout_linestyles',{'-.'});
aux.opts_disp=filldefault(aux.opts_disp,'callout_linewidths',1);
%
aux.opts_disp=filldefault(aux.opts_disp,'connect_data_method','none');
aux.opts_disp=filldefault(aux.opts_disp,'connect_data_list',[]);
aux.opts_disp=filldefault(aux.opts_disp,'connect_data_linestyles',{'none'});
aux.opts_disp=filldefault(aux.opts_disp,'connect_data_linewidths',1);
%
aux.opts_disp=filldefault(aux.opts_disp,'connect_sets_method','none');
aux.opts_disp=filldefault(aux.opts_disp,'connect_sets_list',[]);
aux.opts_disp=filldefault(aux.opts_disp,'connect_sets_data_method','all');
aux.opts_disp=filldefault(aux.opts_disp,'connect_sets_data_list',[]);
aux.opts_disp=filldefault(aux.opts_disp,'connect_sets_linestyles','-');
aux.opts_disp=filldefault(aux.opts_disp,'connect_sets_linewidths',1);
aux.opts_disp=filldefault(aux.opts_disp,'connect_sets_color_mode','split');
aux.opts_disp=filldefault(aux.opts_disp,'connect_sets_colors',[]);
%
aux.opts_disp=filldefault(aux.opts_disp,'if_box',1);
aux.opts_disp=filldefault(aux.opts_disp,'if_grid',1);
aux.opts_disp=filldefault(aux.opts_disp,'if_legend',1);
aux.opts_disp=filldefault(aux.opts_disp,'legend_location','Best');
aux.opts_disp=filldefault(aux.opts_disp,'legend_interpreter',[]);
aux.opts_disp=filldefault(aux.opts_disp,'legend_tags',{'set'});
%
aux=rs_aux_customize(aux,'rs_disp_coordsets');
%quantities dependent on overall defaults
aux.opts_disp=filldefault(aux.opts_disp,'axis_label_font_size',aux.opts_disp.axis_font_size);
aux.opts_disp=filldefault(aux.opts_disp,'legend_font_size',aux.opts_disp.axis_font_size);
aux.opts_disp=filldefault(aux.opts_disp,'data_label_font_size',aux.opts_disp.axis_font_size);
%
%set up other defaults and check consistency
%
disp_msgs=[]; %for warnings encountered during plots
x=aux.opts_disp; %for convenience
switch x.coord_group_method %determine coordinate groups
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
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
end
if x.coord_group_size~=size(x.coord_groups,2)
    wmsg=sprintf('number of columnns in coord_groups (%3.0f) and coord_group_size (%3.0f) is inconsistent',size(x.coord_groups,2),x.coord_group_size);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',x.if_warn));
end
if ~ismember(x.coord_group_size,coords_together_allowed)
    wmsg=sprintf('cannot plot groups of %3.0f coordinates on same axis',x.coord_group_size);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',x.if_warn));
end
if any(x.coord_groups(:)<=0) | any(x.coord_groups(:)>x.dim_select)
    wmsg=sprintf('some specified dimensions are out of bounds for the dimension plotted (%2.0f)',x.dim_select);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',x.if_warn));
end
if ~isempty(setdiff(x.set_select,[1:nsets]))
    wmsg=sprintf('some selections in set_select are out of bounds ([1:%1.0f], and ignored )',nsets);
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
    x.set_select=intersect(x.set_select,[1:nsets]);
end
ngroups=size(x.coord_groups,1);
ngroups_aug=ngroups;
if x.if_legend==-1
    ngroups_aug=ngroups+1;
end
%parse set_offsets
for ifn=1:length(trunc_pad) %trunc_pad={'set_offsets','set_offsets_margin_amount','set_offsets_margin_fraction'}; %fields that are truncated or padded to have dim 2 length = dim_select
    tp=trunc_pad{ifn};
    if isnumeric(x.(tp))
        needcols=[1 x.dim_select];
        needcols_msg=sprintf('1 to %1.0f',x.dim_select);
        %
        if_okcols=double((size(x.(tp),2)>=min(needcols)) & (size(x.(tp),2)<=max(needcols)));
        if if_okcols==0
            wmsg=sprintf('number of columns in %s (%1.0f) is inconsistent with number needed (%s); truncated or padded',tp,size(x.(tp),2),needcols_msg);
            aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
        end
        if size(x.(tp),2)>x.dim_select
            x.(tp)=x.(tp)(:,[1:x.dim_select]);
        end
        if size(x.(tp),2)<x.dim_select
            x.(tp)=cat(2,x.(tp),zeros(size(x.(tp),1),x.dim_select-size(x.(tp),2)));
        end
    end
end
if ~isnumeric(x.set_offsets)    
    %compute min and max of each coord in each set
    mins=zeros(nsets,x.dim_select);
    maxs=zeros(nsets,x.dim_select);
    for iset=1:nsets
        mins(iset,:)=min(data_in.ds{iset}{x.dim_select},[],1);
        maxs(iset,:)=max(data_in.ds{iset}{x.dim_select},[],1);
    end
    switch x.set_offsets
        case 'margin_amount' %space by an absolute amount
            upper=-Inf;
            x.set_offsets=zeros(nsets,x.dim_select);
            for iset=1:nsets
                if ismember(iset,x.set_select)
                    if (upper>-Inf) %have we encountered any sets
                        x.set_offsets(iset,:)=x.set_offsets_margin_amount+upper-mins(iset,:);
                        upper=x.set_offsets(iset,:)+maxs(iset,:);
                    else
                        upper=maxs(iset,:);
                    end
                end
            end
        case 'margin_fraction' %space by a fraction of the average size of the spans
            upper=-Inf;
            x.set_offsets=zeros(nsets,x.dim_select);
            for iset=1:nsets
                if ismember(iset,x.set_select)
                    if (upper>-Inf) %have we encountered any sets
                        meansize=(maxs(iset_prev,:)-mins(iset_prev,:)+maxs(iset,:)-mins(iset,:))/2; %mean span of current and previous set
                        x.set_offsets(iset,:)=x.set_offsets_margin_fraction.*meansize+upper-mins(iset,:);
                        upper=x.set_offsets(iset,:)+maxs(iset,:);
                        iset_prev=iset;
                    else
                        upper=maxs(iset,:);
                        iset_prev=iset;
                    end
                end
            end
      otherwise
            wmsg=sprintf('specification of offset (%s) not recognized; no offset used',x.set_offsets);
            aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
            x.set_offsets=zeros(1,x.dim_select);
    end
    x.set_offsets=x.set_offsets-repmat(mean(x.set_offsets(x.set_select,:),1),nsets,1); %center around zero
    %now process set_offsets_coordchoices:  which coordinates are offset in each coordinate group
    if ~ischar(x.set_offsets_coordchoices) %only force numeric arrays into cells
        if ~iscell(x.set_offsets_coordchoices)
            x.set_offsets_coordchoices={x.set_offsets_coordchoices};
        end
        off_choices=x.set_offsets_coordchoices;
    else %string values cannot be cells
        if iscell(x.set_offsets_coordchoices)
            x.set_offsets_coordchoices=x.set_offsets_coordchoices{1};
        end
        switch x.set_offsets_coordchoices
            case 'all'
                off_choices=num2cell(x.coord_groups,2);
            case 'first'
                off_choices=(num2cell(x.coord_groups(:,1)))';
            case 'last'
                off_choices=(num2cell(x.coord_groups(:,end)))';
            otherwise
                wmsg=sprintf('specification of offset coordinate choices (%s) not recognized; all coordinates offset',x.set_offsets_coordchoices);
                aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
                off_choices{1}=[1:x.dim_select];
        end
    end
    %convert off_choices to [0,1] selection
    x.offsets_select=zeros(ngroups,x.dim_select); %will have 1's to select coordinates with offsets
    for kptr=1:ngroups
        k=1+mod(kptr-1,length(off_choices));
        if (any(off_choices{k}<1) | any(off_choices{k}>x.dim_select) | any(off_choices{k}~=round(off_choices{k}))) 
            wmsg=sprintf(' specification of offset coordinate choices non-integer or out of range ([1 %1.0f], all coordinates offset',x.dim_select);
            aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
            off_choices{k}=[1:x.dim_select];
        end
        x.offsets_select(kptr,intersect(off_choices{k},x.coord_groups(kptr,:)))=1;
    end
else
    x.offsets_select=ones(ngroups,x.dim_select);
end
%
%set up axis scale
switch x.axis_range %check that it is 'tight','auto', or pairs of values
    case {'tight','auto'}
    case 'list'
        if (~isnumeric(x.axis_range_list) | size(x.axis_range_list,2)~=2)
            wmsg=sprintf('axis scale list must have two columns; tight scaling used');
            aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
            x.axis_range='tight';
            x.axis_range_list=[NaN NaN];
        end
    otherwise
        wmsg=sprintf('axis scale specifier (%s) not recognized, tight scaling used',x.axis_range);
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
        x.axis_range='tight';
        x.axis_range_list=[NaN NaN];
end
%set up data show and label params
[x.data_show_list,wmsg]=rs_disp_parse_listmethod(x.data_show_method,[1:nstims],x.data_show_list,'specification of data points to show');
if ~isempty(wmsg)
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
end
[x.data_label_list,wmsg]=rs_disp_parse_listmethod(x.data_label_method,[x.data_show_list],x.data_label_list,'specification of data points to label');
if ~isempty(wmsg)
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
end
[x.data_label_setsel_list,wmsg]=rs_disp_parse_listmethod(x.data_label_setsel_method,x.set_select,x.data_label_setsel_list,'specification of sets to label');
if ~isempty(wmsg)
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
end
%set up params for connecting points within sets
[x.connect_data_list,wmsg]=rs_disp_parse_pairmethod(x.connect_data_method,x.data_show_list,x.connect_data_list,'specification of data points to connect within a set');
if ~isempty(wmsg)
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
end
if ~isempty(x.connect_data_list) %convert a set of pairs to a set of chains to simplify plotting
    x.connect_data_chains=pairs2chains(x.connect_data_list);
else
    x.connect_data_chains=[];
end
%set up params for connecting points across sets
[x.connect_sets_list,wmsg]=rs_disp_parse_pairmethod(x.connect_sets_method,x.set_select,x.connect_sets_list,'specification of sets to connect');
if ~isempty(wmsg)
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
end
if strcmp(x.connect_sets_data_method,'labeled')
    x.connect_sets_data_method=x.data_label_method;
    x.connect_sets_data_list=x.data_label_list;
end
[x.connect_sets_data_list,wmsg]=rs_disp_parse_listmethod(x.connect_sets_data_method,[x.data_show_list],x.connect_sets_data_list,'specification of data points to connect between sets');
if ~isempty(wmsg)
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
end
%set up connection colors
x.set_colors=x.set_colors(:);% ensure a column
x.set_colors_filled=x.set_colors_filled(:);
if size(x.connect_sets_list,1)>0
    connect_sets_list_mod=mod(x.connect_sets_list-1,length(x.set_colors))+1;
    switch x.connect_sets_color_mode
        %connect_sets_list_mod=mod(x.connect_sets_list-1,length(x.set_colors))+1;
        case 'first'
            x.connect_sets_colors=x.set_colors(connect_sets_list_mod(:,1));
        case 'last'
            x.connect_sets_colors=x.set_colors(connect_sets_list_mod(:,2));
        case 'split'
            x.connect_sets_colors=[x.set_colors(connect_sets_list_mod(:,1)),x.set_colors(connect_sets_list_mod(:,2))];
        case 'list'
        otherwise
            wmsg=sprintf('connect color mode (%s) not recognized, connections ignored',x.connect_sets_method);
            x.connect_sets_list=[];
            aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',x.if_warn));
    end
else
    x.connect_sets_list=[];
end
%set up labels
if ~isfield(x,'set_labels')
    x.set_labels=cell(nsets,1);
    for k=1:nsets
        x.set_labels{k}=sprintf('set %1.0f',k);
    end
end
if ~isfield(x,'set_tags')
    x.set_tags=cell(nsets,1);
    for k=1:nsets
        x.set_tags{k}=sprintf('set %1.0f',k);
    end
end
%ensure that certain options are cells
for imc=1:length(make_cell)
    mc=make_cell{imc};
    if ~iscell(x.(mc))
        x.(mc)={x.(mc)};
    end
end
%use set colors for callout colors if requested
if strmatch(x.callout_colors{1},'set_colors')
    x.callout_colors=x.set_colors;
end
%
naxis_handles=length(x.axis_handles);
if naxis_handles>0 & naxis_handles~=ngroups_aug
    wmsg=sprintf('number of axes (subplots) supplied (%3.0f) does not match number of axes needed (%3.0f)',naxis_handles,ngroups_aug);
    aux_out=rs_warning(wmsg,double(naxis_handles<ngroups_aug),setfield(aux_out,'if_warn',x.if_warn));
end
%
if aux_out.warn_bad==0
    %set up styles for each component:  dataset, connections between data in a set, callouts, connectoins between sets
    set_styles=struct;
    set_styles.colors=x.set_colors;
    set_styles.markers=x.set_markers;
    set_styles.markersizes=x.set_markersizes;
    set_styles.linestyles={'none'};
    set_styles.linewidths=1;
    set_styles.colors_filled=x.set_colors_filled;
    set_styles.filled=x.set_filled;
    set_styles.alphas=x.set_alphas;
    %
    connect_data_styles=struct;
    connect_data_styles.colors=x.set_colors;
    connect_data_styles.markers={'none'};
    connect_data_styles.markersizes=8;
    connect_data_styles.linestyles=x.connect_data_linestyles;
    connect_data_styles.linewidths=x.connect_data_linewidths;
    %
    callout_styles=struct;
    callout_styles.colors=x.callout_colors;
    callout_styles.markers={'none'};
    callout_styles.markersizes=8;
    callout_styles.linestyles=x.callout_linestyles;
    callout_styles.linewidths=x.callout_linewidths;
    %
    connect_set_styles=struct;
    connect_set_styles.colors={'k'};
    connect_set_styles.markers={'none'};
    connect_set_styles.markersizes=8;
    connect_set_styles.linestyles=x.connect_sets_linestyles;
    connect_set_styles.linewidths=x.connect_sets_linewidths;
    %
    if isempty(x.fig_handle)
        x.fig_handle=figure;
    else
        if x.fig_handle~=gcf
            figure(x.fig_handle);
        end
    end
    set(gcf,'Position',x.fig_position);
    set(gcf,'NumberTitle','off');
    set(gcf,'Name',x.fig_name);
    if naxis_handles==0
        fig_posit=get(gcf,'Position');
        [nrows,ncols]=nicesubp(ngroups_aug,fig_posit(4)/fig_posit(3)); %find an arrangement of rows and columns that fits the aspect ratio
        for igp=1:ngroups_aug
            x.axis_handles{igp}=subplot(nrows,ncols,igp);
        end
    end
    for igp_aug=1:ngroups_aug
        haxis=x.axis_handles{igp_aug};
        igp=mod(igp_aug-1,ngroups)+1; %if igp_aug=ngroup+1 (if_legend=-1) then igp=1 but it is plotted in a new subplot
        subplot(haxis);
        set(gca,'FontSize',x.axis_font_size);
        cg=x.coord_groups(igp,:);
        %plot points
        for isetptr=1:length(x.set_select)
            k=x.set_select(isetptr);
            %plot with no line, later connect
            z_all=data_in.ds{k}{x.dim_select}(:,cg); %all the points in the dataset
            ko=mod(k-1,size(x.set_offsets,1))+1;
            z_all=z_all+repmat(x.set_offsets(ko,cg).*x.offsets_select(igp,cg),size(z_all,1),1); %add the offset
            z=z_all(x.data_show_list,:); %points to plot
            [hline,plotstyle_used,opts_plotstyle_used]=rs_disp_doplot(z,k,set_styles);
            disp_msgs=strvcat(disp_msgs,opts_plotstyle_used.msgs);
            set(hline,'Tag',x.set_tags{1+mod(k-1,length(x.set_tags))});
            set(hline,'DisplayName',x.set_labels{1+mod(k-1,length(x.set_labels))});
            %connect requested points
            if ~isempty(x.connect_data_chains)
                for ichain=1:length(x.connect_data_chains)
                    [hline,plotstyle_used,opts_plotstyle_used]=rs_disp_doplot(z_all(x.connect_data_chains{ichain},:),k,connect_data_styles);
                    disp_msgs=strvcat(disp_msgs,opts_plotstyle_used.msgs);
                    set(hline,'Tag',sprintf('ds %2.0f chain %2.0f',k,ichain));
                    set(hline,'DisplayName',x.set_labels{1+mod(k-1,length(x.set_labels))});
                end
            end
            %label?
            if ismember(k,x.data_label_setsel_list)
                zcallout=z; 
                if x.callout_amount>0 %compute position of call-out for every data point shown
                    centroid=mean(z_all,1);
                    dists=sqrt(sum((z_all-repmat(centroid,size(z_all,1),1)).^2,2)); %distances from centroid
                    rmsdist=sqrt(mean(dists.^2)); %rms distances from centroid
                    dists(dists==0)=1;
                    for lab=1:size(x.data_show_list,1)
                        zcallout(lab,:)=centroid+(zcallout(lab,:)-centroid)*(1+x.callout_amount*rmsdist/dists(x.data_show_list(lab)));
                    end
                else
                    zcallout=z;
                end
                typenames=data_in.sas{k}.typenames;
                for ipt_ptr=1:length(x.data_label_list)
                    ipt=x.data_label_list(ipt_ptr);
                    ipt_rel=find(x.data_show_list==ipt); %which of the selected points is being labelled
                    switch x.coord_group_size
                        case 2
                            ht=text(zcallout(ipt_rel,1),zcallout(ipt_rel,2),typenames{ipt});
                        case 3
                            ht=text(zcallout(ipt_rel,1),zcallout(ipt_rel,2),zcallout(ipt_rel,3),typenames{ipt});
                    end %coord group size
                    set(ht,'FontSize',x.data_label_font_size);
                    if ~isempty(x.data_label_interpreter)
                        set(ht,'Interpreter',x.data_label_interpreter);
                    end
                    if x.callout_amount>0
                        [hcallout,plotstyle_used,opts_plotstyle_used]=rs_disp_doplot(cat(1,z(ipt_rel,:),zcallout(ipt_rel,:)),k,callout_styles);
                        disp_msgs=strvcat(disp_msgs,opts_plotstyle_used.msgs);
                    end
                end %ipt
            end %set to label?
        end %isetptr
        %set up view and axis labels
        n_axis_labels=length(x.axis_labels);
        ax_labels=cell(1,x.coord_group_size);
        for ix=1:x.coord_group_size
            if isempty(x.axis_labels) | n_axis_labels==0;
                ax_labels{ix}=sprintf('%s %1.0f',x.axis_label_prefix,cg(ix));
            else
                ax_labels{ix}=x.axis_labels{1+mod(ix-1,n_axis_labels)};
            end
        end
        if x.if_finalize
            if x.coord_group_size<=3
                hl=xlabel(ax_labels{1});
                set(hl,'FontSize',x.axis_label_font_size);
                hl=ylabel(ax_labels{2});
                set(hl,'FontSize',x.axis_label_font_size);
            end
            if (x.coord_group_size==3)
                hl=zlabel(ax_labels{3});
                set(hl,'FontSize',x.axis_label_font_size);
                axis vis3d;
                index_view=1+mod(igp-1,length(x.axis_view));
                view(x.axis_view{index_view});
            end
        end
        %connections between sets
        for ic=1:size(x.connect_sets_list,1)
            cset=x.connect_sets_list(ic,:);
            if all(ismember(cset,x.set_select))
                data_connect_list=intersect(x.data_show_list,x.connect_sets_data_list); %find the points that are shown and also those selected for inter-set connection
                endpoints=zeros(length(data_connect_list),x.coord_group_size,2);
                for iz=1:2
                    endpoints(:,:,iz)=data_in.ds{cset(iz)}{x.dim_select}(data_connect_list,cg);
                    ko=mod(cset(iz)-1,size(x.set_offsets,1))+1;
                    endpoints(:,:,iz)=endpoints(:,:,iz)+repmat(x.set_offsets(ko,cg).*x.offsets_select(igp,cg),size(endpoints,1),1,1); %add the offset
                end
                midpoints=mean(endpoints,3);
                if ~strcmp(x.connect_sets_color_mode,'split')
                    connect_set_styles.colors=x.connect_sets_colors;
                    for istim=1:length(data_connect_list)
                        [hconnect,plotstyle_used,opts_plotstyle_used]=rs_disp_doplot([endpoints(istim,:,1);endpoints(istim,:,2)],ic,connect_set_styles);
                        disp_msgs=strvcat(disp_msgs,opts_plotstyle_used.msgs);
                    end
                else
                    for istim=1:length(data_connect_list)
                        for iseg=1:2
                            [hconnect,plotstyle_used,opts_plotstyle_used]=rs_disp_doplot([endpoints(istim,:,iseg);midpoints(istim,:)],ic,setfield(connect_set_styles,'colors',x.connect_sets_colors(:,iseg)));
                            disp_msgs=strvcat(disp_msgs,opts_plotstyle_used.msgs);
                        end %each segment
                    end %each stimulus
                end %split or not
            end %both sets are plotted
        end %each connection pair
        %box, view, axis scaling, legend
        if  x.if_finalize
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
            switch x.axis_range
                case 'tight'
                    axis tight;
                case 'auto'
                    axis auto;
                case 'list'
                    for ic=1:x.coord_group_size
                        set(gca,xyzlim{ic},x.axis_range_list(1+mod(x.coord_groups(igp,ic)-1,size(x.axis_range_list,1)),:));
                    end
            end
            %legend
            if (x.if_legend==1)
                need_legend=1;
            elseif (x.if_legend==-1)
                need_legend=(igp_aug==ngroups_aug);
            else
                need_legend=0;
            end
            if need_legend
                hc=get(haxis,'Children');
                tags_all=cell(length(hc),1);
                for ich=1:length(hc)
                    tags_all{ich}=get(hc(ich),'Tag');
                end
                hc_show=[];
                for itag=1:length(x.legend_tags)
                    hc_show=union(hc_show,strmatch(x.legend_tags{itag},tags_all)); %select the objects whose tags start with x.legend_tags
                end
                if ~isempty(hc_show)
                    h_legend=legend(hc(flipud(hc_show)),'Location',x.legend_location,'FontSize',x.legend_font_size);  %flipud since children appear to be added in reverse order
                    if ~isempty(x.legend_interpreter)
                        set(h_legend,'Interpreter',x.legend_interpreter);
                    end
                end
            end
        end %if_finalize
    end %igp_aug
end
%
aux_out=rs_warning(unique(disp_msgs,'rows'),0,setfield(aux_out,'if_warn',x.if_warn));
aux_out.opts_disp=x;
return
end

function [hline,plotstyle_used,opts_plotstyle_used]=rs_disp_doplot(coords,index,style_specs,opts)
%plot the data (rows of coords) into the current plot, using index into style_specs.set* to determine the style
%
if (nargin<=3)
    opts=struct;
end
%
style_specs=filldefault(style_specs,'colors_filled',style_specs.colors);
style_specs=filldefault(style_specs,'filled',0);
style_specs=filldefault(style_specs,'alphas',1);
%
plotstyle=struct;
%
index_color=1+mod(index-1,length(style_specs.colors));
plotstyle.color=style_specs.colors{index_color};
%
index_colors_filled=1+mod(index-1,length(style_specs.colors_filled));
plotstyle.color_fill=style_specs.colors_filled{index_colors_filled};
%
index_filled=1+mod(index-1,length(style_specs.filled));
plotstyle.filled=style_specs.filled(index_filled);
%
index_alpha=1+mod(index-1,length(style_specs.alphas));
plotstyle.alpha=style_specs.alphas(index_alpha);
%
index_marker=1+mod(index-1,length(style_specs.markers));
plotstyle.marker=style_specs.markers{index_marker};
%
index_markersize=1+mod(index-1,length(style_specs.markersizes));
plotstyle.markersize=style_specs.markersizes(index_markersize);
%
index_linestyle=1+mod(index-1,length(style_specs.linestyles));
plotstyle.linestyle=style_specs.linestyles{index_linestyle};
%
index_linewidth=1+mod(index-1,length(style_specs.linewidths));
plotstyle.linewidth=style_specs.linewidths(index_linewidth);
%
[handles,plotstyle_used,opts_plotstyle_used]=rs_plot_style(coords,plotstyle,opts);
hline=handles.legend;
hold on;
return
end

function [pair_list,wmsg]=rs_disp_parse_pairmethod(method,vals_avail,list_specified,msg)
%parse a method token that specifies a list of pairs
n=length(vals_avail);
wmsg=[];
pair_list=[];
npairs=0;
if n>=1
    switch method
        case 'none'
        case 'all'
            if n>=2
                pairs=nchoosek([1:n],2);
                npairs=n*(n-1)/2;
            end
        case 'chain'
            pairs=1+mod([[0:n-2];[1:n-1]],n)';
            npairs=n-1;
        case 'circuit'
            pairs=1+mod([[0:n-1];[1:n]],n)';
            npairs=n;
        case {'star','star_first'}
            pairs=[repmat(1,1,n-1);[2:n]]';
            npairs=n-1;
        case {'star_last'}
            pairs=[repmat(n,1,n-1);[1:n-1]]';
            npairs=n-1;
            pair_list=[vals_avail(pairs(:,1))',vals_avail(pairs(:,2))'];
        case 'list'
            pair_list=list_specified;
            have_pair=find(all(ismember(pair_list,vals_avail),2));
            pair_list=pair_list(have_pair,:);
        otherwise
            wmsg=strvcat(wmsg,sprintf('%s not recognized; none used',msg));
    end
    if npairs>0
        %make pair_list 2 columns
        v1=vals_avail(pairs(:,1));
        v2=vals_avail(pairs(:,2));
        pair_list=[v1(:),v2(:)];
    end
end
if ~isempty(pair_list)
    if ((size(pair_list,2)~=2) | any(list_specified(:)<=0) | any(list_specified(:)>max(vals_avail)) | any(floor(pair_list(:))~=pair_list(:)))
        wmsg=strvcat(wmsg,sprintf('%s exceeds bounds ([1 %1.0f]), or is not integer, or is not two columns; none used',msg,max(vals_avail)));
    end
end
if ~isempty(wmsg)
    pair_list=[];
end
return
end

function [list_vals,wmsg]=rs_disp_parse_listmethod(method,vals_avail,list_specified,msg)
%parse a method token that specifies a list: first, last, and all are relative to contents of vals_avail
wmsg=[];
list_vals=[];
switch method
    case 'none'
    case 'all'
        list_vals=vals_avail(:);
    case 'first'
        list_vals=vals_avail(1);
    case 'last'
        list_vals=vals_avail(end);
    case 'list'
        list_vals=list_specified(find(ismember(list_specified(:),vals_avail))); %so we don't change the order
        list_vals=list_vals(:);
    otherwise
        wmsg=strvcat(wmsg,sprintf('%s not recognized; none used',msg));
end
if ~isempty(list_vals)
    if ((size(list_vals,2)~=1) | any(list_vals(:)<=0) | any(list_vals(:)>max(vals_avail)) | any(floor(list_vals(:))~=list_vals(:)))
        wmsg=strvcat(wmsg,sprintf('%s exceeds bounds ([1 %1.0f]), or is not integer, or is not one column; none used',msg,max(vals_avail)));
    end
end
if ~isempty(wmsg)
    list_vals=[];
end
return
end
