function aux_out=rs_disp_enh_coordsets(data_in,aux,rays)
% aux_out=rs_disp_enh_coordsets(data_in,aux,rays) displayes one or more
% views of the coordinates in a `dataset structure`, with graphical enhancements: connecting stimuli along rays, in rings, and nearest neighbors.
% These enhancements depend on the availability of a `ray structure`, which specifyues rays (stimuli that lie on an approximate straight line from the origin) and
% rings (stimuli that lie in a plane at approximately equal distances from the origin), and nearest-neigbhbor pairs.
% 
%
% Args:
%   data_in (struct): `dataset structure` to be processed, with fields
%
%     - ds (cell array): `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas (cell array): `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets (cell array): `set metadata structure`, sets{k} is the response metadata for the kth record
%
%   aux (struct): auxiliary inputs, may be empty, with fields
%
%     - opts_disp_enh (struct): options for enhanced display, with fields
%
%         - if_points (int): 1 to display each data point, 0 to suppress; default is 1; see notes below regarding points and rays
%         - if_rays (int): 1 to connect data points along rays, 0 to suppress; default is 1 if 'rays' is non-empty, otherwise 0; see notes below regarding points and rays
%         - if_rings (int): 1 to connect data points in rings, 0 to suppress; default is 1 if 'rays' is non-empty, otherwise 0
%         - if_nbrs (int): 1 to connect nearest-neighbors, 0 to suppress; default is 1 if 'rays' is non-empty, otherwise 0
%         - if_nbrs_notsameray (int): 1 to suppress nearest-neighbor connections  if both points are on the same ray, or next to origin; 0 to connect all nearest neighbors; default is 1
%         - if_usetypenames (int): how colors and symbols are determined; 1 (use 'typenames') is default; 0-> determine from stimulus coordinates, a field of data_in.sas{1} (search order: 'type_coords','btc_specoords','btc_augcoords', see `rs_findrays` for further details)
%
%      - opts_tn2c (struct): controls how stimulus labels (data_in.sas{:}.typenames) are mapped to colors and symbols; can be empty, see `rs_typenames2colors` for details
% 
%      - opts_disp (struct): controls basic display; see `rs_disp_coordsets` for details. Most fields are of opts_disp are passed directly to `rs_disp_coordsets`, with unspecified fields in opts_disp filled with the defaults of `rs_disp_coordsets`. The following field values are inserted into opts_disp based on the fields of opts_disp_enh and the graphical element being drawn:
%
%
%          |                      element: | points       | rays              | rings        | neighbors    |
%          |-------------------------------|--------------|-------------------|--------------|--------------|
%          | data_show_method              | 'all' [1]    | 'list'            | 'list'       | 'list'       |
%          | data_label_method             | 'none'[1]    | 'last'            | 'none'[1]    | 'none'[1]    |
%          | connect_data_method           |              | 'list'            | 'list'[1]    | 'list'       |
%          | connect_data_linestyles       | 'none'[1]    | '--' or '-'[2]    | ':'  [1]     | '-'   [1]    |
%          | set_markers                   |              | [3]               | 'none'[1]    | 'none'[1]    |
%          | set_tags                      |              | 'rays'            | 'rings'      | 'nbrs'       |
%          | callout_amount                |              | 0.5[1]            |              |              |
%          | set_colors                    |              | per ray[3]        |              |              |
%          | callout_colors                |              | per ray[1]        |              |              |
%
%         - [1]: if a value is supplied value in aux.opts_disp, it is not overridden
%         - [2]: line style depends on whether the ray is negative (first option) or positive (second option)
%         - [3]: set markers and colors determined by `rs_typenames2colors` 
%
%
%   rays (struct): a `ray structure`, ordinarily created by `rs_findrays`. If empty or omitted the enhanced graphical elements will not be displayed.
%
% Returns:
%   aux_out: auxiliary outputs and parameter values used
%
%     - opts_disp (struct): aux.opts_disp, with defaults and overrides filled in
%     - opts_disp_enh (struct): aux.opts_disp_enh, with defaults filled in
%     - opts_t2nc (struct): aux.opts_t2nc, with defaults filled in
%     - points (struct): aux_out from `rs_disp_coordsets` for display of points; omitted if opts_disp_enh.if_points=0
%     - rays (cell array of struct): aux_out from `rs_disp_coordsets` for display of each ray; rays{:,isign} corresponds to display of each ray in the negative direction (isign=1) and the positive direction, (isign=2); omitted if opts_disp_enh.if_rays=0;
%     - rings (cell array of struct): aux_out from `rs_disp_coordsets` for display of each ring; omitted if no rings are displayed or opts_disp_enh.if_rings=0
%     - nbrs (struct): aux_out from `rs_disp_coordsets` for connections between neighbors; omitted if no connections are displayed or opts_disp_enh.if_nbrs=0
%
% Note regarding points and rays:
%     - Rays are plotted before data points, so that data points overlay the rays and can be color-coded by set.
%     - Legend behavior: If opts_disp_enh.if_rays=1 and opts_disp_enh.if_points=0, legend is the ray label; otherwise legend is set label.
%
%  See also: RS_DISP_COORDSETS, RS_TYPENAMES2COLORS, RS_FINDRAYS, RS_PLOT_STYLE.
%
if (nargin<=1)
    aux=struct;
