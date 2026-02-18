function [basis,onb]=extorthb_gen(v)
% [basis,onb]=extorthb_gen(v) extends a set of column vectors
% to an orthogonal basis
%
% it attempts to do this in a numerically "good" way, not by simply
% doing a Gram-Schmidt procedure
%
% v: an array, viewed as a set of column vectors. Assumed to be orthonormal.
%
% basis: orthonormal basis a square matrix, size(basis)=[size(v,1) size(v,1)]; 
%        basis'*basis and basis*basis' is the identity
%  If v is orthonormal, then basis(:,1:size(v,2))=v
%  If v is not orthonormal, then v is in the span of the first size(v,2)
%        columns of basis, with v(:,1) proportional to basis(:,1),
%        v(:,k) in the span of basis(:,1:k). Coefficients are in in basis'*v,
%        which is upper-triangular
% onb: orthonormal basis, vectors thought of in columns; onb'*onb=1,
%   same as basis (after 31Dec24)
%
% 31Dec24: fix documentation concerning onb, and need for v being orthonormal
%
%   See also: GRMSCMDT, EXTORTHB, RANDORTHU_GEN.
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
