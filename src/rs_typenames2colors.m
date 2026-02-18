function [rgb,symb,cvecs,aux_out]=rs_typenames2colors(typenames,aux)
% [rgb,symb,cvecs,aux_out]=rs_typenames2colors(typenames,aux) is a utility that assigns a plotting color and
% plotting symbol to a list of stimuli. The coordinates are extracted from the strings in typenames yielding
% cvecs (see below). rgb indicates the axis, and symb indicates the sign
%
% typenames: a string, or cell array of strings, typically from data.sas{:}.typenames
% aux.opts_tn2c: 
%   paradigm_type: paradigm type, typically from data.sets{:}.paradigm_type, if omited, defaults to 'unknown'
%   paradigms_reserved: paradigm types that are passed through to psg_typenames2colors:
%     defaults to 'btc','mpi_faces','mater','irgb'
%   coord_lets: coordinate letters.  Defaults to 'abcdefghij'. Avoid including m, p, z.
%     Overriding this will remove the default colors, which are assigned to [a-j].
%   color: a structure, fields labeled by coord_lets, each containing an r,g,b triple
%     Default values are given below in colors_def.
%   colors_nomatch: rgb triplet if no color has been assigned to a coordinate, defaults to [0 0 0];
%   if_color_arith: 1 (default) to enable averaging of colors
%   symbs_nomatch: plotting symbol to be assigned if no coords can be found, defaults to .
%   symbs.[z,p,m,pm,mp]: plotting symbol to be assigned, defaults in symbs_def below, if coords are:
%      z: all zeros
%      p: at least one positive value, no negatives
%      m: at least one negative value, no positives
%      pm: mixed values, positive occurs before negatives (by rows in cvecs)
%      mp: mixed values, negative occurs before poistives (by rows in cvecs)
%
%  rgb: an rgb color triplet
%  symb: a plotting symbol
%  cvecs: array of size [length(typenames) length(coord_lets)]
%    indicating the coordinates as decoded from the typename (NaN if coordinate not found)
%
%  Typenames should be a cell array of strings, each of which contains one or more segments of a letter that designates
%  a coordinate axis, typically [a-j] nless modified by opts_tn2c.coord_lets, followed by a numeric quantity.
%  The numeric quantity consists either of string of digits (assumed to represent a positive quantity),
%  or a string of digits preceded by p or m (to represent a positive or negative quantity), or z (followed by any numbers), indicating zero.
%     Decimal points, +, and -  can be used, and the sign is multiplied by the sign designated by a preceding 'p' or 'm'
%       e.g.:
%     'bp4 hm36' indicates +4 on the b axis, -36 on the h axis
%     'z' indicates the origin, i.e., 0 on all coordinate axes
%     'cm52' indicates -52 on the c axis
%     'j17dm3' indicates 17 on the j axis, -3 on the c axis
%     'hm1.4' and 'hm-1.4' indicate -1.4 on the h-axis but 'hm-1.4' indicates +1.4 on the h axis
%
% Color assignment details: If ony one axis is present among typenames, then its color is used.  If more than one axis is present
%   anong the typenames, and color values are given as rgb triples, and if_color_arith=1, then colors are weighted by the magnitudes.
%   Otherwise the largest color's rgb value will be used, ties broken by order of axes
%  
if (nargin<=1)
    aux=struct;
end
%
%set up sub-structure options
aux=filldefault(aux,'opts_tn2c',struct); %options for this module (psg_template)
%
aux.opts_tn2c=filldefault(aux.opts_tn2c,'paradigms_reserved',{'btc','mpi_faces','mater','irgb'});
aux.opts_tn2c=filldefault(aux.opts_tn2c,'paradigm_type','unknown');
aux.opts_tn2c=filldefault(aux.opts_tn2c,'colors',struct);
aux.opts_tn2c=filldefault(aux.opts_tn2c,'colors_nomatch',[0 0 0]);
aux.opts_tn2c=filldefault(aux.opts_tn2c,'coord_lets','abcdefghij');
aux.opts_tn2c=filldefault(aux.opts_tn2c,'if_color_arith',1);
aux.opts_tn2c=filldefault(aux.opts_tn2c,'symbs_nomatch','.');
aux.opts_tn2c=filldefault(aux.opts_tn2c,'symbs',struct);
%
aux=rs_aux_customize(aux,'rs_typenames2colors');
%
if ~iscell(typenames)
    typenames=cellstr(typenames);
end
%
%reserved paradigm type?
%
if length(strmatch(aux.opts_tn2c.paradigm_type,aux.opts_tn2c.paradigms_reserved,'exact'))>0
    [rgb,symb,cvecs,opts_used]=psg_typenames2colors(typenames,aux.opts_tn2c);
    fns=fieldnames(opts_used);
    for ifn=1:length(fns)
        fn=fns{ifn};
        if (length(strmatch('color',fn))>0 | length(strmatch('symb',fn))>0)
            aux.opts_tn2c.(fn)=opts_used.(fn);
        end
    end
    aux_out=aux;
    return
