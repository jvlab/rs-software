function [rgb,symb,vecs,opts_used]=psg_typenames2colors(typenames,opts)
% [rgb,symb,vecs,opts_used]=psg_typenames2colors(typenames,opts) is a utility that assigns a plotting color and
% plotting symbol to a list of stimulus type names
%
% for btc: if multiple nonzero coord values are present, a sign is assigned only if they are all the same.
% if multiple btc letters are found, the color used is the mean.
%
% if the file in opts.faces_mpi_inventory_filename exists, it uses the
% variable in it, faces_mpi_attrib_info to determine whether typenames are faces, and if so, to parse them.
% if opts.faces_mpi_inventory_filename does not exist, typenames are assumed to be NOT faces_mpi
%
% btc: color used for axis (btc coord), symbol used for sign
% faces_mpi: color used for gender and age, symbol used for emotion and set
%
% typenames: cell array of type names, such as {'gp0133','gp0267','gp0400'}
% opts: options: can be omitted
%  opts.colors.[g,b,c,d,e,t,u,v,w,a]: colors to assign to each ray
%  opts.symbs.[z,m,p]: symbols to assign to zero, positive, negative
%  opts.colors_anymatch: an rgb triplet which, if present, overrides the color assigned to any match
%  opts.symbs_anymatch: a symbol which, if present, overrides the symbol assigned to any match
%  rgb: an rgb color triplet
%  symb: a plotting symbol
%  vecs: array of the coordinates found, NaN if unspecified
%    e.g., typenames= {'gp0300','bm0100ap0500','gm0400'} yields 
%   vecs=[...
%         0.30   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN;...
%          NaN -0.10   NaN   NaN   NaN   NaN   NaN   NaN   NaN -0.50;...
%        -0.40   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN]
%
%  opts_used: options used
%
% 12Apr23: modify c color; fix bug in assigning symbols to bp0000cm0100 and similar; add symbols for pm and mp
% 29Jun23: begin capability for typenames from mpi faces. opts.type_class='btc' or 'faces_mpi', based on parsing
% 15Dec23: convert any color letter to a triplet
%    See also:  PSG_PLOTCOORDS, PSG_PLOTANGLES, PSG_READCOORD_DATA, PSG_FINDRAYS, BTC_DEFINE, PSG_TYPENAMES2COLORS_TEST,
%    PSG_COLORS_LEGACY, FACES_MPI_INVENTORY, PSG_COLOR2RGB.
% 19Feb24: add opts.[colors|symbs]_anymatch
% 14May24: modularize conversion of letters to rgb triples
% 06May26: force averaging of rgb triples to go along dimension 1 (i.e., triples are in rows)
%
if (nargin<2)
    opts=struct;
end
opts=psg_defopts(opts);
opts=filldefault(opts,'colors_nomatch',[0 0 0]);
opts=filldefault(opts,'symbs_nomatch','.');
opts=filldefault(opts,'colors',[]);
opts=filldefault(opts,'symbs',[]);
opts=filldefault(opts,'colors_anymatch',[]);
opts=filldefault(opts,'symbs_anymatch',[]);
%
%values if we find no matches
rgb=opts.colors_nomatch;
symb=opts.symbs_nomatch;
vecs=[];
%
ntn=length(typenames);
%
%determine whether typenames are mpi faces, i.e., of form {'132_y_f_n_a'}, and parse
%
if exist(opts.faces_mpi_inventory_filename,'file')
    underscore='_';
    if_faces_mpi=1;
    faces_mpi_attrib_info=getfield(load(opts.faces_mpi_inventory_filename),'faces_mpi_attrib_info');
    %faces_mpi_attrib_info
    attribs=faces_mpi_attrib_info.psg_order;
    nattribs=length(attribs);
    table_order=cell(1,nattribs+1);
    for ia=1:nattribs
        table_order{faces_mpi_attrib_info.(attribs{ia}).dim}=attribs{ia}; %order of attributes in file name;
    end
    table_order{1}='indiv';
    attrib_table_num=NaN(ntn,nattribs+1);
    attrib_table_cell=cell(ntn,nattribs+1);
    attrib_table_avg=NaN(1,nattribs+1);
    for k=1:ntn
        unds=strfind(typenames{k},underscore);
        if length(unds)==nattribs
            %check that each attribute has a legitimate value and parse
            unds=[unds length(typenames{k})+1];
            indiv=str2num(typenames{k}(1:unds(1)-1));
            if ~isempty(indiv) %extract individual
                attrib_table_num(k,1)=indiv;
                attrib_table_cell{k,1}=indiv;
            end
            for ia=1:nattribs
                att_char=typenames{k}(unds(ia)+1:unds(ia+1)-1);
