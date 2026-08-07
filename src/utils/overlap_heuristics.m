function h=overlap_heuristics(overlaps)
% h=overlap_heuristics(overlaps)
% computes several heuristics for whether the number of overlaps of pairwise distances across several datasets
% suffices for a well-defined knitting across these datasets
% 
% Args:
%   overlaps (int 2-D array): overlaps(istim,iset) is 1 if stimulus istim is present in record iset, 0 otherwise
%
% Returns:
%   h (struct): structure of heuristics, with fields
% 
%     - nstims (int): number of stimuli (size(overlaps,1))
%     - nstims_used (int): number of stimuli present in at least one record
%     - npairs (int): total number of pairwise distances within records
%     - nmax (int): maximum number of pairwise distances if all stimuli were in the same record
%     - counts (int 2-D array): counts(istim,jstim) is the number of records that contain both stimuli
%     - nfree (int 1-D array): nfree(iset) is the number of stimuli unique to record iset
%     - nbound (int 1-D array): nbound(iset) is the number of stimuli in record iset that are in at least one other record
%     - novlp (int 2-D array): novlp(iset,jset) is the number of stimuili in common between records iset and jset
%     - dmax_free (int): maximum dimension that is rigidly constrained by bound points, equal to min(nbound-1) for all records with nfree(irec)>0
%     - dmax_constraints (int): maximum dimension for which number of coordinates to be found, minus offset and rotational d.o.f., does not exceed npairs
%     - dmax (int): maximum dimension for which a well-defined knitting solution can be expected, min(dmax_free,dmax_constraints)
%
% Note: Note regarding format of overlaps
%     - The format of overlaps is identical to the optional argument opts_pcon.overlaps in `procrustes_consensus`.
%
% See also: PROCRUSTES_CONSENSUS.
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