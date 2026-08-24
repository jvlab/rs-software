function [loglik,opts_used]=loglik_beta_discrete(ab,obs,opts)
% [loglik,opts_used]=loglik_beta_discrete(ab,obs,opts) determines the log likelihood
% (natural log) of a pair of parameters [a,b] of a beta distribution (Dirichlet prior)
% with discrete part that would yield a set of observations.
%
% Also has options for adding a set of point masses if obs is [successes trials]
%
% also see .../jv/ey07977/psg_umi_notes.doc
%
% a and b must be >0.
% if any of obs are 0 or 1, results may be Inf, -Inf, or NaN 
%
% ab: [a b], or, if scalar, the common value of a and b.  Note a=b=1 for flat prior.
% obs: a vector of observations where obs(:,1) is successes and obs(:,2) is total tries
% opts: options
%    opts.hvec: vector of weights for point-mass probabilities
%       must be all >=0 and sum to <=1 (not checked for), defaults to [];
%    opts.qvec: vector of probabilities corresponding to the elements of hvec,
%       must all be strictly >0 and < 1 (not checked for)
%    Notes re hvec,qvec: 
%       * opts.qvec and opts.hvec ignored if obs is probabilities
%       * if hvec, qvec present, opts.if_norm ignored; normalization always computed and incorporated into loglik
% Re normalization (for size(obs,2)=2, obs is counts):  
%   the likelihood does not take into account other sequences of trials
%   that have the same counts.  So for a point-mass at 0.5 (qvec=.5,hvec=1),
%   log likelihood depends for obs=[k,n] depends only on n.
%   Same is true for continuous part only (hvec=0), with beta-parameters equal and large, which approximates
%   a point mass at 0.5.  See loglik_beta_test.
%
% Modified from loglik_beta, to consider only the two-column case for obs, and to always normalize
%
% loglik: the log likelihood
% opts_used: options used
%
% 09Jan23: add opts.hvec,opts.qvec
% 10Jan23: add checking to see if betaln arguments are <0 for finite-obs case
% 17Mar23: added documentation
%
%   See also:  LOGLIK_BETA, BETALN, FILLDEFAULT.
%
if (nargin<3)
    opts=struct();
end
opts=filldefault(opts,'hvec',[]);
opts=filldefault(opts,'qvec',[]);
%
if length(ab)==1
    ab=[ab ab];
end
a=ab(1);
b=ab(2);
nobs=size(obs,1);
%obs is [successes tries]
loglik_beta_each=zeros(nobs,1);
if nobs>0
    a_args=a+obs(:,1);
    b_args=b+obs(:,2)-obs(:,1);
    if any(a_args<=0) | any(b_args<=0)
        loglik_beta_each=Inf;
    else
        loglik_beta_each=betaln(a_args,b_args); %contribution of each non-exceptional beta term
    end
end
loglik_beta=sum(loglik_beta_each);
%
if (a<=0) | (b<=0)
    lognorm_beta_each=-Inf;
else
    lognorm_beta_each=-betaln(a,b);
end
lognorm_beta=lognorm_beta_each*nobs;
%
if sum(opts.hvec)>0
    lik_beta_each=exp(loglik_beta_each+lognorm_beta_each);% beta-component, with normalization
    lik_pointmass_each=ones(nobs,length(opts.hvec));
    for hptr=1:length(opts.hvec)
        q=opts.qvec(hptr);
        lik_pointmass_each(:,hptr)=q.^(obs(:,1)).*(1-q).^(obs(:,2)-obs(:,1)); %contribution of point-mass
    end
    lik_total_each=lik_beta_each*(1-sum(opts.hvec))+lik_pointmass_each*opts.hvec(:); %weighted sum
    loglik=sum(log(lik_total_each));
    lognorm=0;
else
    lognorm=lognorm_beta;
    loglik=loglik_beta;
end
loglik=loglik+lognorm;
%
if any(opts.hvec<0) | (sum(opts.hvec)>1) %put in a wall so that h stays withinb legal range
    loglik=-Inf;
end
opts.lognorm=lognorm;
opts_used=opts;
return
