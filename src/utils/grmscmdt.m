function [gs,gsn]=grmscmdt(a)
% [gs,gsn]=grmscmdt(a) produces a matrix whose columns represent
% the gram-schmidt procedure applied to a.
%
% note that complex conjugate is used properly, so procedure
% will work if a is complex
%
% note that if the columns of a are linearly dependent, then gs will 
% have some columns that are 0.
%
% gsn: gs, normalized
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
