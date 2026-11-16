function [partitions,opts_used]=psg_ineq_logic(nc,ineq_type,opts)
% [partitions,opts_used]=psg_ineq_logic(nc,ineq_type,opts) sets up the
% partitions of a "probability n-hypercube" that satisfy a set of inequalities
% and thereby exclude a model for a perceptual geometry
%
% in all cases, transitivity of comparing numbers is assumed, i.e,. if x>y and y>z then x>z
%
% if called with no arguments, partitions returns a structure of the allowed
%   values of ineq_type, each of which has a field nc indicating the allowed range of nc
% nc: number of rank-choice probability estimates, typically 3 or 6
%  If nc=3, the three rank-choice probabilities are in the order given by psg_ineq_triads('triplet'):
%   P(d(a,b)<d(a,c)), P(d(b,c)<d(b,a)), P(d(c,a)<d(c,b)), so  values that are < 1/2, > 1/2, and = 1/2 means that
%   d(a,b)>d(a,c), d(b,c) < d(b,a), d(c,a)=d(c,b) which is inconsistent with ultrameteric
%   since this is an isosceles triangle with the unequal side (a,b) the longest, so partitions(1,3,2)=1 (masked out, as inconsistent)
%   An example of consistency with ultrametric: d(a,b)=d(a,c); d(b,c)< d(b,a); d(c,a)>d(c,b), i.e., isosceles with d(a,b) longest.
%   This corresponds to an entry of 0 in (2,3,1), and similarly for cyclic permutation of the indices: 
%   partitions(2,3,1)=partitions(3,1,2)=partitions(1,2,3)=0
%  If nc=4 (comparisons around a 4-cycle), the 4 rank-choice probabilities are in the order given by psg_ineq_triads('cyc4'):
%    'P(d(z,b)<d(z,c))', 'P(d(c,z)<d(c,a))', 'P(d(a,c)<d(a,b))', 'P(d(b,a)<d(b,z))'
%  If nc=6, the six rank-choice probabilities are in the order given by psg_ineq_triads('tent'):
%   P(d(z,b)<d(z,c)), P(d(z,c)<d(z,a)), P(d(z,a)< d(z,b), P(d(a,b)<d(a,c)), P(d(b,c)<d(b,a)), P(d(c,a)<d(c,b))
%  If nc=12 (all comparisons among 4 stimuli), the 12 rank-choice probabilities are in the order given by psg_ineq_triads('tetra'):
%   P(d(z,b)<d(z,c)), P(d(z,c)<d(z,a)), P(d(z,a)<d(z,b)), P(d(a,b)<d(a,c)), P(d(b,c)<d(b,a)), P(d(c,a)<d(c,b))
%   P(d(a,b)<d(a,z)), P(d(b,c)<d(b,z)), P(d(c,a)<d(c,z)), P(d(a,c)<d(a,z)), P(d(b,a)<d(b,z)), P(d(c,b)<d(c,z))
%   (note that the first 6 match the 6 probabilities for nc=6)
%
% ineq_type: type of inequality
%   'all': covers all partitions (just for checking)
%   'exclude_sym'           (nc=3): conditions that exclude symmetry (transitivity assumed)
%   'exclude_trans'         (nc=3): conditions that exclude transitivity (symmetry of distance assumed) -- same as exclude_sym
%   'exclude_umi'           (nc=3): conditions that exclude the ultrametric inequality but may
%        allow for non-transitivity (symmetry of distance assumed)
%   'exclude_umi_trans'     (nc=3): conditions that exclude the ultrametric inequality or transitivity
%      (computed recursively from exclude_umi, exclude_trans)
%   'exclude_trans_tent'    (nc=6): conditions that exclude transitivity in a tent
%      (computed recursively from exclude_trans)
%   'exclude_addtree'       (nc=6): conditions that exclude addtree inequality (symmetry of distance assumed)
%                           based on original criteria in psg_umi_notes_v3.
%   'exclude_addtree_rev'   (nc=6): conditions reversing what is paired d(z,c) and d(a,b)  -- though this is equivalent to 
%                            exclude_addtree
%   'exclude_addtree_trans' (nc=6): conditions that exclude addtree inequality or transitivity
%      (computed recursively from exclude_addtree, exclude_trans_tent)
%   'exclude_trans_tetra'   (nc=12): conditions that exclude transitivity on a tetrahedron (4 tripods)
%   'exclude_addtree_tetra' (nc=12): conditions that exclude addtree on a tetrahedron (4 tripods)   
%   'exclude_addtree_trans_tetra' (nc=12): conditions that exclude addtree and transitivity on a tetrahedron (4 tripods)
%   'exclude_trans_cyc4'    (nc=4): conditions that exclude transitivity (or symmetry) on a 4-cycle
%   'exclude_trans_tetra_cyc4 (nc=12): conditions that exclude transitivity (or symmetry) on a 4-cycle
%   'exclude_trans_tetra_all' (nc=12): conditions that exclude transitivity (or symmetry) on a tripod or 4-cycle
%   'exclude_addtree_trans_tetra_all' (nc=12) conditions that exclude addtree and transitivity (or symmetry) on a tripod or 4-cycle
%   'exclude_scission'       (nc=12): conditions that exclude addtree based on no scission condition holding
%   'exclude_trans_scission' (nc=12): condtions that exclude transitivity (or symmertry) or exclude addtree based on scission
%
% opts: options
%   opts.if_log: 1 to log, -1 to not log and not calculate edge_counts or partitions_nz
%
% partitions: array of nc dimensions (one for each rank-choice),
%  3 values on each dimension, corresponding to rank choice< 1/2, = 1/2, > 1/2
%    Rank choice <1/2 means first arm of comparision is larger  distance than second arm
%    Rank choice =1/2 means first arm of comparision is same    distance than second arm
%    Rank choice >1/2 means first arm of comparision is smaller distance than second arm
%  (size is 3^nc)
%  An entry of 0 means that this combination is NOT excluded
%  An entry of 1 means that this combination is part of the exclusion
% opts_used: options used
% opts_used.edge_counts: array of size nc+1, edge_counts(k+1) is the number of nonzero entries in
%  partitions that have k coordinates = 2 (i.e., on the rank choice=1/2 edge)
% opts_used.partitions_nz: an array of nc dimensions, 2 values on each dimension, 
%  excluding the "=1/2" values of partitions
%
% The correspondence to ord_char_sim* and psg_umi_notes* is that
% partitions=1 where V=0: partitions is a mask, while V is an indicator function.
%
% Note that trans_tent, addtree, and addtree_trans do not have tetrahedral symmetry -- transformations for swapping a and z:
% orig P(d(z,b)<d(z,c)), P(d(z,c)<d(z,a)), P(d(z,a)< d(z,b), P(d(a,b)<d(a,c)), P(d(b,c)<d(b,a)), P(d(c,a)<d(c,b))
% swap P(d(a,b)<d(a,c)), P(d(a,c)<d(a,z)), P(d(a,z)< d(a,b), P(d(z,b)<d(z,c)), P(d(b,c)<d(b,z)), P(d(c,z)<d(c,b))
% d1 and d4 interchange; d2,d3,d5,d6 are unique
%
% 11Mar23: add special call with no arguments
% 12Mar23: check for legitimate arguments based on avail_types, add descriptive fields to avail_types.(ineq_type)
% 02Jun23: add _rev variant of exclude_addtree
% 31Aug23: add tetra options
% 04Aug23: add exclude_trans_cyc4
% 26Dec23: add psg_ineq_logic_scission
%
% See also:  PSG_UMI_TRIPLIKE, PSG_UMI_TRIPLIKE_DEMO, PSG_CHECK_PROBS, PSG_TENTLIKE_DEMO, PSG_INEQ_APPLY, PSG_PROBS_CHECK,
%   PSG_INEQ_EDGECOUNT, PSG_INEQ_LOGIC_DEMO, PSG_INEQ_LOGIC_TETRA, PSG_INEQ_TRIADS, PSG_INEQ_LOGIC_SCISSION.
%
flip_invar={'all','none','exclude_sym','exclude_trans','exclude_trans_tent','exclude_trans_tetra',...
    'exclude_trans_cyc4','exclude_trans_tetra_cyc4','exclude_trans_tetra_all',...
    'exclude_scission','exclude_trans_scission'};  %logic types that are unchanged if < replaced by >.  NO umi or addtree
% Although the tetra structures do have a symmetry if the points
% are interchanged, this also requires flipping of some dimensions, so they
% are not included in this list -- which refers to just cycling the dimensions without flips
cycle_invar={'all','none','exclude_sym','exclude_trans','exclude_umi','exclude_umi_trans','exclude_trans_cyc4'}; %logic types that are unchanged if all dimensions are cycled
avail_types=struct();
avail_types.all.nc=[];
avail_types.none.nc=[];
avail_types.exclude_sym.nc=3;
avail_types.exclude_trans=avail_types.exclude_sym;
avail_types.exclude_umi.nc=3;
avail_types.exclude_umi_trans.nc=3;
avail_types.exclude_trans_tent.nc=6;
avail_types.exclude_addtree.nc=6;
avail_types.exclude_addtree_trans.nc=6;
avail_types.exclude_addtree_rev.nc=6;
avail_types.exclude_trans_tetra.nc=12;
avail_types.exclude_addtree_tetra.nc=12;
avail_types.exclude_addtree_trans_tetra.nc=12;
avail_types.exclude_trans_cyc4.nc=4;
avail_types.exclude_trans_tetra_cyc4.nc=12;
avail_types.exclude_trans_tetra_all.nc=12;
avail_types.exclude_addtree_trans_tetra_all.nc=12;
avail_types.exclude_scission.nc=12;
avail_types.exclude_trans_scission.nc=12;
%
ineq_types=fieldnames(avail_types);
for iq=1:length(ineq_types)
    fn=ineq_types{iq};
    avail_types.(fn).flip_invar=double(~isempty(strmatch(fn,flip_invar,'exact')));  
    avail_types.(fn).cycle_invar=double(~isempty(strmatch(fn,cycle_invar,'exact')));
end
if (nargin==0)
    partitions=avail_types;
    return
end
if (nargin<=2)
    opts=struct;
end
%
if ~isfield(avail_types,ineq_type)
    warning(sprintf('inequality type %s unrecognized',ineq_type));
    return
else
    nc_allowed=avail_types.(ineq_type).nc;
    if ~isempty(nc_allowed)
        if ~ismember(nc,nc_allowed)
             warning(sprintf('wrong number of rank-choice probabilities (%1.0f) for %s',nc,ineq_type));
             return
        end
    end
end
%    
threes=[repmat(3,1,nc) 1];
opts=filldefault(opts,'if_log',0);
partitions=zeros(threes);
if_warn=0;
lt=1; %token for rank choice probabilty less than 1/2 (first distance judged as >)
eq=2; %token for rank choice probabilty equal to 1/2 (first distance judged as =)
gt=3; %token forrank  choice probability greater than 1/2 (first distance judged as <)
le=[lt:eq]; %rank choice prob <=1/2, first distance >= second distance
ge=[eq:gt]; %rank choice prob >=1/2, first distance <= second distance
switch ineq_type
    case 'all'
        partitions(:)=1;
    case 'none'
    case {'exclude_sym','exclude_trans'} 
        %symmetry is excluded (assuming transitivity) if there is a consistent cycle of inequalities
        %and at least one inequality is strict
        %
        %transitivity is excluded (assuming symmetry) under the same
        %conditions, which can also be phrased
        % two equalities and one strict inequality
        % one equality and two strict inequalities of same sign
        % no equalities; three strict inequalities of the same sign
        for id=1:3
            is=double([1:nc]~=id); %one inequality must be strict
            partitions(lt:lt+is(1),lt:lt+is(2),lt:lt+is(3))=1;
            partitions(gt-is(1):gt,gt-is(2):gt,gt-is(3):gt)=1;
        end
    case 'exclude_umi'
        % ultrametric inequality excluded if there is one equality and two strict inequalities
        % implying an isosceles triangle with the odd leg longest
        % partitions(1,3,2)=1;
        % partitions(3,2,1)=1;
        % partitions(2,1,3)=1;                       
        %ultrametric inequality is excluded
        % if there are two equalities and one strict inequality
        % partitions([1 3],2,2)=1;
        % partitions(2,[1 3],2)=1;
        % partitions(2,2,[1 3])=1; 
        for id=1:3
             partitions(id,1+mod(id+1,3),1+mod(id,3))=1;
             im=double([1:nc]==id);
             partitions([eq-im(1) eq+im(1)],[eq-im(2) eq+im(2)],[eq-im(3) eq+im(3)])=1;
        end
        %ultrametric inequality is excluded if there are no equalities, with inconsistent sign
        %    partitions([1 3],[1 3],[1 3])=1;
        partitions([lt gt],[lt gt],[lt gt])=1;
        %
        %partitions(1,1,1)=0; %consistent sign (but this is inconsistent with transitivity)
        %partitions(3,3,3)=0; %consistent sign (but this is inconsistent with transitivity)           
        partitions(1)=0;
        partitions(end)=0;
    case 'exclude_umi_trans'
        p_umi=psg_ineq_logic(nc,'exclude_umi');
        p_trans=psg_ineq_logic(nc,'exclude_trans');
        partitions=p_umi | p_trans;
    case 'exclude_trans_tent'
        p_trans=psg_ineq_logic(3,'exclude_trans');
        %exclude transitivity if either the tripod part (first 3 coords) or the triangle part (last 3 coords)
        %are inconsistent with transitivity
        partitions=repmat(p_trans,[1 1 1 3 3 3]) | repmat(reshape(p_trans,[1 1 1 3 3 3]),[3 3 3 1 1 1]); 
     case 'exclude_addtree'
        %for each rotation order of dimension, cannot have one pairsum strictly greater than the other two
        %  P(d(z,b)<d(z,c)), P(d(z,c)<d(z,a)), P(d(z,a)< d(z,b), P(d(a,b)<d(a,c)), P(d(b,c)<d(b,a)), P(d(c,a)<d(c,b))
        %
        z6=zeros(repmat(3,1,nc));
        %d(z,c)>=d(z,a) and d(a,b)>=d(b,c), at least one inequality strict
        zc_ab_gt_za_bc=z6;
        zc_ab_gt_za_bc(:,le,:,:,ge,:)=1;
        zc_ab_gt_za_bc(:,eq,:,:,eq,:)=0;
        %d(z,c)>=d(z,b) and d(a,b)>=d(c,a), at least one inequality strict
        zc_ab_gt_zb_ca=z6;
        zc_ab_gt_zb_ca(ge,:,:,le,:,:)=1;
        zc_ab_gt_zb_ca(eq,:,:,eq,:,:)=0;
        %
        zc_ab_largest=and(zc_ab_gt_za_bc,zc_ab_gt_zb_ca);
        %
        %now apply this after cycling by [a,b,c]
        partitions=zc_ab_largest | permute(zc_ab_largest,[2 3 1 5 6 4]) | permute(zc_ab_largest,[3 1 2 6 4 5]);
    case 'exclude_addtree_rev'
        %for each rotation order of dimension, cannot have one pairsum strictly greater than the other two
        %  P(d(z,b)<d(z,c)), P(d(z,c)<d(z,a)), P(d(z,a)< d(z,b), P(d(a,b)<d(a,c)), P(d(b,c)<d(b,a)), P(d(c,a)<d(c,b))
        %
        z6=zeros(repmat(3,1,nc));
        %d(z,c)>=d(z,a) and d(a,b)>=d(c,a)
        zc_ab_gt_za_ca=z6;
        zc_ab_gt_za_ca(:,le,:,le,:,:)=1;
        %d(z,c)>=d(z,b) and d(a,b)>=d(b,c)
        zc_ab_gt_zb_bc=z6;
        zc_ab_gt_zb_bc(ge,:,:,:,ge,:)=1;
        %
        zc_ab_largest=and(zc_ab_gt_za_ca,zc_ab_gt_zb_bc);
        zc_ab_largest(:,eq,:,:,eq,:)=0; %d(z,c)>=d(z,a) or d(a,b)>=d(b,c) must be strict
        zc_ab_largest(eq,:,:,eq,:,:)=0; %d(z,c)>=d(z,b) or d(a,b)>=d(c,a) must be strict
        %
        %now apply this after cycling by [a,b,c]
        partitions=zc_ab_largest | permute(zc_ab_largest,[2 3 1 5 6 4]) | permute(zc_ab_largest,[3 1 2 6 4 5]);           
    case 'exclude_addtree_trans'
        p_addtree=psg_ineq_logic(nc,'exclude_addtree');
        p_trans_tent=psg_ineq_logic(nc,'exclude_trans_tent');
        partitions=p_addtree | p_trans_tent;
    case 'exclude_trans_tetra'
        partitions=psg_ineq_logic_tetra('exclude_trans_tent');
    case 'exclude_addtree_tetra'
        partitions=psg_ineq_logic_tetra('exclude_addtree');
    case 'exclude_addtree_trans_tetra' 
        partitions=psg_ineq_logic_tetra('exclude_addtree_trans');
    case 'exclude_trans_cyc4'
        %cannot all be of same sign with at least one inequality strict
        partitions(le,le,le,le)=1;
        partitions(ge,ge,ge,ge)=1;
        partitions(eq,eq,eq,eq)=0;
    case 'exclude_trans_tetra_cyc4' 
        partitions=psg_ineq_logic_tetra('exclude_trans_cyc4');
    case 'exclude_trans_tetra_all' 
        partitions=double(psg_ineq_logic(12,'exclude_trans_tetra')|psg_ineq_logic(12,'exclude_trans_tetra_cyc4'));
    case 'exclude_addtree_trans_tetra_all' 
        partitions=double(psg_ineq_logic(12,'exclude_addtree_tetra')|psg_ineq_logic(12,'exclude_trans_tetra_all'));
    case 'exclude_scission'
        partitions=psg_ineq_logic_scission([]);
    case 'exclude_trans_scission'
        partitions=double(psg_ineq_logic(12,'exclude_trans_tetra')|psg_ineq_logic(12,'exclude_scission'));
end
if opts.if_log>=0
    %
    %create a template of the number of edges in each location to use as a mask
    %
    z=[0 1 0];
    for k=2:nc
        z=[z z+1 z];
    end
    opts.edge_counts=psg_ineq_edgecount(partitions,opts.if_log);
    pz=partitions(find(z==0));
    opts.partitions_nz=reshape(pz,[repmat(2,1,nc) 1]);
end
opts_used=opts;
return
