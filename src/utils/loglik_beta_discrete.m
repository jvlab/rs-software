function [loglik,opts_used]=loglik_beta_discrete(ab,obs,opts)
% [loglik,opts_used]=loglik_beta_discrete(ab,obs,opts) determines the log likelihood (natural log) for a beta distribution (Dirichlet prior)
% with discrete part, based on a set of observations
%
% Args:
%   ab (int 1-D array): Dirichlet parameters a=ab(1), b=ab(2), or a=b=ab(1) if scalar; a and b must be >0
%
%   obs (int 2-D array): a vector of observations where obs(:,1) is successes and obs(:,2) is total tries
%
%   opts (struct): options, with fields
%
%     - hvec (float 1-D array): vector of weights for point-mass probabilities,  must be all >=0 and sum to <=1 (not checked for), defaults to [];
%     - qvec (float 1-D array): vector of probabilities corresponding to the elements of hvec, must all be strictly >0 and < 1
%
% Returns:
%   loglik (float): log likelihood (natural log)
%   opts_used (struct): option values used
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
opts_used=opts;
return
