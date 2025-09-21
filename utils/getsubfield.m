function x=getsubfield(s,fns)
% x=getsubfield(s,fns) gets a (possibly deeply) nested subfield
%
% s: a structure
% fns: a cell array of field names, fns={n_1,n_2,...,n_k}, where n_i are strings
%
% x: result
%
% If any of the subfields are not present, [] is returned.
% Subfield arrays not supported.
%
% recursive logic:
%    k>=2: getsubfield(s,{n_1,n_2,...,n_k})=getsubfield(s.(n_1),{n_1,n_2,...,n_k})
%    k=1:  getsubfield(s,{n_1})=x.(n_1)
%
%  See also:  GETFIELD, RMSUBFIELD.
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