end
%
%set up colors; override defaults by any provided in aux.opts_tn2c.colors
%
colors_def.a=[1.00 0.00 0.00];
colors_def.b=[0.00 0.00 1.00];
colors_def.c=[0.00 1.00 0.00];
colors_def.d=[0.75 0.75 0.00];
colors_def.e=0.5*(colors_def.a+colors_def.b);
colors_def.f=0.5*(colors_def.b+colors_def.c);
colors_def.g=0.5*(colors_def.c+colors_def.d);
colors_def.h=0.5*(colors_def.d+colors_def.a);
colors_def.i=[0.75 0.75 0.75];
colors_def.j=[0.30 0.30 0.30];
%
nrgb=3;
%
color_regexp=cat(2,'[',aux.opts_tn2c.coord_lets,']');
for ic=1:length(aux.opts_tn2c.coord_lets)
    cl=aux.opts_tn2c.coord_lets(ic);
    if isfield(aux.opts_tn2c.colors,cl)
        colors.(cl)=aux.opts_tn2c.colors.(cl);
    elseif isfield(colors_def,cl)
        colors.(cl)=colors_def.(cl);
    end
end
aux.opts_tn2c.colors=colors;
%
%set up symbols; override defaults by any provided in aux.opts_tn2c.symbs
%
symbs_def=struct;
symbs_def.z='o';
symbs_def.m='*';
symbs_def.p='+';
symbs_def.pm='v'; %downward triangle
symbs_def.mp='^'; %upward triangle
%
symbs_fns=fieldnames(symbs_def);
for is=1:length(symbs_fns)
    fn=symbs_fns{is};
    aux.opts_tn2c.symbs=filldefault(aux.opts_tn2c.symbs,fn,symbs_def.(fn));
end
if isfield(aux.opts_tn2c.symbs,fn)
%
%go through each element in typenames, determine coordinates and signs
%
cvecs=NaN(length(typenames),length(aux.opts_tn2c.coord_lets));
for it=1:length(typenames)
    tn=typenames{it};
    toks=regexp(tn,color_regexp);
    if length(toks)>0
        toks_aug=[toks length(tn)+1];
        for itk=1:length(toks)
            tok=tn(toks_aug(itk):toks_aug(itk+1)-1);
            tok_coord=find(aux.opts_tn2c.coord_lets==tok(1));
            tok_val=tok(2:end);
            if length(tok_val)==0
                val=NaN;
            else
                switch tok_val(1)
                    case 'z'
                        val=0;
                    case 'm'
                        val=-str2num(tok_val(2:end));
                    case 'p'
                        val=str2num(tok_val(2:end));
                    otherwise
                        val=str2num(tok_val);
                end
                if isempty(val)
                    val=0;
                end
            end
            cvecs(it,tok_coord)=val;
        end
    end
end
%compute the r,g,b value
coords_found=find(any(~isnan(cvecs),1));
if length(coords_found)==0
    rgb=aux.opts_tn2c.colors_nomatch;
elseif length(coords_found)==1
    rgb=aux.opts_tn2c.colors.(aux.opts_tn2c.coord_lets(coords_found));
else %more than one axis is present
    can_average=1; %assume we can average, but verify
    if aux.opts_tn2c.if_color_arith==0
        can_average=0;
    else
        color_vals=zeros(length(coords_found),nrgb);
        for ic=1:length(coords_found)
            cf=aux.opts_tn2c.coord_lets(coords_found(ic));
            if ~isfield(aux.opts_tn2c.colors,cf)
                cv=aux.opts_tn2c.colors_nomatch;
            else
                cv=aux.opts_tn2c.colors.(cf);
            end
            if isnumeric(cv)
                if size(cv)==[1 nrgb]
                    color_vals(ic,:)=cv;
                else
                    can_average=0;
                end
            else
                can_average=0;
            end
        end
    end
    mean_abs=mean(abs(cvecs),1,'omitnan');
    if (can_average)
        rgb=mean_abs(coords_found)*color_vals/sum(mean_abs(coords_found));
    else
        large_color=min(find(mean_abs==max(mean_abs)));
        rgb=aux.opts_tn2c.colors.(aux.opts_tn2c.coord_lets(large_color));
    end
end
%
cvecs_trans=cvecs';
sign_seq=sign(cvecs_trans(~isnan(cvecs_trans(:)))); %sequence of signed values
if all(sign_seq==0)
    symb=aux.opts_tn2c.symbs.z;
else
    sign_seq=sign_seq(sign_seq~=0); %consider only nonzero values
    if all(sign_seq>0)
        symb=aux.opts_tn2c.symbs.p;
    elseif all(sign_seq<0)
        symb=aux.opts_tn2c.symbs.m;
    elseif min(find(sign_seq>0))<min(find(sign_seq<0))
        symb=aux.opts_tn2c.symbs.pm;
    elseif min(find(sign_seq>0))>min(find(sign_seq<0))
        symb=aux.opts_tn2c.symbs.mp;
    end
end
%make sure that at least some output is provided
if ~exist('rgb') rgb=aux.opts_tn2c.colors_nomatch; end
if isnumeric(rgb)
    rgb=min(max(rgb,0),1);
end
if ~exist('symb') symb=aux.opts_tn2c.symbs_nomatch; end
%
aux_out=aux;
return
end
