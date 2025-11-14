% rs_disp_coordsets_demo: demonstrate display of datasets
% with several customizations, with and without rotating to consensus
%
%  See also:  RS_DISP_COORDSETS.
%
filenames={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S4','./samples/animals/image_coords_S5','./samples/animals/image_coords_S6'};
nfiles=length(filenames);
aux_in=struct;
aux_in.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_in.nsets=length(filenames);
%
[data_read,aux_read]=rs_get_coordsets(filenames,aux_in);
%
%plot raw data with no customization
%
aux_nocust=struct;
aux_out_nocust=rs_disp_coordsets(data_read,aux_nocust);
%
%now rotate data into a consensus, and use each component, aligned to consensus, for further plotting
%
aux_knit_def=struct;
[data_consensus,aux_knit]=rs_knit_coordsets(data_read,aux_knit_def);
data_components=aux_knit.components;
%
aux_knit_scale=struct;
aux_knit_scale.opts_knit.allow_scale=1;
[data_consensus_scale,aux_knit_scale]=rs_knit_coordsets(data_read,aux_knit_scale);
data_components_scale=aux_knit_scale.components;
%
aux_knit_normscale=struct;
aux_knit_normscale.opts_knit.allow_scale=1;
aux_knit_normscale.opts_knit.if_normscale=1;
[data_consensus_normscale,aux_knit_normscale]=rs_knit_coordsets(data_read,aux_knit_normscale);
data_components_normscale=aux_knit_normscale.components;
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
%large  plot, adding the consensus, and showing connections to the consensus 
% first, append the components to the consensus
%
%customize the display options
opts_disp_conn=struct;
for ifile=1:nfiles
    opts_disp_conn.set_labels{ifile}=data_read.sets{ifile}.subj_id;
end
opts_disp_conn.set_labels{nfiles+1}='consensus';
opts_disp_conn.coord_group_method='onlylowest';
opts_disp_conn.set_markers=cellstr(strvcat(repmat('.',nfiles,1),'x'))'; %consensus plotted with x
opts_disp_conn.connect_sets_method='star_last';
opts_disp_conn.connect_sets_color_mode='split';
%
ncols=3; %noscale, scale, scale and normalize
%3-d coord sets
hfig=figure;
opts_disp_conn.dim_select=3;
set(hfig,'Position',[100 100 1400 800]);
set(hfig,'Name','comparison, 3 dims');
set(hfig,'NumberTitle','off');
%
for iscale=1:ncols
    switch iscale
        case 1
            data_all=data_components;
            data_c=data_consensus;
            subtitle='no scaling';
        case 2
            data_all=data_components_scale;
            data_c=data_consensus_scale;
            subtitle='scaling';
        case 3
            data_all=data_components_normscale;
            data_c=data_consensus_normscale;
            subtitle='scaling, normalized';
    end
    data_all.ds{nfiles+1}=data_c.ds{1};
    data_all.sas{nfiles+1}=data_c.sas{1};
    data_all.sets{nfiles+1}=data_c.sets{1};
    if iscale==2
        opts_disp_conn.if_legend=0; %show with legend suppressed
    else
        opts_disp_conn.if_legend=1;
    end
    opts_disp_conn.fig_handle=hfig;
    opts_disp_conn.axis_handles{1}=subplot(1,ncols,iscale);
    aux_out_conn=rs_disp_coordsets(data_all,setfield(aux_nocust,'opts_disp',opts_disp_conn));
    subplot(1,ncols,iscale);
    title(subtitle);
end
%
%4-d coord sets
hfig=figure;
opts_disp_conn.dim_select=4;
set(hfig,'Position',[100 100 1400 800]);
set(hfig,'Name','comparison, 4 dims');
set(hfig,'NumberTitle','off');
for iscale=1:ncols
    switch iscale
        case 1
            data_all=data_components;
            data_c=data_consensus;
            subtitle='no scaling';
        case 2
            data_all=data_components_scale;
            data_c=data_consensus_scale;
            subtitle='scaling';
        case 3
            data_all=data_components_normscale;
            data_c=data_consensus_normscale;
            subtitle='scaling, normalized';
    end
    data_all.ds{nfiles+1}=data_c.ds{1};
    data_all.sas{nfiles+1}=data_c.sas{1};
    data_all.sets{nfiles+1}=data_c.sets{1};
    if iscale==2
        opts_disp_conn.if_legend=0; %show with legend suppressed
    else
        opts_disp_conn.if_legend=1;
    end
    opts_disp_conn.fig_handle=hfig;
    opts_disp_conn.axis_handles{1}=subplot(2,ncols,iscale);
    opts_disp_conn.axis_handles{2}=subplot(2,ncols,iscale+ncols);
    opts_disp_conn.coord_group_method='list';
    opts_disp_conn.coord_groups=[[1 2 3];[1 2 4]];
    aux_out_conn=rs_disp_coordsets(data_all,setfield(aux_nocust,'opts_disp',opts_disp_conn));
    subplot(2,ncols,iscale);
    title(subtitle);
end
%
%plots with multiple customizations, just for demonstration
%
opts_disp2=struct;
opts_disp2.fig_name='highly customized';
opts_disp2.dim_select=5;
opts_disp2.set_select=[1 3 4];
opts_disp2.fig_position=[50 150 1400 700];
opts_disp2.axis_font_size=9;
opts_disp2.axis_label_font_size=7;
opts_disp2.axis_label_prefix='d';
opts_disp2.set_colors={'g',[.5 .5 0],[.5 0 .7],[.8 .2 .1]};
opts_disp2.set_markers={'*','o','x','.'};
opts_disp2.set_markersizes=[7 8 9 10];
opts_disp2.set_labels={'s1','s2','s3','s4'};
opts_disp2.connect_set_linestyles={':','-',':','--'};
opts_disp2.connect_set_linewidths=[2 1 1]; %will cycle
opts_disp2.coord_group_size=3;
opts_disp2.coord_group_method='list';
opts_disp2.coord_groups=[[1 2 3];[1 2 3];[1 2 3];[1 2 3];[1 2 3];[1 2 3];[2 3 4];[1 2 5]];
opts_disp2.if_box=0;
opts_disp2.axis_view={3,[-37.5 30],[-47.5 30],[-27.5 30],[-37.5 10],2,3,3};
opts_disp2.axis_scales=3*[-1 2;-2 3;-4 5;-5 6;-6 7];
opts_disp2.axis_scale='list';
opts_disp2.legend_font_size=6;
opts_disp2.legend_location='SouthEast';
aux_out_custm=rs_disp_coordsets(data_components,setfield(aux_nocust,'opts_disp',opts_disp2));
