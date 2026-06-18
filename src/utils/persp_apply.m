function y=persp_apply(a,b,c,x)
% y=persp_apply(a,b,c,x) applies a perspective (projective) transformation to one or more vectors
%
% Args:
%   a (float 2-D array): array of size [dimx, dimy], affine component of the transformation
%
%   b (float 1-D array): array of size [   1, dimy], offset component of the transformation
%
%   c (float 1-D array): array of size [dimx,    1], perspective component of the transformation
%
%   x (float 2-D array): array of size [npts, dimx], the (row) vectors to be transformed; npts is the number of vectors to be transformed
%
% Returns:
%   y (float 2-D array): array of size [npts, dimy], its row vectors are the results of transformation
%
% Note: How the transformation is defined
%   Each row of x is considered as a homogeneous vector with an augmented coordinate 1 at the end, creating an array of size [npts, dimx+1].
%
%   A matrix T, of size [dimx+1, dimy+1] is formed with a in its upper left, b in its lower left, c in its upper right, and 1 in its lower right.
%
%   X is then post-multiplied by T, Y=XT.
%
%   Y is a homogeneous vector.  y is the rows of Y, with each row divided by the final element.
%
%   T only matters up to homogeneity, but its lower right element is fixed at 1.
%
%   If c is zero, this is an affine transformation.
%
%   If c and b are zero, this is a linear transformation.
%
% See also:  PERSP_XFORM_FIND, PERSP_SSQDIF, PERSP_FIT, PERSP_SSQDIF_FIT.
%
T=[a c;b 1];
X=[x,ones(size(x,1),1)];
Y=X*T;
y=Y(:,1:end-1)./repmat(Y(:,end),1,size(a,2));
return
end
    