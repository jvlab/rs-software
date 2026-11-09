function [d,transform]=psg_geo_pwaffine_obj(params,ref,adj,u,a,opts)
% [d,transform]=psg_geo_pwaffine_obj(params,ref,adj,u,a,opts) computes the objective
% function for a piecewise affine model, with unconstrained parameters 
% in the tangent plane (see psg_geo_pwaffine)
%
% params: vector of length [1 dim_x*ncuts]
%    params has the specifications for each cutplane concatenated
%    as a row vector of length dim_x.  The normalized part gives the
%    direction of the cutplane, the magnitude gives the multiplication factor for each acut
% ref: reference dataset, [npts dim_xy], dim_xy >= dim_x
% adj: dataset to adjust, [npts dim_x]
% u: coordinate frame for parameterization, size [dim_x dim_x]
%    See psg_geo_pwaffine_va for relationship of u to the cutplanes.
% a: reference value for cutpoints, size [1 ncuts]
% opts: options for psg_geo_pwaffine_va
%
% d: residuals
% transform: transform of best piecewise model (has acut, vcut)
%
% 20Dec23: modifications for multiple cuts.  This changes the behavior for
%    single cuts because the parameterization makes use of columns [ncuts+1:end] of inv(u),
%    rather than rows [ncuts+1:end] of u
%
%   See also:  PSG_GEO_PWAFFINE, PSG_GEO_PWAFFINE_VA.
%
if (nargin<=5)
    opts=struct;
end
dim_x=size(adj,2);
ncuts=size(params,2)/dim_x;
params=(reshape(params',dim_x,ncuts))'; %now params has ncuts rows, each row specifies the vcut and acut for a single cutplane
%v=[0 0 0 0...0] should map to original cut planes and acut=a
% this works if there is only one cutplane, since then the first row of u is the first column of inv(u)
%v=params*u+u(1,:); % vector in the tangent plane 
%
uinv=inv(u);
v=(params*uinv'+uinv(:,1:ncuts)'); 
%v_old=params*u+u(1,:); % vector in the tangent plane 
%v-v_old
vnorm=sqrt(sum(v.^2,2));
vcut=v./repmat(vnorm,1,dim_x);
acut=a.*vnorm';
[d,transform]=psg_geo_pwaffine_va(ref,adj,vcut,acut,opts);
end
