function chains=pairs2chains(pairs)
% chains=pairs2chains(pairs) converts pairs of tokens to chains of tokens
%
% For example, the pairs [a b;c d;a e;a f;c f] are converted to the chains  {[a b],[e a f],[d c f]}.
% The pairs are un-ordered, and must be unique. This is useful for graphics: rather than connect multiple pairs of points with each pair connected as separate line objects,
% one can instead connect them with a smaller number of line objects, one for each chain.
%
% This likely could be optimized; here the algorithm is just to extend chains until there is no unused node.
% There is no attmept to merge chains, e.g., by splicing together intersecting loops.
% 
% Args:
%   pairs (int 2-D array): a 2-column array of the pairs; each token is a unique integer
%
% Returns:
%   chains (cell array): a cell array of vectors of chains; paired tokens are adjacent in exactly one chain
% 
chains=cell(0);
loop_list=[];
%
npairs=size(pairs,1);
tmax=max(pairs(:));
tmin=min(pairs(:));
pairs=pairs-tmin+1;
mtx=zeros(tmax-tmin+1);
%create an incidence matrix
for ip=1:npairs
    mtx(pairs(ip,1),pairs(ip,2))=1;
end
mtx=mtx+mtx';
npairs_used=0;
%choose any unused node and attempt to grow it until the chain returns toitself, or has no choice
while any(sum(mtx,1)>0) %any pairs remaining?
    k=min(find(sum(mtx,1)>0));
    knbrs=find(mtx(k,:)>0); %determine the neigbhbors of k
    nnbrs=length(knbrs);
    if nnbrs==1
        kset=[k knbrs(1)];
    else
        kset=[knbrs(2) k knbrs(1)];
    end
    if_extend=1;
    while if_extend==1 %attempt to extend forward
        ke=kset(end);
        %find k_used: the points of kset that have already been connected with ke
        e_pos=find(kset==ke);
        v_fwd=kset(e_pos(e_pos<length(kset))+1);
        v_rev=kset(e_pos(e_pos>1)-1);
        v_used=union(v_fwd,v_rev);
        kex=setdiff(find(mtx(kset(end),:)>0),v_used); %extend into a new element?
        if isempty(kex)
            if_extend=0;
        else
            kset=[kset,kex(1)];
        end
    end
    if_loop=0;
    if nnbrs>=2
        if mtx(kset(end),kset(1))>0 %found a loop
            if_loop=1;
        else
            if_extend=1;
            while if_extend==1 %attempt to extend backward
                ke=kset(1);
                e_pos=find(kset==ke);
                v_fwd=kset(e_pos(e_pos<length(kset))+1);
                v_rev=kset(e_pos(e_pos>1)-1);
                v_used=union(v_fwd,v_rev);
                kex=setdiff(find(mtx(kset(1),:)>0),v_used); %extend backward?
                if isempty(kex)
                    if_extend=0;
                else
                    kset=[kex(1),kset];
                end
            end
            if mtx(kset(end),kset(1))>0
                if_loop=1;
            else
                if_loop=-1;
            end
        end
    else
        if_loop=-1; %done but no loop
    end
    nk=length(kset);
    chain=kset;
    if if_loop==1
        chain(end+1)=chain(1);
    end
    chains{end+1}=chain+tmin-1; %add offset
    lc=length(chain);
    for icl=1:lc-1
        mtx(chain(icl),chain(icl+1))=0;
        mtx(chain(icl+1),chain(icl))=0;
    end
end
return
end

