function z=nchoosek2seq_3v(a)
% z=nchoosek2seq_3v(a) maps an increasing sequence of 3 natural numbers a into an integer, using lexicographical ordering 
% starting from the highest value of a
%
%  This has the same function as nchosek2seq for the special case that a is a triplet -- and also,
%    it will work for a matrix a, in which case each row of a becomes an entry in the column vector v.
%
%  See opt_segment_notes.doc for details.
%
% a: a sequence of increasing triplets of integers, or a row of such sequences
% z: the lexicographical index, or a column vector of indices
%
%  to test: create all the increasing sequences within [1:n] of length k=3, put them in lexicographic order, 
% clear; n=8;k=3;u=fliplr(sortrows(fliplr(nchoosek([1:n],k))));
% z=nchoosek2seq_3v(u);
% size(z)
% ans =
%     56     1
% unique(diff(z))
% ans =
%      1
% z(1)
% ans =
%     1
% 
%   See also:  SEQ2NCHOOSEK, NCHOOSEK2SEQ_2V, NCHOOSEK2SEQ, NCHOOSEK2SEQ_3VR.

z=a(:,1)+(a(:,2)-1).*(a(:,2)-2)/2+(a(:,3)-1).*(a(:,3)-2).*(a(:,3)-3)/6;
return
