function h=overlap_heuristics(overlaps)
% h=overlap_heuristics(overlaps) computes several heuristics related to the number of overlaps of pairwise distances across several datasets
%
% overlaps: 2-d array, nstims x nsets, 1 = data available
%
% h: structure with fields
%    npairs: total number of pairwise distances within the same dataset
%    nmax: maximum number of pairwise distances, if all points were in the same datasaet
%    nstims: number of stimuli (from rows of overlaps)
%    nstims_used: number of stimuli used in at least one set
%    counts: 2-d array [nstims nstims], number of sets containing each pair distance
%    nfree: 1-d array, length is nsets, number of points in each dataset that are not connected with any other dataset
%    nbound: 1-d array, length is nsets, number of points in each dataset that are connected to some point in another dataset
%    novlp: 2-d array [nsets nsets], number of overlaps between each pair of datasets
%    dmax_free: maximum dimension that is rigidly constrained by bound points, equal to min(nbound-1) for all datasets with nfree>0
%    dmax_constraints: maximum dimension for which number of coordinates to be found, minus offset and rotational d.o.f., does not exceed number of pairs of distances
%    dmax: min(dmax_free,dmax_constraints)
%
%   See also: RIGIDITY_CONSTRAINTS, RIGIDITY_CONSTRAINTS_DEMO, PROCRUSTES_CONSENSUS.
%
nstims=size(overlaps,1);
nsets=size(overlaps,2);
npairs=0;
nstims_used=sum(sum(overlaps,2)>0);
nmax=nstims_used*(nstims_used-1)/2;
%
novlp=overlaps'*overlaps;
%
counts=overlaps*overlaps';
counts=counts-diag(diag(counts));
npairs=sum(counts(:)>0)/2;
%
h.npairs=npairs;
h.nmax=nmax;
h.nstims=nstims;
h.nstims_used=nstims_used;
h.counts=counts;
h.novlp=novlp;
nhits=sum(overlaps,2);
h.nfree=sum(overlaps.*repmat(nhits==1,1,nsets),1)';
h.nbound=sum(overlaps.*repmat(nhits>=2,1,nsets),1)';
h.dmax_free=min(h.nbound(h.nfree>0)-1);
if isempty(h.dmax_free)
    h.dmax_free=Inf;
end
%
%determine max dimension for which the number of free h does not exceed the number of pairwise distances
id=1; %candidate dimension
if_ok=1;
while if_ok
    dneeded=nstims_used*id-id-(id*(id-1)/2); %number of coords for each stimulus present, minus constraint for centroid, minus rotational d.o.f.'s
    if dneeded>npairs | id>(nstims_used+1)
        if_ok=0;
    else
        id=id+1;
    end
end
h.dmax_constraints=id-1;
h.dmax=min(h.dmax_free,h.dmax_constraints);
return
end