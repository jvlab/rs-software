function aux_out=rs_disp_enh_coordsets(data_in,rays,aux)
% function aux_out=rs_disp_enh_coordsets(data_in,rays,aux)
%
% aux.opts_disp_enh: controls which enhanced features are added to plots
%   if_points: 1 (default) to display each data point
%   if_rays:   1 (default) to display rays
%   if_rings:  1 to display rings (default: 0)
%   if_nbrs:   1 (default) to connect nearest-neighbors
%   if_nbrs_nosameray: 1 (default) to suppress nearest-neighbor connections 
%      if both points are on the same ray, or next to origin, and rays are displayed
%
% aux.opts_disp: these fields are starting points for customization for enhanced plots
%  fields not specified are passed through to rs_disp_coordsets
%                                  points     rays     rings    neighbors
%    data_show_method:             'all'     'list'   'list'     'list' 
%    data_label_method:            'none'*   'last'   'none'*    'none'*
%    data_connect_method:                    'list'   'list'*    'list'
%    connect_data_linestyles       'none'*  '-'/'--'   ':'*      '-'*
%    set_markers                                                 'none'
%    set_tags                                'rays'   'rings'    'nbrs'
%    callout_amount                           0.5*
%    set_colors                             per ray
%    callout_colors                         per ray*
%   * indicates that an explicitly supplied value in aux.opts_disp is NOT overridden
%
%need to document, what is passed through, and handles on output
%provide options for psg_typenames2colors
%labellig options
%rings, rays, grids
%need to test with multiple subsets of axes, selectoin of datasets, views,etc
%
%   See also: RS_DISP_COORDSETS, PSG_TYPENAMES2COLORS.
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
if aux.opts_disp_enh.if_rays %plot points along each ra,y, in designated colors
    %customize standard plot options for rays
    opts_disp_rays=aux.opts_disp;
    opts_disp_rays.data_show_method='list';
    opts_disp_rays.connect_data_method='chain';
    opts_disp_rays=filldefault(opts_disp_rays,'data_label_method','last');
    opts_disp_rays.set_tags='rays'; %so that this will not be in legend
    opts_disp_rays=filldefault(opts_disp_rays,'callout_amount',0.5);
    if_callout_colors_supplied=double(isfield(opts_disp_rays,'callout_colors'));
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
                    case -1
                        opts_disp_rays.connect_data_linestyles='--';
                end
                %
                if isign==-1 | iray<rays.nrays
                    opts_disp_rays.if_finalize=0;
                else
                    opts_disp_rays.if_finalize=1;
                end
                aux_out_ray=rs_disp_coordsets(data_in,setfield(struct,'opts_disp',opts_disp_rays));
                aux_out.rays{iray,(3+isign)/2}=aux_out_ray;
                aux.opts_disp=rs_disp_enh_hupdate(aux.opts_disp,aux_out_ray.opts_disp);
            end %not empty
        end %sign
    end %iray
end
%
if aux.opts_disp_enh.if_rings %connect rings
    %customize standard plot options for rings
    opts_disp_rings=aux.opts_disp;
    opts_disp_rings.data_show_method='list';
    opts_disp_rings.connect_data_method='list';
    opts_disp_rings=filldefault(opts_disp_rings,'data_label_method','none');
    opts_disp_rings=filldefault(opts_disp_rings,'connect_data_linestyles',':');
    opts_disp_rings.set_tags='rings'; %so that this will not be in legend
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
