%rs_disp_coordsets_demo_opposites:  display datasets in a structured domain (stimulus coordinates and rays)
%
% run after rs_read_coorddata_demo_opposites
%
% See also:  RS_DISP_COORDSETS
%
dim_list=getinp('dimension list','d',[2 3],3);
aux_disp=struct;
for ifile=1:nfiles %label each dataset by subject ID
    aux_disp.opts_disp.set_labels{ifile}=data_out.sets{ifile}.subj_id;
end
aux_disp.opts_disp.set_colors={[0.5 0.5 0.5],[0.9 0.4 0],[0 0 0]}; %custom colors for the datasets
%
aux_disp1=aux_disp;
aux_disp1.opts_disp.connect_sets_method='all'; %connect datasets
%
aux_disp2=aux_disp;
aux_disp2.opts_disp.set_markersizes=16; %larger markers
aux_disp2.opts_disp.data_label_setsel_method='all'; %label all sets
aux_disp2.opts_disp.set_offsets='margin_amount'; %how to space between datasets
aux_disp2.opts_disp.set_offsets_coordchoices=1; %offset along coordinate 1
aux_disp2.opts_disp.connect_sets_method='chain'; %connect set 1 to 2, and 2 to 3
aux_disp2.opts_disp.connect_sets_data_method='list';  %label all sets
%
aux_disp3=aux_disp;
aux_disp3.opts_disp.set_offsets='margin_amount'; %how to space between datasets
aux_disp3.opts_disp.set_offsets_coordchoices=1; %offset along coordinate 1
aux_disp3.opts_disp_enh.if_rings=1;
aux_disp3.opts_disp_enh.if_nbrs=0;
aux_disp3.opts_disp_enh.if_usetypenames=0; %use coordinate values rather than typenames to color
%
rays=aux_out{1}.rayss{1};
%
%knit by Procrustes
%
opts_knit=struct;
aux_knit=struct;
aux_knit.opts_knit=opts_knit;
[data_knit,aux_knit_out]=rs_knit_coordsets(data_out,aux_knit); %align stimuli via Procrustes; stimuli will be reordered alphabetically
rays_knit=aux_knit_out.rayss{1}; %stimuli will be reordered by knitting, so rays need to be recalculated
data_aligned=aux_knit_out.components; %
%
%knit by Procrustes and then pca
%
aux_knit_pca=aux_knit;
aux_knit_pca.opts_knit=setfield(opts_knit,'if_pca',1);
[data_knit_pca,aux_knit_out_pca]=rs_knit_coordsets(data_out,aux_knit_pca); %align stimuli via Procrustes and apply pca
data_aligned_pca=aux_knit_out_pca.components;
for plot_type=1:3
    switch plot_type
        case 1
            prefix='raw';
            data_disp=data_out;
            rays_disp=rays;
        case 2
            prefix='knit: procrustes only';
            data_disp=aux_knit_out.components;
            rays_disp=rays_knit;
        case 3
            prefix='knit: procrustes and PCA';
            data_disp=aux_knit_out_pca.components;
            rays_disp=rays_knit;
    end
    for idim=dim_list
        aux_disp1.opts_disp.dim_select=idim;
        aux_disp1.opts_disp.fig_name=sprintf('%s, dim %1.0f: superimpose, connect all stims, all sets',prefix,idim);
        rs_disp_coordsets(data_disp,aux_disp1); %standard plots, superimposed and connected
        %
        aux_disp2.opts_disp.dim_select=idim;
        aux_disp2.opts_disp.fig_name=sprintf('%s dim %1.0f: separate, connect one stim as a chain',prefix,idim);
        data_connect_ptrs=union(strmatch('hot',data_disp.sas{1}.typenames,'exact'),strmatch('cold',data_disp.sas{1}.typenames,'exact'));
        aux_disp2.opts_disp.connect_sets_data_list=data_connect_ptrs; %just connect the points labeled hot and cold
        rs_disp_coordsets(data_disp,aux_disp2); %standard plots, spaced along second dimension
        %
        aux_disp3.opts_disp.dim_select=idim;
        aux_disp3.opts_disp.fig_name=sprintf('%s dim %1.0f: separate, show rays',prefix,idim);
        rs_disp_enh_coordsets(data_disp,aux_disp3,rays_disp); %enhanced plots with rays and rings
    end
end %plot_type
%
