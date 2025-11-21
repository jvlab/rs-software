% rs_disp_coordsets_demo2: demonstrate display of datasets
% with several customizations
%
% options illustrated:
%  sample datasets are rotated via PCA (in rs_knit_coordsets)
%  choice of dataset to label
%  choice of datasets to display
%  offsets between datasets
%
%  See also:  RS_DISP_COORDSETS, RS_DISP_COORDSETS_DEMO.
%
filenames={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S4','./samples/animals/image_coords_S5','./samples/animals/image_coords_S6'};
nfiles=length(filenames);
aux_in=struct;
aux_in.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_in.nsets=length(filenames);
%
[data_read,aux_read]=rs_get_coordsets(filenames,aux_in);
%
%align and rotate data into a consensus, and use each component, aligned to consensus, for further plotting
%
aux_align_def=struct;
[data_align,aux_align]=rs_align_coordsets(data_read,aux_align_def);
aux_knit_def=struct;
aux_knit_def.opts_knit.if_pca=1; %rotate to PCA
[data_consensus,aux_knit]=rs_knit_coordsets(data_align,aux_knit_def);
data_components=aux_knit.components;
%
%plots with 2-d projection and 3-d projections of a 5-d model
%
dim_select=5;
group_size_list=[2:3];
coord_group_methods={'keeplow'};
%
aux_nocust=struct;
opts_disp=struct;
opts_disp.dim_select=dim_select;
opts_disp.data_label_setsel_method='list';
opts_disp.data_label_setsel_list=2;
opts_disp.set_select=[1 2 4]; % datasets to show
opts_disp.set_offsets=repmat([0:nfiles-1]',1,dim_select)+repmat([1:dim_select]/2,nfiles,1);
opts_disp.connect_sets_method='list';
opts_disp.connect_sets_list=[2 4];
opts_disp.connect_sets_color_mode='split';
disp('set_offsets');
disp(opts_disp.set_offsets)
%
aux_out_custproj=cell(length(group_size_list),length(coord_group_methods));
for igroup=1:length(group_size_list)
    opts_disp.coord_group_size=group_size_list(igroup);
    if opts_disp.coord_group_size==2
        opts_disp.axis_scale='auto';
    end
    if opts_disp.coord_group_size==3
        opts_disp.if_legend=-1;
    end
    for imethod=1:length(coord_group_methods)
        opts_disp.coord_group_method=coord_group_methods{imethod};
        opts_disp.fig_name=sprintf('consensus dim %2.0f: coords in groups of %2.0f (method: %s)',opts_disp.dim_select,opts_disp.coord_group_size,opts_disp.coord_group_method);
        aux_out_custproj{igroup,imethod}=rs_disp_coordsets(data_components,setfield(aux_nocust,'opts_disp',opts_disp));
    end
end
%
