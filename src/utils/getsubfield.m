function x=getsubfield(s,fns)
% x=getsubfield(s,fns) gets a (possibly deeply) nested subfield
%
% Args:
%   s (struct): a structure
%
%   fns (cell array): field names, fns={n<sub>1</sub>, n<sub>2</sub>,..., n<sub>k</sub>}
%
% Returns: 
%   x (int, float, cell, or struct): the nested subfield s.(n<sub>1</sub>).(n<sub>2</sub>). ... .(n<sub>k</sub>)
%
% Note: Notes
%   If any of the subfields are not present, x=[].
% 
%   Subfield arrays not supported.
%
%   Uses recursion:
%
%     - k>=2: getsubfield(s,{n<sub>1</sub>, n<sub>2</sub>,..., n<sub>k</sub>})=getsubfield(s.(n<sub>1</sub>),{n<sub>2</sub>,..., n<sub>k</sub>})
%     - k=1:  getsubfield(s,{n<sub>1</sub>})=s.(n<sub>1</sub>)
%
%  See also:  RMSUBFIELD.
%
if isfield(s,fns{1})
    k=length(fns);
    if k>1
        x=getsubfield(s.(fns{1}),fns(2:end));
    else
        x=s.(fns{1});
    end
else
    x=[];
end
return
