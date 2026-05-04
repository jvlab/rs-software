%rs_read_coorddata_demo_opposites: 
% demonstration of reading a generic coordinate file in a structured domain
% data file: 37 stimuli, automobile names, with random coordinates for model dimensions 1,2,3, and 4
%
%
% ans =
%          0         0         0
%    -3.0000         0         0
%    -2.5000         0         0
%     1.0000         0         0
%     2.0000         0         0
%     3.0000         0         0
%          0   -3.0000         0
%          0   -2.2000         0
%          0    0.5000         0
%          0    1.0000         0
%          0    2.0000         0
%          0    4.0000         0
%          0         0   -3.0000
%          0         0   -2.0000
%          0         0    1.5000
%          0    2.0000    3.0000
% stim_labels
% ans =
%   16×9 char array
%     'neutral  '
%     'never    '
%     'rare     '
%     'often    '
%     'usually  '
%     'always   '
%     'terrible '
%     'bad      '
%     'ok       '
%     'good     '
%     'great    '
%     'excellent'
%     'frigid   '
%     'cold     '
%     'warm     '
%     'hot      '
% 
fullname='demos/opposites_coords_FG'; %mat-file name
aux.opts_read.domain_sigma=struct;
aux.opts_read.paradigm_type_def='opposites';
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
disp('can now display with rs_disp_coordsets_demo_opposites')
