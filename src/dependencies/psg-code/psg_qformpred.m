function [d_qform,d_mds,opts_qform_used]=psg_qformpred(q,btc_coords,rays,opts_qform)
% [d_qform,d_mds,opts_qform_used]=psg_qformpred(q,btc_coords,rays,opts_qform)
% computes predicted coordinates from a quadratic form defined form model of thresholds
%
% q: a quadratic form defined by threshold data; coords in order of btc_define
% btc_coords: [nstims nbtc]: btc coordinates of each stimulus
% rays: ray structure, typically from btc_findrays
% opts_qform: options
%    if_log: 1 to log (defaults to 0)
%    negeig_makezero: 1 to set negative eigenvalues to zero in MDS (default)
%    
% d_qform, d_mds: cell arrays {1,nbtc}, for d_[qform|mds]{idim} is [nstim nbtc] array of predicted coords
% d_qform:  Find the square root of the quadratic form.  Then since
%   x'qy=[sqrt(q)x]'[sqrt(q)y], then sqrt(q)x yields the coordinates that
%   whose Euclidean distances are given by the quadratic form x'qy.  For a
%   k-dimensional model, take the first k PC's of that.
% d_mds: compute the distances via the quadratic form.  Then do
%    muldimensional scaling, and take the k-dimensional model
% opts_qform_used: opts with defaults filled in, and
%    var_ex: variance explained by each d_mds model
%    var_tot: total variance
%    predcoords: coordinates predicted by full quadratic model
%
% d_qform (first method) and d_mds(second method) appear identical except for arbitrary sign flips
%
% 19Dec22: add if_pca_centroid: defaults to 1 to do pca around centroid for the qform model
% 24Dec22: add post-multiplying by eigenvectors in d_pca, to bring methods into coincidnce
% 07May26: fix bug (d_pca_mdscoords undefined)
%
%  See also: PSG_QFORMPRED_DEMO, BTC_DEFINE, BTC_FINDRAYS, EIG, SVD, PSG_PCAOFFSET.
%
if (nargin<4) 
    opts_qform=struct();
end
opts_qform=filldefault(opts_qform,'if_log',0);
opts_qform=filldefault(opts_qform,'negeig_makezero',1);
opts_qform=filldefault(opts_qform,'negtol',10^-7); %eigenvalues between 0 and -negtol are set to zero before checking for negative eigenvalues
opts_qform=filldefault(opts_qform,'if_pca_centroid',1); %1 to do PCA around centroid
%
nstims=size(btc_coords,1);
nbtc=size(q,1);
if_origin=any(rays.whichray==0);
if (opts_qform.if_log)
    disp(sprintf('origin found: %1.0f',if_origin));
end
%
%fit quadratic form two ways
%
%diagonalize
[qeivecs,qeivals]=eig(q);
qeivals=diag(qeivals);
tinyneg=find(qeivals>-opts_qform.negtol & qeivals<0);
qeivals(tinyneg)=0;
[qeivals_sorted,inds]=sort(qeivals,'descend');
qeivecs_sorted=qeivecs(:,inds);
nbtc=length(qeivals_sorted);
if opts_qform.if_log
    disp(sprintf('qform: %3.0f eigenvalues, largest is %5.2f, smallest is %5.2f, %3.0f are less than 0',...
        nbtc,qeivals_sorted(1),qeivals_sorted(end),sum(qeivals_sorted<0)));
end
if (opts_qform.negeig_makezero)
    if opts_qform.if_log
        disp(sprintf('%3.0f eigenvalues set to zero',sum(qeivals_sorted<0)));
    end
    qeivals_sorted(qeivals_sorted<0)=0;
end
if opts_qform.if_log
    disp('eigenvectors as columns, sorted from largest to smallest eigenvalues')
    disp(qeivecs_sorted)
