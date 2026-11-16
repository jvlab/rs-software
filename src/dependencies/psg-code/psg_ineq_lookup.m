function [triad_ptr,if_flip]=psg_ineq_lookup(triad_list,triad)
% function [triad_ptr,if_flip]=psg_ineq_lookup(triad_list,triad) looks up a triad 
% in a table of triads, set up by psg_ineq_triads
%
% triad_list: array of [nc 3] containing a list of triadic comparisons
% triad: array of size [nt 3], integers
%
% triad_ptr: triad_ptr(k) is the row number of triad(k,:) in triad_list, or 0 if not found
% if_flip: if_flip(k) is
%   0 if triad is found in triad_list
%   1 if it is found with the second and third elements reversed
%
%   See also:  PSG_INEQ_LOGIC, PSG_INEQ_TRIADS, PSG_INEQ_LOGIC_TETRA.
%
nt=size(triad,1);
triad_ptr=zeros(nt,1);
if_flip=zeros(nt,1);
nc=size(triad_list,1);
%
for k=1:nt
    row_forward=find(all(repmat(triad(k,:),nc,1)==triad_list,2)==1);
    triad_rev=triad(k,[1 3 2]);
    row_reverse=find(all(repmat(triad_rev,nc,1)==triad_list,2)==1);
    if length(row_forward)==1 & length(row_reverse)==0
        if_flip(k)=0;
        triad_ptr(k)=row_forward;
    end
    if length(row_forward)==0 & length(row_reverse)==1
        if_flip(k)=1;
        triad_ptr(k)=row_reverse;
    end
end
return


