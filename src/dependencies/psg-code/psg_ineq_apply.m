function [liks,lik_intervals,lik_orthants,lik_margs,lik_blocks]=psg_ineq_apply(params,obs,ineq_list,permutes)
% [liks,lik_intervals,lik_orthants,lik_margs,lik_blocks]=psg_ineq_apply(params,obs,ineq_list,permutes) computes likelihoods that rank choice probabilities
% for a set of observations is allowed by a set of  inequalities necessary for umi, sym, tent, etc.
% and also calculates likelihoods for flips of these inequalities for statistics
%
% no checking for consistency or presence of requisite arguments
%
% params: params.a and params.h describe the mixed Dirichlet/point mass prior; 
%    these could be fitted as shown in loglik_beta_demo2.
% obs: two-column array of integers, of length nc.  Each row corresponds to a dimension of a probability
%    cube as set up in psg_ineq_logic.
%    obs(ic,1) is number of trials in A is seen as closer to B than to C in r(A;B,C), for the triad corresponding to dimension ic
%    obs(ic,2) is the total number of trials
%  obs can have a third dimension (of size nsets), to carry out the analysis for multiple sets of observations
% ineq_list: cell array, of length ni; each component is an array of dimension nc, 3 elements on each dimension, determined by psg_ineq_logic
%  an entry of 1 excludes a volume
% permutes: array of size [3^nc,nflips], determined by psg_permutes_logic
%    nflips depends on flip_type argument to psg_permutes_logic, as follows: 'none': 1 'all':  2, 'each': 2^nc
%    if omitted, no permutations are done and nflips=1
% 
% liks: the likelihoods. size is [ni nflips], or [ni nflips nsets] if size(obs,3)>1
% lik_intervals: array of size [2 nc nsets], marginal likelihoods excluding boundary component, rows correspond to rank choice probability <1/2, >1/2
% lik_orthants: array of nc dimensions (or nc+1 if nsets>1), 2 values on each, the products of lik_intervals
% lik_margs: array of size [3 nc nsets], marginal likelihoods, rows correspond to rank choice probability <1/2, =1/2, >1/2
% lik_blocks: array of nc dimensions (or nc+1 if nsets>1), 3 values on each, the products of lik_intervals
%
% For background, see .../jv/ey07977/psg_umi_notes.doc.
%
% See also:  PSG_INEQ_LOGIC, PSG_PERMUTES_LOGIC, PSG_UMI_TRIPLIKE, PSG_PROBS_CHECK, BETAINC, GAMMALN, PSG_PROBS_CHECK, ORD_CHAR_SIMUL_DEMO.
%
ni=length(ineq_list);
nc=size(obs,1);
nsets=size(obs,3);
if (nargin<=3)
    permutes=[1:3^nc]';
end
nflips=size(permutes,2);
%
%convert ineqs into convenient list of values
%
ineqs=zeros(3^nc,ni);
for ineq=1:ni
    ineqs(:,ineq)=double(ineq_list{ineq}(:)==0);
end
liks=zeros(ni,nflips,nsets);
lik_intervals=zeros(2,nc,nsets);
lik_orthants=zeros([repmat(2,1,nc) nsets]);
lik_margs=zeros(3,nc,nsets);
lik_blocks=zeros([repmat(3,1,nc) nsets]);
%
% code from psg_probs_check to calculate interval, boundary, and orthant probabilities
%
a=params.a;
h=params.h;
betaln_aa=gammaln(a)*2-gammaln(2*a);
for iset=1:nsets
    a1s=a+obs(:,1,iset);
    a2s=a+obs(:,2,iset)-obs(:,1,iset);
    bfs=betainc(0.5,a1s,a2s);
    mults=exp(gammaln(a1s)+gammaln(a2s)-gammaln(a1s+a2s)-betaln_aa);
    lik_intervals(:,:,iset)=[bfs.*mults,(1-bfs).*mults]';
    lik_boundaries=(0.5.^obs(:,2,iset))'; 
    lik_margs(:,:,iset)=(1-params.h)*[lik_intervals(1,:,iset);zeros(1,nc);lik_intervals(2,:,iset)]+h*[zeros(1,nc);lik_boundaries;zeros(1,nc)];
    orthant_prod=lik_intervals(:,1,iset);
    block_prod=lik_margs(:,1,iset);
    for icomp=2:nc
        orthant_prod=[orthant_prod.*lik_intervals(1,icomp,iset);orthant_prod.*lik_intervals(2,icomp,iset)];
        block_prod=[block_prod.*lik_margs(1,icomp,iset);block_prod.*lik_margs(2,icomp,iset);block_prod.*lik_margs(3,icomp,iset)];       
    end
    lik_orthants((iset-1)*2^nc+[1:2^nc])=orthant_prod;
    lik_blocks((iset-1)*3^nc+[1:3^nc])=block_prod;
    %apply each set of likelihoods and permutations
    liks(:,:,iset)=ineqs'*block_prod(permutes);
end %iset
return
