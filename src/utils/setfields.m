function newstruct=setfields(oldstruct,cfields,cvals)
% newstruct=setfields(oldstruct,cfields,cvals) sets multiple fields of a structure
%
% Args:
%   oldstruct (struct): structure, may be empty
%
%   cfields (cell array of char): field names
%
%   cvals (cell array): field values
%
% Returns:
%   newstruct (struct): oldstruct, with each field cfields{k} set equal to cvals{k}
%
newstruct=oldstruct;
if (length(cfields)~=length(cvals))
   error('number of fields and number of values must match.')
end
for k=1:length(cfields)
   newstruct=setfield(newstruct,cfields{k},cvals{k});
end


