function [likrat,lik,opts_used]=psg_umi_triplike(params,obs,opts)
% [likrat,lik,opts_used]=psg_umi_triplike(params,obs,opts) analyzes a triplet of
% observed rank choice judgments w.r.t. the likelihood that their underlying
% probabilities are consistent with the ultrametric inequality, and also, consistent with symmetry
%
% The starting data are three related ranked choice probabilities (see obs, below)
% A priori distribution for the underlying probabilites ia a mixture of a symmertric
% Dirichlet prior, (parameters a,a) with weight 1-h, and and a point mass at 0.5, with weight h
%
% The likelihood ratio is for this triplet of observations, i.e., is per triplet;
% The number of observations is taken into account implicitly as it sharpens the posterior distribution
% for the underlying probabilities.
% 
% For background, see .../jv/ey07977/psg_umi_notes.doc.
%
% Calculation is related to pbetabayes_compare but normalization is
% different (factor of lik.orthants_sum) because we need to compare to the discrete distribution.
%
% params: params.a and params.h describe the mixed Dirichlet/point mass prior; 
%    these could be fitted as shown in loglik_beta_demo2.
% obs: [3 2] array of integers, 
%    obs[1,:] is number of trials in which A is seen as closer to B than to C, and total trials; fraction is r(A;B,C)
%    obs[2,:] is number of trials in which B is seen as closer to C than to A, and total trials; fraction is r(B;C,A)
%    obs[3,:] is number of trials in which C is seen as closer to A than to B, and total trials; fraction is r(C;A,B)
% opts: options
%   opts.tol: tolerance for checking consistency
%   opts.if_check: defaults to 0;
%      1 to check consistency with pbetabayes_compare, -1 to log results
%   opts.if_fast: if present, skips checking; uses some hard-coding instead of transparent code; skips calls to filldefault
%   opts.if_vec:  if present, uses vectorized version (even if if_fast present); skips checking; seems slightly slower than if_fast
%   opts.if_partition: if present, uses calculation via psg_ineq_logic, more general but not faster
%     if this is present, then opts.partition.exclude_trans|umi|umi_trans], from psg_ineq_logic, 
%     should be present, if not they are created -- but this is inefficient for multiple calls since they do not depend on the data
%
% likrat: structure of likelihood ratios
%    likrat.umi_trans: likelihood ratio for satisfying umi, given symmetry and transitivity
%      = lik.umi_trans/lik.trans
%    likrat.sym: likelihood ratio for consistency with symmetry
%      =lik.sym/(lik.sym+lik.sym_not);
% lik: structure of intermediate calculations. Note, all but lik.sym and lik.sym_not assume symmetry.
%         (lik.sym and lik.sym_not do not assume a metric-space structure).
%    lik.trans: total likelihood consistent with transitivity
%    lik.umi: total likelihood consistent with ultrametric
%    lik.umi_trans: total likelihood consistent with ultrametric and transitivity
%    lik.umi_orthants: likelihood of consistency with umi, if h=0 (note, these violate transitivity)
%    lik.orthants(2,2,2): likelihood in each orthant, if h=0
%    lik.orthants_sum: sum of lik.orthants
%    lik.orthants_dimlabels: labels for each of the dimensions of lik.orthants
%    lik.boundaries: likelihood on each boundary, if h=1
%    lik.boundaries_labels: labels for each of the elements of lik.boundaries
%    lik.sym: likelihood that underlying distances are consistent with symmetry
%       *this is identical to lik.trans -- if symmetry is excluded by assuming transitivity, then
%       transitivity is excluded by assuming symmetry*
%    lik.sym_not: likelihood that underlying distances are inconsistent with symmetry
%
% opts_used: options used
%
% 09Feb23: added if_fast
% 10Feb23: changed computation of betaln to explicit difference in gammaln's, saving time
% 22Feb23: added if_vec, fast and vectorized
% 27Feb23: fixed error in all-equal calculation
% 27Feb23: added opts.if_partition
%
%   See also: PSG_UMI_STATS, PBETABAYES_COMPARE, LOGLIK_BETA, LOGLIK_BETA_DEMO2, INT2NARY, BETA_INC
%     BETA_LN, GAMMA_LN, PSG_PROBS_CHECK, PSG_INEQ_LOGIC, ORD_CHAR_SIMUL_DEMO.
%
if nargin<3
    opts=struct;
