function [a,pcoefs]=btc_meabt(b,t)
% [a,pcoefs]=btc_meabt(b,t) is a special-purpose routine to determine the
% maximum-entropy value of the "alpha" parameter for a 2x2 Markov process with
% defined beta-h, theta.  Pickard conditions not checked.
%
% a is a solution of
% (1+2b+t+a)(1+2b-t+a)(1-2b+t+a)(1-2b-t+a)=
% (1+t-a)^2(1-t-a)^2
%
% pcoefs are the coefficients of the cubic, highest power first
% monomials multiplied via "poly"
%
%   See also:  BTC_AUGCOORDS, BTC_MEABB, POLY.
%
if (t==0) %avoid a laborious calculation and a risk of spurious roots
    a=b^2;
    pcoefs=[];
    return;
end
den_coefs=poly([1+t,1+t,1-t,1-t]);
num_coefs=poly(-[1+2*b+t,1+2*b-t,1-2*b+t,1-2*b-t]);
pcoefs=num_coefs(2:end)-den_coefs(2:end);
a=roots(pcoefs);
a=max(a(find(imag(a)==0)));
return