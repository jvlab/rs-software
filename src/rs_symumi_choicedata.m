function [su,aux_out]=rs_symumi_choicedata(data_comp,aux)
% [su,aux_out]=rs_symumifit_choicedata(data_comp,aux) analyzes a set of triadic choices for consistency with symmetry and the ultrametric inequality
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
%     - dirichlet (struct): Dirichlet fits, a structure with fields 
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_symumi (struct): aux,opts_symumi with defaults and values used
%     - opts_check (struct): aux.opts_check, with defaults filled in
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
% triadic? at least two choices neded to fit a, three choices for a and h, and one extra if doing jackknifes
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
%code from psg_umi_triplike_demo, adapted for if_fixa=0, and rs_dirfit_choicedata
%
aux_dirfit=struct;
for k=1:length(dirfit_opts)
    aux_dirfit.opts_dirfit.(dirfit_opts{k})=aux.opts_symumi.(dirfit_opts{k});
end
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
return
end