%                disp(sprintf('%2.0f %2.0f %s',k,ia,att_char));
%                disp(attribs{ia})
                if length(att_char)==1
                    idx=strmatch(att_char,faces_mpi_attrib_info.(table_order{ia+1}).vals);
                    if length(idx)==1
                        attrib_table_num(k,ia+1)=idx;
                        attrib_table_cell{k,ia+1}=att_char;
                    end
                end
            end
        else
            if_faces_mpi=0;
        end
    end
    if any(isnan(attrib_table_num(:)))
        if_faces_mpi=0;
    else %now set up symbol and coords
        attrib_table_avg=mean(attrib_table_num,1);
    end
    opts.faces_mpi.attrib_table_avg=attrib_table_avg;
    opts.faces_mpi.attrib_table_num=attrib_table_num;
    opts.faces_mpi.attrib_table_cell=attrib_table_cell;
    opts.faces_mpi.attrib_table_order=table_order;
    opts.faces_mpi.attrib_info=faces_mpi_attrib_info;
else
    if_faces_mpi=0;
    opts.faces_mpi=struct();
end
if (if_faces_mpi)
    opts.type_class='faces_mpi';
else
    opts.type_class='btc';
end
%determine symbols, colors, and vectors based on typename and type_class
switch opts.type_class
    case 'faces_mpi' %color is used for age and gender, symbol for emotion
        colors_each=NaN(ntn,3); %colors for each parse-able entry
        symbs_each=cell(ntn,1);
        %
        %this assignment of colors for faces_mpi can be over-ridden by opts.colors;
        cs.faces_mpi.colors_def=struct;
        cs.faces_mpi.colors_def.gender=[1 0 0;0 0 1]; %colors for f and mc
        cs.faces_mpi.colors_def.age_blendval=[.75 1 .75]; %color used for either gender if age_mix=0
        cs.faces_mpi.colors_def.age_blendfacs=[0.4 0.7 1.0]; %factors used for blending (y,m,o)
        %
        %this assignment of symbols for faces_mpi can be over-ridden by opts.symbs
        %two entries, one for each set
        cs.faces_mpi.symbs_def=struct; %typo fixed 01Jul23
        cs.faces_mpi.symbs_def.n='x+'; %neutral
        cs.faces_mpi.symbs_def.a='**'; %angry
        cs.faces_mpi.symbs_def.s='vv'; %sad
        cs.faces_mpi.symbs_def.h='^^'; %happy
        cs.faces_mpi.symbs_def.f='hh'; %fright
        cs.faces_mpi.symbs_def.d='pp'; %disgust
        %
        opts=psg_typenames2colors_cs(opts,cs.faces_mpi);
