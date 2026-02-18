% rs_disp_coordsets_test1: demonstrate display of datasets with several customizations
%
% options illustrated:
%  sample datasets are rotated via PCA (in rs_knit_coordsets)
%  choice of dataset to label
%  choice of datasets to display
%  offsets between datasets
%  plots of selected subsets of ponints, each with own kind of line or marker
%  callouts for labels
%
%  See also:  RS_DISP_COORDSETS, RS_DISP_COORDSETS_DEMO, RS_DISP_COORDSETS_TEST2,RS_DISP_COORDSETS_TEST3.
%
%testing is in several sets, each of which contains (by rs_auto_test) one test, so ntests=1 but testset may be > 1
rs_module='disp_coordsets';
testset=1; 
ntests=1;
%
if ~exist('if_save_and_close')
    if_save_and_close=0;
end
if if_save_and_close==0
    if_save_and_close=getinp('1 to save and close all figures','d',[0 1]);
end
if if_save_and_close
    close all;
end
aux_outs=cell(1);
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
%plots with 2-d projection and 3-d projections of a 5-d model, with offsets
%and connections between datasets
%
dim_select=5;
group_size_list=[2:3];
coord_group_methods={'keeplow'};
%
opts_disp=struct;
opts_disp.dim_select=dim_select;
opts_disp.data_label_setsel_method='list';
opts_disp.data_label_setsel_list=2;
opts_disp.set_select=[1 2 4]; % datasets to show
opts_disp.set_offsets=repmat([0:nfiles-1]',1,dim_select)+repmat([1:dim_select]/2,nfiles,1);
opts_disp.connect_sets_method='list';
opts_disp.connect_sets_list=[2 4];
opts_disp.connect_sets_color_mode='split';
%offsets, connections between datasets
aux_outs{1}.aux_out_disp=cell(length(group_size_list),length(coord_group_methods));
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
        aux_outs{1}.aux_out_disp{igroup,imethod}=rs_disp_coordsets(data_components,setfield(struct,'opts_disp',opts_disp));
    end
end
%
%plots with 2-d projection and 3-d projections of a 5-d model, with offsets
%and connections between datasets, but only plot a subset of points
%
opts_disp2=opts_disp;
opts_disp2=rmfield(opts_disp2,'set_offsets');
opts_disp2.connect_sets_method='chain';
opts_disp2.connect_sets_color_mode='first';
opts_disp2.coord_group_method='list';
opts_disp2.coord_groups=[2 3 5];
opts_disp2.coord_group_size=3;
opts_disp2.data_show_method='list';
opts_disp2.data_show_list=[4:2:28];
opts_disp2.if_legend=1;
opts_disp2.fig_name=sprintf('consensus dim %2.0f: coords in groups of %2.0f (method: %s)',opts_disp2.dim_select,opts_disp2.coord_group_size,opts_disp2.coord_group_method);
aux_outs{1}.aux_out_disp2=rs_disp_coordsets(data_components,setfield(struct,'opts_disp',opts_disp2));
%
% repeated plots into same axis, with different subsets of data and different colors and symbols
% 
filename_rep={'./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat'};
nsets=length(filename_rep);
aux_rep=struct;
aux_rep.nsets=1;
aux_rep.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
[data_rep,aux_read_rep]=rs_get_coordsets(filename_rep,aux_rep);
hfig=figure;
set(gcf,'Position',[100 100 1200 700]);
set(gcf,'Numbertitle','off');
set(gcf,'Name','selected subsets of data points');
hax=cell(1,1);
hax{1}=subplot(1,1,1);
opts_disp_rep=struct;
opts_disp_rep.dim_select=3;
opts_disp_rep.fig_handle=hfig;
opts_disp_rep.axis_handles=hax(1);
opts_disp_rep.if_legend=1;
typenames=data_rep.sas{1}.typenames;
opts_disp_rep.data_show_method='list';
%define subsets
subs{1}.string='bp';
subs{1}.set_colors='b';
subs{1}.set_markers='+';
subs{1}.line_style='-';
subs{2}.string='bm';
subs{2}.set_colors='b';
subs{2}.set_markers='*';
subs{2}.line_style=':';
subs{3}.string='ap';
subs{3}.set_colors='r';
subs{3}.set_markers='+';
subs{3}.line_style='-';
subs{4}.string='rand';
subs{4}.set_colors='k';
subs{4}.set_markers='o';
subs{4}.line_style='none';
subs{5}.string='am';
subs{5}.set_colors='r';
subs{5}.set_markers='*';
subs{5}.line_style=':';
%
opts_disp_rep.connect_data_method='chain';
opts_disp_rep.callout_amount=0.5;
%
for isubs=1:length(subs)
    opts_disp_rep.set_colors=subs{isubs}.set_colors;
    opts_disp_rep.set_markers=subs{isubs}.set_markers;
    opts_disp_rep.data_show_list=find(contains(typenames,subs{isubs}.string));
    opts_disp_rep.connect_data_linestyles=subs{isubs}.line_style;
    opts_disp_rep.set_labels=subs{isubs}.string; %only one dataset
    opts_disp_rep.set_tags=subs{isubs}.string; %so that only some components will be in legend
    opts_disp_rep.legend_tags={'b','a'}; %what is in the legend
    if contains(subs{isubs}.string,'m')
        opts_disp_rep.callout_linestyles={'--'}; %callout line style is -- for am and bm
    elseif strcmp(subs{isubs}.line_style,'none')
        opts_disp_rep=rmfield(opts_disp_rep,'callout_linestyles'); %default callout line style if no line for connectoin
    else
        opts_disp_rep.callout_linestyles=opts_disp_rep.connect_data_linestyles; 
    end
    if contains(subs{isubs}.string,'b')
        opts_disp_rep.callout_linewidths=2; %thicker lines for callouts for b
    end
    opts_disp_rep.callout_colors=opts_disp_rep.set_colors; %use data colors for callouts
    opts_disp_rep.connect_data_linewidths=3;
    aux_outs{1}.aux_rep_disp=rs_disp_coordsets(data_rep,setfield(struct,'opts_disp',opts_disp_rep));
end
if if_save_and_close
    rs_save_figs(sprintf('./tests/rs_disp_coordsets_testset%1.0f',testset),'all',setfield(struct(),'if_log',1));
else
    getinp('1 when ready to close and compare','d',[1 1],1);
end
close all;
%
fns{1}=sprintf('rs_%s_testset%1.0f',rs_module,testset);
s=struct;
s.aux_out=aux_outs;
rs_save_mat(cat(2,'tests',filesep,fns{1}),s);
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
disp(sprintf('testing rs_%s: %s',rs_module,sprintf('testset %1.0f',testset)));
opts_compare=struct;
[ifdif{1},opts_used{1}]=rs_benchmark_compare(fns{1},opts_compare);
