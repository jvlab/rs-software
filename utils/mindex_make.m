function [mindex,mults]=mindex_make(dims)
% [mindex,mults]=mindex_make(dims) creates a multi-indexing scheme for an array whose dimensions are in dims
%
% mindex: size is prod(dims) length(dims)
%   mindex(:,id) has values from 0 to dims(id)-1
%   mindex(:,1) cycles the most rapidly
%   all rows of mindex are unique
% mults: a column of length length(dims)=1, containing [1 dims(1) dims(1)*dims(2) ...]
% mindex*mults is [0:prod(dims)-1]
%    
%   See also:  OPT_TAG_BOXCUT, CUMPROD, OPT_TAG_INIT, MINDEX_INV, MINDEX_MAKE_CHECK.
%
r=length(dims);
dprod=[1 cumprod(dims)];
mults=dprod(1:end-1)';
mindex=zeros(prod(dims),r);
for id=1:r
    mindex(:,id)=floor(mod([0:dprod(end)-1]',dprod(id+1))/dprod(id));
end
return
