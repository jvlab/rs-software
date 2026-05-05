%rs_read_coorddata_demo_opposites 
% demonstration of reading generic coordinate datasets in a structured domain
% data file: 16 stimuli, 3 pairs of opposites
% 
% See also:  RS_READ_COORDDATA, RS_CONCAT_COORDSETS.
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
fullnames={'demos/opposites_coords_FG','demos/opposites_coords_PQ','demos/opposites_coords_UV'}; %mat-file name
nfiles=length(fullnames);
aux.opts_read.domain_sigma=struct;
aux.opts_read.paradigm_type_def='opposites';
aux.opts_read.domain_list_def={'cars','boats','opposites','sizes'};
aux.opts_read.need_setup_file=0;
aux.opts_read.if_auto=1;
%
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
data_out
disp('can now display with rs_disp_coordsets_demo_opposites')
