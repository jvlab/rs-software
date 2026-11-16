function [d,adj_model,transform,opts_used]=psg_geo_affine(ref,adj,opts)
% [d,adj_model,transform,opts_used]=psg_geo_affine(ref,adj,opts) finds an affine model
% using regression, with standardized input and output variables
%
% ref: reference coordinates, size=[npts,ref_dim]
% adj: coordinates of dataset to be adjusted, size=[npts,adj_dim]
% opts: options, can be omitted or empty
%   opts.if_offset: 1 to allow offset (default)
%   opts.no_rankwarn: 1 to disable rank-deficient warnings (default)
%
% d: goodness of fit, mean squared deviation of adj_model from res, divided by mean squared dev of ref
% adj_model: coordinates of adj, after transformation
% transform:
%   transform.b: scalar, here always 1 since scale factor is absorbed into T 
%   transform.T: matrix of size [adj_dim max(ref_dim,adj_dim)]
%   transform.c: offset, row of size [1 max(ref_dim, adj_dim)] 
%   adj_model=transform.b*adj*transform.T+repmat(transform.c,npts,1)
% opts_used: options used  
%
% if ref dimension is less than adj dimension, then ref will be padded with
% columns of zeros
%
% 15Dec23: added optional disabling of rank-deficient warning
%
%   See also:  REGRESS, PSG_GEO_PROCRUSTES, PSG_GEOMODELS_TEST, PSG_GEOMODELS_DEFINE, PSG_GEO_GENERAL.
%
if (nargin<=2) opts=struct; end
opts=filldefault(opts,'if_offset',1);
opts=filldefault(opts,'no_rankwarn',1);
if opts.no_rankwarn
    warn_id='stats:regress:RankDefDesignMat';
    warn_state=warning('query',warn_id);
    warning('off',warn_id);
end
adj_dim=size(adj,2);
ref_dim=size(ref,2);
opts_used=opts;
%
npts=size(adj,1);
if ref_dim<adj_dim
    ref=[ref,zeros(npts,adj_dim-ref_dim)];
end
%
% regression (affine) fit
%
t_regr=zeros(opts.if_offset+adj_dim,ref_dim);
if (opts.if_offset==1)
    adj_aug=[ones(npts,1),adj];
else
    adj_aug=adj;
end
for iref_dim=1:max(ref_dim,adj_dim) 
    t_regr(:,iref_dim)=regress(ref(:,iref_dim),adj_aug);
end
if opts.no_rankwarn
    warning(warn_state);
end
adj_model=adj_aug*t_regr; %reconstitute based on regression
transform.T=t_regr(1+opts.if_offset:end,:);
if opts.if_offset
    transform.c=t_regr(1,:);
else
    transform.c=zeros(1,max(ref_dim,adj_dim));
end
transform.b=1; %for consistency with Procrustes
d_num=sum(sum((ref-adj_model).^2,1));
d_den=sum(sum((ref-repmat(mean(ref,1),npts,1)).^2,1));
d=d_num/d_den;
return
end
