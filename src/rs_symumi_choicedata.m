function [su,aux_out]=rs_symumi_choicedata(data_comp,aux)
% [su,aux_out]=rs_symumi_choicedata(data_comp,aux) analyzes a set of triadic choices for consistency with symmetry and the ultrametric inequality
% as described in Ordinal Characterization of Similarity Judgments on [arXiv](https://arxiv.org/abs/2310.07543)
% and [Mathematical Neuroscience and Applications](https://mna.episciences.org/16310/pdf)
%
% The analysis is carried out for a range of criteria for the triads to include, and for Dirichlet fits to the choice probability distribution
% based on all triads (in 'su.global'), or only the triads that meet threshold criteria (in 'su.private').
%
% Args:
%   data_comp (int 2-D array): Triadic choice data, with each row containing the data from a single kind of comparison
%
%      - col 1 is reference, col 2 is s1, col 3 is s2
%      - col 4: number of times the first difference was judged __more similar than__ the second difference
%      - col 5: number of times the comparison was made
%
%   aux (struct): a structure, can be omitted, with fields 
%
%     - opts_symumi (struct): options for analysis, with fields
%
%         - if_log (int): 1 to log progress, 0 to omit; default is 1
%         - h_fixlist (float 1-D array): values for discrete component, should include zero, default is [0 0.001 0.01 0.1]
%         - ntriplets_min (int): minimum number of triplets for an analysis, default is 3
% 
%         - **Options for statistics and shuffles**
%         - if_frozen (int): random number control; 1 for same numbers every run, 0 for different random numbers each run, negative integer for a fixed seed each run, default is 1
%
%         - **Options to control optimization details**
%         - a_limits (float): allowed range for 'a' (shape), when fitting only 'a', default is [10^-2 10^2]
%         - a_optimset (struct): non-default optimizations parameters for fitting 'a', with `fminbnd`, default is struct()
%         - ah_optimset (struct): non-default optimizations parameters for fitting 'a' and 'h', with `fminsearch`, default is struct()
%
%         - **Options for internal use and maintenance**
%         - if_fast (int): use hard-coding for partitions, skip calls to filldefault,  default is 1
%         - if_check (int): 1 to compare methods, -1 to log, treated as 0 if if_fast=1, default is 0
%         - tol (float): tolerance for checking consistency, ignored if if_check is 0, default is 10^-5
%         - if_vec (int): if present, use vectorized method, default is abesent
%         - if_partition (struct): if present, use general calculation of psg_ineq_logic, default is absent
%
%     - opts_check (struct): options for consistency checking, with field
%
%         - if_warn (int): 1 to show warnings, 0 to suppress; default is 1
%
% Returns:
%   su (struct): analysis results, a structure with fields
%
%     - counts (struct): summary tallies, a structure with fields
%
%         - ntrials_found (int): number of individual judgments
%         - ntriads_found (int): number of distinct triads judged
%         - nstims_found (int): number of different stimuli
%         - unique_stims (int 1-D array): list of unique stimuli
%
%     - dirichlet (struct): Dirichlet fits, with fields ??
%
%     - global (struct): likelihood analysis for symmetry and ultrametric
%     inequality, based on Dirichlet fits to choice probabilities for all triadic judgments, with fields ??
%
%     - private (struct): likelihood analysis for symmetry and ultrametric inequality, based on Dirichlet fits only to choice probabilities that meet the threshold criterion; fields are identical to su.global
% 
%     - meta (struct): labels for dimensions of the variables in su.global and su.private
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_symumi (struct): aux,opts_symumi with defaults and values used
%     - opts_check (struct): aux.opts_check, with defaults filled in
%     - opts_dirfit_a (struct): options used for `rs_dirfit_choicedata` for fitting Dirichlet parameter 'a'
%     - opts_dirfit_ah (struct): options used for `rs_dirfit_choicedata` for fitting Dirichlet parameters 'a' and 'h'
%     - opts_triplike (struct): options used for `psg_umi_triplike`
%
% See also: RS_DIRFIT_CHOICEDATA, PSG_TRIPLET_CHOICES, LOGLIK_BETA_DISCRETE.
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_symumi',struct);
aux.opts_symumi=filldefault(aux.opts_symumi,'if_log',1);
aux.opts_symumi=filldefault(aux.opts_symumi,'if_frozen',1);
aux.opts_symumi=filldefault(aux.opts_symumi,'a_limits',[10^-2 10^2]);
aux.opts_symumi=filldefault(aux.opts_symumi,'a_optimset',struct());
aux.opts_symumi=filldefault(aux.opts_symumi,'ah_optimset',struct());
%
aux.opts_symumi=filldefault(aux.opts_symumi,'h_fixlist',[0 0.001 0.01 0.1]);
aux.opts_symumi=filldefault(aux.opts_symumi,'ntriplets_min',3);
%
aux.opts_symumi=filldefault(aux.opts_symumi,'if_fast',1);
aux.opts_symumi=filldefault(aux.opts_symumi,'if_check',0);
aux.opts_symumi=filldefault(aux.opts_symumi,'if_tol',10^-5);
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_symumi_choicedata');
%
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
dirfit_opts={'a_limits','a_optimset','ah_optimset','if_frozen','if_log'}; %options to transfer from aux.opts_symumi to aux_dirfit.opts_dirfit
triplike_opts={'if_fast','if_check','tol','if_vec','if_partition'}; %options to transfer from aux.opts_symumi to opts_triplike;
%
%set up random number generator
%
if_frozen=aux.opts_symumi.if_frozen;
if (if_frozen~=0) 
    rng('default');
    if (if_frozen<0)
        rand(1,abs(if_frozen));
    end
else
    rng('shuffle');
end
%
su=struct;
%
% triadic?
%
if size(data_comp,2)~=5
    wmsg=sprintf('choice data must be triadic');
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
%
choices=data_comp(:,end-1:end);
choices_nz=find(choices(:,2)>0);
choices_used=choices(choices_nz,:);
probs=choices_used(:,1)./choices_used(:,2);
choices_used=choices(choices_nz,:);
%
% enough data? at least two choices needed to fit a, three choices for a and h
%
nchoices=length(choices_nz);
choices_needed=3; %minimal choices needed
if nchoices<choices_needed
    wmsg=sprintf('insufficient choices available for fitting; at least %2.0f needed',choices_needed);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
if all(or(probs==0,probs==1))
   wmsg=sprintf('all probabilities are 0 or 1; fitted parameter values are unreliable');
   aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
%
aux_out.opts_check=aux.opts_check;
aux_out.opts_symumi=aux.opts_symumi;
%
if aux_out.warn_bad>0
    disp('cannot proceed');
    disp(aux_out.warnings);
    return
end
%
%report number of stimulus types
%
data_nz=data_comp(choices_nz,:); %ignore choices with no trials
col_closer=4;
col_trials=5;
ntrials_found=sum(data_nz(:,col_trials));
ntriads_found=size(data_nz,1);
ustims_found=unique(reshape(data_nz(:,[1:3]),[3*ntriads_found,1]));
nstims_found=length(ustims_found);
%
su.counts=struct;
su.counts.ntrials_found=ntrials_found;
su.counts.ntriads_found=ntriads_found;
su.counts.nstims_found=nstims_found;
su.counts.unique_stims_found=ustims_found;
%
nstims=nstims_found;
%
%make stimulus indices be consecutive from 1 to nstims
data=data_nz;
indices=data_nz(:,[1:3]);
[ui,ai,ci]=unique(indices(:));
data(:,[1:3])=reshape(ci,ntriads_found,3);
%
if aux.opts_symumi.if_log
    disp(sprintf('number of unique stimuli found: %3.0f; range from %3.0f to %3.0f',nstims_found,min(ustims_found),max(ustims_found)));
    disp(sprintf('number of trials found: %6.0f',ntrials_found));
    disp(sprintf('number of triads found: %6.0f',ntriads_found));
end
%
triplets=nchoosek([1:nstims],3); %triplets: unordered subsets of 3
ntriplets=nchoosek(nstims,3); %ntriplets: number of unordered subsets of 3
%
% ncloser: [ntriplets,3]: N(d(a,b)<d(a,c)), N(d(b,c)<d(b,a)), N(d(c,a)<d(c,b))
% ntrials: [ntriplets,3]: total trials in above
[ncloser,ntrials]=psg_triplet_choices(nstims,data); %extract triplets and sort
%
if aux.opts_symumi.if_log
    disp(sprintf('number of trials   after sorting: %6.0f',sum(ntrials(:)))) 
    disp(sprintf('number of triads   after sorting: %6.0f',sum(ntrials(:)>0)));
    disp(sprintf('number of triplets after sorting: %6.0f',sum(sum(ntrials,2)>0)));
    disp(sprintf('number of trials per triad range from %6.0f to %6.0f',min(ntrials(:)),max(ntrials(:))));
end
if (sum(ntrials(:))~=ntrials_found)
    wmsg=sprintf('mismatch of number of trials in data before sorting (%5.0f) vs after sorting (%5.0f)',ntrials_found,sum(ntrials(:)));
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
%
h_fixlist=aux.opts_symumi.h_fixlist;
h_fixlist=unique([0 h_fixlist(:)']);
nhfix=length(h_fixlist);
%
su.dirichlet=struct();
su.dirichlet.columns_tallies={'min_trials_per_triad','ntriads','ntrials'};
su.dirichlet.columns_a={'a','loglike_per_trial'};
su.dirichlet.columns_ah={'a','h','loglike_per_trial'};
su.dirichlet.h_fixlist=h_fixlist;
%
%Dirichlet fits, for fixed values of h and also h fitted
%code modified from psg_umi_triplike_demo, adapted for if_fixa=0, and rs_dirfit_choicedata
%
aux_dirfit=struct;
for k=1:length(dirfit_opts)
    fn=dirfit_opts{k};
    if isfield(aux.opts_symumi,fn)
        aux_dirfit.opts_dirfit.(fn)=aux.opts_symumi.(fn);
    end
end
%
aux_dirfit.opts_dirfit.if_fit_a=0;
aux_dirfit.opts_dirfit.if_fit_h=0;
aux_dirfit.opts_dirfit.if_fit_ah=0;
aux_dirfit.opts_dirfit.fixed_h=0;
aux_dirfit.opts_dirfit.if_stats=0;
%
aux_dirfit.opts_check=aux.opts_check;
%
aux_dirfit_a=aux_dirfit;
aux_dirfit_a.opts_dirfit.if_fit_a=1;
%
aux_dirfit_ah=aux_dirfit;
aux_dirfit_ah.opts_dirfit.if_fit_ah=1;
%
aux_out.opts_dirfit_a=aux_dirfit_a.opts_dirfit;
aux_out.opts_dirfit_ah=aux_dirfit_ah.opts_dirfit;
%
ithr=0;
for thr=min(ntrials(:)):max(ntrials(:))
    triads_use=find((ntrials(:)>=thr));
    ntriads_use=length(triads_use);
    ntrials_use=sum(ntrials(triads_use));
    if (ntriads_use>=aux.opts_symumi.ntriplets_min)
        ithr=ithr+1;
        su.dirichlet.tallies(ithr,:)=[thr,ntriads_use,ntrials_use];
        data_use=[ncloser(triads_use) ntrials(triads_use)];
        %fixed  values of h
        for ihfix=1:nhfix
            %
            aux_dirfit_a.opts_dirfit.fixed_h=h_fixlist(ihfix);
            [dirfit_a,aux_dirfit_out_a]=rs_dirfit_choicedata(data_use,aux_dirfit_a);
            su.dirichlet.a(ithr,:,ihfix)=[dirfit_a.a.val,dirfit_a.a.llnat_per_trial];
        end
        %fit a and h
        [dirfit_ah,aux_dirfit_out_ah]=rs_dirfit_choicedata(data_use,aux_dirfit_ah);
        su.dirichlet.ah(ithr,:)=[dirfit_ah.ah.val',dirfit_ah.ah.llnat_per_trial];
    end
end
%
%analyze for ultrametric inequality and symmetry, via strategy of psg_umi_triplike_demo with conform=0 and if_fast=1
%
ipg_strings={'private','global'};
npg=length(ipg_strings);
thr_types={'min','max','avg'};
nthr_types=length(thr_types);
%
%global analyses: Dirichlet fits not adjusted based on which triads are used
%private analyses: Dirichlet fits are private to the triads used
%
su.meta=struct;
su.global=struct;
su.private=struct;
su.meta.thr_types=thr_types;
su.meta.columns_tallies={'thr','ntriplets','ntrials'};
su.meta.columns_a={'a','loglike_per_trial'}; %values of a and h determined from the selected trials
su.meta.columns_ah={'a','h','loglike_per_trial'}; %values of a and h determined from the selected trials
su.meta.columns_sym={'llr_sym_vs_sym+notsym'}; %from likrat.sym of psg_umi_triplike
su.meta.columns_umi={'llr_umi_trans_vs_trans'}; %from likrat.umi_trans of psg_umi_triplike
su.meta.columns_sym_hfixed=su.meta.columns_sym; %from likrat.sym of psg_umi_triplike
su.meta.columns_umi_hfixed=su.meta.columns_umi; %from likrat.umi_trans of psg_umi_triplike
su.meta.thr_types=thr_types;
su.meta.ipg_strings=ipg_strings;
su.meta.surr_types={'orig data','flip_all','flip_any'};
%
su.global.a=su.dirichlet.a(1,1,:); % values with h fixed
%compute using global a and h from unthresholded Dirichlet and save in r.su.global.ah
if su.dirichlet.ah(1,2)>=0 %use full fit if h>=0
    su.global.ah=su.dirichlet.ah(1,1:2);
else %otherwise use best fit with h=0
    su.global.ah=[su.dirichlet.a(1,1,1),0];
end
% compute these later using private a and h, to go in r.su.private.[a|ah]{ithr_type}
su.private.a=cell(1,nthr_types); 
su.private.ah=cell(1,nthr_types);
%
su.meta.global_private_d1={'mean of sum','variance of sum'};
su.meta.global_private_d2={'threshold type'};
for ipg=1:npg
    su.(ipg_strings{ipg}).sym=cell(2,nthr_types);
    su.(ipg_strings{ipg}).umi=cell(2,nthr_types);
    su.(ipg_strings{ipg}).sym_hfixed=cell(2,nthr_types);
    su.(ipg_strings{ipg}).umi_hfixed=cell(2,nthr_types);
end
%
ncomps=3;
flipconfigs=int2nary([0:2^ncomps-1]',2);  %rows are [0 0 0;1 0 0;0 1 0;1 1 0; 0 0 1;1 0 1;0 1 1;1 1 1];
nflips=size(flipconfigs,1); %2^8
%
su.meta.llr_d1={'threshold value'};
su.meta.llr_d2=su.meta.surr_types;
su.meta.llr_d3={'hfixed'};
su.meta.nsurr=length(su.meta.surr_types);
nsurr=length(su.meta.llr_d2); %three kinds of surrogates: native, flip all, flip any
%
% nconform=0;
% if_fast=1;
% %
llr_sym=cell(nsurr,2); %summed log likelihood ratio across trials, and summed variance of total 
llr_umi=cell(nsurr,2);
llr_sym_hfixed=cell(nsurr,2);
llr_umi_hfixed=cell(nsurr,2);
surr_list={1,[1 nflips],[1:nflips]};
%
%if_fast=1: calculate probabilities for all triplets
loglik_rat_sym_all=zeros(ntriplets,nflips);
loglik_rat_umi_all=zeros(ntriplets,nflips);
loglik_rat_sym_hfixed_all=zeros(ntriplets,nflips,nhfix);
loglik_rat_umi_hfixed_all=zeros(ntriplets,nflips,nhfix);
ah=su.global.ah;
ah_fixed=[squeeze(su.dirichlet.a(1,1,:)),h_fixlist(:)];
%
opts_triplike=struct;
for k=1:length(triplike_opts)
    fn=triplike_opts{k};
    if isfield(aux.opts_symumi,fn)
        opts_triplike.(fn)=aux.opts_symumi.(fn);
    end
end
aux_out.opts_triplike=opts_triplike;
%
for itriplet=1:ntriplets %accumulate likelihood ratios from each set of triplets   
    obs_orig(:,1)=ncloser(itriplet,:)';
    obs_orig(:,2)=ntrials(itriplet,:)';
    obs_orig_flip=obs_orig(:,2)-obs_orig(:,1); 
    %
    for iflip=1:nflips %each surrogate
        obs=obs_orig;
        whichflip=find(flipconfigs(iflip,:)==1);
        obs(whichflip,1)=obs_orig_flip(whichflip);
        params.a=ah(1);
        params.h=ah(2);
        likrat=psg_umi_triplike(params,obs,opts_triplike);
        loglik_rat_sym_all(itriplet,iflip)=log(likrat.sym);
        loglik_rat_umi_all(itriplet,iflip)=log(likrat.umi_trans);
        for ihfix=1:nhfix
            params.a=ah_fixed(ihfix,1);
            params.h=ah_fixed(ihfix,2);
            likrat=psg_umi_triplike(params,obs,opts_triplike);
            loglik_rat_sym_hfixed_all(itriplet,iflip,ihfix)=log(likrat.sym);
            loglik_rat_umi_hfixed_all(itriplet,iflip,ihfix)=log(likrat.umi_trans);
        end
    end %iflip
end %itriplet
if aux.opts_symumi.if_log
    disp(sprintf('symmetry and ultrametric global calculations done'));
end
% for ipg=ipg_min:2 %private and global
%     disp(sprintf('%10s calculations',ipg_strings{ipg}));
%     for ithr_type=1:nthr_types %three kinds of thresholds: min, max, average
%         if_ok=1;
%         thr=0; %threshold
%         ithr=1; %threshold pointer
%         disp(sprintf('analyzing for symmetry and ultrametric likelihood ratio for threshold type %s',thr_types{ithr_type}));
%         nuse_prev=-1; %will allow for reuse if increasing the threshold doesn't change the number of triplets/tents used
%         while (if_ok)
%             switch thr_types{ithr_type}
%                 case 'min'
%                     triplets_use=find(min(ntrials,[],2)>=thr);
%                     thr_val=thr;
%                 case 'max'
%                     triplets_use=find(max(ntrials,[],2)>=thr);
%                     thr_val=thr;
%                 case 'avg'
%                     triplets_use=find(sum(ntrials,2)>=thr);
%                     thr_val=thr/3; %average not total
%             end
%             if (length(triplets_use)>=nfit_min)
%                 ntriplets_use=length(triplets_use);
%                 if ntriplets_use~=nuse_prev
%                     did_or_skipped='did'; %have to calculate
%                     nuse_prev=ntriplets_use;
%                     ntrials_use=sum(sum(ntrials(triplets_use,:)));
%                     r.su.tallies{ithr_type}(ithr,:)=[thr_val ntriplets_use ntrials_use]; %threshold, number of triplets, number of trials
%                     %compute private best-fitting a and h
%                     data_use=[reshape(ncloser(triplets_use,:),3*ntriplets_use,1) reshape(ntrials(triplets_use,:),3*ntriplets_use,1)];
%                     %fit with assuming fixed values of h
%                     for ihfix=1:nhfix
%                         if (if_fixa==0)
%                             [fit_a,nll_a,exitflag_a]=fminbnd(@(x) -loglik_beta(x,data_use,setfield(opts_loglik,'hvec',h_fixlist(ihfix))),...
%                                 a_limits(1),a_limits(2)); %optimize assuming discrete part
%                         else
%                             fit_a=a_fixval;
%                             nll_a=-loglik_beta(fit_a,data_use,setfield(opts_loglik,'hvec',h_fixlist(ihfix)));
%                         end
%                         r.su.private.a{ithr_type}(ithr,:,ihfix)=[fit_a,-nll_a/ntrials_use];
%                     end
%                     ah_init=[r.su.private.a{ithr_type}(ithr,1,1);h_init]; %optimize with discrete part, using a_only fit as starting point
%                     [fit_ah,nll_ah,exitflag_ah,output_ah]=fminsearch(@(x) -loglik_beta(x(1),data_use,setfield(opts_loglik,'hvec',x(2))),ah_init);
%                     if fit_ah(2)>=0
%                         r.su.private.ah{ithr_type}(ithr,:)=[fit_ah(:)',-nll_ah/ntrials_use];
%                     else
%                         r.su.private.ah{ithr_type}(ithr,:)=[fit_a,0,-nll_a/ntrials_use];
%                     end
%                     %
%                     %fast global option:calculate probabilities for all triplets and later select
%                     %
%                     if if_fast~=0 & ipg==2
%                         loglik_rat_sym=loglik_rat_sym_all(triplets_use,:);
%                         loglik_rat_umi=loglik_rat_umi_all(triplets_use,:);
%                         loglik_rat_sym_hfixed=loglik_rat_sym_hfixed_all(triplets_use,:,:);
%                         loglik_rat_umi_hfixed=loglik_rat_umi_hfixed_all(triplets_use,:,:);
%                     else %if_fast==0
%                         if (ipg==1) %private
%                             ah=r.su.private.ah{ithr_type}(ithr,:); %a and h both fitted
%                             ah_fixed=[squeeze(r.su.private.a{ithr_type}(ithr,1,:)),h_fixlist(:)]; %a fitted, h fixed
%                         else %global
%                             ah=r.su.global.ah;
%                             ah_fixed=[squeeze(r.dirichlet.a(1,1,:)),h_fixlist(:)];
%                         end
%                         loglik_rat_sym=zeros(ntriplets_use,nflips);
%                         loglik_rat_umi=zeros(ntriplets_use,nflips);
%                         loglik_rat_sym_hfixed=zeros(ntriplets_use,nflips,nhfix);
%                         loglik_rat_umi_hfixed=zeros(ntriplets_use,nflips,nhfix);
%                         for itriplet=1:ntriplets_use %accumulate likelihood ratios from each set of triplets
%                             obs_orig(:,1)=ncloser(triplets_use(itriplet),:)';
%                             obs_orig(:,2)=ntrials(triplets_use(itriplet),:)';
%                             obs_orig_flip=obs_orig(:,2)-obs_orig(:,1); 
%                             %
%                             for iflip=1:nflips %each surrogate
%                                 obs=obs_orig;
%                                 whichflip=find(flipconfigs(iflip,:)==1);
%                                 obs(whichflip,1)=obs_orig_flip(whichflip);
%                                 params.a=ah(1);
%                                 params.h=ah(2);
%                                 likrat=psg_umi_triplike(params,obs,opts_triplike);
%                                 loglik_rat_sym(itriplet,iflip)=log(likrat.sym);
%                                 loglik_rat_umi(itriplet,iflip)=log(likrat.umi_trans);
%                                 for ihfix=1:nhfix
%                                     params.a=ah_fixed(ihfix,1);
%                                     params.h=ah_fixed(ihfix,2);
%                                     likrat=psg_umi_triplike(params,obs,opts_triplike);
%                                     loglik_rat_sym_hfixed(itriplet,iflip,ihfix)=log(likrat.sym);
%                                     loglik_rat_umi_hfixed(itriplet,iflip,ihfix)=log(likrat.umi_trans);
%                                 end
%                             end %iflip
%                         end
%                     end %if_fast
%                     %do statistics
%                     for isurr=1:nsurr+nconform
%                         if (isurr<=nsurr)
%                             surr_sel=surr_list{isurr}; %for isurr=1, this is just the original data (1)
%                             llr_sym{isurr,1}=sum(mean(loglik_rat_sym(:,surr_sel),2),1);
%                             llr_umi{isurr,1}=sum(mean(loglik_rat_umi(:,surr_sel),2),1);
%                             llr_sym_hfixed{isurr,1}=reshape(sum(mean(loglik_rat_sym_hfixed(:,surr_sel,:),2),1),[1 1 nhfix]);
%                             llr_umi_hfixed{isurr,1}=reshape(sum(mean(loglik_rat_umi_hfixed(:,surr_sel,:),2),1),[1 1 nhfix]);
%                             if (isurr>1)
%                                 %each triplet contributes independently to the variance
%                                 %variance for each triplet is normalized by N not N-1, since we have all the values
%                                 llr_sym{isurr,2}=sum(var(loglik_rat_sym(:,surr_sel),1,2),1);
%                                 llr_umi{isurr,2}=sum(var(loglik_rat_umi(:,surr_sel),1,2),1);
%                                 llr_sym_hfixed{isurr,2}=reshape(sum(var(loglik_rat_sym_hfixed(:,surr_sel,:),1,2),1),[1 1 nhfix]);
%                                 llr_umi_hfixed{isurr,2}=reshape(sum(var(loglik_rat_umi_hfixed(:,surr_sel,:),1,2),1),[1 1 nhfix]);
%                             else %isurr=1: original data. Here, goal is for psg_umi_triplike_plota to compute standard error of the mean
%                                 %which is sqrt(var)/ntriplets_use, but
%                                 %psg_umi_triplike_plota will find square root and then divide by ntriplets_use
%                                 %so here we just compute var, normalized by N-1 since it is a sample
%                                 %here, surr_sel=1
%                                 llr_sym{isurr,2}=var(loglik_rat_sym(:,surr_sel),0,1);
%                                 llr_umi{isurr,2}=var(loglik_rat_umi(:,surr_sel),0,1);
%                                 llr_sym_hfixed{isurr,2}=reshape(var(loglik_rat_sym_hfixed(:,surr_sel,:),0,1),[1 1 nhfix]);
%                                 llr_umi_hfixed{isurr,2}=reshape(var(loglik_rat_umi_hfixed(:,surr_sel,:),0,1),[1 1 nhfix]);
%                             end
%                         else %do conform
%                             %select the appropriate flip for each triplet
%                             loglik_rat_sym_conform=zeros(ntriplets_use,1);
%                             loglik_rat_umi_conform=zeros(ntriplets_use,1);
%                             loglik_rat_sym_hfixed_conform=zeros(ntriplets_use,nhfix);
%                             loglik_rat_umi_hfixed_conform=zeros(ntriplets_use,nhfix);
%                             for itptr=1:ntriplets_use
%                                 it=triplets_use(itptr);
%                                 loglik_rat_sym_conform(itptr)=loglik_rat_sym(itptr,which_flip_conform.sym(it));
%                                 loglik_rat_umi_conform(itptr)=loglik_rat_umi(itptr,which_flip_conform.umi(it));
%                                 loglik_rat_sym_hfixed_conform(itptr,:)=reshape(loglik_rat_sym_hfixed(itptr,which_flip_conform.sym(it),:),[1 nhfix]);
%                                 loglik_rat_umi_hfixed_conform(itptr,:)=reshape(loglik_rat_umi_hfixed(itptr,which_flip_conform.umi(it),:),[1 nhfix]);
%                             end
%                             llr_sym{isurr,1}=sum(loglik_rat_sym_conform);
%                             llr_umi{isurr,1}=sum(loglik_rat_umi_conform);
%                             llr_sym_hfixed{isurr,1}=reshape(sum(loglik_rat_sym_hfixed_conform),[1 1 nhfix]);
%                             llr_umi_hfixed{isurr,1}=reshape(sum(loglik_rat_umi_hfixed_conform),[1 1 nhfix]);
%                             %variances are calculated as for original data, but surr_sel must be set
%                             surr_sel=1;
%                             llr_sym{isurr,2}=var(loglik_rat_sym(:,surr_sel),0,1);
%                             llr_umi{isurr,2}=var(loglik_rat_umi(:,surr_sel),0,1);
%                             llr_sym_hfixed{isurr,2}=reshape(var(loglik_rat_sym_hfixed(:,surr_sel,:),0,1),[1 1 nhfix]);
%                             llr_umi_hfixed{isurr,2}=reshape(var(loglik_rat_umi_hfixed(:,surr_sel,:),0,1),[1 1 nhfix]);
%                         end
%                         %
%                         for imv=1:2% mean and variance
%                             r.su.(ipg_strings{ipg}).sym{imv,ithr_type}(ithr,isurr)=llr_sym{isurr,imv};
%                             r.su.(ipg_strings{ipg}).umi{imv,ithr_type}(ithr,isurr)=llr_umi{isurr,imv};
%                             r.su.(ipg_strings{ipg}).sym_hfixed{imv,ithr_type}(ithr,isurr,:)=llr_sym_hfixed{isurr,imv};
%                             r.su.(ipg_strings{ipg}).umi_hfixed{imv,ithr_type}(ithr,isurr,:)=llr_umi_hfixed{isurr,imv};
%                         end %imv
%                     end %isurr
%                 else
%                     did_or_skipped='skp';
%                     r.su.tallies{ithr_type}(ithr,:)=r.su.tallies{ithr_type}(ithr-1,:);
%                     r.su.tallies{ithr_type}(ithr,1)=thr_val; %threshold is new
%                     if (ipg==1)
%                         r.su.private.a{ithr_type}(ithr,:,:)=r.su.private.a{ithr_type}(ithr-1,:,:);
%                         r.su.private.ah{ithr_type}(ithr,:)=r.su.private.ah{ithr_type}(ithr-1,:);
%                     end
%                     for isurr=1:nsurr+nconform
%                         for imv=1:2% mean and variance
%                             r.su.(ipg_strings{ipg}).sym{imv,ithr_type}(ithr,isurr)=llr_sym{isurr,imv};
%                             r.su.(ipg_strings{ipg}).umi{imv,ithr_type}(ithr,isurr)=llr_umi{isurr,imv};
%                             r.su.(ipg_strings{ipg}).sym_hfixed{imv,ithr_type}(ithr,isurr,:)=llr_sym_hfixed{isurr,imv};
%                             r.su.(ipg_strings{ipg}).umi_hfixed{imv,ithr_type}(ithr,isurr,:)=llr_umi_hfixed{isurr,imv};
%                         end %imv
%                     end %isurr
%                 end %nuse_prev
%                 disp(sprintf('%s ipg %3.0f ithr_type %3.0f ithr %3.0f thr %3.0f ntriplets_use %6.0f size(loglik_rat_sym) %6.0f %4.0f size(loglik_rat_sym_hfixed) %6.0f %4.0f %4.0f',...
%                     did_or_skipped,ipg,ithr_type,ithr,thr,ntriplets_use,size(loglik_rat_sym),size(loglik_rat_sym_hfixed)));
%                 thr=thr+1; %threshold
%                 ithr=ithr+1; %pointer
%             else
%                 if_ok=0;
%             end
%         end %if_ok
%     end %thr_type
% end %ipg
% %
% %finish and do plots
% %
% if (if_del)
%     clear *all
% end
% if ~exist('plot_opts') %allow for setting plot_opts.frac_keep_list
%     plot_opts=struct;
% end
% plot_opts.ipg_min=ipg_min;
% plot_opts.data_fullname=data_fullname;
% plot_opts.llr_field='su';
% plot_opts.nconform=nconform;
% plot_opts.nsurr=nsurr;
% if ~isempty(sel_desc)
%     plot_opts.sel_desc=sel_desc;
% end
% if (if_plot)
%     psg_umi_triplike_plot(r,plot_opts);
% end
% if (if_plota) | (if_auto)
%     [plot_opts_used,figh,s]=psg_umi_triplike_plota(r,plot_opts);
%     if (if_auto)
%         if exist(auto.db_file,'file')
%             db=getfield(load(auto.db_file),'db');
%         else
%             db=struct;
%         end
%         data_shortname=data_fullname;
%         data_shortname=strrep(data_shortname,'.mat','');
%         data_shortname=strrep(data_shortname,'/',filesep);
%         data_shortname=strrep(data_shortname,'\',filesep);
%         data_shortname=cat(2,filesep,data_shortname);
%         data_shortname=data_shortname(1+max(find(data_shortname==filesep)):end);
%         if isempty(sel_desc)
%             data_fieldname=data_shortname;
%         else
%             data_fieldname=cat(2,data_shortname,'_',sel_desc);
%         end
%         db.(data_fieldname).r=r;
%         db.(data_fieldname).s=s;
%         db.(data_fieldname).select.sel_string=sel_string;
%         db.(data_fieldname).select.sel_desc=sel_desc;
%         save(auto.db_file,'db');
%         disp(sprintf('saved results from %s in %s',data_fieldname,auto.db_file));
%     end
% end

%
return
end
