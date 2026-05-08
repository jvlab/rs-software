%rs_disp_coordsets_demo_opposites 
% demonstration of display of a dataset for a structured domain 
% run after rs_disp_coordsets_demo
%
% See also:  RS_DISP_COORDSETS.
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
aux_disp2.opts_disp.set_marker_sizes=16; %larger markers
aux_disp2.opts_disp.set_offsets='margin_amount';
aux_disp2.opts_disp.set_offsets_coordchoices=1; %offset along coordinate 1
aux_disp2.opts_disp.connect_sets_method='chain';
aux_disp2.opts_disp.connect_sets_data_method='list';
data_connect_ptrs=union(strmatch('hot',data_out.sas{1}.typenames,'exact'),strmatch('cold',data_out.sas{1}.typenames,'exact'));
aux_disp2.opts_disp.connect_sets_data_list=data_connect_ptrs; %just connect the points labeled hot and cold
%
aux_disp3=aux_disp;
aux_disp3.opts_disp.set_offsets='margin_amount';
aux_disp3.opts_disp.set_offsets_coordchoices=1; %offset along coordinate 1
aux_disp3.opts_disp_enh.if_rings=1;
aux_disp3.opts_disp_enh.if_nbrs=0;
aux_disp3.opts_disp_enh.if_usetypenames=0; %use coordinate values rather than typenames to color
%
rays=aux_out{1}.rayss{1};
%
%align data, rotate data into a consensus, and use each component, aligned to consensus, for further plotting
%%%NEED TO DO THIS WITH AND WITHIOUT IF_PCA=1
%%%pLOT COMPONENTS, AND ALSO PLOT KNIT VERSION
[data_knit,aux_knit_out]=rs_knit_coordsets(data_out,aux_knit); %align stimuli, will be reordered alphabetically
rays_knit=aux_knit_out{1}.rayss{1}; %stimuli will be reordered by knitting, so rays need to be recalculated
data_aligned=aux_knit_out.components; %

%
for idim=2:3
    aux_disp1.opts_disp.dim_select=idim;
    aux_disp1.opts_disp.fig_name=sprintf('dim %1.0f: superimpose, connect all stims, all sets',idim);
    rs_disp_coordsets(data_out,aux_disp1); %standard plots, superimposed and connected
    %
    aux_disp2.opts_disp.dim_select=idim;
    aux_disp2.opts_disp.fig_name=sprintf('dim %1.0f: separate, connect one stim as a chain',idim);
    rs_disp_coordsets(data_out,aux_disp2); %standard plots, spaced along second dimension
    %
    aux_disp3.opts_disp.dim_select=idim;
    aux_disp3.opts_disp.fig_name=sprintf('dim %1.0f: separate, show rays',idim);
    rs_disp_enh_coordsets(data_out,aux_disp3,rays); %enhanced plots with rays and rings
end
%