end
if (nargin<=2)
    rays=struct;
end
%
aux=filldefault(aux,'opts_disp_enh',struct());
aux=filldefault(aux,'opts_tn2c',struct());
aux=filldefault(aux,'opts_disp',struct());
%
aux.opts_disp_enh=filldefault(aux.opts_disp_enh,'if_points',1);
aux.opts_disp_enh=filldefault(aux.opts_disp_enh,'if_rays',1);
aux.opts_disp_enh=filldefault(aux.opts_disp_enh,'if_rings',0);
aux.opts_disp_enh=filldefault(aux.opts_disp_enh,'if_nbrs',1);
aux.opts_disp_enh=filldefault(aux.opts_disp_enh,'if_nbrs_notsameray',1);
aux.opts_disp_enh=filldefault(aux.opts_disp_enh,'if_usetypenames',1);
%
if aux.opts_disp_enh.if_usetypenames==0 %get coordinates
    opts_rays=getfield(rs_aux_customize(setfield(struct(),'opts_rays',struct()),'rs_findrays'),'opts_rays'); %get defaults for ray_reorder_ring and ray_plane_jit
    opts_rays=filldefault(opts_rays,'coord_names',getfield(psg_defopts,'coord_fields')); % was {'type_coords','btc_specoords','btc_augcoords'});
    [stim_coords,coord_names]=psg_type_coords_util(data_in.sas{1},opts_rays.coord_names);
end
%
aux.opts_tn2c.paradigm_type=data_in.sets{1}.paradigm_type; %so that rs_typenames2colors knows the paradigm
aux.opts_tn2c.if_usetypenames=aux.opts_disp_enh.if_usetypenames;
%
if isempty(rays) | isempty(fieldnames(rays))
    aux.opts_disp_enh.if_rays=0;
    aux.opts_disp_enh.if_rings=0;
    aux.opts_disp_enh.if_nbrs=0;
end
%ensure that a figure handle is open and that we plot into currenf figure
if ~isfield(aux.opts_disp,'fig_handle')
    aux.opts_disp.fig_handle=[];
end
if isempty(aux.opts_disp.fig_handle)
    aux.opts_disp.fig_handle=figure;
end
if aux.opts_disp.fig_handle~=gcf
    aux.opts_disp.fig_handle=gcf;
