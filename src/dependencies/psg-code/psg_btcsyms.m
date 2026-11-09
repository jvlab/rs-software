function syms=psg_btcsyms(sym_apply,btc_dict)
%syms=psg_btcsyms(sym_apply,btc_dict) gets a list of coordinate permutations corresponding 
%to mirror or rotational symmetries of the btc coordinates
%
% sym_apply: which symmetries to apply, one opts.sym_type_avail returned by btc_soidfg_define
% btc_dict: optional, output of btc_define
%
% if called with no inputs, returns the possible values for sym_apply
%
% syms: syms{k}=the btc coordinates resulting from the application of the kth symmetry to 'gbcdetuvwa'
%
%  See also:  BTC_DEFINE, BTC_SOIDFG_MODEL, PSG_BTCMETA_SYMAPPLY,
%    BTC_HFLIP, BTC_VFLIP, BTC_ROT90, BTC_ROT180, BTC_HVFLIP, BTC_HVI, BTC_HVIREV.
%
if (nargin==0)
    syms={'hflip','vflip','rot180','rot90','hvflip','diag','full','none'};
    return
end
if (nargin<=1)
    btc_dict=btc_define();
end
syms{1}=btc_dict.codel;
switch sym_apply
    case 'none'
    case {'hflip'}
        syms{2}=btc_hflip(btc_dict.codel,btc_dict);
    case {'vflip'}
        syms{2}=btc_vflip(btc_dict.codel,btc_dict);
    case {'rot180'}
        syms{2}=btc_rotcode(btc_dict.codel,2,btc_dict);
    case 'rot90'
        for irot=1:3
            syms{1+irot}=btc_rotcode(btc_dict.codel,irot,btc_dict);
        end
    case {'hvflip'}
        syms{2}=btc_hflip(btc_dict.codel,btc_dict);
        syms{3}=btc_vflip(btc_dict.codel,btc_dict);
        syms{4}=btc_rotcode(btc_dict.codel,2,btc_dict);
    case {'diag','full'}
        syms{2}=btc_hvi(btc_dict.codel,btc_dict);
        syms{3}=btc_hvirev(btc_dict.codel,btc_dict);
        syms{4}=btc_rotcode(btc_dict.codel,2,btc_dict);
        if strcmp(sym_apply,'full')
            for imod=1:4
                syms{4+imod}=btc_hflip(syms{imod},btc_dict);
            end
        end
    otherwise
        warning(sprintf('symmetry type %s not recognized',sym_apply))
end
