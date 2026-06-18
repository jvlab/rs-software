function [vecs,mults,addoff]=mindex_inv(dimranges,indexes)
% [vecs,mults,addoff]=mindex_inv(dimranges,indexes) implements a multi-indexing scheme with ranges are in dimranges
%
% This allows for arbitrary start and stop indices along each dimension.
% In contrast to mindex_make, the first entry in dimranges is the outer loop, i.e., cycles the slowest.
%
% Args:
%   dimranges (int 2-D array): an array of size [ndims 2], dimranges(k,1) is the lowest index (typically 0 or 1), dimranges(k,2) is the highest index for dimension k
%
%   indexes (int 1-D array): a column vector of scalars to convert to a multi-index; if not supplied, then the max of each row of dimranges is assumed
%
% Returns:
%   vecs (int 2-D array): array of size [length(indexes),ndims]: vecs(k,b) is the multi-index converted from indexes(b); each vecs(k,b) is in [dimranges(k,1) dimranges(k,2)]
%
%   mults (int 1-D array): a column of length ndims
%
%   addoff (int): offset to convert from vecs to indices, if supplied; indices=vecs\*mults+addoff
%    
% See also:  MINDEX_MAKE.
%
r=size(dimranges,1);
mindex_dims=(dimranges(:,2)-dimranges(:,1)+1)';
mults=[];
addoff=[];
[mindex,mindex_mults]=mindex_make(fliplr(mindex_dims)); %get multi-indices and exchange fast and slow dimensions
mults=flipud(mindex_mults);
if (nargin<=1)
    vecs=prod(mindex_dims);
else
    vecs=fliplr(mindex(indexes,:))+dimranges(:,1)';
end
addoff=1-dimranges(:,1)'*mults;
return
