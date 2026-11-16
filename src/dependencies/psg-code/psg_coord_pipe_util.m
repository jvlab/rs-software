function pipeline=psg_coord_pipe_util(pipe_type,opts,sets,file_list,sets_combined)
% pipeline=psg_coord_pipe_util(pipe_type,opts,sets,file_list,sets_combined) is a
% utility to create the pipeline field.
%
% each of these input variables becomes the field of pipeline, with the
%   same name, except that 'type' is the field name for pipe_type
%   if sets is empty, file_list, or sets_combined are empty, those fields are not created -- but 
%   sets must be passed
% sets is the set field or a cell array of fields of the dataset(s) that are directly transformed into the new dataset. 
%    For 'consensus', it is empty, and the field is not created.
%    For 'knitted;, it contains all the datasets combined.
% file_list and sets_combined indicate the datasets that are used together
%    to create a new dataset for 'consensus' (and similar) or as a reference (for 'procrustes').
%    Both can be absent or omitted, e.g., for type='pca_rotation'
% 
% pipe_type: a string, no blanks
% opts: a structure
% sets: a structure
% file_list: a cell array of strings
% sets_combined: a cell array of structures like sets
%
% 22Mar24: change documentatuin to include use of file_list and sets_combined as a single reference
% 10Jun25: pipeline.sets forced to be a structure
%
% See also: PSG_COORD_PIPE_PROC, PSG_ALIGN_KNIT_DEMO.
%
if (nargin<=3)
    file_list=[];
    sets_combined=[];
end
pipeline=struct;
pipeline.type=pipe_type;
pipeline.opts=opts;
if ~isempty(sets)
    if ~iscell(sets)
        sets={sets};
    end
    pipeline.sets=sets;
end
if ~isempty(file_list)
    pipeline.file_list=file_list;
end
if ~isempty(sets_combined)
    pipeline.sets_combined=sets_combined;
end
return
