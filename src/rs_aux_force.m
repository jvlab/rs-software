function [opts_forced,def,force]=rs_aux_force(aux_name,caller,aux_force_filename,aux_default_filename)
% [opts_forced,def,force]=rs_aux_force(aux_name,caller,aux_force_filename,aux_default_filename) sets an options structure to override user-customized defaults
% 
% This module is solely intended for use during benchmarking with the rs_\*test modules.  
%
% Args:
%   aux_name (char): name of an options structure, e.g., opts_read, opts_disp
%
%   caller (char): name of calling function, e.g., 'rs_get_coordsets'; may be empty
%
%   aux_force_filename (char): full path to the overriding set of default auxiliary inputs
%
%   aux_default_filename (char): full path to the default auxiliary input file created by `rs_aux_defaults_define`; defaults to 'rs_aux_defaults.mat'
%
% Returns:
%   opts_forced (struct): structure whose fields in aux_force_filename differ from those in aux_default_filename
%   
%   def (struct): auxiliary inputs from aux_default_filename
%
%   force (struct): auxiliary inputs from aux_force_filename
%
% See also: RS_AUX_DEFAULTS_DEFINE, RS_AUX_CUSTOMIZE.
%
if (nargin<=3)
    aux_default_filename='rs_aux_defaults.mat';
end
opts_forced=struct;
def=rs_aux_customize(setfield(struct(),aux_name,struct()),caller,aux_default_filename);
force=rs_aux_customize(setfield(struct(),aux_name,struct()),caller,aux_force_filename);
fns=fieldnames(force.(aux_name));
for ifn=1:length(fns)
    fn=fns{ifn};
    if isfield(def.(aux_name),fn) %is this in the defaults?
        if ~isequal(def.(aux_name).(fn),force.(aux_name).(fn)) %does it match
            opts_forced.(fn)=force.(aux_name).(fn);
        end
    else
        opts_forced.(fn)=force.(aux_name).(fn);
    end
end
return
end
