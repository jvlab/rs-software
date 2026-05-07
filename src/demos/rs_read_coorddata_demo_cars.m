%rs_read_coorddata_demo_cars
% demonstration of reading a generic coordinate dataset in an unstructured domain
% data file: 37 stimuli, automobile names, with random coordinates for model dimensions 1,2,3, and 4
%
% See also:  RS_READ_COORDDATA.
%
fullname='demos/cars_coords_JK'; %mat-file name
aux.opts_read.paradigm_type_def='transport';
aux.opts_read.domain_list_def={'cars','boats','opposites','sizes'};
aux.opts_read.need_setup_file=0;
aux.opts_read.if_auto=1;
[data_out,aux_out]=rs_read_coorddata(fullname,aux);
data_out
aux_out
disp(' ');
disp('ds{1}: coordinate structure');
disp(data_out.ds{1});
disp(' ');
disp('sas{1}: stimulus metadata structure');
disp(data_out.sas{1});
disp(' ');
disp('sets{1}: set metadata structure');
disp(data_out.sets{1});
disp('can now display with rs_disp_coordsets_demo_cars')
