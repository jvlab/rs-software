function depth_max=rs_showpipeline(pipeline,opts)
%depth_max=rs_showpipeline(pipeline,opts) shows the contents of a pipeline field
% 
% pipeline: structure indicating processing path, typically a field of sets
% opts: (can be omitted)
%   depth_limit: maximum depth (processing stages) to show, defaults to Inf
%   fields_expand: names of fields to expand, if present, defaults to {'opts','file_list'}
%     could add 'sets','sets_combined'
%
% depth_max: maximum depth reached (cannot exceed opts.depth_limit)
%
%   see also:  PSG_SHOWPIPELINE
%
if nargin<=1
    opts=struct;
end
depth_max=psg_showpipeline(pipeline,opts);
return
end
