function coords_new=psg_geomodels_apply(model_class,coords,transform)
% coords_new=psg_geomodels_apply(model_class,coords,transform) applies any of several
% geometric models to a coordinate set
%
% model_class: one of the model classes in psg_geomodels_define, typically one of 
% 'mean','procrustes','affine','projective','pwaffine'
% coords: coordinates: size is [npts,ndims]
% transform: a structure containing the transform parameters, typically
%    transform.b: scale
%    transform.T: [ndims,ndims]: a post-multiplying matrix or, for 
%      pwaffine and pwprojective, a stack of 2^ncut matrices
%    transform.c: offset, [1 ndims] 
%      Note this differs from matlab's procrustes output
%      * For mean, procrustes, affine, or projective, only the first row is needed;
%      other rows are redundant and ignored.
%      * for pwaffine and pwprojective, the multiple rows have different meanings
%    transform also may include specifications of cutplanes (vcut), cutpoints (acut)
%      and projective parameters p (see psg_pwaffine_apply, psg_pwprojective_apply)
%
% coords_new: coordinates after transformation, size is [npts,ndims]
%
% 10Jul24: added pwprojective
% 25Dec24: allow transform.c to have multiple rows for mean, procrutes, affine, projective
%
%   See also:  PSG_GEOMODELS_RUN, PROCRUSTES, PSG_GEO_GENERAL, PSG_GEOMODELS_DEFINE,
%     PERSP_APPLY, PSG_PWAFFINE_APPLY, PSG_PWPROJECTIVE_APPLY.
%
switch model_class
    case {'mean','procrustes','affine'}
       npts=size(coords,1);
       coords_new=transform.b*coords*transform.T+repmat(transform.c(1,:),npts,1);
    case 'projective'
        %note change of variable names between psg_geo_projective and persp_apply
        coords_new=persp_apply(transform.T,transform.c(1,:),transform.p,coords);
    case 'pwaffine'
        coords_new=psg_pwaffine_apply(transform,coords);
    case 'pwprojective'
        coords_new=psg_pwprojective_apply(transform,coords);
    otherwise
        warning(sprintf('unknown model class %s',model_class));
        coords_new=nan(size(coords));
end
return
