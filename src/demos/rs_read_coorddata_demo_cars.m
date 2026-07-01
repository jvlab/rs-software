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
% ```
%  37 different stimulus types found in  data file demos/cars_coords_JK
%  37 different stimulus types found in setup file [unused]
%  37 of  37 labels found
% coordinate sets with  1 to  4 dimensions read.
% ##### rs_warning: cannot find stimulus coordinates, so cannot identify rays
% ```
% The warning is expected, as these are categorical stimuli without order,
% so no order on a ray from the origin can be deduced.
%
% ## Outputs from `rs_read_coorddata`
% The function returns two cell arrays, `data_out` containing the data
data_out
% ```
%data_out = 
%
%  struct with fields:
%
%      ds: {{1×4 cell}}
%     sas: {[1×1 struct]}
%    sets: {[1×1 struct]}
%
%```
%
% and `aux_out` containing several options and arguments
aux_out
% 
% ```
% aux_out = 
%  struct with fields:
% 
%             warnings: 'cannot find stimulus coordinates, so cannot identify rays'
%             warn_bad: 0
%              if_warn: 1
%          warn_leadin: '##### rs_warning: '
%    if_warn_traceback: 0
%           opts_check: [1×1 struct]
%            opts_read: {[1×1 struct]}
%            opts_rays: {[1×1 struct]}
%                rayss: {[1×1 struct]}
%           opts_qpred: {[1×1 struct]}
%            syms_list: [1×1 struct]
% ```
%
% Inside `data_out`, we have a `coordinate structure`
disp(' ');
disp('ds{1}: coordinate structure');
disp(data_out.ds{1});
% ```
% ds{1}: coordinate structure
%    {37×1 double}    {37×2 double}    {37×3 double}    {37×4 double}
% ```
%
% a `stimulus metadata structure`
disp(' ');
disp('sas{1}: stimulus metadata structure');
disp(data_out.sas{1});
% ```
% sas{1}: stimulus metadata structure
%           nstims: 37
%        typenames: {37×1 cell}
%    btc_specoords: []
%      type_coords: []
%    paradigm_name: 'cars'
%       sigma_orig: 1
%       sigma_info: 'coordinates have been normalized to sigma=1'
% ```
%
% and a `set metadata structure`
disp(' ');
disp('sets{1}: set metadata structure');
disp(data_out.sets{1});
% ``` 
%sets{1}: set metadata structure
%             type: 'data'
%    paradigm_type: 'transport'
%    paradigm_name: 'cars'
%          subj_id: 'JK'
%    subj_id_short: 'JK'
%            extra: []
%         dim_list: [1 2 3 4]
%           nstims: 37
%       label_long: 'demos/cars_coords_JK'
%            label: 'demos/cars_JK'
%         pipeline: [1×1 struct]
% ```
%
% These outputs can be now be displated with `rs_disp_coordsets`. 
% The demo `rs_disp_coordsets_demo_cars` shows this.
