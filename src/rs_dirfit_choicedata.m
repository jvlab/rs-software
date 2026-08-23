function [dirfit,aux_out]=rs_dirfit_choicedata(choices,aux)
% [dirfit,aux_out]=rs_dirfit_choicedata(choices,aux) does maximum-likelihood fit of Dirichlet distribution to choice probabilities, optionally including a discrete component at p=0.5
% 
% Args:
%   choices (int 2-D array): choices(:,1) is the number of times the first difference was judged __more similar than__ the second difference; choices(:,2) is the number of times the comparison was made; this is typically the last two columns of data_comp as returned by `rs_read_choicedata`
%
%   aux (struct): a structure, can be omitted, with fields 
%
%     - opts_dirfit (struct): options for fitting Dirichlet parameters, can be omitted, with fields
%
%         - if_log (int): 1 to log progress, 0 to omit; default is 1; see note below regarding customization
%         - a_limits (float): allowed range for the a-parameter, default is [10^-2 10^2]
%         - if_discrete (int): 1 to inclulde a discrete component ('h') for choice probability=0.5
%
%         - **Statistics and shuffles**
%         - if_stats (int): 1 to compute jackknife standard error of measuirement, 0 does not; default is 0
%         - if_frozen (int): random number control for shuffles and initialization; 1 for same numbers every run, 0 for different random numbers each run, negative integer for a fixed seed each run;  default is 1
% 
%     - opts_check (struct): options for consistency checking, with field
%
%         - if_warn (int): 1 to show warnings, 0 to suppress; default is 1
%
% Returns:
%   dirfit (struct): the fitted Dirichlet parameter values, a structure with fields
%
%      - nchoices (int): number of choices used in the analysis, i.e., the number of rows of choices that has a nonzero element in the final column 
%      - a (struct): analysis of the Dirichlet parameter, with fields
%
%          - val (float): maximum-likelihood value
%          - ll_per_choice (float): log likelihood per choice probability
%          - exitflag (int): exit flag for `fminbnd` optimization
%          - output (int): detailed output from `fminbnd` optimization
% 
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_dirfit (struct): opts_dirfit with values used
%     - opts_check (struct): aux.opts_check, with defaults filled in
%
%  See also: RS_READ_CHOICEDATA, LOGLIK_BETA, FMINSEARCH, FMINBND.
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_dirfit',struct);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'if_log',1);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'a_limits',[10^-2 10^2]);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'if_discrete',0);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'if_frozen',1);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'if_stats',0);
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
choices_used=choices(choices(:,2)>0,:);
%
probs=choices_used(:,1)./choices_used(:,2);
nchoices=size(choices_used,1);
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
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
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
%optimize with to the samples, leaving out the discrete part
%
[a_fit,nll_a_fit,a_fit_exitflag,output]=fminbnd(@(x) -loglik_beta(x,choices),aux.opts_dirfit.a_limits(1),aux.opts_dirfit.a_limits(2));
dirfit.a.val=a_fit;
dirfit.a.ll_per_choice=-nll_a_fit/nchoices;
dirfit.a.exitflag=a_fit_exitflag;
dirfit.a.output=output;
%
% add loglik_beta and any dependents to utils
% bring out options for fminbnd, fminsearch, defaults to empty
%
% if ~exist('a_limits') a_limits=[2^-10 2^3]; end
% if ~exist('h_limits') h_limits=[0 1]; end
% if ~exist('a_try') a_try=2.^[-10:.0625:10]; end
% if ~exist('q_limits') q_limits=[0.001 0.999]; end
% if ~exist('h_init') h_init=0; end %initial value for h

% [a_best_samp_beta,nll_best_samp_beta,exitflag_beta]=fminbnd(@(x) -loglik_beta(x,[successes tries]),a_limits(1),a_limits(2));
% %
% %optimize to the finite samples, assuming discrete part known
% %
% [a_best_samp_disc,nll_best_samp_disc,exitflag_disc]=fminbnd(@(x) -loglik_beta(x,[successes tries],opts_disc),a_limits(1),a_limits(2));
% %
% %now fit both, using fitted a as starting point
% %
% ah_init=[a_best_samp_beta;h_init];
% [ah_best_samp,nll_best_ah,exitflag_ah,output_ah]=fminsearch(@(x) -loglik_beta(x(1),[successes tries],setfield(opts_disc,'hvec',x(2))),ah_init);
% %



return
