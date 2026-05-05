%rs_read_coorddata_demo_opposites 
% demonstration of reading generic coordinate datasets in a structured domain
% data file: 16 stimuli, 3 pairs of opposites
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
fullnames={'demos/opposites_coords_FG','demos/opposites_coords_PQ','demos/opposites_coords_UV'}; %mat-file name
nfiles=length(fullnames);
%aux.opts_read.domain_sigma=struct;
aux.opts_read.paradigm_type_def='opposites';
aux.opts_read.domain_list_def={'cars','boats','opposites','sizes'};
aux.opts_read.need_setup_file=0;
aux.opts_read.type_coords=opposite_coords;
aux.opts_read.if_auto=1;
%
which_read=getinp('1 to read file by file with rs_read_coorddata, 2 to read via rs_get_coordsets, 3 to read quadratic form models','d',[1 3],1);
switch which_read
    case 1
        data_set=cell(nfiles,1);
        aux_out=cell(nfiles,1);
        for ifile=1:nfiles
            [data_set{ifile},aux_out{ifile}]=rs_read_coorddata(fullnames{ifile},aux);
            if ifile==1
                data_out=data_set{ifile};
            else
                data_out=rs_concat_coordsets(data_out,data_set{ifile});
            end
        end
    case 2
        aux.opts_read.input_type=1; %several data records
        aux.nsets=nfiles;
        [data_out,aux_out{1}]=rs_get_coordsets(fullnames,aux);
    case 3
        aux.opts_read.input_type=2; %several quadratic form models
        aux.nsets=nfiles;
        [data_out,aux_out{1}]=rs_get_coordsets(fullnames,aux);
end
%
data_out
disp('can now display with rs_disp_coordsets_demo_opposites')
