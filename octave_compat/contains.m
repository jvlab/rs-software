function tf=contains(str,pat) 
% tf=contains(str,pat) is a minimal replacement for Matlab's 'contains'
% that uses strfind
%
% str and pat must be strings.
%  Not supported:
%   * str and pat as cells
%   * pat as an array
%   * (...,'IgnoreCase',IGNORE) syntax
%
% Copyright (C) J. Victor, 2025.
%
tf=~isempty(strfind(str,pat));
return
end
