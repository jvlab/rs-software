function [sa_sym,syms_applied,opts_used]=psg_btcmeta_symapply(sa,sym_apply,opts,btc_dict)
%[sa_sym,syms_applied,opts_used]=sa_sym=psg_btcmeta_symapply(sa,sym_apply,opts,btc_dict) applies symmetry operations to a btc metadata structure
% 
% sa: btc metadata structure, typicall returned by psg_read_coorddata
% sym_apply: which symmetries to apply, one opts.sym_type_avail returned by btc_soidfg_define
% opts: (can be omitted)
%   if_log=1 to log
%   other fields for typenames generation
%   decdig: 3, decimal digits in corr val in stimulus file name 3: cval=1->1000 
%   sign_chars: {'m','z','p'}, prefix characters for negative, zero, and positive cvals
%   base: '', start of stimulus file name
%   rand: 'rand', name for random stimulus
% btc_dict: optional, output of btc_define
%
% sa_sym: cell array, sa_sym{1}=sa, other sa_sym{k} are results of applying a symmetry to sa
% syms_applied: syms_applied{k}=the btc coordinates resulting from the application of the kth symmetry to 'gbcdetuvwa'
% opts_used: options used
%
%  See also:  BTC_DEFINE, PSG_READ_COORDDATA, PSG_SPOKES_SETUP, BTC_SOIDFG_DEFINE, BTC_SOIDFG_MODEL, BTC_SYMS,
%    PSG_SPEC2FILENAME, BTC_AUGCOORDS.
% 
if (nargin<=2)
    opts=struct;
end
opts=filldefault(opts,'if_log',0);
opts=filldefault(opts,'decdig',3); %decimal digits in corr val in stimulus file name 3: cval=1->1000 
opts=filldefault(opts,'sign_chars',{'m','z','p'}); %prefix characters for negative, zero, and positive cvals
opts=filldefault(opts,'base',''); %start of stimulus file name
opts=filldefault(opts,'rand','rand'); %name for random stimulus
%
if (nargin<=3)
    btc_dict=btc_define();
end
opts_used=opts;
codel=btc_dict.codel;
nbtc=length(codel);
syms_all=psg_btcsyms(sym_apply,btc_dict);
opts_used.syms_all=syms_all;
%
aug_opts=struct;
aug_opts.ifstd=1;
aug_opts.nocheck=1;
%
%find the axes that are specified in sa
%
spec_used_ptrs=find(any(~isnan(sa.btc_specoords),1));
nz_ptrs=find(any(sa.btc_augcoords~=0,1));
btc_used_ptrs=intersect(spec_used_ptrs,nz_ptrs);
btc_used=codel(btc_used_ptrs);
syms_used=cell(1,length(syms_all));
for isym=1:length(syms_all)
    syms_used{isym}=syms_all{isym}(btc_used_ptrs);
end
syms_applied=unique(syms_used);
if opts.if_log
    disp(sprintf(' symmetry type %s leads to %2.0f symmetries; %2.0f relevant to coords %s',sym_apply,length(syms_all),length(syms_applied),btc_used));
end
%
%apply the symmetries
%
for isym=1:length(syms_applied)
    sa_sym{isym}=sa;
    spec_labels=cell(sa.nstims,1);
    btc_specoords_new=NaN(sa.nstims,nbtc);
    for istim=1:sa.nstims
        if ~strcmp(sa.spec_labels{istim},'random') %the random stimulus does not get permuted
            %first create a temporary structure so that the new structure with symmetry applied
            %will have the fields in the same order -- this is ncecessary so that typenames is properly generated
            %in parallel create btc_specoords_new then create btc_augcoords from it
            spec_temp=struct; 
            for ilet=1:nbtc
                inperm=find(btc_used==codel(ilet));
                if inperm>0
                    newlet=syms_applied{isym}(inperm);
                    ilet_new=find(codel==newlet);
                    btc_specoords_new(istim,ilet_new)=sa.btc_specoords(istim,ilet);
                else %unpermuted
                    newlet=codel(ilet);
                end
                if isfield(sa.specs{istim},codel(ilet))
                    cval=sa.specs{istim}.(codel(ilet)); %set up the new spec
                    spec_temp.(newlet)=cval; %set up the new spec
                end
            end
            %now set up specs and spec_labels, with components in the order of codel
            sa_sym{isym}.specs{istim}=struct;
            for ilet=1:nbtc
                 if isfield(spec_temp,codel(ilet))
                    cval=spec_temp.(codel(ilet));
                    sa_sym{isym}.specs{istim}.(codel(ilet))=cval;
                    spec_labels{istim}=cat(2,spec_labels{istim},sprintf('%s=%5.2f ',codel(ilet),cval));
                end
            end
            spec_labels{istim}=deblank(spec_labels{istim});
            %create augmented coords from specs, after permutation
            augcoords=btc_augcoords(sa_sym{isym}.specs{istim},btc_dict,aug_opts);
            sa_sym{isym}.btc_augcoords(istim,:)=augcoords.method{1}.vec;
        else %random
            sa_sym{isym}.specs{istim}=sa.specs{istim};
            spec_labels{istim}=sa.spec_labels{istim};
        end
        sa_sym{isym}.typenames{istim}=psg_spec2filename(sa_sym{isym}.specs{istim},opts);
    end %istim
    sa_sym{isym}.spec_labels=spec_labels;
    sa_sym{isym}.btc_specoords=btc_specoords_new;
    %
end
return
