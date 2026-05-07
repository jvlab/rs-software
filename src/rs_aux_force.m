function [opts_forced,def,force]=rs_aux_force(aux_name,caller,aux_force_filename,aux_default_filename)
% [opts_forced,def,force]=rs_aux_force(aux_name,caller,aux_force_filename,aux_default_filename)
% creates an options structure that forces a non-default options to override those in rs_aux_defaults.mat
%
% aux_name: name of an options structure, e.g., opts_read, opts_disp
% caller: string, name of calling function, may be empty
% aux_force_filename: full path to the overriding set of default auxiliary inputs, e.g., rs_aux_defaults_btc.mat
% aux_default_filename: full path to the default auxiliary inputs, defaults to rs_aux_defaults.mat, may be omitted
%
% opts_forced: structure whose fields are the fields in which force_filename gives different values than default_filename
% def: default auxiliary inputs
% force: forced auxiliary inputs
%
%  See also: RS_AUX_DEFAULTS_DEFINE, RS_AUX_CUSTOMIZE, COMPSTRUCT.
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
