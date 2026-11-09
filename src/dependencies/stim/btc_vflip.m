function flipcodes=btc_vflip(codes,dict)
% flipcodes=btc_vflip(codes,dict) finds the axis corresponding to
% vertical flip of a code letter. The new string may no longer be in the standard order,
% but this can be fixed by a call to BTC_EXPTNAME. (March 2, 2018: documentation typo fixed)
%
% d->e->d
% t->u->t
% v->w->v
% others unchanged
%
% does this via a lookup table
%
% codes: a string of one or more unrotated coordinate letters
% dict: the dictionary of 2x2 coordinates, from btc_define (or, btc_define([] if not passed)
% flipcodes: a string of one or more rotated coordinate letters, may need char(flipcodes) to convert
%
%   See also:  BTC_DEFINE, BTC_EXPTNAME, BTC_ROTCODE,  BTC_HVI, BTC_HFLIP.
%
%stdtable='gbcdetuvwa';
fliptable='gbcedutwva';
if (nargin<=1) dict=btc_define([]); end
flipcodes='';
for icode=1:length(codes)
    codeno=find(codes(icode)==dict.codel);
    flipcodes(1,icode)=fliptable(1,codeno);
end
return
