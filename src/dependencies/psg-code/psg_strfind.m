function ind=psg_strfind(text,pattern,key,flag)
% ind=psg_strfind(text,pattern,key,flag) is a replacement for strfind that
% behaves properly in octave, i.e., does not fail when pattern=[]
%
% key and flag are optional.
%
%  See also: STRFIND.
%
if isempty(pattern)
    ind=[];
    return
else
    if (nargin==4)
        ind=strfind(text,pattern,key,flag);
    else
        ind=strfind(text,pattern);
        return
    end
end
return
end