end
%
if aux.opts_disp_enh.if_rays %plot points along each ray, in designated colors
    %customize standard plot options for rays
    opts_disp_rays=aux.opts_disp;
    opts_disp_rays.data_show_method='list';
    opts_disp_rays.connect_data_method='chain';
    opts_disp_rays=filldefault(opts_disp_rays,'data_label_method','last');
    opts_disp_rays.set_tags='rays'; %to identify for legend
    if aux.opts_disp_enh.if_points==0
        opts_disp_rays.legend_tags='rays'; %to include in legend
    end
    opts_disp_rays=filldefault(opts_disp_rays,'callout_amount',0.5);
    if_callout_colors_supplied=double(isfield(opts_disp_rays,'callout_colors'));
    aux_used_rays=[];
    for iray=1:rays.nrays
        orig_ptr=min(find(rays.whichray==0));
        for isign=-1:2:1
            bidir=find(rays.whichray==iray);
            mults=rays.mult(bidir);
            sign_sel=find(sign(mults)==isign);
            if ~isempty(sign_sel)
                bidir_sel=bidir(sign_sel);
                mults_sel=mults(sign_sel);
                mb_sorted=sort([abs(mults_sel(:)),bidir_sel],1,'ascend');
                bidir_sorted=mb_sorted(:,2); %sorted in ascending order of magnitude
                opts_disp_rays.data_show_list=[orig_ptr bidir_sorted']; %add origin to the beginning
                %
                %[rgb,symb,vecs,opts_used]=psg_typenames2colors(data_in.sas{1}.typenames(bidir_sorted),aux.opts_tn2c); %get standard colors and symbols
                if aux.opts_disp_enh.if_usetypenames
                    [rgb,symb]=rs_typenames2colors(data_in.sas{1}.typenames(bidir_sorted),setfield(struct(),'opts_tn2c',aux.opts_tn2c));
                else
                    [rgb,symb]=rs_typenames2colors(stim_coords(bidir_sorted,:),setfield(struct(),'opts_tn2c',aux.opts_tn2c));
                end
                opts_disp_rays.set_colors=rgb;
                if ~if_callout_colors_supplied
                    opts_disp_rays.callout_colors=rgb;
                end               
                opts_disp_rays.set_markers=symb;
                switch isign
                    case 1
                        opts_disp_rays.connect_data_linestyles='-';
                    case -1
                        opts_disp_rays.connect_data_linestyles='--';
                end
                %
                if isign==-1 | iray<rays.nrays
                    opts_disp_rays.if_finalize=0;
                else
                    opts_disp_rays.if_finalize=1;
                end
                opts_disp_rays.set_labels=data_in.sas{1}.typenames(bidir_sorted(end)); %use typenames of last stimulus in the ray
                aux_out_ray=rs_disp_coordsets(data_in,setfield(struct,'opts_disp',opts_disp_rays));
                aux_out.rays{iray,(3+isign)/2}=aux_out_ray;
                aux.opts_disp=rs_disp_enh_hupdate(aux.opts_disp,aux_out_ray.opts_disp);
                if isempty(aux_used_rays) %to use for legends
                    aux_used_rays=aux_out_ray;
                end
            end %not empty
        end %sign
    end %iray
end
%
if aux.opts_disp_enh.if_points %plot individual points?
    %customize standard plot options for points
    opts_disp_points=aux.opts_disp;
    opts_disp_points=filldefault(opts_disp_points,'data_show_method','all');
    opts_disp_points=filldefault(opts_disp_points,'data_label_method','none');
    opts_disp_points=filldefault(opts_disp_points,'connect_data_linestyles','-');
    %
    aux_out.points=rs_disp_coordsets(data_in,setfield(struct(),'opts_disp',opts_disp_points));
    %update figure and axis handles so future plots are in same place
    aux.opts_disp=rs_disp_enh_hupdate(aux.opts_disp,aux_out.points.opts_disp);
end
%
if aux.opts_disp_enh.if_rings %connect rings
    %customize standard plot options for rings
    opts_disp_rings=aux.opts_disp;
    opts_disp_rings.data_show_method='list';
    opts_disp_rings.connect_data_method='list';
    opts_disp_rings=filldefault(opts_disp_rings,'set_markers','none');
    opts_disp_rings=filldefault(opts_disp_rings,'data_label_method','none');
    opts_disp_rings=filldefault(opts_disp_rings,'connect_data_linestyles',':');
    opts_disp_rings.set_tags='rings'; %to identify for legend
    %find which ring is the last non-empty ring so if_finalize can be used to speed up
    ring_nz=zeros(1,rays.nrings);
    for iring=1:rays.nrings
        ring_nz(iring)=length(rays.rings{iring}.coord_ptrs);
    end
    ring_last=max(find(ring_nz>0));
    for iring=1:rays.nrings
        ring_list=rays.rings{iring}.coord_ptrs;
        if ~isempty(ring_list)
            ring_list_offset=[ring_list(2:end) ring_list(1)];
            opts_disp_rings.data_show_list=ring_list;
            opts_disp_rings.connect_data_list=[ring_list(:),ring_list_offset(:)];
            if iring<ring_last
                opts_disp_rings.if_finalize=0;
            else
                opts_disp_rings.if_finalize=1;
            end
            %
            aux_out_ring=rs_disp_coordsets(data_in,setfield(struct,'opts_disp',opts_disp_rings));
            aux_out.rings{iring}=aux_out_ring;
            aux.opts_disp=rs_disp_enh_hupdate(aux.opts_disp,aux_out_ring.opts_disp);
         end %empty?
    end %iray
end
%
if aux.opts_disp_enh.if_nbrs %connect neighbors
   if rays.npairs>0
        %customize standard plot options for rings
        opts_disp_nbrs=aux.opts_disp;
        opts_disp_nbrs.data_show_method='list';
        opts_disp_nbrs.connect_data_method='list';
        opts_disp_nbrs=filldefault(opts_disp_nbrs,'set_markers','none');
        opts_disp_nbrs=filldefault(opts_disp_nbrs,'data_label_method','none');
        opts_disp_nbrs=filldefault(opts_disp_nbrs,'connect_data_linestyles','-');
        opts_disp_nbrs.set_tags='nbrs'; %so that this will not be in legend
        pairs=rays.pairs;
        if aux.opts_disp_enh.if_nbrs_notsameray
            pair_rayid=reshape(rays.whichray(pairs),size(pairs));
            pair_keep=double(pair_rayid(:,1)~=pair_rayid(:,2)); %note, this will keep if both are NaN
            pair_keep=and(pair_keep,all(pair_rayid~=0,2)); %exclude rays that include the origin
            pairs=pairs(find(pair_keep),:);
        end
        if ~isempty(pairs)
            opts_disp_nbrs.data_show_list=unique(pairs(:));
            opts_disp_nbrs.connect_data_list=pairs;
            opts_disp_nbrs.set_markers={'none'};
            aux_out_nbrs=rs_disp_coordsets(data_in,setfield(struct,'opts_disp',opts_disp_nbrs));
            aux_out.nbrs=aux_out_nbrs;
            aux.opts_disp=rs_disp_enh_hupdate(aux.opts_disp,aux_out_nbrs.opts_disp);
        end
    end %empty?
end
%
%if rays but not points are plotted, then clean up legend: 
% ray label will have been repeated for each dataset
%
if aux.opts_disp_enh.if_rays==1 & aux.opts_disp_enh.if_points==0 & ~isempty(aux_used_rays)
    x=aux_used_rays.opts_disp; %these are the options used for plotting rays
    for iax=1:length(aux.opts_disp.axis_handles)
        haxis=aux.opts_disp.axis_handles{iax};
        legh=get(haxis,'Legend');
        if ~isempty(legh)
            subplot(haxis);
            hc=get(haxis,'Children');
            tags_all=cell(length(hc),1);
            display_all=cell(length(hc),1);
            for ich=1:length(hc)
                tags_all{ich}=get(hc(ich),'Tag');
                display_all{ich}=get(hc(ich),'DisplayName');
            end
            hc_show=strmatch('rays',tags_all); %select the objects whose tags start with x.legend_tags
            if ~isempty(hc_show)
                %find the unique display names, to eliminate duplicates across datasets
                display_unique=unique(display_all(hc_show));
                hc_show_unique=zeros(length(display_unique),1);
                for iu=1:length(display_unique)
                    hc_show_unique(iu)=hc_show(min(strmatch(display_unique{iu},display_all(hc_show),'exact'))); 
                end
                h_legend=legend(hc(flipud(hc_show_unique)),'Location',x.legend_location,'FontSize',x.legend_font_size);  %flipud since children appear to be added in reverse order
                if ~isempty(x.legend_interpreter)
                    set(h_legend,'Interpreter',x.legend_interpreter);
                end
            end
            %
        end %legend is present
    end
end
%
aux_out.opts_disp=aux.opts_disp;
aux_out.opts_disp_enh=aux.opts_disp_enh;
aux_out.opts_tn2c=aux.opts_tn2c;
return
end

function anew=rs_disp_enh_hupdate(aold,a)
fns={'fig_handle','axis_handles'};
for ifn=1:length(fns)
    anew=aold;
    fn=fns{ifn};
    if isfield(a,fn)
        anew.(fn)=a.(fn);
    end
end
return
end
