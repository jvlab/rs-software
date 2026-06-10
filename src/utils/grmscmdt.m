function [gs,gsn]=grmscmdt(a)
% [gs,gsn]=grmscmdt(a) applies the Gram-Schmidt procedure to a set of column vectors
%
% Args:
%    a (float 2-D array): a set of column vectors
%
% Returns:
%   gs (float 2-D array): orthogonal column vectors; span of first k columns match those of a
%
%   gsn (float 2-D array): orthonormal column vectors; span of first k columns match those of a
%
% Notes:
%   If some columns of a are linearly dependent, then gs and gsn will have some columns that are zero.
%   
%   This works if a is complex.  gs'\*gs will be diagonal, and gsn'\*gsn will be the identity.
%
%    See also: EXTORTHB, EXTORTHB_GEN.
%
[rows, cols] = size(a);
gs=zeros(rows,cols);
for icol=1:cols
   if (max(abs(a(:,icol)))<eps*rows) return; end
   gs(:,icol)=a(:,icol);
   for jcol=1:(icol-1)
      coef=a(:,icol)'*gs(:,jcol)/(gs(:,jcol)'*gs(:,jcol));
      gs(:,icol)=gs(:,icol)-conj(coef)*gs(:,jcol);
   end
   if (max(abs(gs(:,icol)))<eps*rows) return; end
end
if (nargout>=2)
   gsn=gs./repmat(sqrt(sum(gs.^2)),size(gs,1),1);
end
