function [recon_pcaxes,recon_coords,var_ex,var_tot,coord_maxdiff,opts_used]=psg_pcaoffset(coords,offset,opts)
% [recon_pcaxes,var_ex,var_tot,cooord_maxdiff,opts_used]=psg_pcaoffset(coords,offset,opts) 
% carries out pca after an offset, and then adds the offset back,
% and creates recon_pcaxes with successive additions of principal components
%
% coords: [nstims nd]: each row is the coordinate of a point
% offset: [1,nd]: offset; typically centroid, but zeros if not specified
% opts.if_log: 1 to log
% opts.nd_max: maximum dimension to fit, defaults to Inf; nd_fit=min(nd,nd_max)
%
% recon_pcaxes[nstims nd] recon_pcaxes[: 1:k] are the coordinates in the first k pcs
% recon_coords{nd}: recon_coords{k} is [nstims nd], the reconstructions in the original axes from the first k pcs
% var_ex: [1 nd]: var_ex(k) is variance explained around offset by first k components
% var_tot: total variance of coords around offset
% coords_maxdiff: [1 nd]: maximum difference to reconstructed coords
% opts_used: options used, also qu, qs, qv,offset such that coords=qu*qs*qv'+offset
%
% offset+(coords-offset)*qv(:,k)*qv(:,k)' is a reconstruction from the first k coordinates in original axes
% offset+(coords-offset)*qv is the reconstruction in the PC space. Since qv'*qv is the identity (up to rank), and coords-offset=qu*qs*qv',
%    this is also offset+qu*qs
%
%  24May24: allow coords to have nans (which are ignored)
%  23Jun25: add offset to opts_used
%  24Jun25: allow for nstims<nd
%  11Oct26: doc fix
%
%   See also:  PSG_QFORMPRED, PSG_PLANECYCLE, PSG_VISUALIZE_DEMO.
%
if (nargin<2)
    offset=zeros(1,size(coords,2));
end
if (nargin<3)
    opts=struct();
end
opts=filldefault(opts,'if_log',0);
opts=filldefault(opts,'nd_max',Inf);
%
nans=find(any(isnan(coords),2));
nonans=setdiff([1:size(coords,1)],nans);
%
coords_nonans=coords(nonans,:);
%
nstims=size(coords,1);
nstims_nonan=size(coords_nonans,1);
nd=size(coords_nonans,2);
nd_fit=min(nd,opts.nd_max);
coords_offset=coords_nonans-repmat(offset,nstims_nonan,1);
%
[qu,qs,qv]=svd(coords_offset,0); %coords_offset = qu*qs*qv';
recon_pcaxes=qu*qs+repmat(offset,nstims_nonan,1); %coordinates in pca space with offset added back
%
d_econ=size(qs,1); %section added 24Jun25
if d_econ<nd_fit
    qs=[qs;zeros(nd_fit-d_econ,nd_fit)];
    qu=[qu,zeros(d_econ,nd_fit-d_econ)];
    qv(:,d_econ+1:nd_fit)=0; %ensure rank-deficiency when computing (coords-offset)*qv
end
var_tot=sum(coords_offset(:).^2);
var_ex=zeros(1,nd_fit);
coord_maxdiff=zeros(1,nd_fit);
recon_coords=cell(1,nd_fit);
for idim=1:nd_fit
    quqs=qu(:,[1:idim])*qs([1:idim],[1:idim]);
    recon_offset=quqs*(qv(:,[1:idim]))';
    recon_coords{idim}=NaN(nstims,nd);
    recon_coords{idim}(nonans,:)=recon_offset+repmat(offset,nstims_nonan,1);
    coord_maxdiff(idim)=max(max(abs(recon_offset-coords_offset)));
    var_ex(idim)=sum(quqs(:).^2);
    if opts.if_log
        disp(sprintf(' %2.0f-dim pca, variance explained =%7.3f of %7.3f (frac unex: %8.5f), max coord diff to %2.0f-dim MDS is %6.3f',...
            idim,var_ex(idim),var_tot,1-var_ex(idim)/var_tot,nd_fit,coord_maxdiff(idim)));
    end
end
%take care of nans
recon_pcaxes(nonans,:)=recon_pcaxes;
recon_pcaxes(nans,:)=NaN;
opts.qu=NaN(nstims,size(qu,2));
opts.qu(nonans,:)=qu;
opts.qs=qs;
opts.qv=qv;
opts.offset=offset;
%
opts_used=opts;
return
