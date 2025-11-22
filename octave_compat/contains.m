function tf=contains(str,pat) 
% tf=contains(str,pat) is a minimal replacement for Matlab's 'contains'
% that uses strfind
%
% pat must be a string.
% str can be a string or a cell array
%  Not supported:
%   * pat as an array
%   * (...,'IgnoreCase',IGNORE) syntax
%
% Copyright (C) J. Victor, 2025.
%
if iscell(str)
    str_shape=size(str);
    str_reshaped=str(:);
    z=zeros(1,length(str_reshaped));
    for k=1:length(str_reshaped)
        z(k)=~isempty(strfind(str_reshaped{k},pat));
    end
    tf=logical(reshape(z,str_shape));
else
    tf=~isempty(strfind(str,pat));
end
return
end
