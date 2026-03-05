function [ssq,y_fit,a,b]=persp_ssqdif_fit(c,x,y)
% [ssq,y_fit,a,b]=persp_ssqdif_fit(c,x,y) fits a perspective (projective) transformation
% and finds the deviation between target and fitted values
%
% c: array of size [dimx,    1]
% x: array of size [npts, dimx], the (row) vectors to be transformed
% y: array of size [npts, dimy], the target
%
% ssq: sum of squared differences between y and fitted vales
% y_fit: array of size [npts, dimy], the fitted values
% a: array of size [dimx, dimy]
% b: array of size [   1, dimy]
%
% See persp_apply for the details of the projective transformation
%
%   See also:  PERSP_XFORM_FIND, PERSP_APPLY, PERSP_FIT, PERSP_SSQDIF.
%
[a,b]=persp_fit(c,x,y);
[ssq,y_fit]=persp_ssqdif(a,b,c,x,y);
return
end
