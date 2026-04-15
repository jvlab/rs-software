# rs_disp_coordsets_demo
Simple display of coordinate sets

Workflow:

 - data files are read
  -data are displayed

Plot options illustrated:

 - custom labeling of datasets based on subject ID
 - custom interpreter for stimuus labels and legend
 - basic plots of rays

See also:  [rs_get_coordsets](rs_get_coordsets.md), [rs_disp_coordsets](rs_disp_coordsets.md), [rs_disp_enh_coordsets](rs_disp_enh_coordsets.md)

```matlab
filenames={...
    './samples/animals/image_coords_S3',... %example 1: animal experiment image domain, Warich and Victor, J. Neurosci. 2024
    './samples/bwtextures/bgca3pt_coords_BL_sess01_10',...; %example 2: binary texture experiment, Victor and Conte, VSS 2025
    './samples/bwtextures/bgca3pt_coords_BL_sess01_10',...; %example 3: binary texture experiment, Victor and Conte, VSS 2025, quadratic form model
    './samples/faces/faces_mpi_en2_fc_coords_MC_sess01_10',...; %example 4: MPI faces dataset, Ebner, N. C., Riediger, M., & Lindenberger, U. (2010). FACES—A database of facial expressions in young, middle-aged, and older women and men: Development and validation. Behavior Research Methods, 42, 351-362. doi:10.3758/BRM.42.1.351
    './samples/material/mater-orig-bw_coords_MC_sess01_10',...; %example 5: materials preliminary data
    './samples/color/irgb_test25distrib_coords_XX_sess01_10'}; %example 6: color textures, simulated data
nex=length(filenames);
```

```matlab
aux_in=cell(1,nex);
data_read=cell(1,nex);
aux_read=cell(1,nex);
```

```matlab
opts_disp=cell(1,nex);
aux_out=cell(1,nex);
opts_disp_enh=cell(1,nex);
aux_out_enh=cell(1,nex);
for iex=1:nex
    disp('************** ');
    disp(sprintf(' example %2.0f',iex));
    aux_in{iex}=struct;
    aux_in{iex}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1}); %input type 1=data, if_auto=1: non-interactive, if_log=1 to log
    aux_in{iex}.nsets=1;
    if_enh=0;
    paradigm_type_assert=[];
    typename_prefix=[];
    opts_disp{iex}=struct;
    opts_disp_enh{iex}=struct;
    switch iex %handle exceptions
        case 2 % binary textures, data
            if_enh=1; %also do enhanced plot
            opts_disp_enh{iex}.if_points=0;
        case 3 % binary textures, quadratic model
            aux_in{iex}.opts_read.input_type=2; %model
            if_enh=1; %also do enhanced plot
            paradigm_type_assert='btc';
            opts_disp_enh{iex}.if_points=0;
        case 4 %faces
            if_enh=1;
            aux_in{iex}.opts_rays.ray_minpts=1; %single points can define a ray
            opts_disp{iex}.data_label_interpreter='none';
            opts_disp{iex}.legend_interpreter='none';
            opts_disp_enh{iex}.if_points=0;
        case 5 %materials
            typename_prefix='mater-orig-bw-orig-';
        case 6 %color
            typename_prefix='random_';
    end
```

read the coordinates and metadata

```matlab
[data_read{iex},aux_read{iex}]=rs_get_coordsets(filenames{iex},aux_in{iex});
    if ~isempty(paradigm_type_assert) %optionally assert paradigm type
        data_read{iex}.sets{1}.paradigm_type=paradigm_type_assert;
    end
    if ~isempty(typename_prefix) %optionally shorten typenames
        data_read{iex}.sas{1}.typenames=strrep(data_read{iex}.sas{1}.typenames,typename_prefix,'');
    end
    disp(data_read{iex}.sets{1});
    subj_id=data_read{iex}.sets{1}.subj_id;
    opts_disp{iex}.set_labels=data_read{iex}.sets{1}.subj_id;
```

plot

```matlab
aux_out{iex}=rs_disp_coordsets(data_read{iex},setfield(struct,'opts_disp',opts_disp{iex})); %create the plot
```

enhanced plot

```matlab
if if_enh
        aux_out_enh{iex}=rs_disp_enh_coordsets(data_read{iex},setfields(struct,{'opts_disp','opts_disp_enh'},{opts_disp{iex},opts_disp_enh{iex}}),aux_read{iex}.rayss{1});
    end
end
```