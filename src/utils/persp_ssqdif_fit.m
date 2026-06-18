function [ssq,y_fit,a,b]=persp_ssqdif_fit(c,x,y)
% [ssq,y_fit,a,b]=persp_ssqdif_fit(c,x,y) fits a projective transformation, assuming a perspective component, 
% and finds the deviation between target and fitted values
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
%   ssq (float): sum of squared differences between y and y_fit
%
%   y_fit (float 2-D array): array of size [npts, dimy], the fitted values, i.e., the results of applying the fitted transformation to x
%
%   a (float 2-D array): array of size [dimx, dimy], affine component of the transformation
%
%   b (float 1-D array): array of size [   1, dimy], offset component of the transformation
%
% See also:  PERSP_XFORM_FIND, PERSP_APPLY, PERSP_FIT, PERSP_SSQDIF.
%
[a,b]=persp_fit(c,x,y);
[ssq,y_fit]=persp_ssqdif(a,b,c,x,y);
return
end
