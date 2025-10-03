function opts_used=rs_save_mat(fullname,s,opts)
% opts_used=rs_save_mat(fullname,s,opts) saves the fields of a structure s in a file
%
% fullname: file name, with path; .mat appended if need be
% s: a structure
% opts: options, 
%   opts.ver: defaults to '-v7'
%
%  See also:  PSG_SAVE_MAT.
%
% opts_used: options used
%
if (nargin<=2)
    opts=struct;
end
opts_used=psg_save_mat(fullname,s,opts);
return
end