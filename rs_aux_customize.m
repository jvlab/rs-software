function aux_out=rs_aux_customize(aux,caller)
% aux_out=rs_aux_customize(aux,caller) customizes the default auxiliary inputs
%
%This reads rs_aux_defaults.mat, which is creted by rs_aux_defaults_define.m
%rs_aux_defaults_define.m should be edited to customize the default auxiliary inputs as needed
%
% aux: a structure, typically with many opts subfields, e.g., opts_read, opts_plot
% caller: string, name of calling function
%
%  See also: RS_AUX_DEFAULTS_DEFINE, RS_AUX_CUSTOMIZE_TEST.
%
aux_defaults_filename='rs_aux_defaults.mat';
s=load(aux_defaults_filename);
aux_fields=fieldnames(aux);
for ifn=1:length(aux_fields)
    fn=aux_fields{ifn}; %fn='opts_read' or similar
    %create the defaults from s.generic.(fn), overridden by s.specific.(caller).(fn)
    defaults=struct;
    if isfield(s.generic,fn)
        defaults=s.generic.(fn);
    end
    if isfield(s.specific,caller)
        if isfield(s.specific.(caller),fn)
            specific_fns=fieldnames(s.specific.(caller).(fn));
            for ifn=1:length(specific_fns)
                sfn=specific_fns{ifn};
                defaults.(sfn)=s.specific.(caller).(fn).(sfn);
            end
        end
    end %overrides
    def_names=fieldnames(defaults);
    for id=1:length(def_names)
        aux.(fn)=filldefault(aux.(fn),def_names{id},defaults.(def_names{id}));
    end %default values to fill
end %fields of aux
aux_out=aux;
return
