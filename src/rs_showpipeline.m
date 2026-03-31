function depth_max=rs_showpipeline(pipeline,opts)
%depth_max=rs_showpipeline(pipeline,opts)
% is a utility to show the pipeline field of a `set metadata structure`
% 
% The pipeline field tracks the processing steps leading to a `dataset structure`. 
% It may have subfields 'sets', indicating a single dataset that was modified to create this structure;
% 'sets_combined', indicating a group of datasets that were combined to create this structure;
% 'opts', the options used in the processing path; and
% 'file_list', the names of the files containing the data.
%
% Args:
%   pipeline (struct): the 'pipeline' field of a `set metadata structure
%   opts (struct): options, can be omitted, with fields
%
%      - depth_limit (int): maximum depth to show; defaults is Inf
%      - breadth_limit (int): maximum breadth (number of branches) to show if sets_combined is present; default is Inf
%      - verbosity (int): 0 (brief), 1, or 2; default is 1
%      - fields_expand (cell array of char): names of fields to expand;
%      defaults to {'opts','file_list'}; other fields that could be added are 'sets','sets_combined'
%
% Returns:
%   depth_max: maximum depth reached (cannot exceed opts.depth_limit)
%
%  See also:  PSG_SHOWPIPELINE.
%
if nargin<=1
    opts=struct;
end
opts=filldefault(opts,'depth_limit',Inf);
opts=filldefault(opts,'breadth_limit',Inf);
opts=filldefault(opts,'verbosity',1);
opts=filldefault(opts,'fields_expand',{'opts','file_list'});
depth_max=psg_showpipeline(pipeline,opts);
return
end
