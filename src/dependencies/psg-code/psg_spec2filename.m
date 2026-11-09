function [typename,opts_used]=psg_spec2filename(btc_spec,opts_stn)
% [typename,opts_used]=psg_spec2filename(btc_spec,opts_stn) makes a file name (without stimulus example number)
% from a btc btc_spec structure
%
%  btc_spec: a structure of values of btc parameters
%  opts_stn: options, may be omitted
%      opts_stn.decdig: decimal digits in corr val in stimulus file name 3: cval=1->1000 
%      opts_stn.sign_chars: cell(1,3) prefix characters for negative, zero, and positive cvals
%      opts_stn.base:  start of stimulus file name
%      opts_stn.rand: %name for random stimulus
%
% typename: file name string
% opts_used: options used
%
%  12Oct25: allow filldefaults to act even if opts_stn is specified
%
% See also:  BTC_DEFINE, PSG_COND_CREATE, PSG_SPOKES_SETUP.
%
if nargin<2
    opts_stn=struct;
end
opts_stn=filldefault(opts_stn,'decdig',3); %decimal digits in corr val in stimulus file name 3: cval=1->1000 
opts_stn=filldefault(opts_stn,'sign_chars',{'m','z','p'}); %prefix characters for negative, zero, and positive cvals
opts_stn=filldefault(opts_stn,'base',''); %start of stimulus file name
opts_stn=filldefault(opts_stn,'rand','rand'); %name for random stimulus
%
opts_used=opts_stn;
params=fieldnames(btc_spec);
typename=[];
if length(params)==0
    typename=opts_stn.rand;
else
    for ip=1:length(params)
        param=params{ip};
        val=btc_spec.(param);
        schar=opts_stn.sign_chars{2+sign(val)}; %neg->sign_chars{1}, zero->sign_chars{2}, pos->sign_chars{3}
        typename=cat(2,typename,param,schar,zpad(round(10^opts_stn.decdig.*abs(val)),1+opts_stn.decdig));
    end
end
return
