function [consensus,znew,ts,details,opts_pcon_used]=procrustes_consensus(z,opts_pcon)
% [consensus,znew,ts,details,opts_pcon_used]=procrustes_consensus(z,opts_pcon) carries out a Procrustes consensus calculation
%
% This algorithm generalizes MATLAB's procrustes tomore than two datasets, allowing for missig values (indicated by NaNs), eliminating translations,
% and creation of a consensus that is of higher dimension than any of the components, by zero-padding z along dimension 2.
%
% Args:
%   z (float 3-D array): input data, size is [npts nds nsets] where npts is the number of points, nds is the number of dimensions, and nsets is the number of datasets
%
%   opts_pcon (struct): options struture, may be omitted, with fields
%
%      - **Allowed transformations**
%      - allow_scale (int): 1 to allow scaling, 0 to not allow; default is 1
%      - allow_reflection (int): 1 to allow reflection, 0 to not allow; default is 1
%      - allow_offset (int): 1 to allow translation, 0 to not allow; default is 1
%
%      - **Initialization and termination**
%      - initialize_set (int or char): method for initialization and alignment on each iteration; default is 1
%
%          - If in [1:nsets]: use (z(:,:,intialize_set)) for initial guess and alignment, or first dataset after that with at least some overlap
%          - if 'pca','pca_center','pca_nocenter': use first nds principal components across all datasets for initial guess and alignment
%          
%              - 'pca_center': replace NaN's by mean and then center prior to PCA
%              - 'pca_nocenter': replace NaN's by mean and do not center prior to PCA
%              - 'pca': replace NaN's by mean and center if allow_offset=1, do not center if allow_offset=0
%
%          - If 0: specify initial guess and alignment explicitly with the fields
%
%              - initial_guess (float 2-D array): array of size [npts nds] for initial guess; if empty ([]), then normally distributed random quantities,
%              - alignment (float 2-D array): array of size [npts nds] for alignment; if empty ([]), use initial_guess
%
%      - if_initpca_rot (int): specifies how to use PCA for initialization, if initialize_set='pca_center','pca_nocenter',or 'pca'; default is 1
%
%          - 1 rotates the initial guess into its principal components, best if data are not zero-padded
%          - 0 does not rotate the initial guess into its initial components, best if the data are zero-padded to access higher dimensions
%
%      - max_niters (int): maximum number of iterations; default is 100
%      - max_rmstol (float): rms tolerance for termination, as rms change in all coordinates of consensus, default is 10^<sup>-5</sup>
%
%      - **Treatment of overlaps**
%       - exclude_nan (int): 1 to exclude NaN values when computing overlaps, 0 to not exclude; default is 1
%      - overlaps (int 2-D array): array of size [npts nsets]; 1 indicates which points should be included, 0 to exclude.  If omitted or empty (default), it is computed based on exclude_nan
%      - if_justcheck (int): 1 to just check if overlaps are sufficient, 0 for full computation; default is 0; see note below rearding algorihtm.
%
% Returns:
%   consensus (float 2-D array): [npts ndims]: the consensus data
%
%   znew (float 3-D array): [npts ndims nsets]: the original data, after transformation to the consensus
%
%   ts (cell 1-D array): the transformations.  They act as follows: znew(:,:,iset)=ts{iset}.scaling\*z(:,:,iset)\*ts{iset}.orthog+repmat(ts{iset}.translation,npts,1). These variable names can be converted to MATLAB's conventions via `procrustes_compat`.
%   
%   details (struct): details of convergence, with fields
%
%        - ts_cum{k}{iset} is the cumulative transformation found for dataset iset at iteration k
%        - consensus(:,:,k) is the consensus found at iteration k
%        - z(:,:,iset,k) is the best fit of each dataset at iteration k
%        - rms_change(k) is the rms change at iteration k
%        - rms_dev(iset,k) is the rms deviation between all fitted points in dataset iset and the consensus at iteration k (points without overlaps are omitted), per coordinate
%        - zz_check_diff(k+1,iset):, are computatooinal checks at each iteration, should be neaer zero
%        - warnings: warnings if not enough overlaps
%        - overlap_pairs(iset1,iset2): number of points that overlap between datasets 1 and 2
%        - overlap_totals(ipt): number of overlaps at each data point
%        - initialize_use(ipt,1): which dataset is used to initialize each point (if initialize_set>0)
%
%   opts_pcon_used (struct): opts_pcon, with options used filled in
%
% Note: The algorithm
%   Initialization: guess a consensus via one of the methods specified by initialize_set
%
%   Iteration: 
%       - Align all the datasets to the tentative consensus, using settings in opts_pcon for scale, reflection, and offset
%       - Set the new tentative consensus to be the point-by-point centroid of each of the component dataasets, following the above alignment
%       - Align the tentative consensus as specified by opts_pcon.alignment, to prevent drift
%
%   Terminate after coordinates have not changed within tolerance of opts_pcon.max_rmstol
%
%   As a screen for whether there is sufficient overlap between the datasets,
%   `isgraphc` is used; if the overlap graph is disconnected, a consensus alignment should not be attempted. But note that connectivity of the overlap graph is not sufficient to
%   guarantee stability, as multiple points (depending on the dimension to be fit, and the number of datasets that overlap) are needed to determine a
%   transformation. Overlap details are in details.overlap_pairs and details.overlap_totals .
%
% See also:  PROCRUSTES_COMPAT, ISGRAPHC.
%
if (nargin<2)
    opts_pcon=struct;
