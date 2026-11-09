function [ra,warnings,details]=psg_align_stats(ds_align,sas_align,dim_list_in,dim_list_out,opts_pcon)
% [ra,warnings,details]=psg_align_stats(ds_align,sas_align,dim_list_in,dim_list_out,opts_pcon)
% knits together sets of coordinates that may have incompletely overlapping
% stimulus lists, and computes statistics of alignments via shuffles
%
% ds_align: cell array of coordinate sets
%   ds_align{iset}{idim} is an array of nstims x idim, containing the coordinates. 
%   coordinates for missing stimuli should be NaN
% sas_align: cell array of metadata
% dim_list_in: list of dimensions to process.  
% dim_list_out: list of dimennsions to create, one entry for each entry in dim_list_in
%    each must be >=corresponding entry in dim_list_in
% opts_pcon: options.  Most in procrustes_consensus, but also
%   nshuffs: number of shuffles (0: statistics not done), defaults to 500
%   if_frozen: 1 for frozen random numbers, 0 for new random numbers each time, <0 for a specific seed, defaults to 1
%   if_log: 1 to log, defaults to 1
%   if_swarm: 1 to use swarm, defaults to zero; if 1, then opts_pcon.swarm may have the folloiwng fields
%    if_log: 1 to log; default is zero
%    if_frozen: 1 for frozen random numbers (retains state of random number generator in any case); default is 1
%    max_niters:  max number of iterations for trials, default is 50
%    max_rmstol: max rms tolerance, default is 10^-4;
%    nrand: number of swarm initial guesses based on random numbers (in addition to based on pca and component data); default is 10
%
% ra: structure of results
%   ra.ds_knitted: coordinates for the knitted datasets
%   ra.ds_components{iset}: coordinates for the component datasets, after transformaton
%   ra.counts*: counts of data points, overall, by stimulus, and by set
%   ra.rmsavail*: root-mean-squared deviations prior to finding a consensus, overall, by stimulus, and by set
%   ra.rmsdev*: root-mean-squared deviations after consensus, by stimulus, and by set
%   ra.rmsdev*_shuff: root-mean-squared deviations after consensus, by stimulus, and by set  for shuffles
%   ra.opts_pcon_eachdim: cell array of structure of options used, for each dimension in dim_list_in
%   ra.opts_pcon: options common to all dimensions
%   ra.ts{ip}{iset}: transformation for dimension ip, set iset
%       ts{ip}{iset}.scaling is a scalar, ts{ip}{iset}.orthog is [dim_out dim_out], ts{iset}.translation is [1 dim_out]
% warnings: warnings
% details: details of minimization, from procrustes_consensus
% 
% 28Oct25: add details to output
% 30Oct25: add ts to output
% 31Oct25: add desc fields to output
% 10Oct25: bug fix in computing stims_nonan
% 11Mar26: allow for specified opts_pcon.initial_guess and opts_pcon.alignment
% 25May26: fix results metadata (last dim vs all dims on d5)
% 19Oct26: fix dimensioning of z
% 21Oct26: begin allowing for multiple intialization types, via opts_pcon.if_swarm and opts_pcon.swarm
%
%  See also:  PSG_ALIGN_STATS_DEMO, PSG_ALIGN_COORDSETS, PROCRUSTES_CONSENSUS, PSG_KNIT_STATS.
%
if nargin<=4
    opts_pcon=struct;
end
opts_pcon=filldefault(opts_pcon,'if_frozen',1);
opts_pcon=filldefault(opts_pcon,'nshuffs',500);
opts_pcon=filldefault(opts_pcon,'if_log',1);
opts_pcon=filldefault(opts_pcon,'pcon_initial_guess',[]);
opts_pcon=filldefault(opts_pcon,'pcon_alignment',opts_pcon.pcon_initial_guess);
opts_pcon=filldefault(opts_pcon,'if_swarm',0);
if opts_pcon.if_swarm
    opts_pcon=filldefault(opts_pcon,'swarm',struct());
    opts_pcon.swarm=filldefault(opts_pcon.swarm,'if_log',0);
    opts_pcon.swarm=filldefault(opts_pcon.swarm,'if_frozen',1);
    opts_pcon.swarm=filldefault(opts_pcon.swarm,'max_niters',50);
    opts_pcon.swarm=filldefault(opts_pcon.swarm,'max_rmstol',10^-4);
    opts_pcon.swarm=filldefault(opts_pcon.swarm,'nrand',10);
