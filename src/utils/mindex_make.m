function [mindex,mults]=mindex_make(dims)
% [mindex,mults]=mindex_make(dims) creates a multi-indexing scheme for an array whose dimensions are in dims
%
% Args:
%   dims (int 1-D array): length of each dimension
%
% Returns:
%   mindex (int 2-D array): array of size [prod(dims) length(dims)], in which mindex(:,id) has values from 0 to dims(id)-1, mindex(:,1) cycles most rapidly, and  all rows are unique
%
%   mults (int 1-D array): a column of length length(dims), containing [1 dims(1) dims(1)\*dims(2) ... dims(1)\*...\*dims(end-1)]. mindex\*mults is [0:prod(dims)-1]
%    
% See also: MINDEX_INV, MINDEX_MAKE_CHECK.
%
r=length(dims);
dprod=[1 cumprod(dims)];
mults=dprod(1:end-1)';
mindex=zeros(prod(dims),r);
for id=1:r
    mindex(:,id)=floor(mod([0:dprod(end)-1]',dprod(id+1))/dprod(id));
end
return
