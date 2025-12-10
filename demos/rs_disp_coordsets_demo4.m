% rs_disp_coordsets_demo4: demonstrate display of datasets with rays
%
%  Note: when using data from components, rays also need to be taken from compoents
%
%   To do:
%    plot the grid (may need to eliminate pairs that are in rays)
%    demonstrate offset
%    better legend based on whether there are multiple subjects or one subject
%    plot fitted rays
%
%  See also:  RS_DISP_COORDSETS, RS_DISP_COORDSETS_DEMO, RS_DISP_COORDSETS_DEMO3,
%   PSG_TYPENAMES2COLORS.
%
if ~exist('filename_gps')
    filename_gps{1}={'./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat'};
    filename_gps{2}={'./samples/bwtextures/bcpm24pt_coords_MC_sess01_10.mat'};
    filename_gps{3}={'./samples/bwtextures/bcpp55qpt_coords_MC_sess01_10.mat'};
    filename_gps{4}={'./samples/bwtextures/dgea3pt_coords_MC_sess01_10.mat'};
    filename_gps{5}={...
        './samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat',...
        './samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat',...
        './samples/bwtextures/bgca3pt_coords_NF_sess01_10.mat'};
end
if ~exist('opts_tn2c') opts_tn2c=struct; end %for psg_typenames2colors
if ~exist('nvars') nvars=4; end %for variants such as with and without rings or axes
ngps=length(filename_gps);
aux_out_disp=cell(nvars,2,ngps); %dim 2 is if_pca+1
%
gp_list=getinp('group list','d',[1 ngps]);
for igp_ptr=1:length(gp_list)
    igp=gp_list(igp_ptr);
    filenames=filename_gps{igp};
    nfiles=length(filenames);
    aux_in=struct;
    aux_in.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,0});
    aux_in.nsets=nfiles;
    disp(sprintf(' group %1.0f: %2.0f files',igp,nfiles))
    [data_read,aux_read]=rs_get_coordsets(filenames,aux_in);
    if_ok=1;
    for ifile=1:nfiles
        rays=aux_read.rayss{ifile};
        if isempty(rays)
            disp(sprintf(' file %1.0f: %70s: ray structure not created',ifile,filenames{ifile}))
            if_ok=0;
        else
            disp(sprintf(' file %1.0f: %70s: %3.0f rays, %3.0f rings, %3.0f pairs',ifile,filenames{ifile},rays.nrays,rays.nrings,rays.npairs))
        end
    end
    if (if_ok)
        %
        aux_align_def=struct;
        aux_align_def.opts_align.if_log=0;
        [data_align,aux_align]=rs_align_coordsets(data_read,aux_align_def);
        aux_knit_def=struct;
        aux_knit_def.opts_knit.if_log=0;
        aux_knit_def.opts_knit.if_pca=1; %rotate to PCA
        [data_consensus,aux_knit]=rs_knit_coordsets(data_align,aux_knit_def);
        %
        opts_disp=struct;
        opts_disp.fig_name=sprintf('group %1.0f: %s',igp,data_read.sets{1}.paradigm_name);
        for ifile=1:nfiles
            opts_disp.set_labels{ifile}=data_read.sets{ifile}.subj_id;
        end
        opts_disp.fig_handle=figure;
        set(gcf,'Name',opts_disp.fig_name);
        set(gcf,'Position',[50 100 1400 800]);
        set(gcf,'NumberTitle','off');       
        for ivar=1:nvars
            for if_pca=0:1
                opts_disp_var=opts_disp;
                if (if_pca==0)
                    data_disp=data_read;
                    rays_use=aux_read.rayss{1};
                else %use component data and rays
                    data_disp=aux_knit.components;
                    opts_disp_var.axis_label_prefix='pc';
                    opts_disp_var.connect_sets_method='all';
                    rays_use=aux_knit.rayss{1};
                end
                %set up plot options
                if (ivar>1)
                    opts_disp_var.data_label_method='none';
                end
                opts_disp_var.axis_handles{1}=subplot(2,nvars,ivar+nvars*if_pca);
                %
                %plot all points
                aux_out_disp{ivar,1+if_pca,igp}=struct;
                aux_out_disp{ivar,1+if_pca,igp}.all=rs_disp_coordsets(data_disp,setfield(struct,'opts_disp',opts_disp_var));
                %
                %then plot subsets
                aux_out_disp{ivar,1+if_pca,igp}.rays=cell(0);
                if (ivar>=2)%connect points along a ray
                    for iray=1:rays_use.nrays
                        opts_disp_rays=opts_disp_var;
                        opts_disp_rays.data_show_method='list';
                        orig_ptr=min(find(rays_use.whichray==0));
                        for isign=-1:2:1
                            bidir=find(rays_use.whichray==iray);
                            mults=rays_use.mult(bidir);
                            sign_sel=find(sign(mults)==isign);
                            if ~isempty(sign_sel)
                                bidir_sel=bidir(sign_sel);
                                mults_sel=mults(sign_sel);
                                mb_sorted=sort([abs(mults_sel(:)),bidir_sel],1,'ascend');
                                bidir_sorted=mb_sorted(:,2); %sorted in ascending order of magnitude
                                opts_disp_rays.data_show_list=[orig_ptr bidir_sorted']; %add origin to the beginning
                                opts_disp_rays.connect_data_method='chain';
                                [rgb,symb,vecs,opts_used]=psg_typenames2colors(data_disp.sas{1}.typenames(bidir_sorted),opts_tn2c); %get standard colors and symbols
                                opts_disp_rays.set_colors{1}=rgb;
                                opts_disp_rays.data_label_method='last';
                                opts_disp_rays.callout_amount=0.5;
                                opts_disp_rays.callout_colors{1}=rgb;
                                switch isign
                                    case 1
                                        opts_disp_rays.connect_data_linestyles='-';
                                    case -1
                                        opts_disp_rays.connect_data_linestyles='--';
                                end
                                opts_disp_rays.set_tags='ray'; %so that this will not be in legend
                                aux_out_disp{ivar,1+if_pca,igp}.rays{iray,(3+isign)/2}=rs_disp_coordsets(data_disp,setfield(struct,'opts_disp',opts_disp_rays));                                             
                            end %not empty
                        end %sign
                    end %iray
                end %ivar>=2
                aux_out_disp{ivar,1+if_pca,igp}.rings=cell(0);
                if (ivar>=3)%connect points on a ring
                    for iring=1:rays_use.nrings
                        ring_list=rays_use.rings{iring}.coord_ptrs;
                        ring_list_offset=[ring_list(2:end) ring_list(1)];
                        opts_disp_rings=opts_disp_var;
                        opts_disp_rings.data_show_method='list';
                        opts_disp_rings.data_show_list=ring_list;
                        opts_disp_rings.connect_data_method='list';
                        opts_disp_rings.connect_data_list=[ring_list(:),ring_list_offset(:)];
                        opts_disp_rings.connect_data_linestyles=':';
                        opts_disp_rings.set_tags='rings'; %so that this will not be in legend
                        aux_out_disp{ivar,1+if_pca,igp}.rings{iring}=rs_disp_coordsets(data_disp,setfield(struct,'opts_disp',opts_disp_rings));               
                    end %iray
                end %ivar>=2
            end 
        end %ivar
    end %if_ok
end %igp
% 
% %
% %align and rotate data into a consensus, and use each component, aligned to consensus, for further plotting
% %
% aux_align_def=struct;
% [data_align,aux_align]=rs_align_coordsets(data_read,aux_align_def);
% aux_knit_def=struct;
% aux_knit_def.opts_knit.if_pca=1; %rotate to PCA
% [data_consensus,aux_knit]=rs_knit_coordsets(data_align,aux_knit_def);
% data_components=aux_knit.components;
% %
% %plots with 2-d projection and 3-d projections of a 5-d model, with offsets
% %and connections between datasets
% %
% dim_select=5;
% group_size_list=[2:3];
% coord_group_methods={'keeplow'};
% %
% opts_disp=struct;
% opts_disp.dim_select=dim_select;
% opts_disp.data_label_setsel_method='list';
% opts_disp.data_label_setsel_list=2;
% opts_disp.set_select=[1 2 4]; % datasets to show
% opts_disp.set_offsets=repmat([0:nfiles-1]',1,dim_select)+repmat([1:dim_select]/2,nfiles,1);
% opts_disp.connect_sets_method='list';
% opts_disp.connect_sets_list=[2 4];
% opts_disp.connect_sets_color_mode='split';
% %offsets, connections between datasets
% aux_out_disp=cell(length(group_size_list),length(coord_group_methods));
% for igroup=1:length(group_size_list)
%     opts_disp.coord_group_size=group_size_list(igroup);
%     if opts_disp.coord_group_size==2
%         opts_disp.axis_scale='auto';
%     end
%     if opts_disp.coord_group_size==3
%         opts_disp.if_legend=-1;
%     end
%     for imethod=1:length(coord_group_methods)
%         opts_disp.coord_group_method=coord_group_methods{imethod};
%         opts_disp.fig_name=sprintf('consensus dim %2.0f: coords in groups of %2.0f (method: %s)',opts_disp.dim_select,opts_disp.coord_group_size,opts_disp.coord_group_method);
%         aux_out_disp{igroup,imethod}=rs_disp_coordsets(data_components,setfield(struct,'opts_disp',opts_disp));
%     end
% end
% %
% %plots with 2-d projection and 3-d projections of a 5-d model, with offsets
% %and connections between datasets, but only plot a subset of points
% %
% opts_disp2=opts_disp;
% opts_disp2=rmfield(opts_disp2,'set_offsets');
% opts_disp2.connect_sets_method='chain';
% opts_disp2.connect_sets_color_mode='first';
% opts_disp2.coord_group_method='list';
% opts_disp2.coord_groups=[2 3 5];
% opts_disp2.coord_group_size=3;
% opts_disp2.data_show_method='list';
% opts_disp2.data_show_list=[4:2:28];
% opts_disp2.if_legend=1;
% opts_disp2.fig_name=sprintf('consensus dim %2.0f: coords in groups of %2.0f (method: %s)',opts_disp2.dim_select,opts_disp2.coord_group_size,opts_disp2.coord_group_method);
% aux_out_disp2=rs_disp_coordsets(data_components,setfield(struct,'opts_disp',opts_disp2));
% %
% % repeated plots into same axis, with different subsets of data and different colors and symbols
% % 
% filename_rep={'./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat'};
% nsets=length(filename_rep);
% aux_rep=struct;
% aux_rep.nsets=1;
% aux_rep.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
% [data_rep,aux_read_rep]=rs_get_coordsets(filename_rep,aux_rep);
% hfig=figure;
% set(gcf,'Position',[100 100 1200 700]);
% set(gcf,'Numbertitle','off');
% set(gcf,'Name','selected subsets of data points');
% hax=cell(1,1);
% hax{1}=subplot(1,1,1);
% opts_disp_rep=struct;
% opts_disp_rep.dim_select=3;
% opts_disp_rep.fig_handle=hfig;
% opts_disp_rep.axis_handles=hax(1);
% opts_disp_rep.if_legend=1;
% typenames=data_rep.sas{1}.typenames;
% opts_disp_rep.data_show_method='list';
% %define subsets
% subs{1}.string='bp';
% subs{1}.set_colors='b';
% subs{1}.set_markers='+';
% subs{1}.line_style='-';
% subs{2}.string='bm';
% subs{2}.set_colors='b';
% subs{2}.set_markers='*';
% subs{2}.line_style=':';
% subs{3}.string='ap';
% subs{3}.set_colors='r';
% subs{3}.set_markers='+';
% subs{3}.line_style='-';
% subs{4}.string='rand';
% subs{4}.set_colors='k';
% subs{4}.set_markers='o';
% subs{4}.line_style='none';
% subs{5}.string='am';
% subs{5}.set_colors='r';
% subs{5}.set_markers='*';
% subs{5}.line_style=':';
% %
% opts_disp_rep.connect_data_method='chain';
% opts_disp_rep.callout_amount=0.5;
% %
% for isubs=1:length(subs)
%     opts_disp_rep.set_colors=subs{isubs}.set_colors;
%     opts_disp_rep.set_markers=subs{isubs}.set_markers;
%     opts_disp_rep.data_show_list=find(contains(typenames,subs{isubs}.string));
%     opts_disp_rep.connect_data_linestyles=subs{isubs}.line_style;
%     opts_disp_rep.set_labels=subs{isubs}.string; %only one dataset
%     opts_disp_rep.set_tags=subs{isubs}.string; %so that only some components will be in legend
%     opts_disp_rep.legend_tags={'b','a'}; %what is in the legend
%     if contains(subs{isubs}.string,'m')
%         opts_disp_rep.callout_linestyles={'--'}; %callout line style is -- for am and bm
%     elseif strcmp(subs{isubs}.line_style,'none')
%         opts_disp_rep=rmfield(opts_disp_rep,'callout_linestyles'); %default callout line style if no line for connectoin
%     else
%         opts_disp_rep.callout_linestyles=opts_disp_rep.connect_data_linestyles; 
%     end
%     if contains(subs{isubs}.string,'b')
%         opts_disp_rep.callout_linewidths=2; %thicker lines for callouts for b
%     end
%     opts_disp_rep.callout_colors=opts_disp_rep.set_colors; %use data colors for callouts
%     opts_disp_rep.connect_data_linewidths=3;
%     aux_rep_disp=rs_disp_coordsets(data_rep,setfield(struct,'opts_disp',opts_disp_rep));
% end