end
%
if opts_pcon.if_log
    disp(sprintf(' calculations with allow_scale=%1.0f, if_normscale=%1.0f',opts_pcon.allow_scale,opts_pcon.if_normscale));
end
%
ra=struct;
warnings=[];
%
nsets=length(ds_align);
dim_list_in_max=max(dim_list_in);
dim_list_out_max=max(dim_list_out);
%
ra.opts_pcon=opts_pcon;
ra.opts_pcon_eachdim=cell(1,dim_list_in_max);
%
%set up random number generator
%
if_frozen=opts_pcon.if_frozen;
if (if_frozen~=0) 
    rng('default');
    if (if_frozen<0)
        rand(1,abs(if_frozen));
    end
else
    rng('shuffle');
end
%verify that each set has same number of stimuli (possibly including nans)
nstims_all=sas_align{1}.nstims;
for iset=1:nsets
    if sas_align{iset}.nstims~=nstims_all
        wmsg='number of stimuli (including NaN responses for missing stimuli) differ across datasets after alignment, cannot proceed';
        disp(wmsg);
        warnings=strvcat(warnings,wmsg);
        return
    end
end
%
%determine number of stimuli in each set and make permutations for shuffling
%
stims_nan_align=cell(1,nsets);
stims_each_align=zeros(1,nsets);
permutes=cell(1,nsets);
nshuffs=opts_pcon.nshuffs;
for iset=1:nsets
    nstims_each_align(iset)=sas_align{iset}.nstims;
    stims_nan_align{iset}=find(isnan(ds_align{iset}{1}));
    stims_nonan=setdiff(1:nstims_each_align(iset),stims_nan_align{iset}); %nstims_align_each -> nstims_align_each(iset)
    permutes{iset}=zeros(dim_list_in_max,nstims_each_align(iset),nshuffs);
    for ishuff=1:nshuffs
        for dptr=1:length(dim_list_in)
            ip=dim_list_in(dptr);
            permutes{iset}(ip,stims_nonan,ishuff)=stims_nonan(randperm(length(stims_nonan))); %only shuffle nonans
        end
    end
    permutes{iset}(:,stims_nan_align{iset},:)=repmat(stims_nan_align{iset}(:)',[dim_list_in_max 1 nshuffs]); %nan's don't get shuffled
    if opts_pcon.if_log
        disp(sprintf(' set %2.0f: created shuffles for %3.0f stimuli',iset,length(stims_nonan)));
    end
end
%
%reformat data for consensus calculation
%
z=cell(dim_list_in_max,1); %,1 added 19Oct26
for dptr=1:length(dim_list_in)
    ip=dim_list_in(dptr);
    z{ip}=NaN(nstims_all,ip,nsets);
    for iset=1:nsets
        z{ip}(:,:,iset)=ds_align{iset}{ip}(:,[1:ip]); %only include data up to max dim used
    end
    npad=dim_list_out(dptr)-ip; %pad if we are to compute a consensus in a higher dimension
    if npad>0
        z{ip}(:,ip+[1:npad],:)=0;
    end
end
%
ra.ds_knitted=cell(1,dim_list_out_max);
ra.ds_components=cell(1,nsets); 
for iset=1:nsets
    ra.ds_components{iset}=cell(1,dim_list_out_max);
end
%
%these are vector distances, taking all coordinates into account
%
ra.rmsdev_dims='d1: dimension, d2: set or stim';
ra.rmsdev_setwise=zeros(dim_list_in_max,nsets); %d1: dimension, d2: set
ra.rmsdev_stmwise=zeros(dim_list_in_max,nstims_all); %d1: dimension, d2: stim,
ra.rmsdev_overall=zeros(dim_list_in_max,1); %rms distance, across all datasets and stimuli
ra.counts_dims='d1: n/a, d2: set or stim';
ra.counts_setwise=zeros(1,nsets);
ra.counts_stmwise=zeros(1,nstims_all);
%
ra.rmsdev_setwise_shuff=zeros(dim_list_in_max,nsets,1,nshuffs,2); %d1: dimension, d2: set, d3: n/a, d4: shuffle, d5: shuffle all coords or last coord
ra.rmsdev_stmwise_shuff=zeros(dim_list_in_max,nstims_all,1,nshuffs,2); %d1: dimension, d2: stim, d3: n/a, d4: shuffle, d5: shuffle all coords or last coord
ra.rmsdev_overall_shuff=zeros(dim_list_in_max,1,1,nshuffs,2); %d1: dimension, d2: n/a, d3: n/a, d4: shuffle, d5: shuffle last coord or all coords
%
%rms variance available in original data
ra.rmsavail_setwise=zeros(dim_list_in_max,nsets);
ra.rmsavail_stmwise=zeros(dim_list_in_max,nstims_all);
ra.rmsavail_overall=zeros(dim_list_in_max,1);
%
%shuffled values
ra.rmsdev_shuff_dims='d1: dimension, d2: set or stim, d3: n/a, d4: shuffle, d5: shuffle last coord or all coords';
ra.rmsdev_setwise_shuff=zeros(dim_list_in_max,nsets,1,nshuffs,2); %d1: dimension, d2: set, d3: n/a, d4: shuffle, d5: shuffle all coords or last coord
ra.rmsdev_stmwise_shuff=zeros(dim_list_in_max,nstims_all,1,nshuffs,2); %d1: dimension, d2: stim, d3: n/a, d4: shuffle, d5: shuffle all coords or last coord
ra.rmsdev_overall_shuff=zeros(dim_list_in_max,1,1,nshuffs,2); %d1: dimension, d2: n/a, d3: n/a, d4: shuffle, d5: shuffle last coord or all coords
%
ra.ts=cell(1,dim_list_in_max);
%
details=cell(1,dim_list_in_max);
for dptr=1:length(dim_list_in)
    ip=dim_list_in(dptr);
    dim_out=dim_list_out(dptr);
    opts_pcon_use=opts_pcon;
    if opts_pcon.initialize_set==0
        if ~isempty(opts_pcon.pcon_initial_guess)
            opts_pcon_use.initial_guess=opts_pcon.pcon_initial_guess{dim_out};
        else
            opts_pcon_use.initial_guess=[];
        end
        if ~isempty(opts_pcon.pcon_alignment)
            opts_pcon_use.alignment=opts_pcon.pcon_alignment{dim_out};
        else
            opts_pcon_use.alignment=[];
        end
    end
    sqs=sum(z{ip}.^2,2);
    ra.rmsavail_setwise(ip,:)=reshape(sqrt(mean(sqs,1,'omitnan')),[1 nsets]);
    ra.rmsavail_stmwise(ip,:)=reshape(sqrt(mean(sqs,3,'omitnan')),[1 nstims_all]);
    ra.rmsavail_overall(ip,:)=sqrt(mean(sqs(:),'omitnan'));
    %do unshuffled
    [consensus,znew,ts,details{ip},ra.opts_pcon_eachdim{ip}]=psg_align_stats_do(z{ip},opts_pcon_use);
    if opts_pcon.if_log
        disp(sprintf(' created  Procrustes consensus from dim %2.0f to dim %2.0f based on component datasets, iterations: %4.0f, final total rms dev per coordinate: %8.5f',...
            ip,dim_out,length(details{ip}.rms_change),sqrt(sum(details{ip}.rms_dev(:,end).^2))));
    end
    %
    ra.ts{ip}=ts;
    ra.ds_knitted{dim_out}=consensus;
    for iset=1:nsets
        ra.ds_components{iset}{dim_out}=znew(:,:,iset);
    end
    sqdevs=sum((znew-repmat(consensus,[1 1 nsets])).^2,2); %squared deviation of consensus from rotated component
    %rms deviation across each dataset, summed over coords, normalized by the number of stimuli in each dataset
    ra.rmsdev_setwise(ip,:)=reshape(sqrt(mean(sqdevs,1,'omitnan')),[1 nsets]);
    ra.counts_setwise=squeeze(sum(~isnan(sqdevs),1))';
    %rms deviation across each stimulus, summed over coords, normalized by the number of sets that include the stimulus
    ra.rmsdev_stmwise(ip,:)=reshape(sqrt(mean(sqdevs,3,'omitnan')),[1 nstims_all]);
    ra.counts_stmwise=(sum(~isnan(sqdevs),3))';
    %rms deviation across all stimuli and coords
    ra.rmsdev_overall(ip,1)=sqrt(mean(sqdevs(:),'omitnan'));
    ra.counts_overall=sum(~isnan(sqdevs(:)));
    %
    if nshuffs>0
        %shuffles: across last coord or all coords
        zp=z{ip};
        for ist=1:2 %1: shuffle last coord, 2: shuffle all coords
            if (ist==1)
                dims_to_shuffle=ip;
                shuff_type='all coords';
            else
                dims_to_shuffle=[1:ip];
                shuff_type='last coord';
            end
            for ishuff=1:nshuffs
                zshuff=zp; %start from un-shuffled data
                for iset=1:nsets
                    perms=permutes{iset}(ip,:,ishuff); %permutes{iset}: d1: dimension, d2: stimulus, d3: which shuffle
                    zshuff(:,dims_to_shuffle,iset)=zp(perms,dims_to_shuffle,iset); %zp: d1 is stimulus, d2 is dimension, d3 is set; permute either last or all dimensions
                end
                shuff_msg=sprintf('shuffle %4.0f: %s',ishuff,shuff_type);
                [consensus_shuff,zn_shuff]=psg_align_stats_do(zshuff,opts_pcon_use,shuff_msg);
                sqdevs=sum((zn_shuff-repmat(consensus_shuff,[1 1 nsets])).^2,2); %squared deviation of consensus from rotated component
                ra.rmsdev_setwise_shuff(ip,:,1,ishuff,ist)=reshape(sqrt(mean(sqdevs,1,'omitnan')),[1 nsets]);
                ra.rmsdev_stmwise_shuff(ip,:,1,ishuff,ist)=reshape(sqrt(mean(sqdevs,3,'omitnan')),[1 nstims_all]);
                ra.rmsdev_overall_shuff(ip,1,1,ishuff,ist)=sqrt(mean(sqdevs(:),'omitnan'));
            end %ishuff
        end %ist
    end %nshuff>0
%
end
return
end

function [consensus,znew,ts,details,ra]=psg_align_stats_do(z,opts,shuff_msg)
%
rep_fields={'max_niters','max_rmstol'}; %options in procrustes_consensus that are relevant to termination
class_names={'init_components','init_random','init_pca'}; % types of initializations or swarms
%
if (nargin<=2)
    shuff_msg=[];
end
%wrapper on procrustses_consensus to allow for swarm optimization
if opts.if_swarm==0
    [consensus,znew,ts,details,ra]=procrustes_consensus(z,opts);
else
    opts_default=procrustes_consensus(); %get defaults for procrustes_consensus
    %
    npts=size(z,1);
    ndims=size(z,2);
    nsets=size(z,3);
    %
    havedata=reshape(~any(isnan(z),2),[npts nsets]);
    nmissing=sum(havedata(:)==0);
    npts_ovlp=zeros(1,nsets);
    %
    if_log=opts.swarm.if_log & isempty(shuff_msg); %logging for non-shuffles
    if_log_brief=opts.swarm.if_log;
    havedata_min=cell(1,nsets);
    havedata_minlist=1;
    for iset=1:nsets
        stim_sel=find(sum(havedata,2)>=iset);
        npts_ovlp(iset)=length(stim_sel); %equivalently, sum(sum(havedata,2)>=iset);
        havedata_min{iset}=zeros(npts,nsets);
        havedata_min{iset}(stim_sel,:)=havedata(stim_sel,:);
        havedata_min{iset}=logical(havedata_min{iset});
        if iset>1
            if npts_ovlp(iset)<npts_ovlp(iset-1)
                havedata_minlist(end+1)=iset;
            end
        end
    end
    %
    if if_log
        disp('swarm optimization started');
    end
    if if_log_brief
        disp(sprintf(' swarm optimization, dim %2.0f, nsets: %4.0f, npts: %4.0f, total missing: %4.0f %s',ndims,nsets,npts,nmissing,shuff_msg));
    end
    if if_log
        disp(sprintf(' random starts: %5.0f',opts.swarm.nrand));
        for iset=1:nsets
            disp(sprintf(' number of points in at least %2.0f sets: %4.0f',iset,npts_ovlp(iset)));
        end
    end
    %setup for pca variants: do pca only on the stimuli that are present in at least nmin sets, for nmin in havedata_minlist
    %if_initpca_rot and allow_offset are taken from opts, or if not, then the default in procrustes_consensus
    %
    opts=filldefault(opts,'allow_offset',opts_default.allow_offset);
    opts=filldefault(opts,'if_initpca_rot',opts_default.if_initpca_rot);
    opts=filldefault(opts,'initialize_set',opts_default.initialize_set);
    if ischar(opts.initialize_set)
        switch opts.initialize_set
            case 'pca_nocenter'
                if_mean=0;
            case 'pca_center'
                if_mean=1;
            case 'pca'
                if_mean=opts.allow_offset;
        end
    else
        if_mean=opts.allow_offset;
    end
    pca_initial_guess=cell(1,length(havedata_minlist));
    %keep only the coords for which havedata_min{nmin}(istim,iset)==1
    for minptr=1:length(havedata_minlist)
        nmin=havedata_minlist(minptr);
        havedata_rep=reshape(permute(repmat(havedata_min{nmin},[1 1 ndims]),[1 3 2]),[npts,ndims*nsets]);
        zpca=reshape(z,npts,ndims*nsets);
        zpca(havedata_rep==0)=NaN;
        zpca_mean_keep=repmat(mean(zpca,'omitnan'),[npts 1]);
        if if_mean
            zpca=zpca-zpca_mean_keep;
            zpca(havedata_rep==0)=0;
        else %mean not subtracted
            zpca(havedata_rep==0)=zpca_mean_keep(havedata_rep==0);
        end
        [u,s,v]=svd(zpca); % zpca=u*s*v'
        if opts.if_initpca_rot
            pca_initial_guess{minptr}=u(:,1:ndims)*s(1:ndims,1:ndims)*v(1:ndims,1:ndims)';
        else
            pca_initial_guess{minptr}=u(:,1:ndims)*s(1:ndims,1:ndims); %do not rotate
        end
    end %minptr
    %
    %set swarm optimization params
    opts_swarm=rmfield(opts,'swarm'); %these will be used for procrustes_consensus for each of the swarm optimizations
    opts_swarm.if_swarm=0;
    opts_swarm.if_log=0;
    %
    %determine the params used for definitive runs
    opts_stop=struct(); %stopping options to be used for definitive iteration
    if_def_eq_swarm=1;
    for k=1:length(rep_fields)
        rf=rep_fields{k};
        if isfield(opts,rf)
            opts_stop.(rf)=opts.(rf);
        else
            opts_stop.(rf)=opts_default.(rf);
        end
        opts_swarm.(rf)=opts.swarm.(rf); %sets the 
        if opts_stop.(rf)~=opts_swarm.(rf)
            if_def_eq_swarm=0;
        end
    end
    %
    if opts.swarm.if_frozen
        rng_state=rng;
        rng('default');
    end
    swarm_details=struct;
    opts_swarm_best=struct;
    rms_dev_total_min=Inf;
    for iclass=1:length(class_names)
        class_name=class_names{iclass};
        switch class_name
            case 'init_components'
                ntries=nsets;
            case 'init_random'
                ntries=opts.swarm.nrand;
            case 'init_pca'
                ntries=length(havedata_minlist);
        end
        rms_dev_total_classmin=Inf;
        rms_dev_total_classmax=-Inf;
        rms_dev_totals=zeros(1,ntries);
        for itry=1:ntries
            switch class_name
                case 'init_components'
                    opts_swarm.initialize_set=itry;
                case 'init_random'
                    opts_swarm.initialize_set=0;
                case 'init_pca'
                    opts_swarm.initialize_set=0;
                    opts_swarm.initial_guess=pca_initial_guess{itry};
            end
            [consensus,znew,ts,details,ra]=procrustes_consensus(z,opts_swarm);
            rms_dev_total=sqrt(sum(details.rms_dev(:,end).^2));
            rms_dev_totals(itry)=rms_dev_total;
            if rms_dev_total<rms_dev_total_classmin
                opts_swarm_classmin=opts_swarm;
                itry_classmin=itry;
                opts_swarm_classmin.initial_guess=details.initial_guess; %keep the specific random start point
            end
            rms_dev_total_classmin=min(rms_dev_total_classmin,rms_dev_total);
            rms_dev_total_classmax=max(rms_dev_total_classmax,rms_dev_total);
        end
        swarm_details.(class_name).opts=opts_swarm_classmin;
        swarm_details.(class_name).counts=ntries;
        swarm_details.(class_name).rms_dev_totals=rms_dev_totals;
        swarm_details.(class_name).itry_min=itry_classmin;
        swarm_details.(class_name).range=[rms_dev_total_classmin rms_dev_total_classmax];
        if if_log
            s=swarm_details.(class_name);
            disp(sprintf(' for swarm type %25s: %4.0f tries, rms devs: min %12.8f max %12.8f',class_name,s.counts,s.range));
        end
        %is the best of this class better than the best across classes?
        if rms_dev_total_classmin<rms_dev_total_min
            rms_dev_total_min=rms_dev_total_classmin;
            class_name_min=class_name;
            itry_min=itry_classmin;
            opts_swarm_min=opts_swarm_classmin;
        end
    end
    %definitive options are the best swarm options, overwritten by the definitive stopping options
    opts_definitive=opts_swarm_min;
    for k=1:length(rep_fields)
        rf=rep_fields{k};
        opts_definitive.(rf)=opts_stop.(rf);
    end
    %rerun best if termination conditions are different for swarm than for opts
    if if_def_eq_swarm==0
        if if_log
            disp('definitive run with best of swarm');
        end
        [consensus,znew,ts,details,ra]=procrustes_consensus(z,opts_definitive);
        rms_dev_total_definitive=sqrt(sum(details.rms_dev(:,end).^2));
    else
        if if_log
            disp('definitive run skipped as params for swarm and definitive optimizations are identical');
        end
        rms_dev_total_definitive=rms_dev_total_min;
    end
    details.swarm=swarm_details;
    details.swarm.rms_dev_total_min=rms_dev_total_min; %run with swarm params
    details.swarm.rms_dev_total_definitive=rms_dev_total_definitive; %after definitive run with swarm initialization
    details.swarm.class_name_min=class_name_min;
    details.swarm.itry_min=itry_min;
    details.swarm.opts_definitive=opts_definitive;
    details.swarm.if_def_eq_swarm=if_def_eq_swarm;
    %recover initialization and alignment
    if opts.swarm.if_frozen
        rng(rng_state);
    end
end
return
end
