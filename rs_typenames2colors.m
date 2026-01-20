function [rgb,symb,cvecs,aux_out]=rs_typenames2colors(typenames,aux)
% [rgb,symb,cvecs,aux_out]=rs_typenames2colors(typenames,aux) is a utility that assigns a plotting color and
% plotting symbol to a list of stimuli, designated by typenames
%
% typenames: a typename, or a cell array of tpenames, typically from data.sas{:}.typenames
% aux.opts_tn2c: 
%   paradigm_type: paradigm type, typically from data.sets{:}.paradigm_type, if omited, defaults to 'unknown'
%   paradigms_reserved: paradigm types that are passed through to psg_typenames2colors:
%     defaults to 'btc','mpi_faces','mater','irgb'
%   coord_lets: coordinate letters.  Defaults to 'abcdefghij'. Avoid including m, p, z.
%     Overriding this will remove the default colors, which are assigned to [a-j].
%   color: a structure, fields labeled by coord_lets, each containing an r,g,b triple
%     Default values are given below in colors_def.
%   colors_nomatch: rgb triplet if no color has been assigned to a coordinate, defaults to [0 0 0];
%   if_color_average: 1 (default) to enable averaging of colors
%
%  rgb: an rgb color triplet
%  symb: a plotting symbol
%  cvecs: array of size length(typenames) x number of coordinates found,
%    indicating the coordinates as decoded from the typename (NaN if coordinate not found)
%
%  It is expected that typenames will be strings that contain one or more
%  segments of a letter, [a-j], followed by a numeric quantity, consisting
%  either of a string of digits (assumed to represent a positive quantity),
%  or a string of digits preceded by p, m (to represent a positive or negative quantity)
%  or z (followed by any numbers), indicating zero. e.g.:
%     'bp4 hm36' indicates +4 on the b axis, -36 on the h axis
%     'z' indicates the origin
%     'cm52' indicates -52 on the c axis
%     'j17dm3' indicates 17 on the j axis, -3 on the c axis
%
% If more than one axis is present, and color values are given as rgb triples, and if_color_average=1, then colors are weighted by the magnitudes
% Otherwise the largest color's rgb value will be used, ties broken by order of colors
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
aux.opts_tn2c=filldefault(aux.opts_tn2c,'colors',struct());
aux.opts_tn2c=filldefault(aux.opts_tn2c,'colors_nomatch',[0 0 0]);
aux.opts_tn2c=filldefault(aux.opts_tn2c,'coord_lets','abcdefghij');
aux.opts_tn2c=filldefault(aux.opts_tn2c,'if_color_average',1);
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
else
    can_average=1;
    if aux.opts_tn2c.if_color_average==0
        can_average=0;
    else
        color_vals=zeros(length(coords_found),nrgb);
        for ic=1:length(coords_found)
            cf=aux.opts_tn2c.coord_lets(coords_found(ic));
            cv=aux.opts_tn2c.colors.(cf);
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
symb='h';
aux_out=aux;
return
end
%%%%%%%%%%%%%%
 %       opts=psg_typenames2colors_cs(opts,cs.faces_mpi);
