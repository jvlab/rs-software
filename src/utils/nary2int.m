function ints=nary2int(nary,d,lastdim)
% ints=nary2int(nary,d,lastdim) converts one or more vectors, considered as integers base d, to integers
%
% One value of ints is calculated for each element in the first ndims(nary)-1 dimensions of nary.
% The last dimension of nary is the base-d expansion, with the least significant bit in position 1.
%
% Args:
%    nary (int array): an array of n-ary numbers
%
%    d (int or int array): the base, 2 if omitted, d may be a vector; see note below regarding generalized n-ary conversion
%
%    lastdim: last dimension of nary; default is ndims(nary).  Required if, for example, size(nary)=[10 7] but this is thought of as [10 7 1]
%
% Returns:
%   ints (int or int array): the converted integers.
%
% Note: Generalized n-ary conversion
%   If d is a vector, then d(1) is used for the first place, d(2) for the second, etc. and d(end) used if d does not have sufficient length.
%
%   In this case, ints(k)=nary(k,1)+d(1)\*nary(k,2)+d(1)\*d(2)\*nary(k,3)+...
%
% See also:  INT2NARY.
%
if (nargin<=1) d=2; end
sn=size(nary);
if (nargin<=2) lastdim=length(sn); end
if (length(sn)<lastdim)
    sn([(length(sn)+1):lastdim])=1;
end
if (length(sn)>lastdim)
    error(sprintf(' attempt to convert n-ary array of dimension %4.0f to integer over non-last dimension %4.0f.',...
    length(sn),lastdim));
end
dprod=[1 d];
if (length(dprod)>sn(end))
    dprod=dprod(1:sn(end));
end
if (length(dprod)<sn(end))
    dprod=[dprod dprod(end)*ones(1,(sn(end)-length(dprod)))];
end
pwrs=cumprod(dprod);
snres=ones(1,lastdim);
snres(end)=sn(end); %[1 1 1 1... 1 sn(end)]
ints=sum(nary.*repmat(reshape(pwrs,snres),[sn([1:(end-1)]) 1]),lastdim);
%
return

