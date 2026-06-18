function [isgraph, msg, niters]=isgraphc(connect,if_fast)
% [isgraph,msg,niters]=isgraphc(connect,if_fast) determines whether a matrix is consistent with a connected graph
%
% This works for directed graphs, and can also be used to compute a graph's diameter.
%
% Args:
%   connect (int 2-D array): a square connectivity matrix: connect(i,j)=1 if there is a connection from node i to node j. For directed graphs, the matrix will not be symmetric.
%
%   if_fast (int): algorithm choice, default is 0
%
%     - 0: use sparse matrix methods rather than squaring; on return, niters+1 is the graph diameter
%     - 1: use successive squaring; on return, niters+1 is not necessarily the graph diameter
%
% Returns:
%   isgraph (int): 1 if graph is connected and symmetric, -1 if connected but directed, 0 if not connected or not a graph
%
%   msg (int): reason for isgraph~=1
%
%   niters (int): number of iterations used
%
% See also: PROCRUSTES_CONSENSUS.
%
isgraph=1;
msg=[];
niters=[];
if (nargin<=1)
    if_fast=0;
end
%
if (size(connect,1)~=size(connect,2))
   isgraph=0;
   msg='Connection matrix not square.';
   return
end
niters=0;
%sparsify
roads=sparse(connect);
if (nnz(roads-spones(roads))>0)
   isgraph=0;
   msg='Connection matrix not just 0''s and 1''s.';
   return
end
if (nnz(roads)==0)
   isgraph=0;
   msg='Connection matrix is null.';
   return
end
%check for connectedness
switch if_fast
    case 0
        fromhere=spones(roads+eye(size(connect,1)));
        nextstep=spones(fromhere*roads);
        while (nnz(fromhere-nextstep)>0)
            fromhere=nextstep;
            nextstep=spones(nextstep+nextstep*roads);
            niters=niters+1;
        end
    case 1
        fromhere=double(roads+eye(size(connect,1))>0);
        u=double(fromhere*fromhere>0);
        while (nnz(fromhere-u)>0)
            fromhere=u;
            u=double(u*u>0);
            niters=niters+1;
        end
end
%
if any(fromhere(:)==0)
   isgraph=0;
   msg='Connection matrix is disconnected.';
   return
end
%check for symmetry
if (nnz(roads-roads')~=0)
   isgraph=-1;
   msg='Connection matrix is not symmetric.';
   return
end
return
