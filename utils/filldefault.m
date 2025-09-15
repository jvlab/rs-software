function optsused=filldefault(opts,names,val)
% optsused=filldefault(opts,names,val) fills an option structure with default values
%
% opts: an option structure, possibly with some values missing
% names: a string, or, an strvcat(string1,string2,...) of field names
% val: the value to use as default, for each name that is missing
%
% 09Feb23: use dynamic field names (for speed)
optsused=opts;
for iname=1:size(names,1)
    fieldname=deblank(names(iname,:));
    if (~isfield(opts,fieldname))
%        optsused=setfield(optsused,fieldname,val);
        optsused.(fieldname)=val;
    end
end
return


