function newstruct=setfields(struct,cfields,cvals)
%
% newstruct=setfields(struct,cfields,cvals) sets multiple fields of a structure
% cfields: cell array of field names
% cvals: cell array of field values
%
newstruct=struct;
if (length(cfields)~=length(cvals))
   error('number of fields and number of values must match.')
end
for k=1:length(cfields)
   newstruct=setfield(newstruct,cfields{k},cvals{k});
end


