function [s_noz,change_list,opts_used]=psg_btcremz(s,opts,btc_dict)
% function [s_noz,change_list,opts_used]=psg_btcremz(s,opts,btc_dict) removes coordinates that are near zero from spec_labels and typenames
%  provided that they do not change the augmented coordinates substantially
%
% This enables better knitting across datasets so that a btc vector with a coordinate that has a specified value of zero 
% will match a btc vector in which that coordinate is unassigned, and thus improve alignments in psg_align_coordsets.
% Uses btc_augcoords to determine whether resulting coords are identical.
%
% Does not influence psg_findrays, since psg_findrays sets any unspecified coordinate (NaN) to zero.
%
% s: metadata structure, typically from psg_get_coordsets, with fields specs, spec_labels and typenames
% opts: options
%   opts.use_btc_augcoords: 1 (default) to use btc_augcoords to check that setting to zero is the same as not specifying
%     (otherwise, always removes a zero coord)
%   opts.tol_spec: tolerance for a specified coordinate to be zero, defaults to 10^-4
%   opts.tol_aug: tolerance for an augmented coordinte to be zero, defaults to 10^-2
%  other fields for typenames generation
%   decdig: 3, decimal digits in corr val in stimulus file name 3: cval=1->1000 
%   sign_chars: {'m','z','p'}, prefix characters for negative, zero, and positive cvals
%   base: '', start of stimulus file name
%   rand: 'rand', name for random stimulus
% btc_dict: optional, output of btc_define
%
% s_noz: metadata structure with specs, spec_labels, typenames, btc_specoords, btc_augcoords, in which values assigned to zero are removed
%    e.g., spec_labels: {'b=-0.00 c=-0.40'}  becomes {c=-0.40'}
%            typenames: {'bm0000cm0400'} becomes {'cm0400'}
% change_list: indices of changed entris in s.spec_labels, s.typenames
% opts_used: options used
% 
% See also: PSG_ALIGN_COORDSETS, PSG_READ_COORDDATA, PSG_ALIGN_KNIT_DEMO, BTC_AUGCOORDS, BTC_DEFINE, BTC_META_SYMAPPLY,
%    PSG_SPEC2FILENAME, BTC_DEFINE, BTC_VECNAN2LETCODE.
% 
if (nargin<=1)
    opts=struct;   
end
opts=filldefault(opts,'use_btc_augcoords',1);
opts=filldefault(opts,'tol_spec',10^-4);
opts=filldefault(opts,'tol_aug',10^-2);
opts=filldefault(opts,'decdig',3); %decimal digits in corr val in stimulus file name 3: cval=1->1000 
opts=filldefault(opts,'sign_chars',{'m','z','p'}); %prefix characters for negative, zero, and positive cvals
opts=filldefault(opts,'base',''); %start of stimulus file name
opts=filldefault(opts,'rand','rand'); %name for random stimulus
opts_used=opts;
%
%
if (nargin<=2)
    btc_dict=btc_define();
end
codel=btc_dict.codel;
nbtc=length(codel);
%
aug_opts=struct;
aug_opts.ifstd=1;
aug_opts.nocheck=1;
change_list=[];
s_noz=s;
%
for istim=1:length(s.spec_labels)
    vec=s.btc_specoords(istim,:);
    if any(abs(vec)<opts.tol_spec)
        coords_zero=find(abs(vec)<opts.tol_spec);
        coords_nz=find(abs(vec)>opts.tol_spec);
        augcoords_orig=s.btc_augcoords(istim,:); %original augmented coords
        %
        %create a specification in which zero-values in btc_specoords are set to NaN
        vec_new=vec;
        vec_new(coords_zero)=NaN; %set all zero-valued coords to NaN (unspecified)for any 
        augcoords=btc_augcoords(btc_vecnan2letcode(vec_new),btc_dict,aug_opts);
        augcoords_new=augcoords.method{1}.vec; %augmented spec with zero-values replaced by NaN
        if all(abs(augcoords_new-augcoords_orig)<opts.tol_aug)
            change_list=[change_list,istim];
            s_noz.specs{istim}=btc_vecnan2letcode(vec_new);
            s_noz.btc_specoords(istim,:)=vec_new;
            s_noz.btc_augcoords(istim,:)=augcoords_new;
            if all(isnan(vec_new))
                s_noz.spec_labels{istim}='random';
            else
                s_noz.spec_labels{istim}='';
                for ilet=1:nbtc
                    if isfield(s_noz.specs{istim},codel(ilet))
                        cval=s_noz.specs{istim}.(codel(ilet));
                        s_noz.spec_labels{istim}=cat(2,s_noz.spec_labels{istim},sprintf('%s=%5.2f ',codel(ilet),cval));
                    end
                end
                s_noz.spec_labels{istim}=deblank(s_noz.spec_labels{istim});
            end
            s_noz.typenames{istim}=psg_spec2filename(s_noz.specs{istim},opts);
        end
    end
end
return
