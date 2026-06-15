function aux_out=rs_aux_customize(aux,caller,aux_default_filename)
% aux_out=rs_aux_customize(aux,caller,aux_default_filename) sets the auxiliary inputs to customized defaults
%
%This read a file created by `rs_aux_defaults_define` at the time of installation, and should be edited to customize the default auxiliary inputs as needed.
%
% Args:
%   aux (struct):options structure, typically with subfields with names like opts_read, opts_disp, opts_knit, etc.
%
%   caller (string): string, name of calling function, e.g., 'rs_get_coordsets'; may be empty
%
%   aux_default_filename (string): full path to the file created by `rs_aux_defaults_define`; defaults to 'rs_aux_defaults.mat'
%
% Returns:
%   aux_out (struct): aux, with defaults filled in
%
% Notes: Default assignment precedence
%   Option values are assigned with the following priority
%     - Value explicitly provided in a function call
%     - Value specified in an rs_\*.m  module via a 'filldefault' statement
%     - Value listed in the specific.(caller) section of `rs_aux_defaults_define`
%     - Value listed in the generic section of `rs_aux_defaults_define`
%
% See also: RS_AUX_DEFAULTS_DEFINE, RS_AUX_FORCE.
%
if (nargin==0)
    aux=struct();
end
if isempty(aux)
    aux=struct();
end
if (nargin<=1)
    caller=[];
end
if (nargin<=2)
    aux_default_filename=[];
end
if isempty(aux_default_filename)
    aux_default_filename='rs_aux_defaults.mat';
end
s=load(aux_default_filename);
aux_fields=fieldnames(aux);
for ifn=1:length(aux_fields)
    fn=aux_fields{ifn}; %fn='opts_read' or similar
    %create the defaults from s.generic.(fn), overridden by s.specific.(caller).(fn)
    defaults=struct;
    if isfield(s.generic,fn)
        defaults=s.generic.(fn);
    end
    if ~isempty(caller)
        if isfield(s.specific,caller)
            if isfield(s.specific.(caller),fn)
                specific_fns=fieldnames(s.specific.(caller).(fn));
                for ifn=1:length(specific_fns)
                    sfn=specific_fns{ifn};
                    defaults.(sfn)=s.specific.(caller).(fn).(sfn);
                end
            end
        end
    end %overrides
    def_names=fieldnames(defaults);
    for id=1:length(def_names)
        aux.(fn)=filldefault(aux.(fn),def_names{id},defaults.(def_names{id}));
    end %default values to fill
end %fields of aux
aux_out=aux;
if isfield(s,'overall')
    aux_out.overall=s.overall;
end
return
end

