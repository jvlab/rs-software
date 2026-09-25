function [ad,aux_out]=rs_addtree_choicedata(data_comp,aux)
% [ad,aux_out]=rs_addtree_choicedata(data_comp,aux) analyzes a set of triadic choices to determine the addtree index
% (a measures of consistency with the four-point inequality, a necessary condition for distances to be consistent with an additive tree).
% Thi is described in Ordinal Characterization of Similarity Judgments on [arXiv](https://arxiv.org/abs/2310.07543)
% and [Mathematical Neuroscience and Applications](https://mna.episciences.org/16310/pdf)
%
% The analysis is carried out for a range of criteria for the triads to include, and for Dirichlet fits to the choice probability distribution
% based on all triads (in 'ad.global'), or only the triads that meet threshold criteria (in 'ad.private').  See note below regarding threshold criteria and global vs. private analyses.
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
%     - opts_addtree (struct): options for analysis, with fields
%
%         - if_log (int): 1 to log progress, 0 to omit; default is 1
%         - h_fixlist (float 1-D array): values for discrete component 'h', should include zero and be in ascending order, default is [0 0.001 0.01 0.1]
%         - ntriplets_min (int): minimum number of triplets for an analysis, default is 3
%         - ntents_min (int): minimum number of tents for an analysis, default is 3
%         - if_private (int): 1 to also do calculations with Dirichlet fits only to the triads that meet threshold criteria, 0 to omit; default is 0
%
%         - **Plotting and replotting**
%         - if_plot (int): 1 for basic plot and statistical summary, 2 for detailed plot, 0 to omit; default is 1
%         - plot_label (char): string for plot label, default is 'ordinal analysis'
%         - ad (struct): include to replot a previous analysis; otherwise omit
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
%   ad (struct): analysis results, a structure with fields
%
%     - **Dirichlet fits**
%     - dirichlet (struct): Dirichlet fits for lowest and highest thresholds for number of trials in a triad, with fields
% 
%         - tallies (int 2-D array): tallies(:,1) is threshold number of trials in a triad; tallies(:,2) is number of triads meeting the threshold; tallies(:,3) is number of trials in those triads
%         - columns_tallies (cell 1-D array): labels for columns of tallies
%         - h_fixlist (float 1-D array): list of values assumed for the discrete component, first element is 0
%         - a (int 3-D array): a(ithr,1,ih) is fitted value of Dirichlet shape parameter 'a' for triads meeting threshold of tallies(ithr,1) and assuming h=h_fixlist(ih); a(ithr,2,ih) is corresponding log likelihood per trial
%         - columns_a (cell 1-D array): labels for columns of a
%         - ah (int 2-D array): ah(ithr,1:2) are jointly fitted values of Dirichlet shape parameter 'a' and discrete parameter 'h' for triads meeting threshold of tallies(ithr,1); ah(ithr,3) is corresponding log likelihoood per trial
%         - columns_ah (cell 1-D array): labels for columns of ah
% 
%     - **Addtree indices**
%     - global (struct): likelihood analysis for symmetry and ultrametric inequality, based on Dirichlet fits to choice probabilities for all triadic judgments, with fields
%
%         - a (int 3-D array): a(1,1:2,ih) is the fitted Dirichlet shape parameter 'a' and log likelihood per trial assuming h=h_fixlist(ih)
%         - ah (int 2-D array): ah(1,1:3) are the jointly fitted Dirichlet parameters 'a' and 'h' and log likelihood per trial for threshold value dirichlet.tallies(ithr,1)
%         - sym_hfixed (cell 2-D array): sym_hfixed{imv,ithr_type}(ithr,:,ih) is the mean (imv=1) or the variance (imv=2) of the symmetry index, for threshold type ithr_type, threshold value dirichlet.tallies(ithr,1), assuming h=h_fixlist(ih)
%         - sym (cell 2-D array): sym{imv,ithr_type}(ithr,:) is the mean (imv=1) or the variance (imv=2) of the symmetry index, for threshold type ithr_type, threshold value dirichlet.tallies(ithr,1), with 'a' and 'h' jointly fitted
%         - umi_hfixed (cell 2-D array): umi_hfixed{imv,ithr_type}(ithr,:,ih) is the mean (imv=1) or the variance (imv=2) of the ultrametric index, for threshold type ithr_type, threshold value dirichlet.tallies(ithr,1), assuming h=h_fixlist(ih)
%         - umi (cell 2-D array): umi{imv,ithr_type}(ithr,:) is the mean (imv=1) or the variance (imv=2) of the ultrametric index, for threshold type ithr_type, threshold value dirichlet.tallies(ithr,1), with 'a' and 'h' jointly fitted
% 
%     - private (struct): likelihood analysis for symmetry and ultrametric inequality, based on Dirichlet fits only to choice probabilities that meet the threshold criterion, with fields
%
%         - a (cell 1-D array): a{ithr_type}(ithr,1:2,ih) are the fitted Dirichlet shape parameter 'a' and log likelihood per trial for threshold type and threshold value dirichlet.tallies(ithr,1), assuming h=h_fixlist(ih)
%         - ah (cell 1-D array): ah{ithr_type}(ithr,1:3,ih) are the jointly fitted Dirichlet parameters 'a' and 'h' and log likelihood per trial for threshold type ithr_type and threshold value dirichlet.tallies(ithr,1)
%         - sym_hfixed (cell 2-D array): sym_hfixed{imv,ithr_type}(ithr,:,ih) is the mean (imv=1) or the variance (imv=2) of the symmetry index, for threshold type ithr_type, threshold value dirichlet.tallies(ithr,1), assuming h=h_fixlist(ih)
%         - sym (cell 2-D array): sym{imv,ithr_type}(ithr,:) is the mean (imv=1) or the variance (imv=2) of the symmetry index, for threshold type ithr_type, threshold value dirichlet.tallies(ithr,1), with 'a' and 'h' jointly fitted
%         - umi_hfixed (cell 2-D array): umi_hfixed{imv,ithr_type}(ithr,:,ih) is the mean (imv=1) or the variance (imv=2) of the ultrametric index, for threshold type ithr_type, threshold value dirichlet.tallies(ithr,1), assuming h=h_fixlist(ih)
%         - umi (cell 2-D array): umi{imv,ithr_type}(ithr,:) is the mean (imv=1) or the variance (imv=2) of the ultrametric index, for threshold type ithr_type, threshold value dirichlet.tallies(ithr,1), with 'a' and 'h' jointly fitted
% 
%     - meta (struct): labels for dimensions of the variables in ad.global and ad.private
%
%     - counts (struct): summary of the input data, a structure with fields
%
%         - ntrials_found (int): number of individual judgments
%         - ntriads_found (int): number of distinct triads judged
%         - nstims_found (int): number of different stimuli
%         - unique_stims (int 1-D array): list of unique stimuli
%
%     - tallies (cell 1-D array): summary of the data used for each calculation in global and private, where tallies{ithr_type}(ithr,:) is [threshold pointer, number of triplets used, number of trials used] for threshold type ithr_type (1: min, 2: max, 3: avg, see note below regarding thresholds); the threshold value corresponding to ithr is dirichlet.tallies(ithr,1)
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_addtree (struct): aux,opts_addtree with defaults and values used
%     - opts_check (struct): aux.opts_check, with defaults filled in
%     - opts_dirfit_a (struct): options used for `rs_dirfit_choicedata` for fitting Dirichlet parameter 'a'
%     - opts_dirfit_ah (struct): options used for `rs_dirfit_choicedata` for fitting Dirichlet parameters 'a' and 'h'
%     - opts_triplike (struct): options used for `psg_umi_triplike`
%     - fig_handles (cell 1-D array): handles to figures for summary plot ((present only if if_plot>=1)
%     - fig_handle_detailed (handle): handle to figure for detailed plot (present only if if_plot=2)
%     - summary (cell 1-D array): statistical summary organized by fraction of triplets retained (only if if_plot>=1), summary{1} is analysis with fixed value of 'h', summary{2} is analysis with 'h' fitted; summary{1}.sym, summary{2}.sym, and summary{1}.umi contain the following subfields
%
%         - params (struct): params.a and params.h are the Dirichlet parameters
%         - apriori_vals (float): a priori value of the index
%         - ah_llr (float): log likelihood ratio for the Dirichlet fit to the choice probability distribution
%         - thr_type (cell 1-D array): statistics for threshold type 1 (min), 2 (max), 3 (avg)
%
%             - tally_table (int 2-D array): tally_table(ithr,[1 2 3]) is the threshold, count of triads, count of trials
%             - means_per_set_adj (float 2-D array): means_per_set_adj(ithr,[1 2 3]) is the mean index for each threshold type, adjusted by log(h) for umi index
%             - eb_stds (float 2-D array): 1 s.d. error bar size
%             - frac_keep_list (float 1-d array): fraction of triplets to keep
%             - thr_ptr_use (int 1-D array): pointers into thresholds (tally_table(:,1)), corresponding to values in frac_keep_list
%
% Note: Note regarding thresholds and global vs. private analyses
%     - Triplets are screened by a threshold criterion based on the number of trials before inclusion in the calculation of the symmetry and ultrametric indices.
%     - The criterion is applied three ways:  to the minimum numnber of trials of the three triads in a triplet, the maximum number, and the average number
%     - For the 'global' analysis, the selected triplets are used to calculate the symmetry and ultrametric indices, but all triads are used to calculate the Dirichlet parameters
%     - For the 'private' analysis, the selected triplets are used to calculate the symmetry and ultrametric indices and also to calculate the Dirichlet parameters 
%     - The 'private' analysis is substantially slower than the 'global' analysis, and values are of the indices are typically similar; it is only enabled by setting opts_addtree.if_private=1
% 
% Note: Triads, trials, triplets, and tents
%     - A triad is a set of three stimuli used in a triadic judgment: one stimulus is the reference, and the other two are the comparison stimuli
%     - A trial is a single judgment of similarity for a given triad
%     - A triplet is a set of three triads built out of the same three stimuli, in which each stimulus in turn serves as the reference
%     - The number of trials in a triplet is the sum of the number of trials in its three triads
%     - A tent is a set of six triads built out of four stimuli.  Three of the triads are a triplet built from the first three stimuil; the other three triads are triads built from the fourth stimulus and two of the first three.
% 
% See also: RS_DIRFIT_CHOICEDATA, RS_SYMUMI_CHOICEDATA, PSG_TRIPLET_CHOICES, LOGLIK_BETA_DISCRETE, PSG_TENTLIKE_DEMO.
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_addtree',struct);
aux.opts_addtree=filldefault(aux.opts_addtree,'if_log',1);
aux.opts_addtree=filldefault(aux.opts_addtree,'h_fixlist',[0 0.001 0.01 0.1]);
aux.opts_addtree=filldefault(aux.opts_addtree,'ntriplets_min',3);
aux.opts_addtree=filldefault(aux.opts_addtree,'ntents_min',3);
aux.opts_addtree=filldefault(aux.opts_addtree,'if_private',0);
%
aux.opts_addtree=filldefault(aux.opts_addtree,'if_frozen',1);
aux.opts_addtree=filldefault(aux.opts_addtree,'a_limits',[10^-2 10^2]);
aux.opts_addtree=filldefault(aux.opts_addtree,'a_optimset',struct());
aux.opts_addtree=filldefault(aux.opts_addtree,'ah_optimset',struct());
%
aux.opts_addtree=filldefault(aux.opts_addtree,'if_fast',1);
aux.opts_addtree=filldefault(aux.opts_addtree,'if_check',0);
aux.opts_addtree=filldefault(aux.opts_addtree,'if_tol',10^-5);
%
aux.opts_addtree=filldefault(aux.opts_addtree,'if_plot',1);
aux.opts_addtree=filldefault(aux.opts_addtree,'plot_label','ordinal analysis');
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_addtree_choicedata');
%
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
if isfield(aux.opts_addtree,'ad') 
    if aux.opts_addtree.if_plot>0
        [aux_out.fig_handles,aux_out.fig_handle_detailed,aux_out.summary]=rs_addtree_plot(data_comp,aux.opts_addtree.ad,aux);
    end
    ad=aux.opts_addtree.ad;
    return
end
dirfit_opts={'a_limits','a_optimset','ah_optimset','if_frozen','if_log'}; %options to transfer from aux.opts_addtree to aux_dirfit.opts_dirfit
triplike_opts={'if_fast','if_check','tol','if_vec','if_partition'}; %options to transfer from aux.opts_addtree to opts_triplike;
%
%set up random number generator
%
if_frozen=aux.opts_addtree.if_frozen;
if (if_frozen~=0) 
    rng('default');
    if (if_frozen<0)
        rand(1,abs(if_frozen));
    end
else
    rng('shuffle');
end
%
ad=struct;
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
aux_out.opts_addtree=aux.opts_addtree;
%
if aux_out.warn_bad>0
    disp('cannot proceed');
    disp(aux_out.warnings);
    return
end
%
ineq_logic_types={'exclude_addtree_trans','exclude_trans_tent'};
nineq=length(ineq_logic_types);
%
ncomps=6; %six rank choice probabilities to be compared
%
partitions=cell(0);
for ineq=1:nineq
    partitions{ineq}=psg_ineq_logic(ncomps,ineq_logic_types{ineq},setfield([],'if_log',aux.opts_addtree.if_log));
    if aux.opts_addtree.if_log
        disp(sprintf('created inequality logic for %s',ineq_logic_types{ineq}));
    end
end
permutes=psg_permutes_logic(ncomps,'flip_each');
nflips=size(permutes,2);
if aux.opts_addtree.if_log
    disp('creating permutation logic for surrogates')
    disp(sprintf(' size is %3.0f x %3.0f',size(permutes)));
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
ad.counts=struct;
ad.counts.ntrials_found=ntrials_found;
ad.counts.ntriads_found=ntriads_found;
ad.counts.nstims_found=nstims_found;
ad.counts.unique_stims_found=ustims_found;
%
nstims=nstims_found;
%
%make stimulus indices be consecutive from 1 to nstims
data=data_nz;
indices=data_nz(:,[1:3]);
[ui,ai,ci]=unique(indices(:));
data(:,[1:3])=reshape(ci,ntriads_found,3);
%
if aux.opts_addtree.if_log
    disp(sprintf('number of unique stimuli found: %3.0f; range from %3.0f to %3.0f',nstims_found,min(ustims_found),max(ustims_found)));
    disp(sprintf('number of trials found: %6.0f',ntrials_found));
    disp(sprintf('number of triads found: %6.0f',ntriads_found));
end
%
nt=3; %number of points in a triangle
triplets=nchoosek([1:nstims],nt); %triplets: unordered subsets of 3
ntriplets=nchoosek(nstims,nt); %ntriplets: number of unordered subsets of 3
%
% ncloser_triplets: [ntriplets,3]: N(d(a,b)<d(a,c)), N(d(b,c)<d(b,a)), N(d(c,a)<d(c,b))
% ntrials_triplets: [ntriplets,3]: total trials in above
[ncloser_triplets,ntrials_triplets,abc_list]=psg_triplet_choices(nstims,data); %extract triplets and sort
%
if aux.opts_addtree.if_log
    disp(sprintf('number of trials   after sorting: %6.0f',sum(ntrials_triplets(:)))) 
    disp(sprintf('number of triads   after sorting: %6.0f',sum(ntrials_triplets(:)>0)));
    disp(sprintf('number of triplets after sorting: %6.0f',sum(sum(ntrials_triplets,2)>0)));
    disp(sprintf('number of trials per triad range from %6.0f to %6.0f',min(ntrials_triplets(:)),max(ntrials_triplets(:))));
end
if (sum(ntrials_triplets(:))~=ntrials_found)
    wmsg=sprintf('mismatch of number of trials in data before sorting (%5.0f) vs after sorting (%5.0f)',ntrials_found,sum(ntrials_triplets(:)));
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
if aux.opts_addtree.if_log
    disp('creating tents from triplets');
end
%
%now create tents from the triplets
%
[ncloser,ntrials]=psg_tent_choices(nstims,data,ncloser_triplets,ntrials_triplets,aux.opts_addtree.if_log);
ntriplets_exclude=nchoosek(nstims-1,nt); %number of triplets that exclude a given stimulus
ntents=nstims*ntriplets_exclude;
%
h_fixlist=aux.opts_addtree.h_fixlist;
h_fixlist=unique([0 h_fixlist(:)']);
nhfix=length(h_fixlist);
%
ad.dirichlet=struct();
ad.dirichlet.columns_tallies={'min_trials_per_triad','ntriads','ntrials'};
ad.dirichlet.columns_a={'a','loglike_per_trial'};
ad.dirichlet.columns_ah={'a','h','loglike_per_trial'};
ad.dirichlet.h_fixlist=h_fixlist;
%
%Dirichlet fits, for fixed values of h and also h fitted
%code modified from psg_tentlike_demo, adapted for if_fixa=0, and rs_dirfit_choicedata
%
%Note that here and in private fits, values of a may differ slightly e.g., 0.01) from those obtained by psg_tentlike_demo
%This is because here, optimization uses loglik_beta_discrete, which adds a quadratic cost when h<0,
%while in psg_umi_triplike_demo, loptimization uses oglik_beta, which does not add a cost, but values of h<0 are replaced by the best fit with h>=0
%
aux_dirfit=struct;
for k=1:length(dirfit_opts)
    fn=dirfit_opts{k};
    if isfield(aux.opts_addtree,fn)
        aux_dirfit.opts_dirfit.(fn)=aux.opts_addtree.(fn);
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
% fit Dirichlet parameters according to occurrences in tents
% note that this weighs triplets more heavily if they occur in multiple tents
% ntrials_triplets is organized by triplets; ntrials is organized by tents, and trials are used more
%
ithr=0;
for thr=[min(ntrials(:)) max(ntrials(:))] %just compute extremes, and we only need min(ntrials(:)) for the index calculation below
    triads_use=find((ntrials(:)>=thr));
    ntriads_use=length(triads_use);
    ntrials_use=sum(ntrials(triads_use));
    if (ntriads_use>=aux.opts_addtree.ntriplets_min)
        ithr=ithr+1;
        ad.dirichlet.tallies(ithr,:)=[thr,ntriads_use,ntrials_use];
        data_use=[ncloser(triads_use) ntrials(triads_use)];
        if aux.opts_addtree.if_log
            disp(sprintf('fitting Dirichlet params after thresholding triads by %3.0f trials',thr))
        end
        %fixed  values of h
        for ihfix=1:nhfix
            %
            aux_dirfit_a.opts_dirfit.fixed_h=h_fixlist(ihfix);
            [dirfit_a,aux_dirfit_out_a]=rs_dirfit_choicedata(data_use,aux_dirfit_a);
            ad.dirichlet.a(ithr,:,ihfix)=[dirfit_a.a.val,dirfit_a.a.llnat_per_trial];
        end
        %fit a and h
        [dirfit_ah,aux_dirfit_out_ah]=rs_dirfit_choicedata(data_use,aux_dirfit_ah);
        ad.dirichlet.ah(ithr,:)=[dirfit_ah.ah.val',dirfit_ah.ah.llnat_per_trial];
    end
end
%
%analyze for consistency with addtree
%
ipg_strings={'private','global'};
npg=length(ipg_strings);
thr_types={'min','max','avg'};
nthr_types=length(thr_types);
%
%global analyses: Dirichlet fits not adjusted based on which triads are used
%private analyses: Dirichlet fits are private to the triads used
%
ad.meta=struct;
ad.global=struct;
ad.meta.thr_types=thr_types;
ad.meta.columns_tallies={'thr','ntriplets','ntrials'};
ad.meta.columns_a={'a','loglike_per_trial'}; %values of a and h determined from the selected trials
ad.meta.columns_ah={'a','h','loglike_per_trial'}; %values of a and h determined from the selected trials
ad.meta.columns_adt={'llr_addtree_trans_vs_trans_tent'}; %not excluded by addtree_trans vs not excluded by anything trans
ad.meta.columns_adt_hfixed=ad.meta.columns_adt; %like adt, but with fixed values of h
ad.meta.thr_types=thr_types;
ad.meta.ipg_strings=ipg_strings;
ad.meta.surr_types={'orig data','flip_all','flip_any'};
%
ad.global.a=ad.dirichlet.a(1,:,:); % values with h fixed
%compute using global a and h from unthresholded Dirichlet and save in r.ad.global.ah
if ad.dirichlet.ah(1,2)>=0 %use full fit if h>=0
    ad.global.ah=ad.dirichlet.ah(1,:);
else %otherwise use best fit with h=0
    ad.global.ah=[ad.dirichlet.a(1,1,1),0,ad.dirichlet.a(1,2,1)];
end
if aux.opts_addtree.if_private % compute these later using private a and h, to go in ad.private.[a|ah]{ithr_type}
    ad.private=struct;
    ad.private.a=cell(1,nthr_types); 
    ad.private.ah=cell(1,nthr_types);
end
%
ad.meta.global_private_d1={'mean of sum','variance of sum'};
ad.meta.global_private_d2={'threshold type'};
ipg_min=2-aux.opts_addtree.if_private;
for ipg=ipg_min:npg
    ad.(ipg_strings{ipg}).adt=cell(2,nthr_types);
    ad.(ipg_strings{ipg}).adt_hfixed=cell(2,nthr_types);
end
%
ad.meta.llr_d1={'threshold value'};
ad.meta.llr_d2=ad.meta.surr_types;
ad.meta.llr_d3={'hfixed'};
ad.meta.nsurr=length(ad.meta.surr_types);
nsurr=length(ad.meta.llr_d2); %three kinds of surrogates: native, flip all, flip any
%
llr_adt=cell(nsurr,2); %summed log likelihood ratio across trials, and summed variance of total 
llr_adt_hfixed=cell(nsurr,2);
llr_umi_hfixed=cell(nsurr,2);
surr_list={1,[1 nflips],[1:nflips]};
%
%if_fast=1: calculate probabilities for all triplets
ah=ad.global.ah;
ah_fixed=[squeeze(ad.dirichlet.a(1,1,:)),h_fixlist(:)];
obs_all=[reshape(ncloser',[ncomps 1 ntents]),reshape(ntrials',[ncomps 1 ntents])];
params.a=ah(1);
params.h=ah(2);
liks_all=psg_ineq_apply(params,obs_all,partitions,permutes);
if aux.opts_addtree.if_log
    disp(sprintf('preliminary global calculations done for a fitted at %6.4f, h fitted at %6.4f',params.a,params.h));
end   
liks_hfixed_all=zeros(nineq,nflips,ntents,nhfix);
for ihfix=1:nhfix
    params.a=ah_fixed(ihfix,1);
    params.h=ah_fixed(ihfix,2);
    liks_hfixed_all(:,:,:,ihfix)=psg_ineq_apply(params,obs_all,partitions,permutes);
    if aux.opts_addtree.if_log
        disp(sprintf('preliminary global calculations done for a fitted at %6.4f, h  fixed at %6.4f',params.a,params.h));
    end   
end
%
for ipg=ipg_min:2 %private and global, code modified from psg_umi_triplike_demo with nconform=0, if_fast=1
    if aux.opts_addtree.if_log
        disp(sprintf('%10s calculations',ipg_strings{ipg}));
    end
    for ithr_type=1:nthr_types %three kinds of thresholds: min, max, average
        if_ok=1;
        thr=0; %threshold
        ithr=1; %threshold pointer
        if aux.opts_addtree.if_log
            disp(sprintf('analyzing addtree likelihood ratio for threshold type %s',thr_types{ithr_type}));
        end
        nuse_prev=-1; %will allow for reuse if increasing the threshold doesn't change the number of triplets/tents used
        while (if_ok)
            switch thr_types{ithr_type}
                case 'min'
                    tents_use=find(min(ntrials,[],2)>=thr);
                    thr_val=thr;
                case 'max'
                    tents_use=find(max(ntrials,[],2)>=thr);
                    thr_val=thr;
                case 'avg'
                    tents_use=find(sum(ntrials,2)>=thr);
                    thr_val=thr/ncomps; %average not total
            end
            if (length(tents_use)>=aux.opts_addtree.ntents_min)
                ntents_use=length(tents_use);
                if ntents_use~=nuse_prev
                    did_or_skipped='did'; %have to calculate
                    nuse_prev=ntents_use;
                    ntrials_use=sum(sum(ntrials(tents_use,:)));
                    ad.tallies{ithr_type}(ithr,:)=[thr_val ntents_use ntrials_use]; %threshold, number of tents, number of trials
                    %compute private best-fitting a and h
                    if (ipg==1)
                        data_use=[reshape(ncloser(tents_use,:),ncomps*ntents_use,1) reshape(ntrials(tents_use,:),ncomps*ntents_use,1)];
                        %private fits, assuming fixed values of h
                        for ihfix=1:nhfix
                            aux_dirfit_a.opts_dirfit.fixed_h=h_fixlist(ihfix);
                            [dirfit_a,aux_dirfit_out_a]=rs_dirfit_choicedata(data_use,aux_dirfit_a);
                            ad.private.a{ithr_type}(ithr,:,ihfix)=[dirfit_a.a.val,dirfit_a.a.llnat_per_trial];
                        end
                        %private fit for a and h
                        [dirfit_ah,aux_dirfit_out_ah]=rs_dirfit_choicedata(data_use,aux_dirfit_ah);
                        if dirfit_ah.ah.val(2)>=0 %ensure h >=0
                            ad.private.ah{ithr_type}(ithr,:)=[dirfit_ah.ah.val',dirfit_ah.ah.llnat_per_trial];
                        else
                            ad.private.ah{ithr_type}(ithr,:)=[dirfit_a.a.val,0,dirfit_ah.ah.llnat_per_trial];
                        end
                    end
                    liks=zeros(nineq,nflips,ntents_use);
                    liks_hfixed=zeros(nineq,nflips,ntents_use,nhfix);
                    %
                    %fast global option:calculate probabilities for all triplets and later select
                    %
                    if ipg==2
                        liks=liks_all(:,:,tents_use); %d1: addtree_trans vs trans_tent, d2: flips, d3: tent
                        liks_hfixed=liks_hfixed_all(:,:,tents_use,:); %d1: addtree_trans vs trans_tent, d2: flips, d3: tent, d4:h_fixed
                    else % ipg=1 (private)
                        ah=ad.private.ah{ithr_type}(ithr,:); %a and h both fitted
                        ah_fixed=[squeeze(ad.private.a{ithr_type}(ithr,1,:)),h_fixlist(:)]; %a fitted, h fixed
                        params.a=ah(1);
                        params.h=ah(2);
                        liks=psg_ineq_apply(params,obs_all(:,:,tents_use),partitions,permutes);
                        for ihfix=1:nhfix
                            params.a=ah_fixed(ihfix,1);
                            params.h=ah_fixed(ihfix,2);
                            liks_hfixed(:,:,:,ihfix)=psg_ineq_apply(params,obs_all(:,:,tents_use),partitions,permutes);
                        end
                    end %ipg
                    %do statistics
                    %likelihood of addtree and trans,/likelihood(trans), i.e., exclude_addtree_trans/exclude_trans_tent';
                    %dimensions reordered to match those of loglik_rat_sym|umi[|_hfixed] of psg_umi_triplike_demo
                    loglikrats=transpose(log(reshape(liks(1,:,:)./liks(2,:,:),[nflips ntents_use]))); %after transpose: d1: tents, d2: flips
                    loglikrats_hfixed=permute(log(reshape(liks_hfixed(1,:,:,:)./liks_hfixed(2,:,:,:),[nflips ntents_use nhfix])),[2 1 3]); %d1:tents, d2:flips, d3:h
                    for isurr=1:nsurr %for each kind of surrogate
                        surr_sel=surr_list{isurr}; %for isurr=1, this is just the original data (1)
                        llr_adt{isurr,1}=sum(mean(loglikrats(:,surr_sel),2),1);
                        llr_adt_hfixed{isurr,1}=reshape(sum(mean(loglikrats_hfixed(:,surr_sel,:),2),1),[1 1 nhfix]);
                        if (isurr>1)
                            %each tent contributes independently to the variance
                            %variance for each tent is normalized by N not N-1, since we have all the values
                            llr_adt{isurr,2}=sum(var(loglikrats(:,surr_sel),1,2),1);
                            llr_adt_hfixed{isurr,2}=reshape(sum(var(loglikrats_hfixed(:,surr_sel,:),1,2),1),[1 1 nhfix]);
                        else %isurr=1: original data. Here, goal is for psg_umi_triplike_plota to compute standard error of the mean
                            %which is sqrt(var)/ntents_use, but
                            %psg_umi_triplike_plota will find square root and then divide by ntents_use
                            %so here we just compute var, normalized by N-1 since it is a sample
                            %here, surr_sel=1
                            llr_adt{isurr,2}=var(loglikrats(:,surr_sel),0,1);
                            llr_adt_hfixed{isurr,2}=reshape(var(loglikrats_hfixed(:,surr_sel,:),0,1),[1 1 nhfix]);
                        end
                        for imv=1:2% mean and variance
                            ad.(ipg_strings{ipg}).adt{imv,ithr_type}(ithr,isurr)=llr_adt{isurr,imv};
                            ad.(ipg_strings{ipg}).adt_hfixed{imv,ithr_type}(ithr,isurr,:)=llr_adt_hfixed{isurr,imv};
                        end %imv
                     end %isurr
                else %change in threshold does not change which triplets are included
                     did_or_skipped='skp';
                     ad.tallies{ithr_type}(ithr,:)=ad.tallies{ithr_type}(ithr-1,:);
                     ad.tallies{ithr_type}(ithr,1)=thr_val; %threshold is new
                     if (ipg==1)
                        ad.private.a{ithr_type}(ithr,:,:)=ad.private.a{ithr_type}(ithr-1,:,:);
                        ad.private.ah{ithr_type}(ithr,:)=ad.private.ah{ithr_type}(ithr-1,:);
                     end
                     for isurr=1:nsurr
                         for imv=1:2% mean and variance
                             ad.(ipg_strings{ipg}).adt{imv,ithr_type}(ithr,isurr)=llr_adt{isurr,imv};
                             ad.(ipg_strings{ipg}).adt_hfixed{imv,ithr_type}(ithr,isurr,:)=llr_adt_hfixed{isurr,imv};
                         end %imv
                     end %isurr
                 end %nuse_prev
                 if aux.opts_addtree.if_log
                     disp(sprintf('%s ipg %3.0f ithr_type %3.0f ithr %3.0f thr %3.0f ntents_use %6.0f size(liks) %4.0f %4.0f %6.0f size(liks_hfixed) %4.0f %4.0f %6.0f %4.0f',...
                         did_or_skipped,ipg,ithr_type,ithr,thr,ntents_use,size(liks),size(liks_hfixed)));
                 end
                 thr=thr+1; %threshold
                 ithr=ithr+1; %pointer
             else
                 if_ok=0;
             end
         end %if_ok
    end %thr_type
end %ipg
%
if aux.opts_addtree.if_plot>0
    [aux_out.fig_handles,aux_out.fig_handle_detailed,aux_out.summary]=rs_addtree_plot(data_comp,ad,aux);
end
return
end

function [fig_handles,fig_handle_detailed,summary]=rs_addtree_plot(data_comp,ad,aux)
%wrapper for psg_umi_triplike_plot and psg_umi_triplike_plota
%
if isfield(ad,'private')
    ipg_min=1; %private and global
else
    ipg_min=2; %only global
end
plot_opts=struct;
plot_opts.ipg_min=ipg_min;
plot_opts.data_fullname=aux.opts_addtree.plot_label;
plot_opts.nconform=0;
%plot_opts.nsurr=size(ad.global.sym{1,1},2);
plot_opts.llr_field='ad';
%
%reorganize for compatibility with psg plotting
r=ad;
r.h_fixlist=ad.dirichlet.h_fixlist;
r.ad.thr_types=ad.meta.thr_types;
r.ad.llr_d1=ad.meta.llr_d1;
r.ad.llr_d2=ad.meta.llr_d2;
r.ad.llr_d3=ad.meta.llr_d3;
r.ad.tallies=ad.tallies;
r.ad.global=ad.global;
if isfield(ad,'private')
    r.ad.private=ad.private;
end
%
[opts_plot_used,fig_handles,summary]=psg_umi_triplike_plota(r,plot_opts);
%
if aux.opts_addtree.if_plot==2 %detailed plot
    [opts_plot_used_det,fig_handle_detailed]=psg_umi_triplike_plot(r,plot_opts);
else
    fig_handle_detailed=[];
end
return
end
