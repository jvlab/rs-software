# rs_read_coorddata_demo_opposites
Read coordinate data and create a dataset structure in a domain with stimulus coordinates

data file: 16 stimuli, 3 pairs of opposites
also demonstrates interactive choice of files
also demonstates quadratic form model

'which_read' and 'if_builtin' are read from the workspace when they are already defined,
and requested at the console otherwise. That is how rs_disp_coordsets_demo_opposites runs
this script unattended when it needs the data.

See also:  [rs_read_coorddata](rs_read_coorddata.md), [rs_get_coordsets](rs_get_coordsets.md), [rs_concat_coordsets](rs_concat_coordsets.md)

```matlab
opposite_coords=[...
 0.0,  0.0,  0.0;... %neutral
-3.0,  0.0,  0.0;... %never
-2.5,  0.0,  0.0;... %rare
 1.0,  0.0,  0.0;... %often
 2.0,  0.0,  0.0;... %usually
 3.0,  0.0,  0.0;... %always
 0.0, -3.0,  0.0;... %terrible
 0.0, -2.2,  0.0;... %bad
 0.0,  0.5,  0.0;... %ok
 0.0,  1.0,  0.0;... %good
 0.0,  2.0,  0.0;... %great
 0.0,  4.0,  0.0;... %excellent
 0.0,  0.0, -3.0;... %frigid
 0.0,  0.0, -2.0;... %cold
 0.0,  0.0,  1.5;... %warm
 0.0,  2.0,  3.0];   %hot
```

```matlab
disp('1-> read data files sequentially with rs_read_coorddata');
disp('2-> read several data files at once with rs_get_coordsets');
disp('3-> read several datasets created with quadratic form models with rs_get_coordsets');
disp('4-> read mix of data files and datasets created with quadratic form models with rs_get_coordsets');
if ~exist('which_read') which_read=getinp('choice','d',[1 4],1); end
if ~exist('if_builtin') if_builtin=getinp('1 for built-in file names, 0 to specify via gui','d',[0 1],1); end
```

Output:

```text
1-> read data files sequentially with rs_read_coorddata
2-> read several data files at once with rs_get_coordsets
3-> read several datasets created with quadratic form models with rs_get_coordsets
4-> read mix of data files and datasets created with quadratic form models with rs_get_coordsets
Enter choice (range: 1 to 4, default= 1):1
Enter 1 for built-in file names, 0 to specify via gui (range: 0 to 1, default= 1):1
```

```matlab
if ~exist('datafile_names')
    datafile_names={'demos/opposites_coords_FG','demos/opposites_coords_PQ','demos/opposites_coords_UV'}; %coordinate file names
end
```

```matlab
if ~exist('qformfile_name')
    qformfile_name='demos/opposites_qform_example'; %example quadratic form model file
end
```

```matlab
nfiles=length(datafile_names);
```

set up options for reading

```matlab
if ~exist('opts_read')
    opts_read=struct;
end
opts_read.paradigm_type_def='opposites';
opts_read.domain_list_def={'cars','boats','opposites','sizes'};
opts_read.need_setup_file=0;
opts_read.type_coords=opposite_coords;
opts_read=filldefault(opts_read,'if_auto',1); %can set to 0 for interactive
```

```matlab
if ~exist('opts_qpred')
    opts_qpred=struct;
end
if ismember(which_read,[3 4]) %quadratic form model
    opts_qpred.qform_datafile_def=qformfile_name;
    load(qformfile_name,'r');
    for k=1:length(r)
        disp(sprintf('%1.0f->%s',k,r{k}.setup.label));
    end
    opts_qpred.qform_modeltype=getinp(sprintf('%1.0f model types',nfiles),'d',[1 length(r)],mod([1:nfiles]-1,length(r))+1);
end
aux.opts_read=opts_read;
aux.opts_qpred=opts_qpred;
```

```matlab
switch which_read
    case 1
        data_set=cell(nfiles,1);
        aux_out=cell(nfiles,1);
        for ifile=1:nfiles
            if if_builtin
                fn=datafile_names{ifile};
            else
                fn=[];
            end
            [data_set{ifile},aux_out{ifile}]=rs_read_coorddata(fn,aux);
```

concatenate

```matlab
if ifile==1
                data_out=data_set{ifile};
            else
                data_out=rs_concat_coordsets(data_out,data_set{ifile});
            end
        end
    case {2,3,4}
        aux.nsets=nfiles;
        if if_builtin
            fn=datafile_names;
        else
            fn=[];
        end
        switch which_read
            case 2
                aux.opts_read.input_type=1; %several data records
            case 3
                aux.opts_read.input_type=2; %several quadratic form models
            case 4
                aux.opts_read.input_type=0; %ask about input type
        end
        [data_out,aux_out{1}]=rs_get_coordsets(fn,aux);
end
```

Output:

```text
 16 different stimulus types found in  data file demos/opposites_coords_FG
 16 different stimulus types found in setup file [unused]
 16 of  16 labels found
coordinate sets with  1 to  3 dimensions read.
 16 different stimulus types found in  data file demos/opposites_coords_PQ
 16 different stimulus types found in setup file [unused]
 16 of  16 labels found
coordinate sets with  1 to  3 dimensions read.
 16 different stimulus types found in  data file demos/opposites_coords_UV
 16 different stimulus types found in setup file [unused]
 16 of  16 labels found
coordinate sets with  1 to  3 dimensions read.
```

```matlab
data_out
disp('can now display with rs_disp_coordsets_demo_opposites')
```

Output:

```text
data_out = 

  <a href="matlab:helpPopup('struct')" style="font-weight:bold">struct</a> with fields:

      ds: {{1x3 cell}  {1x3 cell}  {1x3 cell}}
     sas: {[1x1 struct]  [1x1 struct]  [1x1 struct]}
    sets: {[1x1 struct]  [1x1 struct]  [1x1 struct]}

can now display with rs_disp_coordsets_demo_opposites
```