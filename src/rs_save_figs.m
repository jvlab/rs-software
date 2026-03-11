function rs_save_figs(fullname,whichfigs,opts)
% rs_save_figs(whichfigs,whichfigs,opts) saves one or more open figures to a fig file
%
% fullname: file name, with path.  Used as is if figure handle is given,
%   otherwise, appended with '_fig_n', where n is a sequential figure number
% whichfigs: a figure handle, a list of handles, or 'all', or, if empty, current figure
% opts:
%   if_log to log (defaults to 0)
%   ndigits: number of digits in fig name, or 0 (default), which uses minimum number for available figures
%
% See also:  ZPAD, RS_SAVE_MAT.
%
fullname=strrep(fullname,'.fig',''); %strip .fig if supplied
if nargin<=1
    whichfigs=[];
end
if nargin<=2
    opts=struct;
end
opts=filldefault(opts,'if_log',0);
opts=filldefault(opts,'ndigits',0);
%
if isempty(whichfigs)
    handles=gcf;
    if_append=0;
elseif ischar(whichfigs)
    handles=flipud(findobj('Type','figure'));
    if_append=1;
else
    handles=whichfigs;
    if length(handles)>=2
        if_append=1;
    else
        if_append=0;
    end
end
if length(handles)>0
    if opts.ndigits<=0
        opts.ndigits=floor(log10(length(handles)))+1;
    end
    for ifig=1:length(handles)
        figname=get(handles(ifig),'Name');
        if (if_append)
            savename=cat(2,fullname,'_fig_',zpad(ifig,opts.ndigits));
        else
            savename=fullname;
        end
        savename=cat(2,savename,'.fig');
        savefig(handles(ifig),savename);
        if opts.if_log
            disp(sprintf('figure %s saved as %s',figname,savename));
        end
    end
end
return
end
