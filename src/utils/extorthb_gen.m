function [basis,onb]=extorthb_gen(v)
% [basis,onb]=extorthb_gen(v) extends a set of column vectors to an orthogonal basis
%
% The extension is attempted in a numerically "good" way, not by simply doing a Gram-Schmidt procedure
%
% Args:
%   v (float 2-D array): a set of column vectors, assumed to be orthonormal.
%
% Returns:
%   basis (float 2-D array): basis a square matrix, size(basis)=[size(v,1) size(v,1)], basis'*basis and basis*basis' is the identity
%
%     - If v is orthonormal, then basis(:,1:size(v,2))=v
%     - If v is not orthonormal, then v is in the span of the first size(v,2) columns of basis, with v(:,1) proportional to basis(:,1),
%        v(:,k) in the span of basis(:,1:k). Coefficients are in in basis'*v, which is upper-triangular
%
%   onb (float 2-D array): same as basis, for backwards compatibility
%
%  See also: GRMSCMDT, EXTORTHB.
%
n=size(v,1);
m=size(v,2);
if (n<=1) basis=v; onb=ones(n); return; end
%
basis=eye(n);
vp=v;
for p=1:m
   [bp,bpo]=extorthb(vp([p:n],p));
   ap=eye(n);
   ap([p:n],[p:n])=bpo;
   basis=basis*ap;
   vp=ap'*vp;
end
if (nargout>=2)
   onb=basis; %for compatibilty
   % onb=basis./repmat(sqrt(sum(basis.^2)),size(basis,1),1); %removed 31Dec24
end
