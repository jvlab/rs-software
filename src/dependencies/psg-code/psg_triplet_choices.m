function [ncloser,ntrials,abc_list]=psg_triplet_choices(nstims,data)
% [ncloser,ntrials,abc_list]=psg_triplet_choices(nstims,data) extracts choice probabilitie
%from a data structure read by psg_read_choicedata
%
% nstims: number of distinct stimuli
% data: array with each row consisting of [ref c1 c2 N(d(ref,c1)<d(ref,c2)) Ntot]
%
% ncloser: 3-col array in which each row corresponds to a triplet (a<b<c, in order of nchoosek(nstims,3))
%   and the three columns correspond to  N(d(a,b)<d(a,c)), N(d(b,c)<d(b,a)), N(d(c,a)<d(c,b))
% ntrials: 3-col array of same shape as ncloser, but entries correspond to total number of trials
% abc_list: list of triplets
%
%  See also:  PSG_READ_CHOICEDATA, PSG_TENTLIKE_DEMO, PSG_UMI_TRIPLIKE_DEMO.
%
col_closer=4;
col_trials=5;
ntriads_found=size(data,1);
%
ncloser=zeros(nchoosek(nstims,3),3);
ntrials=zeros(nchoosek(nstims,3),3);
abc_list=zeros(nchoosek(nstims,3),3);
%
%rearrange rank choice data into arrays with:
% triplets: columns 1, 2, 3; stimuli (a<b<c);
% ncloser: [ntriplets,3]: N(d(a,b)<d(a,c)), N(d(b,c)<d(b,a)), N(d(c,a)<d(c,b))
% ntotals: [ntriplets,3]: total trials in above
%
%populate ncloser(itrip,:)
%populate ntrials(itrip,:)
itrip=0;
for a=1:nstims-2
    for b=a+1:nstims-1
        for c=b+1:nstims
            itrip=itrip+1;
            for icyc=1:3
                switch icyc
                    case 1
                        vec=[a b c];
                    case 2
                        vec=[b c a];
                    case 3
                        vec=[c a b];
                end
                dmatch=find(all(data(:,1:3)==repmat(vec,ntriads_found,1),2));
                if ~isempty(dmatch)
                    ntrials(itrip,icyc)=data(dmatch,col_trials);
                    ncloser(itrip,icyc)=data(dmatch,col_closer);
                end
                dmatch_rev=find(all(data(:,1:3)==repmat(vec([1 3 2]),ntriads_found,1),2));
                if ~isempty(dmatch_rev)
                    ntrials(itrip,icyc)=data(dmatch_rev,col_trials);
                    ncloser(itrip,icyc)=data(dmatch_rev,col_trials)-data(dmatch_rev,col_closer);
                end
            end
            abc_list(itrip,:)=[a b c];
        end
    end
end
return
