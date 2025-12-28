% rs_disp_coordsets_demo: demonstrate display of several datasets and their consensus
% 
% data are plotted with and without rotating to consensus
%
% plot options illustrated:
%  choice of dimension and coordinates to plot
%  several plots into same figure
%  selective datapoint labelling with custom callouts
%  custom arrangement of subplots
%  rotation of raw data coordinates into a consensus
%  combining consensus and individual datasets on same plot
%  custom data point symbols
%  custom axis labels
%  connecting corresponding points between plots
%  selection of data points to label based on length of stimulus name
%
%  See also:  RS_DISP_COORDSETS, RS_DISP_COORDSETS_DEMO2, RS_DISP_COORDSETS_DEMO3.
%
filenames={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S4','./samples/animals/image_coords_S5','./samples/animals/image_coords_S6'};
nsets=length(filenames);
aux_in=struct;
aux_in.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_in.nsets=nsets;
%
[data_read,aux_read]=rs_get_coordsets(filenames,aux_in);
subj_ids=cell(1,nsets);
for iset=1:nsets
    subj_ids{iset}=data_read.sets{iset}.subj_id;
end
nstims=data_read.sas{iset}.nstims;
label_maxlength=5; %max length of a stimulus label
data_label_list=[];
for istim=1:nstims
    if length(data_read.sas{1}.typenames{istim})<=label_maxlength
        data_label_list(end+1)=istim;
    end
end
%
coord_groups=[1 2 3;2 3 4]; %coords to plot
ngroups=size(coord_groups,1);
%
hfig=figure;
opts_disp_raw=struct;
%
opts_disp_raw.fig_handle=hfig;
opts_disp_raw.fig_position=[100 100 1200 800];
opts_disp_raw.fig_name='raw data';
opts_disp_raw.dim_select=4;
opts_disp_raw.coord_group_size=3;
opts_disp_raw.coord_group_method='list';
opts_disp_raw.coord_groups=coord_groups;
opts_disp_raw.set_labels=subj_ids;
opts_disp_raw.data_label_method='list';
opts_disp_raw.data_label_list=data_label_list;
opts_disp_raw.callout_amount=0.3;
opts_disp_raw.callout_colors='set_colors';
opts_disp_raw.callout_linestyles='-';
opts_disp_raw.legend_location='North';
%
aux_out_raw=cell(1,ngroups);
haxes=cell(1,ngroups);
for iset=1:nsets
    for igroup=1:2 %set up subplots
        haxes{igroup}=subplot(ngroups,nsets,iset+(igroup-1)*nsets);
    end
    opts_disp_raw.axis_handles=haxes;
    opts_disp_raw.set_select=iset;
    aux_out_raw{iset}=rs_disp_coordsets(data_read,setfield(struct,'opts_disp',opts_disp_raw));
end
%
%align data, rotate data into a consensus, and use each component, aligned to consensus, for further plotting
%
aux_align_def=struct;
[data_align,aux_align]=rs_align_coordsets(data_read,aux_align_def);
aux_knit_def=struct;
[data_consensus,aux_knit]=rs_knit_coordsets(data_align,aux_knit_def);
data_label_list_consensus=[]; %stimulus order may havbe changed, so need to re-identify the stimuli
for istim=1:nstims
    if length(data_consensus.sas{1}.typenames{istim})<=label_maxlength
        data_label_list_consensus(end+1)=istim;
    end
end
%
opts_disp_cons=opts_disp_raw; %many options match the raw plot
opts_disp_cons=rmfield(opts_disp_cons,'fig_handle'); %new figure
opts_disp_raw.fig_position=[80 100 1400 800];
opts_disp_cons=rmfield(opts_disp_cons,'axis_handles');
opts_disp_cons.fig_name='consensus';
opts_disp_cons.set_select=[1:nsets+1];
opts_disp_cons.axis_label_prefix='cons dim';
opts_disp_cons.data_label_list=data_label_list_consensus;
%concatenate the comnponent data and the consensus
data_cons=aux_knit.components;
data_cons.ds{nsets+1}=data_consensus.ds{1};
data_cons.sas{nsets+1}=data_consensus.sas{1};
data_cons.sets{nsets+1}=data_consensus.sets{1};
opts_disp_cons.set_labels{nsets+1}='consensus';
opts_disp_cons.connect_sets_method='star_last';
for k=1:nsets
    opts_disp_cons.set_markers{k}='.';
end
opts_disp_cons.set_markers{nsets+1}='*';
opts_disp_cons.data_label_setsel_method='last';
opts_disp_raw.callout_amount=1.0;
%
rs_disp_coordsets(data_cons,setfield(struct,'opts_disp',opts_disp_cons));