%         %set up colors and symbols with defaults for faces_mpi, unless provided in opts.colors
%         color_fields=fieldnames(colors_def);
%         for ifn=1:length(color_fields)
%             opts.colors=filldefault(opts.colors,color_fields{ifn},colors_def.(color_fields{ifn}));
%         end
%         symb_fields=fieldnames(symbs_def);
%         for ifn=1:length(symb_fields)
%             opts.symbs=filldefault(opts.symbs,symb_fields{ifn},symbs_def.(symb_fields{ifn}));
%         end
        %
        gender_col=strmatch('gender',table_order);
        age_col=strmatch('age',table_order);
        set_col=strmatch('set',table_order);
        emo_col=strmatch('emo',table_order);
        %assign color by gender and age; assign symbol by emotion and set
        for k=1:ntn 
            %assign tentative color by gender
            if ismember(attrib_table_num(k,gender_col),[1:size(opts.colors.gender,1)])
                colors_gender=opts.colors.gender(attrib_table_num(k,gender_col),:);
            else
                colors_gender=mean(opts.colors.gender,1);
            end
            %mix in age
            age_blendfac=1;
            if ismember(attrib_table_num(k,age_col),[1:length(opts.colors.age_blendfacs)])
                age_blendfac=opts.colors.age_blendfacs(attrib_table_num(k,age_col));
            end
            colors_each(k,:)=(1-age_blendfac)*opts.colors.age_blendval+age_blendfac*colors_gender;
            %assign symbol based on emotion and set
            if isfield(opts.symbs,attrib_table_cell{k,emo_col}) & ismember(attrib_table_num(k,set_col),[1:length(opts.symbs.n)])
                symbs_each{k}=opts.symbs.(attrib_table_cell{k,emo_col})(attrib_table_num(k,set_col));
            end
        end
        %
        opts.faces_mpi.colors_each=colors_each;
        opts.faces_mpi.symbs_each=symbs_each;
        rgb=mean(colors_each,1); %average the colors
        if length(unique(attrib_table_num(:,emo_col)))==1
            symb=symbs_each{1};
        end
    case 'btc' %color is used for axis, symbol is used for sign
        dict=btc_define;
        codel=dict.codel;
        nbtc=length(codel);
        %this assignment of colors for btc can be over-ridden by opts.colors;
        cs.btc.colors_def=struct;
        cs.btc.colors_def.g=[0.50 0.50 0.50];
        cs.btc.colors_def.b=[0.00 0.00 0.75];
        %cs.btc.colors_def.c=[0.25 0.25 1.00]; %modified 12Apr23
        cs.btc.colors_def.c=[0.00 0.80 0.80];
        cs.btc.colors_def.d=[0.00 0.75 0.00];
        cs.btc.colors_def.e=[0.00 1.00 0.10];
        %cs.btc.colors_def.t=[0.75 0.25 0.80];
        %cs.btc.colors_def.u=[0.50 0.25 0.80];
        %cs.btc.colors_def.v=[0.50 0.00 0.80];
        %cs.btc.colors_def.w=[0.75 0.00 0.80];
        cs.btc.colors_def.t=[0.85 0.60 0.30];
        cs.btc.colors_def.u=[0.75 0.65 0.20];
        cs.btc.colors_def.v=[1.00 0.90 0.20];
        cs.btc.colors_def.w=[0.85 0.75 0.20];
        cs.btc.colors_def.a=[1.00 0.00 0.00];
        %
        %this assignment of symbols for btc can be over-ridden by opts.colors;
        symbl='zmp';
        cs.btc.symbs_def=struct; %typo fixed 01Jul23
        cs.btc.symbs_def.z='o';
        cs.btc.symbs_def.m='*';
        cs.btc.symbs_def.p='+';
        cs.btc.symbs_def.pm='v'; %downward triangle
        cs.btc.symbs_def.mp='^'; %upward triangle
        %
        opts=psg_typenames2colors_cs(opts,cs.btc);
        %
        symbvals.z=0;
        symbvals.m=-1;
        symbvals.p=+1;
        %
        %replace any unspecified values
        for ibtc=1:nbtc
            if ~isfield(opts.colors,codel(ibtc))
                opts.colors.(codel(ibtc))=colors_def.(codel(ibtc));
            end
        end
        for isymb=1:length(symbl)
            if ~isfield(opts.symbs,symbl(isymb))
                opts.symbs.(symbl(isymb))=symbs_def.(symbl(isymb));
            end
        end
        if ~isfield(opts.symbs,'pm')
            opts.symbs.pm=symbs_def.pm;
        end
        if ~isfield(opts.symbs,'mp')
            opts.symbs.mp=symbs_def.mp;
        end
        %
        %values if we find single matches
        rgb=opts.colors_nomatch;
        symb=opts.symbs_nomatch;
        %
        nu=6;
        nc=2; %number of xchars before digits
        signs_found=[];
        lets_found=[]; %letters found for nonzero value
        vecs=[];
        for k=1:ntn %assume typename strings are in sets of nu(=6), like 'ap0300bm0100'
            tn=typenames{k};
            vec_new=NaN(1,nbtc);
            while length(tn)>=nu
                substr=tn(1:nu);
                if ismember(substr(1),codel) & ismember(substr(2),fieldnames(cs.btc.symbs_def))
                    val=symbvals.(substr(2))*str2num(substr(nc+1:nu))/(10^(nu-nc-1));
                    if val~=0
                        signs_found=[signs_found,substr(2)]; %moved after val~=0, 12Apr23
                        lets_found=[lets_found,substr(1)];
                        vec_new(find(dict.codel==substr(1)))=val;
                    end
                end
                tn=tn(nu+1:end);
            end
            if any(~isnan(vec_new))
                vecs=[vecs;vec_new];
            end
        %    vecs
        end
        lets_found=unique(lets_found);
        if length(lets_found)==0
            if ~isempty(signs_found) %an explicit zero was found
                symb=opts.symbs.z;
            end
        else
            signs_found_nz=setdiff(signs_found,'z');
            if length(signs_found_nz)==1
                symb=opts.symbs.(signs_found_nz);
            elseif strcmp(signs_found,'pm')
                symb=opts.symbs.pm;
            elseif strcmp(signs_found,'mp')
                symb=opts.symbs.mp;
            end
            if length(lets_found)==1
                rgb=opts.colors.(lets_found);
            else %average the colors
                rgbs=zeros(length(lets_found),3);
                for ifound=1:length(lets_found)
                    rgbs(ifound,:)=opts.colors.(lets_found(ifound));
                end
                rgb=mean(rgbs,1); %06May26
            end
        end
end %switch
rgb=psg_color2rgb(rgb); %14May24
% if ischar(rgb) %15Dec23
%     rgb=get(line('color',rgb,'Visible','off'),'color'); %idea from StackOverflow
% end
opts_used=opts;
return

function opts_filled=psg_typenames2colors_cs(opts,def)
%
%set up colors and symbols with defaults for btc, unless provided in opts.colors
color_fields=fieldnames(def.colors_def);
for ifn=1:length(color_fields)
    if isempty(opts.colors_anymatch)
        opts.colors=filldefault(opts.colors,color_fields{ifn},def.colors_def.(color_fields{ifn}));
    else
        opts.colors.(color_fields{ifn})=opts.colors_anymatch;
    end
end
symb_fields=fieldnames(def.symbs_def);
for ifn=1:length(symb_fields)
    if isempty(opts.symbs_anymatch)
        opts.symbs=filldefault(opts.symbs,symb_fields{ifn},def.symbs_def.(symb_fields{ifn}));
    else
        opts_symbs.(symb_fields{ifn})=opts.symbs_anymatch;
    end
end
opts_filled=opts;
return

