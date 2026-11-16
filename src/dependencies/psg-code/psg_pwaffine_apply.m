function [y,sign_vecs,sign_inds,ypw,unsign_vecs]=psg_pwaffine_apply(transform,x)
% [y,sign_vec,sign_inds,ypw,unsign_vecs]=psg_pwaffine_apply(transform,x) applies a piecewise affine transformation
%  but does not check for continuity at the cutpoints
%
%  See psg_piecewise_notes.doc for details on algorithm
%
% x: original coordinates, size=[npts,dim_x]
% transform:
%   transform.b: scalar, typically equal to 1 (scale absorbed into T)
%   transform.T: stack of matrices, size [dim_x dim_y 2^ncuts]
%      typically ncuts=1, but in general
%      let sign_vecs=sign(x*vcut'-a), of size [npts,ncuts] (with equality going to 1)
%      consider each row of sign_vecs:
%      sign_ind=1       for sign_vec=[+ + .... +]
%      sign_ind=2       for sign_vec=[- + .... +]
%      sign_ind=3       for sign_vec=[+ - .... +]
%      sign_ind=4       for sign_vec=[- - .... +]
%         ....
%      sign_ind=2^ncuts for sign_vec=[- - .... -]
%        use transform.T(:,:,sign_ind) for transformation
%   transform.c: stack of offsets, size [2^ncuts dim_y], use (sign_ind,:)
%   transform.vcut: unit vectors, stack of rows, size [ncuts dim_x], orthog to cut planes
%   transform.acut: vector of length ncuts, the cutpoints
%
% y: transformed coordinates, size=[npts,dim_y]
% sign_vecs: array [dim_x ncuts] of signs (+1,-1), each row as above
% sign_inds: column of length dim_x, sign indices for each row of x
% ypw: transformed coordinates in each piece, size=[npts,dim_y,2^ncuts]
% unsign_vecs: array [dim_x ncuts] of unsigned values of projection on cutplane normal after subtraction of acut; signs are given in sign_vecs
%
% If vcut is empty or not listed, then the behavior is the same as for an
% affine or Procrustes transformation:
%  y=transform.b*x*transform.T+repmat(transform.c,npts,1);
%
% 15Dec23: begin multiple cutpoints
% 19Dec23: add compatibility with no cutpoints and multiplication by transform.b
% 09Jul24: add ypw to returned variables
% 10Jul24: documentation fix
% 22May25: add unsign_vecs to output
%
%   See also: PSG_GEOMODELS_TEST, PSG_GEO_PWAFFINE, PSG_GEOMODELS_APPLY_TEST, PSG_PWPROJECTIVE_APPLY.
%
npts=size(x,1);
if ~isfield(transform,'vcut')
    vcut=[];
else
    vcut=transform.vcut;
end
ncuts=size(vcut,1);
if ncuts>0
    n_pw=size(transform.T,3); %number of pieces
    cuts=x*vcut'; %column of values of cutpoints

%    sign_vecs=sign(cuts-repmat(transform.acut(:)',npts,1));
    unsign_vecs=cuts-repmat(transform.acut(:)',npts,1);
    sign_vecs=sign(unsign_vecs);
    sign_vecs(sign_vecs==0)=1; %take care of ties
    sign_inds=1+(1-sign_vecs)/2*(2.^[0:ncuts-1]');%first part maps +1 to 1, -1 to 2
else
    n_pw=1;
    sign_vecs=ones(npts,1);
    sign_inds=ones(npts,1);
    unsign_vecs=zeros(npts,1);
end
ypw=zeros(npts,size(transform.T,2),n_pw); %ypw(:,:,n_pw) are the alternative values of y in each piece
for ipw=1:n_pw
    ypw(:,:,ipw)=transform.b*x*transform.T(:,:,ipw)+repmat(transform.c(ipw,:),npts,1);
end
y=zeros(npts,size(transform.T,2));
for ipw=1:n_pw
    y(sign_inds==ipw,:)=ypw(sign_inds==ipw,:,ipw);
end
%%specific to a single cut
%y=ypw(:,:,1);
%y(cuts<transform.acut,:)=ypw(cuts<transform.acut,:,2);
return
end
