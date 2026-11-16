function [d,adj_model,transform,opts_used]=psg_geo_projective(ref,adj,opts)
% [d,adj_model,transform,opts_used]=psg_geo_projective(ref,adj,opts) finds a 
% projective model (perspective transformation)
% with standardized input and output variables
%
% ref: reference coordinates, size=[npts,ref_dim]
% adj: coordinates of dataset to be adjusted, size=[npts,adj_dim]
% opts: options, can be omitted or empty
%    opts.method: should be 'fmin' (default), alternatively, 'oneshot' (see persp_xform)
%    opts.if_display: 1 to display messages from fminsearch
%   opts.no_rankwarn: 1 to disable rank-deficient warnings (default)
%
% d: goodness of fit, mean squared deviation of adj_model from res, divided by mean squared dev of ref
% adj_model: coordinates of adj, after transformation
% transform:
%   transform.b: scalar, equal to 1 (scale absorbed in T)
%   transform.T: matrix of size [adj_dim max(ref_dim,adj_dim)]
%   transform.c: offset, row of size [max(ref_dim, adj_dim) 1]
%   transform.p: column of size adj_dim
%
%  persp=[T | p]
%        [-----]
%        [c | 1]
%
% Each row of input (adj) is considered as a homogeneous vector with an augmented coordinate 1 at the end
% This matrix is then post-multiplied by persp, yielding a homogeneous vector.
% Output (adj_model) are the rows of this matrix, divided by the final element.
%   Notes
%     persp only matters up to homogeneity, but its lower right element is fixed at 1.
%     If p=persp(1:end-1,end) is zero, this is an affine transformation with offset c=persp(end,1:end-1);
%     if p and c are zero, this is a linear transformation by T.
%
% opts_used: options used
%
% 15Dec23: added optional disabling of rank-deficient warning
%
%   See also: PSG_GEOMODELS_TEST, PSG_GEOMODELS_DEFINE, PSG_GEO_GENERAL, PERSP_XFORM_FIND, PERSP_APPLY,
%    FMINSEARCH.
%
if (nargin<=2) opts=struct; end
opts=filldefault(opts,'method','fmin');
opts=filldefault(opts,'if_cycle',1); %ignored unless opts.method is set to 'oneshot';
opts=filldefault(opts,'if_display',1);
opts=filldefault(opts,'fmin_opts',optimset('fminsearch'));
opts=filldefault(opts,'no_rankwarn',1);
if opts.no_rankwarn
    warn_id='stats:regress:RankDefDesignMat';
    warn_state=warning('query',warn_id);
    warning('off',warn_id);
end
%
if opts.if_display==0 %turn off display in fminsearch
    opts.fmin_opts=optimset(opts.fmin_opts,'Display','off');
end
opts_used=opts;
%
adj_dim=size(adj,2);
ref_dim=size(ref,2);
%
npts=size(adj,1);
if ref_dim<adj_dim
    ref=[ref,zeros(npts,adj_dim-ref_dim)];
end
%
% find the perspective transformation
%
[persp,adj_model,ou_persp]=persp_xform_find(adj,ref,opts);
if opts.no_rankwarn
    warning(warn_state);
end
%  persp=[T | p]
%        [-----]
%        [c | 1]
%retrieve any new fields from ou_persp
fns=fieldnames(ou_persp);
for ifn=1:length(fns)
    fn=fns{ifn};
    opts_used=filldefault(opts_used,fn,ou_persp.(fn));
end
%
% intepretration of persp (variable names changed here for compatibility with psg_geo_procrustes and
% psg_geo_affine: 
%
transform.b=1;
transform.T=persp(1:end-1,1:end-1);
transform.c=persp(end,1:end-1);
transform.p=persp(1:end-1,end);
%
d_num=sum(sum((ref-adj_model).^2,1));
d_den=sum(sum((ref-repmat(mean(ref,1),npts,1)).^2,1));
d=d_num/d_den;
%
return
end
