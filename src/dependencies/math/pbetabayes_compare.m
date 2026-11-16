function [q,opts_used]=pbetabayes_compare(ab,obs,opts)
% [q,opts_used]=pbetabayes_compare(ab,obs,opts) carries out Bayesian evaluation of relationships
% between finite-sample estimates of probabilities, assuming they are drawn from a Dirichlet distribution
% i.e., a priori likelihoods proportional to p^(a-1)*(1-p)^(b-1)
%
% ab: [a b], or, if scalar, the common value of a and b. Note a=b=1 for flat prior.
% obs: a vector of observations where obs(:,1) is successes and obs(:,2) is total tries
% opts: options
%    opts.mode: 'interval' (default) or 'umi' or 'orthants'
%       interval: find probability that p (estimated from obs(1,:) lies in a given interval
%       umi: find the probability that the underlying probability for three pairs of obs([1:3],:)
%       are consistent with the ultrametric inequality, via interior calculation
%          (see .../jv/ey07977/psg_umi_notes.doc)
%       orthants: evaluate the probability that an n-tuple of
%           probabilities (size(opts)=[n 2]) lies in one of the orthants defined
%           by opts.orthant_defs, which has size [m n]
%    opts.interval_def: if opts.mode='interval', then evaluate the probability
%       that p lies in a given interval, defaults to [0 .5];
%    opts.orthant_defs: if opts.mode='orthants', then elements of orthant_defs(r,k)  defines the orthants to be included. 
%           orthant_defs(r,k)=0: the included region for the underlying probability for opts(k,:) is [0 1/2].
%           orthant_defs(r,k)=1: the included region for the underlying probability for opts(k,:) is [1/2 1].
%           Probabilities are summed over the specified orthants. orthant_defs=[0 0 0;1 1 1] corresponds to umi:  same sign
%           Defaults to zeros(1,size(obs,1)), i.e., all probs in [0 1/2]
%
% For background, see .../jv/ey07977/psg_umi_notes.doc.
%
% q: the probability
% opts_used: options used
%       if opts.mode='orthants', the contribution from each orthant is returned in opts_used.q_orth
%
%    See also:  LOGLIK_BETA, BETAINC.
%
if (nargin<3)
    opts=struct();
end
opts=filldefault(opts,'mode','interval');
opts=filldefault(opts,'interval_def',[0 0.5]);
opts=filldefault(opts,'orthant_defs',zeros(1,size(obs,1)));
%
if length(ab)==1
    ab=[ab ab];
end
a=ab(1);
b=ab(2);
switch opts.mode
    case 'interval'
        au=a+obs(1,1);
        bu=b+obs(1,2)-obs(1,1);
        q=diff(betainc(opts.interval_def,au,bu));
    case 'umi'
        if a~=b
            warning(sprintf('in mode %s but a~=b',opts.mode));
        end
        binc_vals=zeros(1,3);
        for k=1:3
            binc_vals(k)=betainc(1/2,a+obs(k,1),b+obs(k,2)-obs(k,1));
        end
        q=prod(binc_vals)+prod(1-binc_vals);
    case 'orthants'
        if a~=b
            warning(sprintf('in mode %s but a~=b',opts.mode));
        end
        nvars=size(opts.orthant_defs,2);
        north=size(opts.orthant_defs,1);
        binc_vals_both=zeros(2,nvars);
        for k=1:nvars
            binc_vals_both(1,k)=betainc(1/2,a+obs(k,1),b+obs(k,2)-obs(k,1));
        end
        binc_vals_both(2,:)=1-binc_vals_both(1,:);
        q_orth=ones(north,1); %contribution of each orthant
        for r=1:north
            for k=1:nvars
                q_orth(r)=q_orth(r)*binc_vals_both(1+opts.orthant_defs(r,k),k);
            end
        end
        q=sum(q_orth);
        opts.q_orth=q_orth;
    otherwise
        warning(sprintf('mode %s is unknown',opts.mode));
        q=NaN;
end
opts_used=opts;
return
