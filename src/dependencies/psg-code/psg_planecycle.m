function [recon_pcplane,cyclic_order,opts_used]=psg_planecycle(coords,opts)
% [recon_pcplane,cyclic_order,opts_used]=psg_planecycle(coords,opts)
% analyzes the arrangement of coordintes in the best fitting plane
%
% Uses psg_pcaoffset to determine the best-fitting plane about the
% centroid, and then determines cyclic order around that point.
% psg_pcaoffset can also be used to find the credentials of this fit.
%
% Could later use this to find the best-fitting ellipse, etc.
%
% coords: [nstims nd]: each row is the coordinate of a point
% opts.if_log: 1 to log
% opts.tol: tolerance for wrapping angles
%
% recon_pcplane[nstims nd] recon_pcaxes[: 1:2] are the coordinates in the first 2 pcs
% cyclic_order: a permutation of [1:nstims], corresponding to the cyclic order in the plane
%   cyclic order starts on positive axis of pc1 and proceeds counterclockwise
% opts_used: options used, also u,s,v such that coords=qu*qs*qv'+offset
%
%   See also:  PSG_PCAOFFSET.
%
if (nargin<2)
    opts=struct();
end
opts=filldefault(opts,'if_log',0);
opts=filldefault(opts,'tol',10^-5);
nstims=size(coords,1);
centroid=mean(coords,1);
recon_pcplane=psg_pcaoffset(coords,centroid,setfield(opts,'nd_max',2));
recon_pcplane_centered=recon_pcplane-repmat(mean(recon_pcplane,1),[nstims 1]);
%
angles=mod(atan2(recon_pcplane_centered(:,2),recon_pcplane_centered(:,1)),2*pi); %angles increase counterclockwise from the first coordinate positive axis
angles((2*pi-angles)<opts.tol)=0;
%positive axis assigned to pi
opts.angles=angles;
[angles_sorted,cyclic_order]=sort(angles);
%
opts_used=opts;
return