end
opts_pcon=filldefault(opts_pcon,'max_niters',100);
opts_pcon=filldefault(opts_pcon,'max_rmstol',10^-5);
opts_pcon=filldefault(opts_pcon,'allow_scale',1);
opts_pcon=filldefault(opts_pcon,'if_normscale',0); %added 29Nov24
opts_pcon=filldefault(opts_pcon,'allow_reflection',1);
opts_pcon=filldefault(opts_pcon,'allow_offset',1);
opts_pcon=filldefault(opts_pcon,'initialize_set',1);
opts_pcon=filldefault(opts_pcon,'initial_guess',[]);
opts_pcon=filldefault(opts_pcon,'alignment',opts_pcon.initial_guess);
opts_pcon=filldefault(opts_pcon,'overlaps',[]);
opts_pcon=filldefault(opts_pcon,'if_justcheck',0);
opts_pcon=filldefault(opts_pcon,'exclude_nan',1);
opts_pcon=filldefault(opts_pcon,'if_initpca_rot',1);
%
opts_pcon_used=opts_pcon;
%
scaling_token=(opts_pcon.allow_scale==1);
if opts_pcon.allow_reflection==1
    reflection_token='best';
else
    reflection_token=false;
end
%
npts=size(z,1);
nds=size(z,2);
nsets=size(z,3);
if isempty(opts_pcon.overlaps)
    opts_pcon.overlaps=ones(npts,nsets);
    if opts_pcon.exclude_nan %25May24
        anynan=reshape(any(isnan(z),2),size(z,1),size(z,3));
    end
    opts_pcon.overlaps(anynan==1)=0;
end
znew=z;
%
details=struct;
details.ts_cum=cell(0);
details.consensus=zeros(npts,nds,0);
details.z=zeros(npts,nds,nsets,0);
details.rms_change=zeros(0);
details.rms_dev=zeros(nsets,0);
details.overlap_pairs=opts_pcon.overlaps'*opts_pcon.overlaps;
details.overlap_totals=sum(opts_pcon.overlaps,2);
details.warnings=[];
if any(details.overlap_totals==0)
    wmsg='some data points never occur in the overlap matrix';
    warning(wmsg);
    details.warnings=strvcat(details.warnings,wmsg);
end
any_ovlp=double(details.overlap_pairs>0);
% graph_ovlp=graph(any_ovlp-diag(diag(any_ovlp)));
% conncomps=conncomp(graph_ovlp); %is the overlap graph connected?
% if any(conncomps>1)
if_connected=isgraphc(any_ovlp-diag(diag(any_ovlp)));
if if_connected~=1
    wmsg='overlap graph is not connected';
    details.warnings=strvcat(details.warnings,wmsg);
end
if (opts_pcon.if_justcheck)
    consensus=[];
    ts=[];
    return
end
%
niters=0;
rms=Inf;
first_nz=zeros(npts,1);
if ischar(opts_pcon.initialize_set)
    switch opts_pcon.initialize_set
        %pca_center: pca combining all datasets, setting NaN's to means, and then subtract means prior to PCA
        %pca_nocenter: pca combining all datasets, setting NaN's to 0, and do not subtract means
        %pca: as above, but center if offset allowed, zero if not
        case {'pca_center','pca_nocenter','pca'}
            switch opts_pcon.initialize_set
                case 'pca_nocenter'
                    if_mean=0;
                case 'pca_center'
                    if_mean=1;
                case 'pca'
                    if_mean=opts_pcon.allow_offset;
            end
            zpca=reshape(z,npts,nds*nsets);
            zpca_means=zeros(1,nds*nsets);
            for ic=1:nds*nsets
                nonans=find(~isnan(zpca(:,ic)));
                nans=find(isnan(zpca(:,ic)));
                if ~isempty(nonans)
                    zpca_means(ic)=mean(zpca(nonans,ic));
                end
                zpca(nans,ic)=if_mean*zpca_means(ic);
            end
            if (if_mean)
                zpca=zpca-repmat(zpca_means,npts,1);
            end
            [u,s,v]=svd(zpca); % zpca=u*s*v'           
            details.pca.init=zpca;
            details.pca.u=u;
            details.pca.s=diag(s);
            details.pca.v=v;
            details.if_mean=if_mean;
            if opts_pcon.if_initpca_rot
                initial_guess=u(:,1:nds)*s(1:nds,1:nds)*v(1:nds,1:nds)';
            else
                initial_guess=u(:,1:nds)*s(1:nds,1:nds); %do not rotate
            end
            alignment=initial_guess;
        otherwise
            error(sprintf('unrecognized initialization option: %s'));
    end
