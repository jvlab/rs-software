function [a,b]=persp_fit(c,x,y)
% [a,b]=persp_fit(c,x,y) fits a projective transformation, assuming a
% vector of  "offset" values
%
% c: array of size [dimx,    1]
% x: array of size [npts, dimx], the (row) vectors to be transformed
% y: array of size [npts, dimy], the target
%
% a: array of size [dimx, dimy]
% b: array of size [   1, dimy]
%
% See persp_apply for the details of the projective transformation
%
%   See also:  PERSP_XFORM_FIND, PERSP_APPLY, PERSP_SSQDIF, PERSP_SSQDIF_FIT, REGRESS.
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
