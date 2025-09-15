function ichars=zpad(ival,ndigits)
%
%ichars=zpad(ival,ndigits) left-pads a non-negative integer with zeros
%
%ival: non-negative integer to pad
%ndigits: total number of digits to pad into
%
%no checking is done if ival >=10^ndigits or <0
%
ich=strcat(repmat('0',1,ndigits-1),sprintf('%d',ival));
ichars=ich([(length(ich)-ndigits+1):length(ich)]);