function sets=psg_make_setstruct(type_string,dim_list,label_long,nstims,pipeline,opts)
% sets=psg_make_setstruct(type_string,dim_list,label_long,nstims,pipeline,opts) is a
% utility function to create a metadata structure
%
% type_string: typically 'data' or 'qform'
% dim_list: list of dimensions available
% label_long: long dataset label, typically file name and path
% nstims: number of stimuli
% pipeline: a processing pipeline structure, can be omitted
% opts: options, can be omitted
%
% 30Sep25: add paradigm_type, paradigm_name, subj_id, subj_id_short, extra.
%
%  See also: PSG_GET_COORDSETS, PSG_PARSE_FILENAME.
%
if (nargin<5)
    pipeline=struct;
end
if (nargin<6)
    opts=struct;
end
sets=struct;
sets.type=type_string;
p=psg_parse_filename(label_long,opts);
sets.paradigm_type=p.paradigm_type;
sets.paradigm_name=p.paradigm_name;
sets.subj_id=p.subj_id;
sets.subj_id_short=p.subj_id_short;
sets.extra=p.extra;
%
sets.dim_list=dim_list;
sets.nstims=nstims;
sets.label_long=label_long;
sets.label=sets.label_long;
sets.label=strrep(sets.label,'./','');
sets.label=strrep(sets.label,'.mat','');
sets.label=strrep(sets.label,'coords_','');
sets.pipeline=pipeline;
return
end
