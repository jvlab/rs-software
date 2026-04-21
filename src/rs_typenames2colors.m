function [rgb,symb,cvecs,aux_out]=rs_typenames2colors(typenames,aux)
% [rgb,symb,cvecs,aux_out]=rs_typenames2colors(typenames,aux) is a utility that assigns a display color and
% symbol to a set of stimulus labels. % Stimulus coordinates are extracted typenames, and mapped  a color as
% detailed below. Color is determined by the direction from the origin and the symbol is determined by the sign.
%
%
% Args:
%   typenames (char or cell array of char): one or more stimulus labels; see note below regarding parsing of typenames into coordinates
%
%   aux (struct): auxiliary input, may be omited, with field
%
%     - opts_tn2c (struct): options controlling mapping of coordinates to colors and symbols, with fields
%
%         - **Colors**
%         - coord_lets (char): letter tokens to be regarded as coordinates; default is 'abcdefghij'; avoid including m, p, z. This is ignored if the paradigm type is one of the reserved paradigms.
%         Specifying this parameter will remove the default color assignments and thus require specification of color assignments in opts_tn2c.colors
%         - colors (struct): custom color assignments for the coordinates
%         in coords_lets, consisting of a structure with fields labeled by
%         coord_lets, each containing an r,g,b triple or other valid color designator; defaults are:
%
%             - a: red [1 0 0]
%             - b: blue [0 0 1]
%             - c: green [0 1 0]
%             - d: yellow [1 1 0] * 0.75
%             - e: purple (red+blue)/2
%             - f: cyan (blue+green)/2
%             - g: lime (green+yellow)/2
%             - h: orange (yellow+red)/2
%             - i: light gray [1 1 1] * 0.75
%             - j: dark gray [1 1 1] * 0.3
%
%         - colors_nomatch (color specifier): color to be used if coordinates cannot be found; default is [0 0 0];
%         - if_color_arith (int): 1 to enable averaging of colors if typenames contains several strings, 0 to use color of point that is maximal distance from origin; default is 1
%
%         - **Symbols**
%         - symbs (struct): plotting symbol to be assigned based on signs of coordinates; defaults are:
%
%             - z: 'o', if all coordinates are zero
%             - m: '*', if at least one coordinate is negative and none are positive
%             - p: '+', if at least one coordinate is positive and none are negative
%             - pm: 'v' (downward triangle), if coordinates have mixed signs, with a positive occurring first
%             - mp: '^' (upward triangle), if coordinates have mixed signs, with a negative occurring first
%
%         - symbs_nomatch (char): symbol to be assigned if no coords can be found, default is '.'
%
%         - **Overall behavior**
%         - paradigm_type (char): paradigm type, typically from data.sets{:}.paradigm_type; default is 'unknown', which will result in colors and symbols assigned as described here.
%         - paradigms_reserved (cell array of char): paradigm types whose colors and symbols are assigned by 'psg_typenames2colors' defaults to {'btc','faces','mater','irgb'}; see note below regarding reserved paradigm types.
%
% Returns:
%   rgb (float 1-D array): the assigned rgb color triplet
%
%   symb (char): the plotting symbol
%
%   cvecs (float 2-D array): decoded coordinates, with each row corresponding to an element of typnames, and consisting of length(coord_lets) coordinate values, with NaN if coordinate is not found
%
% Note regarding parsing of typenames into coordinates:
%     - The typenames argument is a string, or a a cell array of strings; each of which is parsed into coordinates.
%     - These strings consist of a coordinate axis designator, typically [a-j] ynless modified by opts_tn2c.coord_lets, followed by a numeric quantity.
%     - The numeric quantity consists either of string of digits (assumed to represent a positive quantity),
%     or a string of digits preceded by p or m (to represent a positive or negative quantity), or z (followed by any numbers), indicating zero.
%     - The string can also contain a  decimal point,'+', or '-', intrepreted in the standard fashion.  The sign is multiplied by the sign designated by a preceding 'p' or 'm' if present.
%     - Examples, assuning that coords_lets has the default value of 'abcdefghij':
%
%         - 'z' indicates the origin, i.e., 0 on all coordinate axes
%         - 'a3b5cm1' indicates (3,5,-1) on the first three axes
%         - 'cm52' indicates -52 on the c (third) axis
%         - 'bp4 hm36' indicates +4 on the b (second) axis, -36 on the h (eighth) axis
%         - 'j17dm3' indicates  -3 on the d (fourth) axis, 17 on the j (tenth) axis,
%         - 'am1.4' and 'am-1.4' indicate -1.4 on the a (first) axis but 'am-1.4' indicates +1.4 on the a axis
%
%     - All of the strings in typenames are parsed in his fashion.  To assign color:
%
%         - If ony one axis is present among typenames, then its color is used.
%         - If more than one axis is present anong the typenames, and color values are given as rgb triples, and if_color_arith=1, then colors are weighted by the magnitudes.
%         - Otherwise the color of the axis that has the largest magnitude coordinate will be used, with ties broken by order of axes.
%
% Note regarding reserved paradigm types:
%     - For certain reserved paradigm types, color and symbol assignments deviate from the behavior described here and are controlled by psg_typenames2colors.
%         - 'btc': this refers to `binary texture cooordinates`.
%         - 'faces': this refers to face stimuli.
%     - The default reserved paradigms can be changed by adding a line defining generic.opts_tn2c.paradigms_reserved in `rs_aux_defaults_define`, running it once, and saving the workspace as rs_aux_defaults.mat.
%
%  See also: RS_DISP_ENH_COORDSETS.
%  
if (nargin<=1)
    aux=struct;
end
%
%set up sub-structure options
aux=filldefault(aux,'opts_tn2c',struct); %options for this module (psg_template)
%
aux.opts_tn2c=filldefault(aux.opts_tn2c,'paradigms_reserved',{'btc','faces'});
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
