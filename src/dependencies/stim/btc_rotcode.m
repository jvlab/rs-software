function rotcodes=btc_rotcode(codes,nrots,dict)
% rotcodes=btc_rotcode(codes,nrots,dict) finds the axis corresponding to 
% nrots 90-deg rotations of a code letter. The rotated string
% may no longer be in the standard order, but this can be fixed by a call to
% BTC_EXPTNAME.
%
% g unchanged
% b->c->b
% d->e->d
% t-u->v->w->t
% a unchanged
%
% but does this via the data in dict
%
% codes: a string of one or more unrotated coordinate letters
% nrots: number of rotations (defaults to 1)
% dict: the dictionary of 2x2 coordinates, from btc_define (or, btc_define([] if not passed)
% rotcodes: a string of one or more rotated coordinate letters
%   13Nov11: added char() at final step
%
%   See also:  BTC_PAIRSNEEDED, BTC_DEFINE, BTC_EXPTNAME, BTC_HVI, BTC_SOID_PLOT3D.
%
if (nargin<=2) dict=btc_define([]); end
if (nargin<=1) nrots=1; end
rotcodes=[];
for icode=1:length(codes)
    code=codes(icode);
    codeno=find(code==dict.codel);
    name_order_aug=dict.name_order_aug{codeno};
    avail=strmatch(name_order_aug,dict.name_order_aug,'exact');
    newno=min(avail)+mod(codeno-min(avail)+nrots,max(avail)-min(avail)+1);
    rotcodes(1,icode)=dict.codel(newno);
end
rotcodes=char(rotcodes);
return
