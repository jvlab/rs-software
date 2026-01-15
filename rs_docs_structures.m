%rs_docs_structures: documentation of key structures for the Representational Space package
%
% data:
%   data.ds{k}: [row] coordinate sets
%   data.sas{k}: [row] metadata
%
%     typenames: {25×1 cell} 
% 
%        nstims: 25
% btc_specoords: [25×10 double]
%   others are optional
    %       nchecks: 16
    %      nsubsamp: 9

    %         specs: {25×1 cell}
    %   spec_labels: {25×1 cell}
    %      opts_psg: [1×1 struct]
    %      btc_dict: [1×1 struct]
    % if_frozen_psg: 1
    % btc_augcoords: [25×10 double]


%   data.sets{k}: [row] metadata and audit trail
%
% sets{k} has the following fields.
% nstims and dim_list are determined from data.ds.
% pipeline is set to [] on a dataset that is imported by rs_import_coordsets or on initial reading by rs_get_coordsets or rs_read_coorddata
% Other fields are provided in rs_import_coordsets OR decoded from the file name in , they are decoded from the file name
%
% type: 'data' for raw data, 'model' for a computational model
% nstims: integer, number of stimuli
% dim_list: integer row array, list of dimensions of coordinate sets avilable in data.ds
% paradigm_type:
% paradigm_name: 
% subj_id
% subj_id_short
% extra: free text field
% label_long: dataset label, intended to indicate file of origin
% label: optional shorter form of label_long for display
% 
% data_out.sets{1}
% ans = 
%   struct with fields:
% 
%              type: 'data'
%     paradigm_type: 'btc'
%     paradigm_name: 'bgca3pt'
%           subj_id: 'MC-br'
%     subj_id_short: 'MC'
%             extra: 'sess01_10'
%          dim_list: [1 2 3 4 5 6 7]
%            nstims: 25
%        label_long: './samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat'
%             label: 'samples/bwtextures/bgca3pt_MC-br_sess01_10'
%          pipeline: [1×1 struct]
% load tests/rs_get_coordsets_test_4.mat
% data_out.sets{1}
% ans = 
%   struct with fields:
% 
%              type: 'data'
%     paradigm_type: 'animals'
%     paradigm_name: 'image'
%           subj_id: 'S3'
%     subj_id_short: 'S3'
%             extra: []
%          dim_list: [1 2 3 4 5 6 7]
%            nstims: 37
%        label_long: './samples/animals/image_coords_S3'
%             label: 'samples/animals/image_S3'
%          pipeline: [1×1 struct]
% %
% 
% pipeline: processing steps
%   This can be empty if the data file is created by rs_get_coordsets or rs_read_coorddata
%   pipeline.sets{1}: the 'sets' field of the dataset from which this dataset was derived
%       e.g., via a transformation
%   pipeline.sets_combined{:}: the 'sets' fields of one or more datasets that were used in combination
%      for this datsaset, e.g., the multiple sets that were aligned
%     both sets and sets_combined can be present.  For example, in an
%     alignment vi rs_align_coordsets, one dataset's cordinates are used, but the stimulus order,
%     and stimuli that are not present in the parent set but present in the ohter sets used for alignment,
%     are determined by sets_combined
%  type: 
%    'align': created by rs_align_coordsets, via aligning the stimuli of sets{1} with the union of stimuli
%      in sets_combined, and inserting NaN's in the coordiantes for missing stimuli
%    'knit':  created by rs_knit_coordsets via a Procrustes consensus of sets_combined{:}
%    'xform': created by rs_xform_apply, via aligning the stimuli of sets{1} with the union of stimuli
%      in sets_combined{:}, and inserting NaN's in the coordiantes for missing stimuli
%  opts: options used in the pipeline operation
%    type='xform:  opts_xform 
%    type='align': opts_align
%    type='knit':  opts_pcon, opts_knit
%
% The contents of pipeline can be displayed (recursively) with rs_showpipeline

