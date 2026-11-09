function [ncloser,ntrials]=psg_tent_choices(nstims,data,ncloser_triplets,ntrials_triplets,if_log)
%
% [ncloser,ntrials]=psg_tent_choices(nstims,data,ncloser_triplets,ntrials_triplets,if_log)
% tallies the tents from a data structure of triad comparisons
%
% nstims: number of distinct stimuli
% data: array with each row consisting of [ref c1 c2 N(d(ref,c1)<d(ref,c2)) Ntot]
% ncloser_triplets: variable returned from psg_triplet choices
% ntrials_triplets: variable returned from psg_triplet choices
% if_log: 1 to log (defaults to 0)
%
% for ncloser, ntrials, there is one row for every tent.  Rows correspond to rows of tents, which specify z,a,b,c
% ncloser: [ntriplets,6]: N(d(z,b)<d(z,c)), N(d(z,c)<d(z,a)), N(d(z,a)< d(z,b), N(d(a,b)<d(a,c)), N(d(b,c)<d(b,a)), N(d(c,a)<d(c,b))
% ntrials: [ntriplets,6]: total trials in above
%
%   See also: PSG_TENTLIKE_DEMO, PSG_TRIPLET_CHOICES, NCHOOSEK2SEQ_3VR.
%
if (nargin<=4)
    if_log=0;
end
nt=3; %number of points in a triangle
%
ntriplets_exclude=nchoosek(nstims-1,nt); %number of triplets that exclude a given stimulus
ntents=nstims*ntriplets_exclude;
tents=zeros(ntents,nt+1);
%set up table of all possible tents: z,a,b,c, where a,b,c are distinct from z, and a<b<c
for istim=1:nstims
    tents([1:ntriplets_exclude]+(istim-1)*ntriplets_exclude,:)=[repmat(istim,ntriplets_exclude,1) nchoosek(setdiff([1:nstims],istim),nt)];
end
ncloser=zeros(ntents,nt*2); 
ntrials=zeros(ntents,nt*2);
%
% for ncloser, ntrials, there is one row for every tent.  Rows correspond to rows of tents, which specify z,a,b,c
% ncloser: [ntriplets,6]: N(d(z,b)<d(z,c)), N(d(z,c)<d(z,a)), N(d(z,a)< d(z,b), N(d(a,b)<d(a,c)), N(d(b,c)<d(b,a)), N(d(c,a)<d(c,b))
% ntrials: [ntriplets,6]: total trials in above
%
% last 3 columns of ncloser, ntrials are from triplets
%
triplet_rows=nchoosek2seq_3vr(tents(:,1+[1:nt]),nstims); %find rows in triplet table that match cols 2-4 
ncloser(:,nt+[1:nt])=ncloser_triplets(triplet_rows,:);
ntrials(:,nt+[1:nt])=ntrials_triplets(triplet_rows,:);
%
% first 3 columns of nclose, ntrials are the tripod
%note that col 1 and subsequent cols of tent are not necessarily in ascending order
%so we can't simply extract from the triplet table!!!!!
%
% a, b, and c are always i norder a<b<c in triplet table and tent table
%this loop takes care of odd permutation if z is in middle of the selected pair of a,b,c
%then we adjust second column of tent table (N(d(z,c)<d(z,a)) because a is always > c
for it=1:nt %it=1 for a, 2 for b, 3 for c
    tcol=[1 1+setdiff([1:nt],it)]; %[1 3 4], [1 2 4], or [1 2 3]
    tent_toks=tents(:,tcol);
    z_lo=find(tent_toks(:,1)<tent_toks(:,2));
    z_mi=find(tent_toks(:,1)>tent_toks(:,2) & tent_toks(:,1)<tent_toks(:,3));
    z_hi=find(tent_toks(:,1)>tent_toks(:,3));
    if if_log
        disp(sprintf(' tcol length(lo,mi,hi): %2.0f %2.0f %2.0f   %8.0f %8.0f %8.0f tot %10.0f',...
            tcol,length(z_lo),length(z_mi),length(z_hi),length(union(union(z_lo,z_mi),z_hi))));
    end
    %z_lo: triad already has z first, i.e., z, tcol(2), tcol(3), so we need
    %first column of triplet table, which is r(z;tcol(2),tcol(3))
    tentz_lo_rows=nchoosek2seq_3vr(tent_toks(z_lo,:),nstims);
    ncloser(z_lo,it)=ncloser_triplets(tentz_lo_rows,1);
    ntrials(z_lo,it)=ntrials_triplets(tentz_lo_rows,1);
    %z_mi: triad has z in the middle, i.e., tcol(2), z, tcol(3), so we need
    %second column of triplet table, which is r(z;tcol(3),tcol(2)), we t invert the choices since the order is an odd permutation in triplets
    tentz_mi_rows=nchoosek2seq_3vr(tent_toks(z_mi,[2 1 3]),nstims);
    ncloser(z_mi,it)=ntrials_triplets(tentz_mi_rows,2)-ncloser_triplets(tentz_mi_rows,2);
    ntrials(z_mi,it)=ntrials_triplets(tentz_mi_rows,2);
    %z_hi: triad has z lset, i.e., tcol(2), tcol(3), z so we need
    %third column of triplet table, which is r(z; tcol(2), tcol(3))
    tentz_hi_rows=nchoosek2seq_3vr(tent_toks(z_hi,[2 3 1]),nstims);
    ncloser(z_hi,it)=ncloser_triplets(tentz_hi_rows,3);
    ntrials(z_hi,it)=ntrials_triplets(tentz_hi_rows,3);
end
ncloser(:,2)=ntrials(:,2)-ncloser(:,2); %invert choices since second column of tents is N(d(z,c)<d(z,a)) and a>c
return
end

