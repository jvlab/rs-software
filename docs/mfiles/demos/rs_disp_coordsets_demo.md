# rs_disp_coordsets_demo
Demonstration workflow for display of several datasets and their consensus

Workflow:

 - data files are read
 - data files are aligned (coordinates each stimulus are placed in corresponding rows)
 - a consensus is calculated by rotating each dataset so that the coordinates are as closely matched as possible
 - the component datasets
 - the original data, the components, and the consensus are displayed

Plot options illustrated:

 - choice of dimension and coordinates to plot
 - several plots into same figure
 - selective datapoint labelling with custom callouts
 - custom arrangement of subplots
 - rotation of raw data coordinates into a consensus
 - combining consensus and individual datasets on same plot
 - custom data point symbols
 - custom axis labels
 - custom labeling of datasets based on subject ID
 - connecting corresponding points between plots
 - selection of data points to label based on length of stimulus name

See also:  [rs_get_coordsets](rs_get_coordsets.md), [rs_align_coordsets](rs_align_coordsets.md), [rs_knit_coordsets](rs_knit_coordsets.md), [rs_concat_coordsets](rs_concat_coordsets.md), [rs_disp_coordsets](rs_disp_coordsets.md)


## Read four datasets
Datasets are from four subjects of Warich and Victor, J. Neurosci. 2024

```matlab
filenames={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S4','./samples/animals/image_coords_S5','./samples/animals/image_coords_S6'};
nsets=length(filenames);
aux_in=struct;
aux_in.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1}); %input type 1=data, if_auto=1: non-interactive, if_log=1 to log
aux_in.nsets=nsets;
```

Read the coordinates of each dataset with `rs_get_coordsets`

```matlab
[data_read,aux_read]=rs_get_coordsets(filenames,aux_in);
subj_ids=cell(1,nsets);
for iset=1:nsets %extract the subject ids for plot labels
    subj_ids{iset}=data_read.sets{iset}.subj_id;
end
nstims=data_read.sas{1}.nstims; %number of stimuli; assume same in all sets
label_maxlength=5; %max length of a stimulus label
data_label_list=[];
for istim=1:nstims %create a list of short stimulus labels
    if length(data_read.sas{1}.typenames{istim})<=label_maxlength
        data_label_list(end+1)=istim;
    end
end
```

## Display the original data

```matlab
coord_groups=[1 2 3;2 3 4]; %make two 3-d plots, one with dimensions 1,2,3, one with dimensions 2,3,4
ngroups=size(coord_groups,1);%
hfig=figure; %open a figure for the plots
opts_disp_raw=struct;
opts_disp_raw.fig_handle=hfig;
opts_disp_raw.fig_position=[100 100 1200 800];
opts_disp_raw.fig_name='raw data';
opts_disp_raw.dim_select=4; %display coordinates for the 4-dimensional model
opts_disp_raw.coord_group_size=size(coord_groups,2); %display coordinates in groups of 3
opts_disp_raw.coord_group_method='list'; %we explictly list the coordinate groups
opts_disp_raw.coord_groups=coord_groups;
opts_disp_raw.set_labels=subj_ids; %label each plot with subject ID
opts_disp_raw.data_label_method='list'; %we provide a list for the labels for each data point
opts_disp_raw.data_label_list=data_label_list; %labels for each data point
opts_disp_raw.callout_amount=0.3; %labels are slightly removed from each data point
opts_disp_raw.callout_colors='set_colors'; %use the color assigned to each dataset for the callout lines
opts_disp_raw.callout_linestyles='-'; %dashed callout lines
opts_disp_raw.legend_location='North'; %legend location
```

```matlab
aux_out_raw=cell(1,ngroups);
haxes=cell(1,ngroups);
for iset=1:nsets
```

each call to rs_disp_coordsets will plot data from one subject, both coordinate groups

```matlab
for igroup=1:2 %set up subplots for this subject
        haxes{igroup}=subplot(ngroups,nsets,iset+(igroup-1)*nsets); %first row is first coord group, second row is second coord group
    end
    opts_disp_raw.axis_handles=haxes;
    opts_disp_raw.set_select=iset; %subject selection
    aux_out_raw{iset}=rs_disp_coordsets(data_read,setfield(struct,'opts_disp',opts_disp_raw)); %create the plot
end
```

align data, rotate data into a consensus, and use each component, aligned to consensus, for further plotting

```matlab
aux_align_def=struct;
[data_align,aux_align]=rs_align_coordsets(data_read,aux_align_def);
aux_knit_def=struct;
[data_consensus,aux_knit]=rs_knit_coordsets(data_align,aux_knit_def);
data_label_list_consensus=[]; %stimulus order may have changed, so need to re-identify the stimuli
for istim=1:nstims
    if length(data_consensus.sas{1}.typenames{istim})<=label_maxlength
        data_label_list_consensus(end+1)=istim;
    end
end
```

```matlab
opts_disp_cons=opts_disp_raw; %many options match the raw plot
opts_disp_cons=rmfield(opts_disp_cons,'fig_handle'); %new figure
opts_disp_raw.fig_position=[80 100 1400 800];
opts_disp_cons=rmfield(opts_disp_cons,'axis_handles');
opts_disp_cons.fig_name='consensus';
opts_disp_cons.set_select=[1:nsets+1];
opts_disp_cons.axis_label_prefix='cons dim';
opts_disp_cons.data_label_list=data_label_list_consensus;
```

concatenate the component data and the consensus

```matlab
data_cons=rs_concat_coordsets(aux_knit.components,data_consensus);
```

```matlab
opts_disp_cons.set_labels{nsets+1}='consensus';
opts_disp_cons.connect_sets_method='star_last';
for k=1:nsets
    opts_disp_cons.set_markers{k}='.';
end
opts_disp_cons.set_markers{nsets+1}='*';
opts_disp_cons.data_label_setsel_method='last';
opts_disp_raw.callout_amount=1.0;
```

```matlab
rs_disp_coordsets(data_cons,setfield(struct,'opts_disp',opts_disp_cons));
```