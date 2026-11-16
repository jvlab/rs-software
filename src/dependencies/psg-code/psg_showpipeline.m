function [depth_max,subfields,opts_used]=psg_showpipeline(pipeline,opts)
%[depth_max,subfields,opts_used]=psg_showpipeline(pipeline,opts) shows the contents of a pipeline field
% 
% pipeline: structure indicating processing path, typically a field ofsets
% opts: (can be omitted)
%   depth_limit: maximum depth (processing stages) to show, defaults to Inf
%   breadth_limit: maximum breadth (number of branches) to show, defaults to Inf
%   depth_current: current depth, should be 0 except on recursive calls
%   verbosity: 0 (brief), 1, or 2, defaults to 1
%   fields_expand: names of fields to expand, if present, defaults to {'opts','file_list'}
%      should be a structure or a 1-D cell, if verbosity>=1
%
% depth_max: maximum depth reached (cannot exceed opts.depth_limit)
% subfields: subfields that may have 'pipeline' inside
% opts_used: options used
%
if (nargin<=1)
    opts=struct;
end
opts=filldefault(opts,'depth_limit',Inf);
opts=filldefault(opts,'breadth_limit',Inf);
opts=filldefault(opts,'depth_current',0);
opts=filldefault(opts,'fields_expand',{'opts','file_list'});
opts=filldefault(opts,'verbosity',1);
depth=opts.depth_current;
subfields=cell(0);
opts_used=opts;
%
indent=repmat(' ',1,5*depth);
%
depth_max=opts.depth_current;
if opts.verbosity>=2
    disp(sprintf('%s pipeline: depth %1.0f',indent,depth));
end
%
if opts.depth_current>opts.depth_limit
    return
end
%disp(sprintf('pipeline at depth %1.0f',opts.depth_current));
if opts.verbosity>=1
    disp(pipeline);
else
    disp(sprintf('%s depth %1.0f, type %s',indent,depth,pipeline.type));
end
fields=fieldnames(pipeline);
for ifn=1:length(fields) %determine what fields to expand and to recurse on
    fn=fields{ifn};
    s=pipeline.(fn);
    if ~isempty(strmatch(fn,opts.fields_expand,'exact'))
        if opts.verbosity>=1
            if iscell(s)
                for k=1:length(s)
                    disp(' ');
                    disp(sprintf('%s contents of %s{%2.0f}:',indent,fn,k));
                    disp(s{k});
                end
            else
                disp(' ');
                disp(sprintf('%s contents of %s:',indent,fn));
                disp(s);
            end
        end
    end
    if isstruct(s)
        if isfield(s,'pipeline')
            subfields{end+1}=fn;
        end
    elseif iscell(s)
        if isfield(s{1},'pipeline')
            subfields{end+1}=fn;
        end
    end
end
if (opts.verbosity>=2)
    disp('subfields to examine')
    disp(subfields)
end
if (length(subfields)>0 & opts.depth_current<opts.depth_limit)
    header=cat(2,indent,sprintf('examining pipeline at depth %1.0f of',depth+1));
    for isf=1:length(subfields)
        sft=pipeline.(subfields{isf});
        leadin=cat(2,header,sprintf(' %s',subfields{isf}));
        if iscell(sft)
            for k=1:min(length(sft),opts.breadth_limit)
                pipe_recur=sft{k}.pipeline;
                if ~isempty(fieldnames(pipe_recur))
                    disp(' ');
                    disp(sprintf('%s: entry %2.0f of %2.0f',leadin,k,length(sft)))
                    dm=psg_showpipeline(pipe_recur,setfield(opts,'depth_current',depth+1));
                else
                    disp(sprintf('%s: entry %2.0f of %2.0f-> empty',leadin,k,length(sft)))
                    dm=depth+1;
                end
            end
        elseif isstruct(sft)
            pipe_recur=sft.(pipeline);
            if ~isempty(fieldnames(pipe_recur))
                disp(' ');
                disp(leadin);
                dm=psg_showpipeline(pipe_recur,setfield(opts,'depth_current',depth+1));
            else
                disp(sprintf('%s -> empty',leadin));
                dm=depth+1;
            end
        else
            error(' pipeline field not found');
        end
    end
    depth_max=dm;
end
return
