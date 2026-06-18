function optsused=filldefault(opts,names,val)
% optsused=filldefault(opts,names,val) fills an option structure with default values
%
% Args:
%   opts (struct): an option structure, possibly with some fields missing
%
%   names (char or char 2-D array): field name or names to be supplied with default values
%
%   val (int, float, char, cell, or struct): the value to use as default, for each field in 'names' that is not present in 'opts'
%
% Returns:
%   optsused (struct): opts, with missing fields filled in
% 
optsused=opts;
for iname=1:size(names,1)
    fieldname=deblank(names(iname,:));
    if (~isfield(opts,fieldname))
%        optsused=setfield(optsused,fieldname,val);
        optsused.(fieldname)=val;
    end
end
return