%         %set up colors and symbols with defaults for faces_mpi, unless provided in opts.colors
%         color_fields=fieldnames(colors_def);
%         for ifn=1:length(color_fields)
%             opts.colors=filldefault(opts.colors,color_fields{ifn},colors_def.(color_fields{ifn}));
%         end
%         symb_fields=fieldnames(symbs_def);
%         for ifn=1:length(symb_fields)
%             opts.symbs=filldefault(opts.symbs,symb_fields{ifn},symbs_def.(symb_fields{ifn}));
%         end
%         %
%         gender_col=strmatch('gender',table_order);
%         age_col=strmatch('age',table_order);
%         set_col=strmatch('set',table_order);
%         emo_col=strmatch('emo',table_order);
%         %assign color by gender and age; assign symbol by emotion and set
%         for k=1:ntn 
%             %assign tentative color by gender
%             if ismember(attrib_table_num(k,gender_col),[1:size(opts.colors.gender,1)])
%                 colors_gender=opts.colors.gender(attrib_table_num(k,gender_col),:);
%             else
%                 colors_gender=mean(opts.colors.gender,1);
%             end
%             %mix in age
%             age_blendfac=1;
%             if ismember(attrib_table_num(k,age_col),[1:length(opts.colors.age_blendfacs)])
%                 age_blendfac=opts.colors.age_blendfacs(attrib_table_num(k,age_col));
%             end
%             colors_each(k,:)=(1-age_blendfac)*opts.colors.age_blendval+age_blendfac*colors_gender;
%             %assign symbol based on emotion and set
%             if isfield(opts.symbs,attrib_table_cell{k,emo_col}) & ismember(attrib_table_num(k,set_col),[1:length(opts.symbs.n)])
%                 symbs_each{k}=opts.symbs.(attrib_table_cell{k,emo_col})(attrib_table_num(k,set_col));
%             end
%         end
%         %
%         opts.faces_mpi.colors_each=colors_each;
%         opts.faces_mpi.symbs_each=symbs_each;
%         rgb=mean(colors_each,1); %average the colors
%         if length(unique(attrib_table_num(:,emo_col)))==1
%             symb=symbs_each{1};
%         end
%     case 'btc' %color is used for axis, symbol is used for sign
%         dict=btc_define;
%         codel=dict.codel;
%         nbtc=length(codel);
%         %this assignment of colors for btc can be over-ridden by opts.colors;
%         cs.btc.colors_def=struct;
%         cs.btc.colors_def.g=[0.50 0.50 0.50];
%         cs.btc.colors_def.b=[0.00 0.00 0.75];
%         %cs.btc.colors_def.c=[0.25 0.25 1.00]; %modified 12Apr23
%         cs.btc.colors_def.c=[0.00 0.80 0.80];
%         cs.btc.colors_def.d=[0.00 0.75 0.00];
%         cs.btc.colors_def.e=[0.00 1.00 0.10];
%         %cs.btc.colors_def.t=[0.75 0.25 0.80];
%         %cs.btc.colors_def.u=[0.50 0.25 0.80];
%         %cs.btc.colors_def.v=[0.50 0.00 0.80];
%         %cs.btc.colors_def.w=[0.75 0.00 0.80];
%         cs.btc.colors_def.t=[0.85 0.60 0.30];
%         cs.btc.colors_def.u=[0.75 0.65 0.20];
%         cs.btc.colors_def.v=[1.00 0.90 0.20];
%         cs.btc.colors_def.w=[0.85 0.75 0.20];
%         cs.btc.colors_def.a=[1.00 0.00 0.00];
%         %
%         %this assignment of symbols for btc can be over-ridden by opts.colors;
%         symbl='zmp';
%         cs.btc.symbs_def=struct; %typo fixed 01Jul23
%         cs.btc.symbs_def.z='o';
%         cs.btc.symbs_def.m='*';
%         cs.btc.symbs_def.p='+';
%         cs.btc.symbs_def.pm='v'; %downward triangle
%         cs.btc.symbs_def.mp='^'; %upward triangle
%         %
%         opts=psg_typenames2colors_cs(opts,cs.btc);
%         %
%         symbvals.z=0;
%         symbvals.m=-1;
%         symbvals.p=+1;
%         %
%         %replace any unspecified values
%         for ibtc=1:nbtc
%             if ~isfield(opts.colors,codel(ibtc))
%                 opts.colors.(codel(ibtc))=colors_def.(codel(ibtc));
%             end
%         end
%         for isymb=1:length(symbl)
%             if ~isfield(opts.symbs,symbl(isymb))
%                 opts.symbs.(symbl(isymb))=symbs_def.(symbl(isymb));
%             end
%         end
%         if ~isfield(opts.symbs,'pm')
%             opts.symbs.pm=symbs_def.pm;
%         end
%         if ~isfield(opts.symbs,'mp')
%             opts.symbs.mp=symbs_def.mp;
%         end
%         %
%         %values if we find single matches
%         rgb=opts.colors_nomatch;
%         symb=opts.symbs_nomatch;
%         %
%         nu=6;
%         nc=2; %number of xchars before digits
%         signs_found=[];
%         lets_found=[]; %letters found for nonzero value
%         vecs=[];
%         for k=1:ntn %assume typename strings are in sets of nu(=6), like 'ap0300bm0100'
%             tn=typenames{k};
%             vec_new=NaN(1,nbtc);
%             while length(tn)>=nu
%                 substr=tn(1:nu);
%                 if ismember(substr(1),codel) & ismember(substr(2),fieldnames(cs.btc.symbs_def))
%                     val=symbvals.(substr(2))*str2num(substr(nc+1:nu))/(10^(nu-nc-1));
%                     if val~=0
%                         signs_found=[signs_found,substr(2)]; %moved after val~=0, 12Apr23
%                         lets_found=[lets_found,substr(1)];
%                         vec_new(find(dict.codel==substr(1)))=val;
%                     end
%                 end
%                 tn=tn(nu+1:end);
%             end
%             if any(~isnan(vec_new))
%                 vecs=[vecs;vec_new];
%             end
%         %    vecs
%         end
%         lets_found=unique(lets_found);
%         if length(lets_found)==0
%             if ~isempty(signs_found) %an explicit zero was found
%                 symb=opts.symbs.z;
%             end
%         else
%             signs_found_nz=setdiff(signs_found,'z');
%             if length(signs_found_nz)==1
%                 symb=opts.symbs.(signs_found_nz);
%             elseif strcmp(signs_found,'pm')
%                 symb=opts.symbs.pm;
%             elseif strcmp(signs_found,'mp')
%                 symb=opts.symbs.mp;
%             end
%             if length(lets_found)==1
%                 rgb=opts.colors.(lets_found);
%             else %average the colors
%                 rgbs=zeros(length(lets_found),3);
%                 for ifound=1:length(lets_found)
%                     rgbs(ifound,:)=opts.colors.(lets_found(ifound));
%                 end
%                 rgb=mean(rgbs);
%             end
%         end
% end %switch
% rgb=psg_color2rgb(rgb); %14May24
% % if ischar(rgb) %15Dec23
% %     rgb=get(line('color',rgb,'Visible','off'),'color'); %idea from StackOverflow
% % end
% opts_used=opts;
% return
% 
% function opts_filled=psg_typenames2colors_cs(opts,def)
% %
% %set up colors and symbols with defaults for btc, unless provided in opts.colors
% color_fields=fieldnames(def.colors_def);
% for ifn=1:length(color_fields)
%     if isempty(opts.colors_anymatch)
%         opts.colors=filldefault(opts.colors,color_fields{ifn},def.colors_def.(color_fields{ifn}));
%     else
%         opts.colors.(color_fields{ifn})=opts.colors_anymatch;
%     end
% end
% symb_fields=fieldnames(def.symbs_def);
% for ifn=1:length(symb_fields)
%     if isempty(opts.symbs_anymatch)
%         opts.symbs=filldefault(opts.symbs,symb_fields{ifn},def.symbs_def.(symb_fields{ifn}));
%     else
%         opts_symbs.(symb_fields{ifn})=opts.symbs_anymatch;
%     end
% end
% opts_filled=opts;
% return
% 
% 
% 
% %
% % btc: color used for axis (btc coord), symbol used for sign
% % faces_mpi: color used for gender and age, symbol used for emotion and set
% %
% % typenames: cell array of type names, such as {'gp0133','gp0267','gp0400'}
% % opts: options: can be omitted
% %  opts.colors.[g,b,c,d,e,t,u,v,w,a]: colors to assign to each ray
% %  opts.symbs.[z,m,p]: symbols to assign to zero, positive, negative
% %  opts.colors_anymatch: an rgb triplet which, if present, overrides the color assigned to any match
% %  opts.symbs_anymatch: a symbol which, if present, overrides the symbol assigned to any match
% %  rgb: an rgb color triplet
% %  symb: a plotting symbol
% %  vecs: array of the coordinates found, NaN if unspecified
% %    e.g., typenames= {'gp0300','bm0100ap0500','gm0400'} yields 
% %   vecs=[...
% %         0.30   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN;...
% %          NaN -0.10   NaN   NaN   NaN   NaN   NaN   NaN   NaN -0.50;...
% %        -0.40   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN]
% %
% %  opts_used: options used
% %
