function [isgraph, msg, niters]=isgraphc(connect,if_fast)
%
% [isgraph,msg,niters]=isgraphc(connect,if_fast) determines whether a matrix
% connect is consistent with a (possibly directed) connected graph
%
% connect: a matrix of 0's and 1's.  connect(i,j)=1 if there is a connection from i to j
% if_fast:  do not use sparse matrix methods, and use squaring rather than
%     successive multiplication -- so niters+1 is not the graph diameter
% isgraph: 1 if connect is a symmetric graph
%         -1 if not symmetric but otherwise OK
%          0 if not consistent with a  graph
% msg: reason for isgraph~=1
% niters: number of iterations to stability (if if_fast=0)
%   if if_fast=0, for a connected graph, niters+1 is diameter
%
%  2Jul2019: fixed a bug that could result in endless loops, added niters, added if_fast
%
%   See also:  ISCONNECTED, PROCRUSTES_CONSENSUS.
%
isgraph=1;
msg=[];
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
