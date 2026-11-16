function z=nchoosek2seq_3vr(a,amax)
% z=nchoosek2seq_3vr(a,amax) maps an increasing sequence of 3 natural numbers a into an integer, using lexicographical ordering 
% with rightmost value of a increasing first
%
%  z=1,2,3 corresponds to a=[1 2 3],[1 2 4],[1 2 5],..., [1 2 amax],[1 3 4],[1 3 5]
% contrast with nchoosek2seq_3v, for which z=1,2,3 corresonds to a=[1 2 3],[1 2 4],[1 3 4],[2 3 4]; ...
%
% a: a sequence of increasing triplets of integers, or a row of such sequences
% amax: maximum possible value of a
% 
%   See also:  SEQ2NCHOOSEK, NCHOOSEK2SEQ_3V
acombs=nchoosek(amax,3);
z=acombs+1-nchoosek2seq_3v(amax+1-fliplr(a));
return
