function [vecs,mults,addoff]=mindex_inv(dimranges,indexes)
% [vecs,mults,addoff]=mindex_inv(dimranges,indexes) implements a multi-indexing scheme for loops, whose ranges are in dimranges
%
% in contrast to mindex_make, the first listing in dimranges is the slowest, corresponding to the "outer" loop
%
%   dimranges: an array of size [nloops 2], dimranges(:,1) is the lowest index (typically 0 or 1), dimranges(:,2) is the highest index
%   indexes: a column vector of scalars to convert to multi-indexes.
%    if indexes is not supplied, then this  maximum allowed value of indexes in vecs
%
%   vecs(length(indexes),size(dimranges,1)): vecs(k,b) is the multi-index converted from indexes(k); each vecs(k,b) is in [dimranges(k,1) dimranges(k,2)]
%   mults: a column of length size(dimranges,1)
%   addoff: a row vector of length size(dimranges,1)
%     mults and addoff convert  back from vecs to indexes:  vecs*mults+addoff is indexes
%    
%   See also:  MINDEX_MAKE.
%
r=size(dimranges,1);
mindex_dims=(dimranges(:,2)-dimranges(:,1)+1)';
mults=[];
addoff=[];
[mindex,mindex_mults]=mindex_make(fliplr(mindex_dims));
mults=flipud(mindex_mults);
if (nargin<=1)
    vecs=prod(mindex_dims);
else
    vecs=fliplr(mindex(indexes,:))+dimranges(:,1)';
end
addoff=1-dimranges(:,1)'*mults;
return
