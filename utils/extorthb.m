function [basis,onb]=extorthb(cv)

% [basis,onb]=extorthb(cv) extends a column vector to an orthogonal basis
%
% it attempts to do this in a numerically "good" way, not by simply
% doing a Gram-Schmidt procedure
%
% cv: a column vector
%
% basis: a square matrix, size(basis)=[length(cv) length(cv)]; basis(:,1)=cv
%        basis'*basis is diagonal
% onb: orthonormal basis, vectors thought of in columns; onb'*onb=1
%
% 27May24: bug for checking small values fixed
%
%   See also: GRMSCMDT, EXTORTHB_GEN.
%
n=length(cv);
if (n<=1) basis=cv; onb=ones(n); return; end
%
[vs,is]=sort(-abs(cv)); %smallest entries at the end
sbasis=zeros(n);
cvs=cv(is);
%if any zero entries at end, these get replaced with part of the identity matrix
if -vs(end)<=eps
   begsmall=min(find(-vs<=eps)); %< changed to <=, 27May24
   for iz=begsmall:n
 		sbasis(:,iz)=(iz==[1:n]');    
   end
   nm=begsmall-1;
else
   nm=n;
end
sbasis(1:nm,1:nm)=fliplr(triu(repmat(cvs(1:nm),1,nm)));
%do the orthonormalization
for k=2:nm
	sbasis(nm+2-k,k)=-sum(cvs(1:nm+1-k).^2)/cvs(nm+2-k);   %use pivot value
end
basis(is,:)=sbasis; %unsort
%
if (nargout>=2)
   onb=basis./repmat(sqrt(sum(basis.^2)),size(basis,1),1);
end
return