else
    if opts_pcon.initialize_set>0
        %if opts_pcon.overlaps is not all 1's, find first dataset with a nonzero value of overlaps(iset,:)
        overlaps_permute=opts_pcon.overlaps(:,1+mod(opts_pcon.initialize_set-1+[0:nsets-1],nsets));
        for ipt=1:npts
            first_nz(ipt,1)=mod(opts_pcon.initialize_set-1+min(find(overlaps_permute(ipt,:)>0)-1),nsets)+1;
            initial_guess(ipt,:)=z(ipt,:,first_nz(ipt,1));
        end
        alignment=initial_guess;
    else
        initial_guess=opts_pcon.initial_guess;
        if isempty(initial_guess) %section added 27Jan25
            zstd=std(z(:),'omitnan');
            initial_guess=zstd*randn(size(z,1),size(z,2));
            opts_pcon_used.initial_guess=initial_guess;
            if isempty(opts_pcon.alignment)
                opts_pcon.alignment=initial_guess;
                opts_pcon_used.alignment=initial_guess;
            end
        end
        alignment=opts_pcon.alignment;
    end
end
details.initial_guess=initial_guess;
details.initialize_use=first_nz;
details.alignment=alignment;
consensus=initial_guess; %initial guess of consensus
while (niters<opts_pcon.max_niters & rms>opts_pcon.max_rmstol)
    niters=niters+1;
    zz=zeros(npts,nds,nsets);
    zznan=nan(npts,nds,nsets); %will have nan's for all non-selected elements
    ts_cum=cell(1,nsets);
    zz_sel=cell(1,nsets);
    t=cell(1,nsets);
    scale_list=zeros(1,nsets);
    for iset=1:nsets
        select=find(opts_pcon.overlaps(:,iset)>0);
        %do a Procrustes alignment for all points that have an overlap [Step 1]
        [d,zz_sel{iset},t{iset}]=procrustes(consensus(select,:),z(select,:,iset),'Scaling',scaling_token,'Reflection',reflection_token);
        scale_list(iset)=t{iset}.b;
    end
    if (opts_pcon.allow_scale==1) & (opts_pcon.if_normscale) %renormalize if requested
        sf=1/geomean(scale_list);
        for iset=1:nsets
            t{iset}.b=t{iset}.b*sf;
            t{iset}.c=t{iset}.c*sf;
            zz_sel{iset}=zz_sel{iset}*sf;
        end
    else
        sf=1;
    end
    for iset=1:nsets
        select=find(opts_pcon.overlaps(:,iset)>0);
        ts_cum{iset}.scaling=t{iset}.b;
        ts_cum{iset}.orthog=t{iset}.T;       
        % Z = TRANSFORM.b * Y * TRANSFORM.T + TRANSFORM.c.
        c_row=t{iset}.c(1,:);
        zz(:,:,iset)=t{iset}.b*z(:,:,iset)*t{iset}.T+repmat(c_row,npts,1); %but transform all the points
        details.zz_check_diff(niters+1,iset)=max(max(abs(zz(select,:,iset)-zz_sel{iset}))); 
        if (opts_pcon.allow_offset==0) %remove offset if requested
            zz(:,:,iset)=zz(:,:,iset)-repmat(c_row,npts,1);
            ts_cum{iset}.translation=zeros(1,nds);
        else
            ts_cum{iset}.translation=c_row;
        end
        zznan(select,:,iset)=zz(select,:,iset); %non-selected elements remain nans
    end
    consensus_new=mean(zznan,3,'omitnan'); %only average non-nans [Step 2]
    %realign [Step 3]
    scaling_token_new=scaling_token & opts_pcon.if_normscale==0;
    [d,consensus_new,t_new]=procrustes(alignment,consensus_new,'Scaling',scaling_token_new,'Reflection',reflection_token); %don't renormalize
    if opts_pcon.allow_offset==0 %29Nov24
        consensus_new=consensus_new-t_new.c;
    end
    details.ts_cum{niters}=ts_cum;
    details.consensus(:,:,niters)=consensus_new;
    rms=sqrt(mean((consensus_new(:)-consensus(:)).^2));
    details.z(:,:,:,niters)=zz;
    details.rms_change(1,niters)=rms;
    consensus=consensus_new;
%    details.rms_dev(:,niters)=reshape(sqrt(mean(mean((zz-consensus_new).^2,1),2)),[nsets 1]);
%    details.rms_dev_orig(:,niters)=reshape(sqrt(mean(mean((zz-consensus_new).^2,1),2)),[nsets 1]);
    for iset=1:nsets
        details.rms_dev(iset,niters)=sqrt(mean(mean((zznan(:,:,iset)-consensus_new).^2,1,'omitnan'),2));
    end
end   
znew=zz;
ts=ts_cum;
return
