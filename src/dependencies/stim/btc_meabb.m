function [a,pcoefs]=btc_meabb(bh,bv,bd1,bd2)
% [a,pcoefs]=btc_meabb(bh,bv,bd1,bd2) is a special-purpose routine to determine the
% maximum-entropy value of the "alpha" parameter for a 2x2 Markov process with
% defined beta-h, beta-v, bd1, bd2.  Pickard conditions not checked.
%
% if bd1, bd2 not specified:  they do not default to zero, but are replaced
% by bd=bh*bv, which are the maxent values.
%
% if bd1, bd2 specified and equal, bd=(bd1+bd2)/2
% a is a solution of
% (1+2bh+2bv+2bd+a)(1-2bh-2bv+2bd+a)(1+2bh-2bv-2*bd+a)(1-2bh+2bv-2*bd+a)=(1-a)^4
% which reduces to a cubic
%
% if bd1 and bd2 are specified and unequal, bm=(bd1-bd2)/2
% and RHS is (1+2*bm-a)^2(1-2*bm-a)^2
%
% pcoefs are the coefficients of the cubic, highest power first
% monomials multiplied via "poly"
%
% if bh or bv=0, then a=the square of the nonzero one.
%
% changes 1 May 2012 to deal with possible double roots and extreme values
%   See also:  BTC_AUGCOORDS, BTC_MEABT, POLY, BTC_MEABB_ASYMP.
%
tol=10^-6;
if (nargin<=2)
    bd=bh*bv;
    den_coefs=poly([1,1,1,1]);
else
    bd=(bd1+bd2)/2;
    bm=(bd1-bd2)/2;
    den_coefs=poly([1+2*bm,1+2*bm,1-2*bm,1-2*bm]);
end
num_coefs=poly(-[1+2*bh+2*bv+2*bd,1-2*bh-2*bv+2*bd,1+2*bh-2*bv-2*bd,1-2*bh+2*bv-2*bd]);
pcoefs=num_coefs(2:end)-den_coefs(2:end);
az=roots(pcoefs);
az=az(find(abs(imag(az))<tol));
areal=real(az);
%if more than one real root, find the largest in absolute value
a=areal;
if length(areal)>1
    maxa_ptr=find(abs(areal)==max(abs(areal)));
    amax=areal(max(maxa_ptr)); %largest absolute value
    nearmax=find(abs(abs(amax)-abs(areal))<tol);
    if length(nearmax)>1 %are there some near-ties?
        amax=areal(nearmax);
        if abs(amax(1)-amax(2))<tol
            a=(amax(1)+amax(2))/2;
        end
        if (length(nearmax)>2)
            if abs(amax(2)-amax(3))<tol
                a=(amax(2)+amax(3))/2;
            end
            if abs(amax(1)-amax(3))<tol
                a=(amax(1)+amax(3))/2;
            end
        end
    else
        a=amax;
    end
end
if length(a)>1 %exceptional case
    a=0;
    %disp('exceptional case in btc_meabb')
    %disp(' bh, bv, bd')
    %disp([bh bv bd]);
    %if exist('bm')
    %    bm
    %end
    %if exist('bd1')
    %    bd1
    %end
    %if exist('bd2')
    %    bd2
    %end
    %pcoefs
    %areal
    %a
end
return
