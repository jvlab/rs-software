function [rays,wmsg,opts_rays_used]=rs_findrays(sa,label,opts_rays)
% [rays,wmsg,opts_rays_used]=rs_findrays(sa,label,opts_rays) is a utility that creates a `ray structure`
% from a single record of a `stimulus metadata structure`.  The `ray structure` lists the stimuli that lie on rays (points on approximate straight lines),
% rings (points in a plane at approximately equal distance from the origin), and nearest neighbors), and is used by `rs_disp_enh_coordsets`.
%
% Args:
%  sa (struct): one record of a `stimulus metadata structure`, e.g., data.sas{k}, where data is a `dataset structure`
%
%  label (char): a paradigm name, allows for non-standard parameters for identifying rays and rings; typically omitted, defaults to []; see note below regarding nondefault parameters
%
%  opts_rays (struct): options for determining criteria for rays and rings, typically omitted, with fields
%
%     - coord_names (cell array of char): fields of 'sa' to be searched for coordinates in order of priority; default is {'type_coords','btc_specoords','btc_augcoords'}
%     - ray_permute_raynums (int 1-D array): permutation to reorder the numbering of rays; default is [] (no permutation)
%     - ray_tol (float): tolerance for collinearity of rays; default is 10<sup>-5</sup>
%     - ray_minpts (int): minimum number of points (other than the origin) to constitute a ray; default is 3
%     - ray_dirkeep (char): which rays to keep, default is 'all', alternatives are 'card' (keep only cardinal directions), 'diag' (keep only diagonal directions), 'card_diag' (keep ony cardinal and diagonal directions)
%     - ray_reorder_ring (int); 1 to standardize the order of the rings, 0 to omit; default is 1
%     - ray_plane_jit (float): small nonzero to standardize flattening of rays into a plane, 0 to omit; default is  10<sup>-3</sup>
%     - ray_res_ring (float): tolerance for equal radii for a ring; default is 10<sup>-2</sup>
%     - ray_min_ring (int): minimum number of points in a ring; default is 4
%     - ray_mindist_tol (float): tolerance for ties for nearest-neighbor distance; default is 10<sup>-2</sup>
%
% Returns:
%  rays (struct): `ray structure`, with fields
%
%     - nrays (int): number of rays
%     - whichray (int 1-D array): whichray(istim), in [0 nrays], is the index number of the ray that contains stimulus istim, 0 if not on a ray
%     - mult (float 1-D array): mult(istim), in [0 1], is the fractional distance of stimulus istim along its ray, 0 if not on a ray
%     - endpt (float 2-D array): endpt(iray,:), with iray in [1 nrays], are the coordinatates of the stimulus at the end of the corresponding ray
%     - nrings (int): number of rings
%     - rings (cell array of struct): cell array of length nrings; rings{iring}.mult_val is the distance of the ring from the origin, and rings{iring}.coord_ptrs is int 1-d array of indices of stimuli in the ring
%     - npairs (int): number of nearest-neighbor pairs
%     - pairs (int 2-d array): pairs(ipair,:), with ipair in [1 npairs], are indices of stimuli in a nearest-neighbor pair
%
%  wmsg (char): warning message, if any
%
%  opts_rays_used (struct): opts_rays, with defaults and overrides filled in
%
% Note: Note regarding nondefault ray parameters
%     - For specific paradigm names (passed via 'label'), selected default parameters in opts_rays are overriden as follows.
%
%         - 'bcpm24': ray_dirkeep='card_diag' and ray_minpts=2
%         - 'bcpp55','bcmp55','bcpm55', and 'bcmm55': ray_dirkeep='card'
%
%     - Additional overrides can be added by editing 'psg_findray_setopts'
%
%   See also:  RS_DISP_ENH_COORDSETS, PSG_DEFOPTS, PSG_FINDRAYS, PSG_TYPE_COORDS_DEF, PSG_TYPE_COORD_UTIL.
%

if (nargin<=1)
    label=[];
end
if (nargin<=2)
    opts_rays=struct;
end
opts_rays=getfield(rs_aux_customize(setfield(struct(),'opts_rays',opts_rays),'rs_findrays'),'opts_rays'); %get defaults for ray_reorder_ring and ray_plane_jit
%
opts_rays=filldefault(opts_rays,'coord_names',getfield(psg_defopts,'coord_fields')); % was {'type_coords','btc_specoords','btc_augcoords'});
wmsg=[];
rays=struct;
opts_rays_used=struct; %in case psg_findrays is not called
[stim_coords,coord_names]=psg_type_coords_util(sa,opts_rays.coord_names);
if ~isempty(stim_coords)
    opts_rays=setfield(opts_rays,'coord_names',{coord_names});
    if ~isempty(label)
        opts_rays=psg_findray_setopts(label,opts_rays);
    end
    [rays,opts_rays_used]=psg_findrays(stim_coords,opts_rays);
else
    wmsg=sprintf('cannot find stimulus coordinates, so cannot identify rays');
end
return
end
