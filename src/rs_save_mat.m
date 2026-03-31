function opts_used=rs_save_mat(fullname,s,opts)
% opts_used=rs_save_mat(fullname,s,opts) is a utility to save the fields of a structure s to a mat file.
% 
% Args:
%   fullname (char): file name, with path; .mat will appended if necessary
%   s (struct): a structure whose fields are to be saved
%   opts (struct): options, with field
%
%      - ver (char): format for saving; default is '-v7'
%
% Returns:
%   opts_used (struct): opts, with defaults filled in
% 
%  See also: PSG_SAVE_MAT.
%
if (nargin<=2)
    opts=struct;
end
opts_used=psg_save_mat(fullname,s,opts);
return
end