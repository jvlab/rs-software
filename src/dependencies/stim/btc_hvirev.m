function hvicodes=btc_hvirev(codes,dict)
% hvicodes=btc_hvirev(codes,dict) finds the axis corresponding to
% horizontal/vertical interchange of a code letter (NE to SW). The new string
% may no longer be in the standard order, but this can be fixed by a call to BTC_EXPTNAME.
%
% b->c->b
% t->v->t
% others unchanged
%
% does this via a lookup table
%
% codes: a string of one or more unrotated coordinate letters
% dict: the dictionary of 2x2 coordinates, from btc_define (or, btc_define([] if not passed)
% hvicodes: a string of one or more rotated coordinate letters, may need char(hvicodes) to convert
%
%   See also:  BTC_PAIRSNEEDED, BTC_DEFINE, BTC_EXPTNAME, BTC_ROTCODE, BTC_SOID_PLOT3D, 
%    BTC_HFLIP, BTC_VFLIP.
%
%stdtable='gbcdetuvwa';
fliptable='gcbdevutwa';
if (nargin<=1) dict=btc_define([]); end
hvicodes='';
for icode=1:length(codes)
    codeno=find(codes(icode)==dict.codel);
    hvicodes(1,icode)=fliptable(1,codeno);
end
return
