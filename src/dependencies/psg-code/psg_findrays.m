function [rays,opts_used]=psg_findrays(stim_coords,opts)
% [rays,opts_used]=psg_findrays(stim_coords,opts) finds and describes the rays in a set of coordinates
%
% stim_coords: the coordinates, size [npts nd], e.g., sa.btc_specoords from psg_read_coorddata
%   Note that sa.btc_augcoords could also be used, but these values include the induced correlations
%   so, for example, increasing values of gamma or beta will not lie on a ray
% opts: options structure, can be omitted
%   opts.ray_tol: tolerance for matching points or angle wrapping, defaults to 10^-5
%   opts.ray_res_ring: resolution for finding points with equal magnitudes for rings, defaults to 10^-2
%     res_ring is lax because coordinates are derived from stimulus descriptions, which have few significant digits
%   opts.ray_min_ring: minimum number of points in a ring, defaults to 4
%   opts.ray_permute_raynums: a permutation to apply to ray numbers and endpoints for nonzero rays
%     for example, to make the first ray found to be ray number x and the second ray found
%     to have ray number y, then opts.permute_raynums=[x y ...]
%   opts.ray_minpts: minimum number of points in a ray
%
% rays: structure
%   rays.nrays: number of rays, other than the 0 ray
%   rays.whichray, size [npts,1]: whichray(ipt) is the ray that stim_coords(ipt,:) is asssigned to; 0 if the point is the origin, and NaN if not on a ray
%   rays.mult, size [npts,1]: the multiplier
%   rays.endpt, size [nrays,1]: 
% opts_used: options used
%
% 24Jan23: add rings. Note that code is not fully tested since existing
%   datasets all have 'rand' condition at end, so fnz is [1:nstims-1], and
%   does not re-order the coordinates
% 17Jun23: options for grid setups, move options to psg_defopts, add ray_minpts, eliminate rings of radius zero
% 18Jun23: option to only include rays on cardinal axes
% 24Jul23: fixed bug related to ray extraction
% 08Nov23: failsafe if no pairs
% 01Jun25: failsafe if rays have been removed
% 21Sep25: option ray_reorder_ring to reorder coord_ptrs with lowest index at start, and then increase
% 21Sep25: option ray_plane_jit to disambiguate flattening of rays into a ring
% 26Dec25: determine multipliers by projections onto a vector whose first components are positive
% 10Mar26: avoid plane fits if only 1-d coordinates
% 
%   See also:  PSG_READ_COORDDATA, FILLDEFAULT, PSG_VISUALIZE_DEMO, PSG_PLOTCOORDS, 
%   PSG_PLANECYCLE, PSG_PCAOFFSET.
%
if (nargin<2)
    opts=struct;
end
%for legacy
if isfield(opts,'tol') opts.ray_tol=opts.tol; end %fixed 26Dec25
if isfield(opts,'res_ring') opts.ray_res_ring=opts.res_ring; end
if isfield(opts,'min_ring') opts.ray_min_ring=opts.min_ring; end
if isfield(opts,'permute_raynums') opts.ray_permute_raynums=opts.permute_raynums; end
%
opts=psg_defopts(opts);
%
opts_used=opts;
npts=size(stim_coords,1);
nd=size(stim_coords,2);
%
rays=struct;
%
stim_coords(isnan(stim_coords))=0;
%
unassigned=[1:npts];
mags=sqrt(sum(stim_coords.^2,2));
zero_length=find(mags<=opts.ray_tol);
rays.whichray=zeros(npts,1);
rays.mult=zeros(npts,1);
rays.endpt=[];
unassigned=setdiff(unassigned,zero_length);
iray=0;
while ~isempty(unassigned)
    iray=iray+1;
    v=stim_coords(min(unassigned),:);
    %flip v so that first nonzero component is positive
    vnz=find(abs(v)>opts.ray_tol);
    if ~isempty(v)
        v=v*sign(v(min(vnz)));
    end
    projs=stim_coords(unassigned,:)*v'/(v*v');
    diffs=stim_coords(unassigned,:)-projs*v;
    mags=sqrt(sum(diffs.^2,2));
    matches=find(mags<=opts.ray_tol);
    maxproj=max(projs(matches));
%   maxproj_ind=min(find(projs==maxproj)); %replaced by next line 24Jul23
    maxproj_ind=matches(min(find(projs(matches)==maxproj)));
    endpt=stim_coords(unassigned(maxproj_ind),:);
    dir_ok=0;
    which_nz=find(double(abs(endpt)>opts.ray_mindist_tol)); %how many nonzero coords?
    nnz=length(which_nz);
    enz=abs(endpt(which_nz));
    switch opts.ray_dirkeep
        case 'all'
            dir_ok=1;
        case 'card' %one nonzero coord
            dir_ok=double(nnz==1);
        case 'diag' %diagonal: at least two nonzero coords but of equal absolute value
            if (nnz>1)
                if abs(max(enz)-min(enz))<opts.ray_mindist_tol
                    dir_ok=1;
                end
            end
        case 'card_diag'
            if abs(max(enz)-min(enz))<opts.ray_mindist_tol
                dir_ok=1;
            end
    end
    %
    if length(matches)>=opts.ray_minpts & dir_ok==1
        rays.whichray(unassigned(matches))=iray;
        rays.endpt(iray,:)=endpt;
        rays.mult(unassigned(matches))=projs(matches)/maxproj;
    else
        iray=iray-1; %insufficient number of points to define a ray
        rays.whichray(unassigned(matches))=NaN;
    end
    %
    unassigned=setdiff(unassigned,unassigned(matches));
