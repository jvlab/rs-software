function y=persp_apply(a,b,c,x)
% y=persp_apply(a,b,c,x) applies a perspective (projective) transformation to one or more vectors
%
% a: array of size [dimx, dimy]
% b: array of size [   1, dimy]
% c: array of size [dimx,    1]
% x: array of size [npts, dimx], the (row) vectors to be transformed
%
% y: array of size [npts, dimy]
%
% Each row of x is considered as a homogeneous vector with an augmented coordinate 1 at the end
% This matrix X is then post-multiplied by T, Y=XT.  Y is a homogeneous vector, so y is the rows
% of Y, divided by the final element.
%   Notes
%     T only matters up to homogeneity, but its lower right element is fixed at 1.
%     If c is zero, this is an affine transformation.
%     if c and b are zero, this is a linear transformation.
%
%
%  T=[a | c]
%    [-----]
%    [b | 1]
%
%   See also:  PERSP_XFORM_FIND, PERSP_SSQDIF, PERSP_FIT, PERSP_SSQDIF_FIT.
%
T=[a c;b 1];
X=[x,ones(size(x,1),1)];
Y=X*T;
y=Y(:,1:end-1)./repmat(Y(:,end),1,size(a,2));
return
end
    