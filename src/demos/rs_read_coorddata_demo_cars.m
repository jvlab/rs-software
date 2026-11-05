%rs_read_coorddata_demo_cars: read coordinate data and create a dataset structure in a domain without stimulus coordinates
% 
% This demo is meant to show how to read a `coordinate file` (mat-file)
% using `rs_read_coorddata`, and to explore what is returned by the function. 
% The output can be later fed into `rs_disp_coordsets` 
% for visualization or into other functions for further processing.
%
% The file contains a fictional dataset on cars. There are 37 stimuli
% (automobile names), with random coordinates for model dimensions 1, 2, 3,
% and 4.
%
% See also:  RS_READ_COORDDATA.
%
%
% ## Reading data from a mat-file
fullname='demos/cars_coords_JK'; %mat-file name

% ## Setting options
aux.opts_read.paradigm_type_def = 'transport';
aux.opts_read.domain_list_def = {'cars','boats','opposites','sizes'};
aux.opts_read.need_setup_file = 0;
aux.opts_read.if_auto = 1;

% ## Calling `rs_read_coorddata`
% This function will read the mat-file and return the appropiate 
% data structures to be passed to other functions
[data_out, aux_out] = rs_read_coorddata(fullname, aux);
% 
% The warning is expected, as these are categorical stimuli without order,
% so no order on a ray from the origin can be deduced.
%
% ## Outputs from `rs_read_coorddata`
% The function returns two cell arrays, `data_out` containing the data
data_out
%
% and `aux_out` containing several options and arguments
aux_out
% 
%
% Inside `data_out`, we have a `coordinate structure`
disp(' ');
disp('ds{1}: coordinate structure');
disp(data_out.ds{1})
%
% a `stimulus metadata structure`
disp(' ');
disp('sas{1}: stimulus metadata structure');
disp(data_out.sas{1})
%
% and a `set metadata structure`
disp(' ');
disp('sets{1}: set metadata structure');
disp(data_out.sets{1})
%
% These outputs can be now be displated with `rs_disp_coordsets`. 
% The demo `rs_disp_coordsets_demo_cars` shows this.
