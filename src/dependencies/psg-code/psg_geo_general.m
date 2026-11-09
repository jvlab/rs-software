function [d,adj_model,transform,opts_used]=psg_geo_general(ref,adj,model_class,opts)
% [d,adj_model,transform,opts_used]=psg_geo_general(ref,adj,model_class,opts) finds a general model
% (procrustes, affine, etc) with standardized input and output variables
%
% ref: reference coordinates, size=[npts,ref_dim]
% adj: coordinates of dataset to be adjusted, size=[npts,adj_dim]
% model_class: 'procrustes','affine', or any of the other values in model_types_def.(model).class
% opts: options, can be omitted or empty
%     opts.if_scale: 1 to allow scaling (default: 0)
%
% d: goodness of fit, mean squared deviation of adj_model from res, divided by mean squared dev of ref
% adj_model: coordinates of adj, after transformation
% transform: model-specific, but the following are typical
%   transform.b: scalar, will be 1 if opts.if_scale=0
%   transform.T: matrix of size [adj_dim max(ref_dim,adj_dim)]
%   transform.c: offset, row of size [max(ref_dim, adj_dim) 1], will be zeros if ref and adj are centered
%   adj_model=transform.b*adj*transform.T+repmat(transform.c,npts,1)
% opts_used: options used
%   opts_used.warnings: warnings
%
% 05Dec23: add piecewise affine
%
%   See also: PROCRUSTES, PSG_GEOMODELS_TEST, PSG_GEOMODELS_DEFINE, PSG_GEO_PROCRUSTES, PSG_GEO_AFFINE, PSG_GEO_PROJECTIVE.
%
if (nargin<=3) opts=struct; end
adj_dim=size(adj,2);
ref_dim=size(ref,2);
%
npts=size(adj,1);
%
switch model_class
    case 'procrustes'
        [d,adj_model,transform,opts_used]=psg_geo_procrustes(ref,adj,opts);
    case 'affine'
        [d,adj_model,transform,opts_used]=psg_geo_affine(ref,adj,opts);
    case 'projective'
        [d,adj_model,transform,opts_used]=psg_geo_projective(ref,adj,opts);
    case 'pwaffine'
        [d,adj_model,transform,opts_used]=psg_geo_pwaffine(ref,adj,opts);
    case 'mean' %model is mean of the reference dataset
        d=1;
        adj_model=repmat(mean(ref,1),npts,1);
        if (ref_dim<adj_dim)
            adj_model=[adj_model,zeros(npts,adj_dim-ref_dim)];
        end
        opts_used=opts;
        transform=struct;
        transform.b=1;
        transform.T=zeros(adj_dim,max(ref_dim,adj_dim));
        transform.c=adj_model(1,:);
    otherwise
        wstring=sprintf('model class %s not recognized.',model_class);
        d=1;
        adj_model=zeros(npts,max(ref_dim,adj_dim));
        transform=struct;
        opts_used=opts;
        warning(wstring);
        opts_used.warnings=wstring;
end
if ~isfield(opts_used,'warnings')
    opts_used.warnings=[];
end
return
end
