function [a,opts_used]=multi_shuff_enum(counts,opts)
% [a,opts_used]=multi_shuff_enum(counts,opts) enumnerates all the ways of ordering counts(1) 1's, counts(2) 2's, etc.
% 
% The algorithm is recursive.
%
% Args: 
%   counts (int 1-D array): how many 1's, 2's, 3's, etc.  Only non-negative integer entries
%
%   opts (struct): structure, may be omitted, with fields
%
%      - if_log (int): 1 to log; default is 0
%      - level (int): tracks recursion level; default is 0
%      - if_reduce: 1 to reduce by symmetry if any of counts are identical; 0 to omit; default is 0
%
% Returns:
%   a (int 2-D array): a list of the shuffles, each row contains counts(1) 1's, counts(2) 2's, etc
%
%   opts_used (struct): options used
% 
% Note: Multiplicities
%   The number of rows in a, dim(a,1) is sum(counts)!/prod(counts(k)!)/r, a multinomial coefficient
%   possibly divided by r, if if_reduce=1, where r is a product of the factorials of the multiplicities of the counts.
%   For example, with counts=[2 3 3 2 2 2], there are 4 tokens that appear twice (1,4,5, and 6), and 2 tokens that appear three times (2 and 3), so r=4!*2!
%
%   counts=[2 3 3 2 2 2];
%
%   tic;[q,ou]=multi_shuff_enum(counts,setfields(struct(),{'if_log','if_reduce'},{0 1}));toc
%
%   Elapsed time is 4.552206 seconds.
%
%   disp(size(q))
%
%   3153150 14
%
%   disp(factorial(sum(counts))/prod(factorial(counts))/24/2)
%
%   3153150
%
%   disp(q([1:500000:size(q,1)],:))
%
%   1     1     2     2     2     3     3     3     4     4     5     5     6     6
%
%   2     1     2     4     3     5     1     3     2     5     6     3     4     6
%
%   2     2     3     1     4     5     3     4     3     6     1     5     6     2
%
%   1     4     2     3     1     4     2     5     6     2     3     6     3     5
%
%   2     1     4     2     4     5     2     6     5     3     3     6     1     3
%
%   1     4     5     2     3     3     6     4     2     2     6     1     3     5
%
%   1     4     5     2     6     2     1     5     4     3     3     6     2     3
% 
%  See also:  NCHOOSEK.
%
if nargin<2
    opts=struct;
end
opts=filldefault(opts,'if_log',0);
opts=filldefault(opts,'level',0);
opts=filldefault(opts,'if_reduce',0);
opts_used=opts;
if (opts.if_log)
    disp(sprintf('entering multi_shuff_enum: level %1.0f, counts: %s',opts.level,sprintf('%2.0f ',counts)));
end
if sum(counts>0)==1
    a=repmat(find(counts>0),1,sum(counts));
else
    c=counts;
    lc=length(c);
    nck=nchoosek([1:sum(c)],sum(c(1:end-1)));
    a=repmat(lc,size(nck,1),sum(c));
    for r=1:size(nck,1)
        a(r,nck(r,:))=lc-1;
    end
    %do a recursion if length(c)>=3:
    if (lc>=3)
        b=multi_shuff_enum(counts(1:end-1),setfield(opts,'level',opts.level+1));
        %duplicate each row of a by the number of rows in b
        %replace every occurrence of lc-1 in this, by elements in b
 %      ar=reprow(a,size(b,1))'; %working in transpose so that (:) goes along rows of original a
        ar=(reshape(repmat(reshape(a,prod(size(a)),1),1,size(b,1))',size(a).*[size(b,1) 1]))';
        rows=size(ar,2); %transpose
        br=(repmat(b,size(a,1),1))';
        ar(ar==(lc-1))=br(:);
        a=reshape(ar,[sum(c) rows])'; %transpose back
    end    
end
matches=find(counts(1:end-1)==counts(end));
if ~isempty(matches) & opts.if_reduce
    if (opts.if_log)
        disp(sprintf(' matches: %s',sprintf('%2.0f',matches)));
        disp('reducing');
        disp(sprintf('size(a): %10.0f %2.0f, values: %1.0f to %1.0f',size(a),min(a(:)),max(a(:))));
    end
    %keep all rows in which the first occurrence of counts(end) is
    %after the first occurrence of all of counts(matches)
    fend=max(double(a==lc).*repmat(fliplr([1:size(a,2)]),size(a,1),1),[],2);
    for k=1:length(matches)
        fk=max(double(a==matches(k)).*repmat(fliplr([1:size(a,2)]),size(a,1),1),[],2);
        a_keep=find(fk(:)>fend(:));
        a=a(a_keep,:);
        fend=fend(a_keep);
      end
end
if (opts.if_log)
    disp(sprintf('size(a): %10.0f %2.0f, values: %1.0f to %1.0f',size(a),min(a(:)),max(a(:))));
    disp(sprintf(' leaving multi_shuff_enum: level %1.0f, counts: %s',opts.level,sprintf('%2.0f ',counts)));
end
return

