%rs_read_coorddata_demo_opposites 
% demonstration of reading generic coordinate datasets in a structured domain
% data file: 16 stimuli, 3 pairs of opposites
% also demonstrates interactive choice of files
% also demonstates quadratic form model
% 
% See also:  RS_READ_COORDDATA, RS_GET_COORDSETS, RS_CONCAT_COORDSETS.
%
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
% 
disp('1-> read data files sequentially with rs_read_coorddata');
disp('2-> read several data files at once with rs_get_coordsets');
disp('3-> read several datasets created with quadratic form models with rs_get_coordsets');
disp('4-> read mix of data files and datasets created with quadratic form models with rs_get_coordsets');
which_read=getinp('choice','d',[1 4],1);
if_builtin=getinp('1 for built-in file names, 0 to specify via gui','d',[0 1],1);
%
if ~exist('datafile_names')
    datafile_names={'demos/opposites_coords_FG','demos/opposites_coords_PQ','demos/opposites_coords_UV'}; %coordinate file names
end
%
if ~exist('qformfile_name')
    qformfile_name='demos/opposites_qform_example'; %example quadratic form model file
end
%
nfiles=length(datafile_names);
%
%set up options for reading
%
if ~exist('opts_read')
    opts_read=struct;
end
opts_read.paradigm_type_def='opposites';
opts_read.domain_list_def={'cars','boats','opposites','sizes'};
opts_read.need_setup_file=0;
opts_read.type_coords=opposite_coords;
opts_read=filldefault(opts_read,'if_auto',1); %can set to 0 for interactive
%
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
%
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
            %concatenate
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
%
data_out
disp('can now display with rs_disp_coordsets_demo_opposites')