end
lik=struct;
ncomps=3; %number of comparisons
if isfield(opts,'if_partition')
    if_check=0;
    if ~isfield(opts,'partition')
        partition=struct;
        partition.exclude_trans=psg_ineq_logic(ncomps,'exclude_trans');
        partition.exclude_umi=psg_ineq_logic(ncomps,'exclude_umi');
        partition.exclude_umi_trans=psg_ineq_logic(ncomps,'exclude_umi_trans');
        opts.partition=partition;
    end
elseif isfield(opts,'if_vec')
    if_check=0;
    all_match=zeros(2^ncomps,1);
    all_match([1 end])=1;
elseif isfield(opts,'if_fast')
    if_check=0;
    orthant_defs=[0 0 0;1 0 0;0 1 0;1 1 0; 0 0 1;1 0 1;0 1 1;1 1 1]; %hard-coded for speed
    all_match=[1 0 0 0 0 0 0 1]'; %hard-coded for speed
else
    opts=filldefault(opts,'tol',10^-5);
    opts=filldefault(opts,'if_check',0);
    %
    if size(obs,1)~=ncomps
        warning('wrong size of obs');
    end
    tol=opts.tol;
    if_check=opts.if_check;
    lik.orthants_dimlabels={'d(A,B) vs. d(A,C) > or <','d(B,C) vs. (B,A) > or <','d(C,A) vs. d(C,B) > or <'};
    lik.boundaries_labels=strrep(strrep(lik.orthants_dimlabels,'vs.','='),' > or <','');
    orthant_defs=int2nary([0:2^ncomps-1]',2);  %rows are [0 0 0;1 0 0;0 1 0;1 1 0; 0 0 1;1 0 1;0 1 1;1 1 1];
    all_match=double(min(orthant_defs,[],2)==max(orthant_defs,[],2));
    opts.orthant_defs=orthant_defs;
end
%
%parition, vectorized, or fast?
%
if isfield(opts,'if_vec') | isfield(opts,'if_partition') %vectorized version
    lik.boundaries=1./(2.^obs(:,2))';
    %
    a=params.a;
    betaln_aa=gammaln(a)*2-gammaln(2*a); %10Feb23
    a1s=a+obs(:,1);
    a2s=a+obs(:,2)-obs(:,1);
    bfs=betainc(0.5,a1s,a2s);
    mults=exp(gammaln(a1s)+gammaln(a2s)-gammaln(a1s+a2s)-betaln_aa);
    lik.intervals=[bfs.*mults,(1-bfs).*mults]';
    %
    lik.orthants_sum=prod(mults); %normalization for intervals: each interval adds up to mults(icomp)
    %
    orthant_prod=lik.intervals(:,1);
    for icomp=2:ncomps
        orthant_prod=[orthant_prod.*lik.intervals(1,icomp);orthant_prod.*lik.intervals(2,icomp)];
    end
    lik.orthants=reshape(orthant_prod,repmat(2,1,ncomps));
else
    %
    %orthant_defs indicate whether the underlying rank choice probability is closer
    %to 0 (orthant_defs(1,...)  is high, ) or closer to 1 (orthant_defs(2,...) is high)
    %
    %calculate discrete part, prior to weighting by h
    % lik(boundary|obs)=p(obs|boundary)*p(boundary)=p(obs|boundary)
    lik.boundaries=zeros(1,ncomps);
    for icomp=1:ncomps
    %    lik.boundaries(1,icomp)=0.5^obs(icomp,1)*0.5^(obs(icomp,2)-obs(icomp,1));
        lik.boundaries(1,icomp)=0.5^obs(icomp,2); 
    end
    %calculate continuous part, i.e., prob of being on either side of the boundary
    lik.intervals=zeros(2,ncomps);
    a=params.a;
    betaln_aa=gammaln(a)*2-gammaln(2*a); %10Feb23
    for icomp=1:ncomps
        a1=a+obs(icomp,1);
        a2=a+obs(icomp,2)-obs(icomp,1);
        bf=betainc(0.5,a1,a2);
    % 10Feb23    
    %    betaln(z,w) = gammaln(z)+gammaln(w)-gammaln(z+w)
    %    mult=exp(betaln(a1,a2)-betaln(a,a)); %B(a+n,a+N-n)/(B(a,a), overall likelihood of the continuous part
        mult=exp(gammaln(a1)+gammaln(a2)-gammaln(a1+a2)-betaln_aa);
        lik.intervals(1,icomp)=bf*mult;
        lik.intervals(2,icomp)=(1-bf)*mult;
    end
    lik.orthants_sum=prod(sum(lik.intervals,1)); %normalization for intervals
    %individual orthants
    lik.orthants=zeros(2^ncomps,1);
    for ioct=1:2^ncomps
        orthant=1;
        for icomp=1:ncomps
            orthant=orthant*lik.intervals(1+orthant_defs(ioct,icomp),icomp);
        end
        lik.orthants(ioct)=orthant;
    end
    lik.orthants=reshape(lik.orthants,repmat(2,1,ncomps));
end
%
%lik.boundaries, lik.orthants, lik.intervals have proper normalization relative to each
%other, prior to weighting by h and 1-h
%
lik.umi_orthants=sum(prod(lik.intervals(1,:))+prod(lik.intervals(2,:)));
%
%compare with pbetabayes_compare
%
if if_check~=0
    %umi
    lik.umi_orthants_check=pbetabayes_compare(params.a,obs,setfield([],'mode','umi'));
    [lik.norm_check,opts_orth]=pbetabayes_compare(params.a,obs,setfields([],{'mode','orthant_defs'},{'orthants',orthant_defs}));
    lik.orthants_check=opts_orth.q_orth;
    if_ok=1;
    if abs(lik.norm_check-1)>tol
        warning('normalization check failure');
        if_ok=0;
    end
    if abs(lik.umi_orthants_check-lik.umi_orthants/lik.orthants_sum)>tol
        warning('umi check failure');
        if_ok=0;
    end
    if any(abs(lik.orthants_check-lik.orthants(:)/lik.orthants_sum)>tol)
        warning('orthant check failure');
        if_ok=0;
    end
    if (if_ok==1) & if_check==-1
        disp('checks OK');
    end
end
if isfield(opts,'if_partition')
    margliks=(1-params.h)*[lik.intervals(1,:);zeros(1,3);lik.intervals(2,:)]+params.h*[zeros(1,3);lik.boundaries(1,:);zeros(1,3)];
    blockliks=margliks(:,1);
    for nd=2:ncomps
        blockliks=[blockliks*margliks(1,nd);blockliks*margliks(2,nd);blockliks*margliks(3,nd)];
    end
    blockliks=reshape(blockliks,repmat(3,1,ncomps));
    %
    partition=opts.partition;
    lik.trans=sum(sum(sum(blockliks.*(1-partition.exclude_trans))));
    lik.umi=sum(sum(sum(blockliks.*(1-partition.exclude_umi))));
    lik.umi_trans=sum(sum(sum(blockliks.*(1-partition.exclude_umi_trans))));
    lik.sym_not=sum(sum(sum(blockliks.*(partition.exclude_trans)))); %inconsistent with symmetry (assuming trans) = inconsistent with transitivity (assuming sym)
    lik.sym=lik.trans;
else
    %
    %calculate mixed contributions
    %
    %no discrete part (all strict inequality)
    %
    orthant_match=sum(lik.orthants(:).*all_match);
    orthant_mismatch=sum(lik.orthants(:).*(1-all_match));
    lik.umi=(1-params.h)^ncomps*orthant_match;
    lik.trans=(1-params.h)^ncomps*orthant_mismatch;
    lik.umi_trans=0; %not possible
    %
    lik.sym_not=lik.umi; %matched signs
    lik.sym=lik.trans; %mismatched signs
    %
    %one discrete part, two inequalities
    mix=(1-params.h)^(ncomps-1)*params.h;
    contrib_trans=zeros(1,ncomps);
    contrib_umi_trans=zeros(1,ncomps);
    contrib_umi_intrans=zeros(1,ncomps);
    if isfield(opts,'if_vec') %see un-vectorized code below for documentation
        icomps=[1:ncomps];
        ius=mod(icomps,ncomps)+1; %cyclic perm of icomps
        ivs=mod(ius,ncomps)+1; %further cyclic perm of icomps
        %calculation for one equality
        contrib_trans=(lik.intervals(1,ivs).*lik.intervals(2,ius)+lik.intervals(1,ius).*lik.intervals(2,ivs)).*lik.boundaries;
        contrib_umi_trans=lik.intervals(1,ivs).*lik.intervals(2,ius).*lik.boundaries;
        contrib_umi_intrans=(lik.intervals(1,ivs).*lik.intervals(1,ius)+lik.intervals(2,ivs).*lik.intervals(2,ius)).*lik.boundaries;
        lik.trans=lik.trans+mix*sum(contrib_trans);
        lik.umi_trans=lik.umi_trans+mix*sum(contrib_umi_trans);
        lik.umi=lik.umi+mix*sum(contrib_umi_trans)+mix*sum(contrib_umi_intrans);
        lik.sym_not=lik.sym_not+mix*sum(contrib_umi_intrans);
        lik.sym=lik.sym+mix*sum(contrib_trans);
        %two equalities and one inequality
        contrib_2eq=(lik.intervals(1,:)+lik.intervals(2,:)).*lik.boundaries(ivs).*lik.boundaries(ius);
        lik.sym_not=lik.sym_not+(1-params.h)*(params.h^(ncomps-1))*sum(contrib_2eq);
        %all discrete parts (all equality)
        contrib=prod(lik.boundaries)*params.h^ncomps; %fixed 27Feb23, was orthants_sum
        lik.umi=lik.umi+contrib;
        lik.umi_trans=lik.umi_trans+contrib;
        lik.trans=lik.trans+contrib;
        lik.sym=lik.sym+contrib;
    else
        for icomp=1:ncomps
            iu=mod(icomp,ncomps)+1;
            iv=mod(iu,ncomps)+1;
        %for transitivity, any two obs can be on opposite sides of 1/2; third is discrete
        % so we want to add orthants [X 0 1,1 X 0;0 1 X] and [X 1 0;0 X 1;1 0 X], where X is 0 or 1, and indicates a boundary.
            contrib_trans(icomp)=(lik.intervals(1,iv)*lik.intervals(2,iu)+lik.intervals(1,iu)*lik.intervals(2,iv))*lik.boundaries(icomp);
        %for ultrametric and transitive, isosceles with unequal side shorter, so A closer to B than to C but then B closer to A than to C
        % bc_short=[X 1 0]; %d(B,C)<=d(B,A), d(C,A)>=d(C,B);r(B;C,A)>=1/2, r(C;A,B)<=1/2, to pair with a tie for r(A;B,C)
        % ca_short=[0 X 1]; %d(C,A)<=d(C,B), d(A,B)>=d(A,C);r(C;A,B)>=1/2, r(A;B,C)<=1/2, to pair with a tie for r(B;C,A)
        % ab_short=[1 0 X]; %d(A,B)<=d(A,C), d(B,C)>=d(B,A);r(A;B,C)>=1/2, r(B;C,A)<=1/2, to pair with a tie for r(C;A,B)
        % so we want orthants [X 1 0;0 X 1;1 0 X], where X is 0 or 1 as an orthant index and indicates tie.
            contrib_umi_trans(icomp)=lik.intervals(1,iv)*lik.intervals(2,iu)*lik.boundaries(icomp);
        %ultrametric but not transitive also includes [X 0 0;0 X 0;0 0 X;X 1 1;1 X 1;1 1 X];
            contrib_umi_intrans(icomp)=(lik.intervals(1,iv)*lik.intervals(1,iu)+lik.intervals(2,iv)*lik.intervals(2,iu))*lik.boundaries(icomp);
        end
        lik.trans=lik.trans+mix*sum(contrib_trans);
        lik.umi_trans=lik.umi_trans+mix*sum(contrib_umi_trans);
        lik.umi=lik.umi+mix*sum(contrib_umi_trans)+mix*sum(contrib_umi_intrans);
        lik.sym_not=lik.sym_not+mix*sum(contrib_umi_intrans);
        lik.sym=lik.sym+mix*sum(contrib_trans);
        %
        %two equalities and one inequality
        %
        %can only happen if symmetry fails to hold
        contrib_2eq=zeros(1,ncomps);
        for icomp=1:ncomps
            iu=mod(icomp,ncomps)+1;
            iv=mod(iu,ncomps)+1;
            contrib_2eq(icomp)=(lik.intervals(1,icomp)+lik.intervals(2,icomp))*lik.boundaries(iv)*lik.boundaries(iu);
        end
        lik.sym_not=lik.sym_not+(1-params.h)*(params.h^(ncomps-1))*sum(contrib_2eq);
        %
        %all discrete parts (all equality)
        %
        contrib=prod(lik.boundaries)*params.h^ncomps; %fixed 27Feb23, was orthants_sum
        lik.umi=lik.umi+contrib;
        lik.trans=lik.trans+contrib;
        lik.umi_trans=lik.umi_trans+contrib;
        lik.sym=lik.sym+contrib;
        %
    end
end
likrat.umi_trans=lik.umi_trans/lik.trans;
likrat.sym=lik.sym/(lik.sym+lik.sym_not);
%
opts_used=opts;
return
