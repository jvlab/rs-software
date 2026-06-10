function ichars=zpad(ival,ndigits)
%ichars=zpad(ival,ndigits) left-pads a non-negative integer with zeros and creates a string
%
% Args:
%   ival (int): non-negative integer to pad, should be <=10<sup>ndigits</sup>
%
%   ndigits (int): total number of digits for the string
%
% Returns:
%   ichars (char): the left-padded string 
%
% Note: Out-of-range values
%   No checking is done if ival <0 or >=10<sup>ndigits</sup>.
%
%   ival<0 will return an empty string.
%
%   ival>10<sup>ndigits</sup> will be return only the right-most ndigits characters.
%
ich=strcat(repmat('0',1,ndigits-1),sprintf('%d',ival));
ichars=ich([(length(ich)-ndigits+1):length(ich)]);
return
