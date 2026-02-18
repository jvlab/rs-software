function r=rmsubfield(s,fns)
% r=rmsubfield(s,fns) removes a (possibly deeply) nested subfield
%
% s: a structure
% fns: a cell array of field names, fns={n_1,n_2,...,n_k}, where n_i are strings
%
% r: result
%
% If any subfield is not present, then r=s.
% Subfield arrays not supported.
%
% recursive logic:
%    k>=2: rmsubfield(s,{n_1,n_2,...,n_k})=setfield(s,n_1,rmsubfield(s.(n_1),{n_2,...,n_k}))
%    k=1:  rmsubfield(s,{n_1,n_2,...,n_k})=rmfield(s,n_1));
%
%   See also:  SETFIELD, RMFIELD, GETSUBFIELD.
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
