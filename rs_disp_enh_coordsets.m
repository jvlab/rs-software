function aux_out=rs_disp_enh_coordsets(data_in,aux,rays)
% function aux_out=rs_disp_enh_coordsets(data_in,aux,rays)
%
% data_in: a standard dataset structure, with fields ds, sas, sets
%
% aux.opts_disp_enh: controls which enhanced features are added to plots
%   if_points: 1 (default) to display each data point
%   if_rays:   1 (default) to display rays, set to zero if rays is not present or empty
%   if_rings:  1 to display rings (default: 0), set to zero if rays is not present or empty
%   if_nbrs:   1 (default) to connect nearest-neighbors
%   if_nbrs_nosameray: 1 (default) to suppress nearest-neighbor connections 
%      if both points are on the same ray, or next to origin, and rays are displayed
%
% aux.opts_disp: these fields are starting points for customization for enhanced plots
%  fields not specified are passed through to rs_disp_coordsets
%                                  points     rays       rings    neighbors
%    data_show_method:             'all'     'list'      'list'     'list' 
%    data_label_method:            'none'*   'last'      'none'*    'none'*
%    data_connect_method:                    'list'      'list'*    'list'
%    connect_data_linestyles       'none'*  '--' or '-'#    ':'*     '-'*
%    set_markers                             'x' or '+'#            'none'
%    set_tags                                 'rays'     'rings'    'nbrs'
%    callout_amount                            0.5*
%    set_colors                              per ray
%    callout_colors                          per ray*
%   *: an explicitly supplied value in aux.opts_disp is NOT overridden
%   #:line style and set markers depends on whether the ray is negative or positive
% 
% aux.opts_tn2c: options for customizing how stimulus names are mapped to colors, in psg_typenames2colors
%    usually empty
% 
% rays: a standard ray structure, containing metadata for rays and rings
%
% aux_out:
%     opts_disp: values of aux.opts_disp as used
%     opts_disp_enh: values of aux.opts_disp_enh as used
%     opts_t2nc: values of aux.opts_t2nc as used
%     points: aux_out rs_disp_coordsets for plotting points, omitted if aux.opts_disp_enh.if_points=0
%     rays{iray,isign}: aux_out returned by rs_disp_coordsets for ray iray, (isign=1: neg,isign=2, pos), omitted if no rays are plotted, or if aux.opts_disp_enh.if_rays=0
%     rings{iring}: aux_out returned by rs_disp_coordsets for ring iring, omitted if no rings are plotted or aux.opts_disp_enh.if_rings=0
%     nbrs: aux_out returned by rs_disp_coordsets for connectiong neighbors, omitted if no connections are plotted or aux.opts_disp_enh.if_nbrs=0
%
% Notes:
%   Rays are plotted before data points, so that data points overlay the rays and can be color-coded by set.
%
%   See also: RS_DISP_COORDSETS, PSG_TYPENAMES2COLORS.
%
if (nargin<=2)
    rays=[];
end
%
aux=filldefault(aux,'opts_disp',struct());
aux=filldefault(aux,'opts_disp_enh',struct());
aux=filldefault(aux,'opts_tn2c',struct());
%
aux.opts_disp_enh=filldefault(aux.opts_disp_enh,'if_points',1);
aux.opts_disp_enh=filldefault(aux.opts_disp_enh,'if_rays',1);
aux.opts_disp_enh=filldefault(aux.opts_disp_enh,'if_rings',0);
aux.opts_disp_enh=filldefault(aux.opts_disp_enh,'if_nbrs',1);
aux.opts_disp_enh=filldefault(aux.opts_disp_enh,'if_nbrs_notsameray',1);
%
if isempty(rays) | isempty(fieldnames(rays))
    aux.opts_disp_enh.if_rays=0;
    aux.opts_disp_enh.if_rings=0;
    aux.opts_disp_enh.if_nbrs=0;
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
                [rgb,symb,vecs,opts_used]=psg_typenames2colors(data_in.sas{1}.typenames(bidir_sorted),aux.opts_tn2c); %get standard colors and symbols
                opts_disp_rays.set_colors{1}=rgb;
                if ~if_callout_colors_supplied
                    opts_disp_rays.callout_colors{1}=rgb;
                end               
                switch isign
                    case 1
                        opts_disp_rays.connect_data_linestyles='-';
                        opts_disp_rays.set_markers='+';
                    case -1
                        opts_disp_rays.connect_data_linestyles='--';
                        opts_disp_rays.set_markers='x';
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
    opts_disp_points.data_show_method='all';
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
        opts_disp_nbrs=filldefault(opts_disp_nbrs,'data_label_method','none');
        opts_disp_nbrs=filldefault(opts_disp_nbrs,'connect_data_linestyles','-');
        opts_disp_nbrs.set_tags='nbrs'; %so that this will not be in legend
        pairs=rays.pairs;
        if aux.opts_disp_enh.if_nbrs_notsameray
            pair_rayid=rays.whichray(pairs);
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
