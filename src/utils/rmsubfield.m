function r=rmsubfield(s,fns)
% r=rmsubfield(s,fns) removes a (possibly deeply) nested subfield
%
% Args:
%   s (struct): a structure
%
%   fns (cell array): field names, fns={n<sub>1</sub>, n<sub>2</sub>,..., n<sub>k</sub>}
%
% Returns: 
%   r (struct): s, with  s.(n<sub>1</sub>).(n<sub>2</sub>). ... .(n<sub>k</sub>) removed
%
% Note: Notes
%   If any of the subfields are not present, r=s.
% 
%   Subfield arrays not supported.
%
%   Uses recursion:
%
%     - k>=2: rmsubfield(s,{n<sub>1</sub>, n<sub>2</sub>,..., n<sub>k</sub>})=setfield(s.(n<sub>1</sub>),rmsubfield(s.(n<sub>1</sub>),{n<sub>2</sub>,..., n<sub>k</sub>}))
%     - k=1:  rmsubfield(s,{n<sub>1</sub>, n<sub>2</sub>,..., n<sub>k</sub>})=rmfield(s,n<sub>1</sub>)
%
%  See also:  SETFIELD, RMFIELD, GETSUBFIELD.
%
if isfield(s,fns{1})   
    k=length(fns);
    if k>1
        r=setfield(s,fns{1},rmsubfield(s.(fns{1}),fns(2:end)));
    else
        r=rmfield(s,fns{1});
    end
else
    r=s;
end
return