end
rays.nrays=length(unique(rays.whichray(rays.whichray>0)));
fnz=find(rays.whichray~=0); %all points that are on a ray (typically, all points except the origin)
if ~isempty(opts.ray_permute_raynums)
    if max(opts.ray_permute_raynums)==size(rays.endpt,1) %added 01Jun25 in case rays have been removed
        rays.whichray(fnz)=opts.ray_permute_raynums(rays.whichray(fnz));
        rays.endpt(opts.ray_permute_raynums,:)=rays.endpt;
    end
end
%
%find nearest neighbor pairs  (distance calc borrowed from cootodsq)
%
dotab=stim_coords*stim_coords';
dotaa=repmat(diag(dotab),1,npts);
distsq=max(dotaa+dotaa'-2.*dotab,0); %ensure it is non-negative
pair_dists=sqrt(distsq);
pair_dists=pair_dists+eye(npts)*max(pair_dists(:)); %remove self-distances
pair_dists_min=min(pair_dists(:));
%
npairs=0;
pairs=zeros(0,2);
for ipt=1:npts-1
    for jpt=ipt+1:npts
        if pair_dists(ipt,jpt)<=pair_dists_min+opts.ray_mindist_tol
            npairs=npairs+1;
            pairs(npairs,:)=[ipt,jpt];
        end
    end
end
rays.npairs=npairs;
rays.pairs=pairs;
%
%find rings
%
%find progression of angles for all points that are on rays
stim_coords_mod=stim_coords;
stim_coords_mod(find(isnan(stim_coords)))=0;
%changes to prevent degenerate flattening
stim_coords_mod_nz=stim_coords_mod(fnz,:);
if opts.ray_plane_jit~=0
    snz=size(stim_coords_mod_nz);
    s1=[1:snz(1)];
    s2=[1:snz(2)];
    jits=(repmat(s1'/snz(1),[1 snz(2)]).^repmat(s2,[snz(1) 1])); %ramps raised to powers
    stim_coords_mod_nz=stim_coords_mod_nz+opts.ray_plane_jit*jits;
end
if size(stim_coords_mod_nz,2)>=2 %added 10Mar26 in case coords are only 1D
    [recon_pcplane,cyclic_order]=psg_planecycle(stim_coords_mod_nz,opts);
else
    cyclic_order=[1:size(stim_coords_mod_nz,1)];
end
%
%find groups of points that are at the same distance from the origin
mult_vals=round(abs(rays.mult(fnz(cyclic_order))./opts.ray_res_ring));
mult_vals_unique=flipud(unique(mult_vals)); %mult_vals_unique begins with largest value
mult_vals_unique=setdiff(mult_vals_unique,0); %no rings with zero radius
nrings=0;
rings=cell(0);
for iring=1:length(mult_vals_unique)
    thisring=find(mult_vals==mult_vals_unique(iring));
    if length(thisring)>=opts.ray_min_ring
        nrings=nrings+1;
        rings{nrings}.mult_val=opts.ray_res_ring*mult_vals_unique(iring);
%        rings{nrings}.coord_ptrs=fnz(cyclic_order(thisring))'; modified as below, 21Sep25
        coord_ptrs=fnz(cyclic_order(thisring))';
        if opts.ray_reorder_ring
            ncp=length(coord_ptrs);
            ptr_min=find(coord_ptrs==min(coord_ptrs)); %start at low point
            coord_ptrs=coord_ptrs([1+mod(ptr_min-1+[0:ncp-1],ncp)]);
            if coord_ptrs(2)>coord_ptrs(end) %reverse if necessary
                coord_ptrs=coord_ptrs([1 fliplr(2:ncp)]);
            end
        end
        rings{nrings}.coord_ptrs=coord_ptrs;
    end
end
%
%alternate code that looks at one ring at a time -- 
%simpler, but the rings may start at different positions because of
%degeneracy of PCA
%
% %find groups of points that are at the same distance from the origin
% mult_vals=round(abs(rays.mult(fnz)./opts.ray_res_ring));
% mult_vals_unique=flipud(unique(mult_vals)); %mult_vals_unique begins with largest value
% nrings=0;
% rings=cell(0);
% for iring=1:length(mult_vals_unique)
%     thisring=find(mult_vals==mult_vals_unique(iring));
%     if length(thisring)>=opts.ray_min_ring
%         nrings=nrings+1;
%         %if this were applied to all rings together, then all rings would start in the same place
%         [recon_pcplane,cyclic_order]=psg_planecycle(stim_coords_mod(fnz(thisring),:),opts);
%         rings{nrings}.mult_val=opts.ray_res_ring*mult_vals_unique(iring);
%         rings{nrings}.coord_ptrs=fnz(thisring(cyclic_order))';
%     end
% end
rays.nrings=nrings;
rays.rings=rings;
return
