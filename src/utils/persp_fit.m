function [a,b]=persp_fit(c,x,y)
% [a,b]=persp_fit(c,x,y) fits a projective transformation, assuming a vector for the perspective component
% 
% Transformation parameters a,b, and c are described in `persp_apply`.
%
% Args:
%   c (float 1-D array): array of size [dimx,    1], perspective component of the transformation
%
%   x (float 2-D array): array of size [npts, dimx], the (row) vectors to be transformed; npts is the number of vectors to be transformed
%
%   y (float 2-D array): array of size [npts, dimy], its row vectors are to be fit by applying the transformation to x
%
% Returns:
%   a (float 2-D array): array of size [dimx, dimy], affine component of the transformation
%
%   b (float 1-D array): array of size [   1, dimy], offset component of the transformation
%
% See also:  PERSP_XFORM_FIND, PERSP_APPLY, PERSP_SSQDIF, PERSP_SSQDIF_FIT.
%
denom=x*c+1;
regressors=[x./repmat(denom,1,size(x,2)) 1./denom];
a=zeros(size(x,2),size(y,2));
b=zeros(1,size(y,2));
for iy=1:size(y,2)
    ab=regress(y(:,iy),regressors);
    a(:,iy)=ab(1:end-1);
    b(1,iy)=ab(end);
end
return
