function opts_used=rs_save_mat(fullname,s,opts)
% opts_used=rs_save_mat(fullname,s,opts) saves the fields of a structure s in a file
%
% fullname: file name, with path; .mat appended if need be
% s: a structure
% opts: options, 
%   opts.ver: defaults to '-v7'
%
% opts_used: options used
%
if (nargin<=2)
    opts=struct;
end
opts=filldefault(opts,'ver','-v7');
fullname=cat(2,fullname,'.mat');
fullname=strrep(fullname,'.mat.mat','.mat');
if ~isempty(opts.ver)
    save(fullname,'-struct','s',opts.ver);
else
    save(fullname,'-struct','s');
end
opts_used=opts;
return
end