end
%
%compute coordinates (square root of the quadratic form, computed "by hand" from eigenvectors
%and square roots of eigenvalues)
%
qeivecs_scaled=qeivecs_sorted.*repmat(sqrt(qeivals_sorted(:))',nbtc,1)*qeivecs_sorted'; %last term added 24Dec22, just a rotation
predcoords=btc_coords*qeivecs_scaled;
if (if_origin) %if origin is found, use it; otherwise, use centroid
    qform_origin=predcoords(find(rays.whichray==0),:);
    msg='origin for qform coords taken from random stimulus.';
else
    qform_origin=mean(predcoords,1);
    msg='origin for qform coords taken from centroid';
end
if opts_qform.if_log
    disp(msg);
end
predcoords=predcoords-repmat(qform_origin,nstims,1); %move origin to zero
%
%First method:
%For each dimension, use the highest principal components of the full model obtained from the square root
%of the quadratic form. Note that this PCA step is necessary, since, depending on the
%texture params to be modeled, i.e., btc_augcoords, only the "higher" dimensions of the MDS fit 
%may be relevant
%
qform_centroid=mean(predcoords,1);
if (opts_qform.if_pca_centroid)
    pca_offset=qform_centroid;
else
    pca_offset=zeros(1,nbtc);
end
if (opts_qform.if_log)
    disp(sprintf('do pca around centroid: %1.0f',opts_qform.if_pca_centroid));
    disp(qform_centroid);
end
%do offset pca
[d_pca,predcoords_recon,var_ex,var_tot,coord_maxdiff]=psg_pcaoffset(predcoords,pca_offset);
if (if_origin) %if origin is found, use it; otherwise, use centroid
    qform_origin=d_pca(find(rays.whichray==0),:);
    msg='origin for mds coords taken from random stimulus.';
else
    qform_origin=mean(predcoords,1); %was d_pca_mdscoords
    msg='origin for mds coords taken from centroid';
end
d_pca=d_pca-repmat(qform_origin,nstims,1);
d_qform=cell(1,nbtc);
for idim=1:nbtc
    d_qform{idim}=d_pca(:,[1:idim]);
    if opts_qform.if_log
        disp(sprintf(' %2.0f-dim qform model, variance explained =%7.3f of %7.3f (frac unex: %8.5f), max coord diff to %2.0f-dim MDS is %6.3f',...
            idim,var_ex(idim),var_tot,1-var_ex(idim)/var_tot,nbtc,coord_maxdiff(idim)));
    end
end
%
%Second method: do MDS on the distances between the coordinates predicted by the full quadratic form
% and then peel off successive dimensions of the coordinates yielded by MDS
%
d_mds=cell(1,nbtc);
qf_dsq=zeros(nstims,nstims);
for istim=1:nstims
    for jstim=1:nstims
        qf_dsq(istim,jstim)=sum((predcoords(istim,:)-predcoords(jstim,:)).^2);
    end
end
qf_centered=repmat(mean(qf_dsq),nstims,1);
qf_mds=qf_dsq-qf_centered-qf_centered'+mean(qf_dsq(:));
[qf_vec,qf_val]=eig(-qf_mds/2);
qf_val_diag=real(diag(qf_val));
tinyneg=find(qf_val_diag>-opts_qform.negtol & qf_val_diag<0);
qf_val_diag(tinyneg)=0;
qf_val_diag(nbtc+1:end)=0;
if (opts_qform.if_log)
    disp(sprintf('  mds: %3.0f eigenvalues, largest is %5.2f, smallest is %5.2f, %3.0f are less than 0',...
        nbtc,qf_val_diag(1),qf_val_diag(nbtc),sum(qf_val_diag<0)));
end
if (opts_qform.negeig_makezero)
    if (opts_qform.if_log)
        disp(sprintf('%3.0f eigenvalues set to zero',sum(qf_val_diag<0)));
    end
    qf_val_diag=max(0,qf_val_diag);
end
qform_mdscoords=real(qf_vec)*diag(sqrt(qf_val_diag));
%
if (if_origin) %if origin is found, use it; otherwise, use centroid
    qform_mds_origin=qform_mdscoords(find(rays.whichray==0),:);
    msg='origin for mds coords taken from random stimulus.';
else
    qform_mds_origin=mean(qform_mdscoords,1);
    msg='origin for mds coords taken from centroid';
end
if opts_qform.if_log
    disp(msg);
end
qform_mdscoords=qform_mdscoords-repmat(qform_mds_origin,nstims,1);
for idim=1:nbtc
    d_mds{idim}=qform_mdscoords(:,[1:idim]);
end
%
opts_qform.var_ex=var_ex;
opts_qform.var_tot=var_tot;
opts_qform.predcoords=predcoords;
%
opts_qform_used=opts_qform;
return
end
