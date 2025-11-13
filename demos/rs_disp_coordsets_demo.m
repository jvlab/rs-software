% rs_disp_coordsets_demo: demonstrate display of datasets
%
%  See also:  RS_DISP_COORDSETS.
%
%
%totally un-customized version
%
%
filenames={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S4','./samples/animals/image_coords_S5','./samples/animals/image_coords_S6'};
aux_in=struct;
aux_in.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_in.nsets=length(filenames);
%
[data_read,aux_read]=rs_get_coordsets(filenames,aux_in);
%
%plots with no customization
%
aux_nocust=struct;
aux_out_nocust=rs_disp_coordsets(data_read,aux_nocust);
%
%plots with 2-d projection and 3-d projections of a 5-d model
%
dim_select=5;
group_size_list=[2:3];
coord_group_methods={'all','keepone','rolling'};
%
opts_disp=struct;
opts_disp.dim_select=dim_select;
aux_out_custproj=cell(length(group_size_list),length(coord_group_methods));
for igroup=1:length(group_size_list)
    opts_disp.coord_group_size=group_size_list(igroup);
    for imethod=1:length(coord_group_methods)
        opts_disp.coord_group_method=coord_group_methods{imethod};
        opts_disp.fig_name=sprintf('dim %2.0f: coords in groups of %2.0f (method: %s)',opts_disp.dim_select,opts_disp.coord_group_size,opts_disp.coord_group_method);
        aux_out_custproj{igroup,imethod}=rs_disp_coordsets(data_read,setfield(aux_nocust,'opts_disp',opts_disp));
    end
end
%
%plots with multiple customizations, just for demonstration
%
opts_disp2=struct;
opts_disp2.dim_select=5;
opts_disp2.set_select=[1 3 4];
opts_disp2.fig_position=[50 150 1400 700];
opts_disp2.axis_font_size=9;
opts_disp2.axis_label_font_size=7;
opts_disp2.axis_label_prefix='d';
opts_disp2.set_colors={'g',[.5 .5 0],[.5 0 .7],[.8 .2 .1]};
opts_disp2.set_markers={'*','o','x','.'};
opts_disp2.set_markersizes=[7 8 9 10];
opts_disp2.set_linestyles={':','-',':','--'};
opts_disp2.set_linewidths=[2 1 1]; %will cycle
opts_disp2.set_labels={'s1','s2','s3','s4'};
opts_disp2.coord_group_size=3;
opts_disp2.coord_group_method='list';
opts_disp2.coord_groups=[[1 2 3];[1 2 3];[1 2 3];[2 3 4];[1 2 5]];
opts_disp2.if_box=0;
aux_out_custm=rs_disp_coordsets(data_read,setfield(aux_nocust,'opts_disp',opts_disp2));
