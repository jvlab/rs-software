function [dirfit,aux_out]=rs_dirfit_choicedata(choices,aux)
% [dirfit,aux_out]=rs_dirfit_choicedata(choices,aux) does maximum-likelihood fit of symmetric Dirichlet distribution to choice probabilities, optionally including a discrete component at p=0.5
% 
% Args:
%   choices (int 2-D array): choices(:,1) is the number of times the first difference was judged __more similar than__ the second difference; choices(:,2) is the number of times the comparison was made; this is typically the last two columns of data_comp as returned by `rs_read_choicedata`
%
%   aux (struct): a structure, can be omitted, with fields 
%
%     - opts_dirfit (struct): options for fitting Dirichlet parameters, can be omitted, with fields
%
%         - if_log (int): 1 to log progress, 0 to omit; default is 1; see note below regarding customization
%         - if_discrete (int): 1 to inclulde a discrete component ('h') for choice probability=0.5; see note below
%
%         - **Statistics and shuffles**
%         - if_stats (int): 1 to compute jackknife standard error of measuirement, 0 does not; default is 0
%         - if_frozen (int): random number control for shuffles and initialization; 1 for same numbers every run, 0 for different random numbers each run, negative integer for a fixed seed each run,  default is 1
%
%         - **Optimization details**
%         - a_limits (float): allowed range for the a-parameter (shape), default is [10^-2 10^2]
%         - a_optimset (struct): non-default optimizations parameters for fitting a, with `fminbnd`, default is struct()
%         - ah_optimset (struct): non-default optimizations parameters for fitting a and h, with `fminsearch`, default is struct()
% 
%     - opts_check (struct): options for consistency checking, with field
%
%         - if_warn (int): 1 to show warnings, 0 to suppress; default is 1
%
% Returns:
%   dirfit (struct): the fitted Dirichlet parameter values, a structure with fields
%
%      - nchoices (int): number of choices used in the analysis, i.e., the number of rows of choices that has a nonzero element in the final column 
%      - a (struct): analysis of the Dirichlet shape parameter, with fields
%
%          - val (float): maximum-likelihood value for a
%          - ll_per_choice (float): log likelihood per choice probability
%          - exitflag (int): exit flag from `fminbnd` optimization
%          - output (struct): detailed output from `fminbnd` optimization
%          - optimset (struct): optimization options used in `fminbnd` optimization
%
%      - ah (struct): joint analysis of the Dirichlet shape parameter and discrete component, with fields
%
%          - val (float 1-D array): val(1) is maximum-likelihood value for a, val(2) is maximum-likelihood value for h
%          - ll_per_choice (float): log likelihood per choice probability
%          - exitflag (int): exit flag from `fminsearch optimization
%          - output (struct): detailed output from `fminsearch` optimization
%          - optimset (struct): optimization options used in `fminsearch` optimization
% 
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_dirfit (struct): aux,opts_dirfit with defaults and values used
%     - opts_check (struct): aux.opts_check, with defaults filled in
%
% Note: Notes re fitting, log likelihoods and statistics
%     - The distribution of observed probabiliies p is fitted to a symmetric Dirichlet distribution with parameter 'a', i.e., P(p)=(p^(a-1))((1-p)^(a-1))/B(a-1,a-1), where B is the beta function
%
%         - Each row of 'choices' in which the second column is nonzero is considered an independent observation of the chioce probability distribution; rows containing zeros are ignored
%         - If if_discrete=1, it is also fitted to a symmetric Dirichlet distribution mixed with a discrete component at p=0.5, with weights 1-h and h, respectively
%
%     - Log likelihoods use natural logs, and are normalized by the number of nonzero rows of 'choices'
%     - Minimal number of choice probabilities (nonzero rows of 'choices') needed
%
%         - At least 2 choice probabilities are needed to fit the symmetric Dirichlet distribution
%         - At least 3 choice probabilities are needed to fit the distribution with an additional discrete component
%         - For a jacknife estimate of the s.e.m., at least one additional choice probability is needed
%         - If all empirical choice probabilities are 0 or 1, the estimated parameter values will go to the limits allowed for the fitted parameters, 'a\_limits' and 'h\_limits'
%         - This is a bare minimum for non-degeneracy.  Useful fits typically require many more choice probabilities. 
%
%     - Optimization behavior can be controlled by aux.opts_dirfit.a_optimset and aux.opts_dirfit.ah_optimset.  For example, to displahy each iteration for fitting 'a', set aux.opts_dirfit.a_optimset.Display='iter';
%
% See also: RS_READ_CHOICEDATA, LOGLIK_BETA_DISCRETE, FMINSEARCH, FMINBND.
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_dirfit',struct);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'if_discrete',0);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'if_log',1);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'a_limits',[10^-2 10^2]);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'if_frozen',1);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'if_stats',0);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'a_optimset',struct());
aux.opts_dirfit=filldefault(aux.opts_dirfit,'ah_optimset',struct());
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_dirfit_choicedata');
%
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
%set up random number generator
%
if_frozen=aux.opts_dirfit.if_frozen;
if (if_frozen~=0) 
    rng('default');
    if (if_frozen<0)
        rand(1,abs(if_frozen));
    end
else
    rng('shuffle');
end
%
choices_nz=find(choices(:,2)>0);
choices_used=choices(choices_nz,:);
%
probs=choices_used(:,1)./choices_used(:,2);
nchoices=length(choices_nz);
if aux.opts_dirfit.if_log
    disp(sprintf('fitting Dirichlet parameters: %5.0f  choices used, probability range: [%8.6f %8.6f]',nchoices,min(probs),max(probs)));
end
%
dirfit=struct;
dirfit.nchoices=nchoices;
%
% at least two choices neded to fit a, three choices for a and h, and one extra if doing jackknifes
choices_needed=2+aux.opts_dirfit.if_discrete; %minimal choices needed
if nchoices<choices_needed
    wmsg=sprintf('insufficient choices available for fitting; at least %2.0f needed',choices_needed);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
else
    if nchoices<choices_needed+aux.opts_dirfit.if_stats
        wmsg=sprintf('insufficient choices available for computing statistics; at least %2.0f needed',choices_needed+aux.opts_dirfit.if_stats);
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));d
        aux.opts_dirfit.if_stats=0; %remove stats
    end
end
if all(or(probs==0,probs==1))
   wmsg=sprintf('all probabilities are 0 or 1; fitted parameter values are unreliable');
   aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
%
aux_out.opts_dirfit=aux.opts_dirfit;
%
if aux_out.warn_bad>0
    disp('cannot proceed');
    disp(aux_out.warnings);
    return
end
%
%fit a (without discrete part)
%
a_opts=optimset(optimset('fminbnd'),aux.opts_dirfit.a_optimset);
%
[a_fit,a_fit_nll,a_fit_exitflag,a_fit_output]=fminbnd(@(x) -loglik_beta_discrete(x,choices_used),aux.opts_dirfit.a_limits(1),aux.opts_dirfit.a_limits(2),a_opts);
dirfit.a.val=a_fit;
dirfit.a.ll_per_choice=-a_fit_nll/nchoices;
dirfit.a.exitflag=a_fit_exitflag;
dirfit.a.output=a_fit_output;
dirfit.a.optimset=a_opts;
%
if aux.opts_dirfit.if_discrete
    %
    %fit a and h, using fitted a as starting point
    %
    ah_opts=optimset(optimset('fminsearch'),aux.opts_dirfit.ah_optimset);
    h_init=0;
    opts_beta=struct;
    opts_beta.qvec=0.5; %discrete part at 0.5
    ah_init=[a_fit;h_init];
    [ah_fit,ah_fit_nll,ah_fit_exitflag,ah_fit_output]=fminsearch(@(x) -loglik_beta_discrete(x(1),choices_used,setfield(opts_beta,'hvec',x(2))),ah_init,ah_opts);
    dirfit.ah.val=ah_fit;
    dirfit.ah.ll_per_choice=-ah_fit_nll/nchoices;
    dirfit.ah.exitflag=ah_fit_exitflag;
    dirfit.ah.output=ah_fit_output;
    dirfit.ah.optimset=ah_opts;
    %
end
% do jackknife, keeping track of what is left out
return
