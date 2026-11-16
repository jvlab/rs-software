function [rgb,colortab_used]=psg_color2rgb(val,colortab)
% [rgb,colortab_used]=psg_color2rgb(val,colortab) is a utility to convert a text designation of a color to an rgb triplet in range [0 1]
%
% val can be a legal single-character color designator, or a triplet
% colortab, optional, is a table of colors to override default assignent
%
% rgb: size [3 1], is the rgb equivalent, or [0 0 0] if val cannot be interpreted
%   rgb is forced into [0 1] range
% colortab_used: color table used
%
%  See also:  PSG_TYPENAMES2COLORS, FILLDEFAULT.
%

%original versoin, from StackOverflow
%if ischar(rgb) %15Dec23
%    rgb=get(line('color',rgb,'Visible','off'),'color'); %idea from StackOverflow
%end
if (nargin<=1)
    colortab=struct;
end
colortab=filldefault(colortab,'b',[0 0 0]);
colortab=filldefault(colortab,'c',[0 1 1]);
colortab=filldefault(colortab,'g',[0 1 0]);
colortab=filldefault(colortab,'k',[0 0 0]);
colortab=filldefault(colortab,'m',[1 0 1]);
colortab=filldefault(colortab,'r',[1 0 0]);
colortab=filldefault(colortab,'w',[1 1 1]);
colortab=filldefault(colortab,'y',[1 1 0]);
colortab_used=colortab;
wtext='Color cannot be interpreted. [0 0 0] used.';
%
rgb=zeros(1,3);
%
if isnumeric (val)
    if prod(size(val))==3
        rgb=val(:)';
    else
        warning(wtext);
    end
elseif ischar(val)
    if isfield(colortab,val)
        rgb=colortab.(val);
    else
        warning(wtext);
    end
else
    warning(wtext);
end
rgb=max(min(rgb,1),0);% ensure it is in range
return
