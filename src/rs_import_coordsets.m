function [data_out,aux_out]=rs_import_coordsets(coords,aux)
% [data_out,aux_out]=rs_import_coordsets(data_in,aux) imports a set of coordinates
% into a data structure for use by the rs package
%
% coords: an array of size [nstims dmax] of coordinates or, a cell array coords{1,dmax}
%   If an array, then each subarray coords(:,1:id) is taken as the coordinate set for a model of dimension id
%   If a cell array, then coords{1,id} should be either empty, or an array of size [nstims id],for each dimension for which there is a model
%
% aux:
%  aux.opts_import: a structure with fields
%     nstims: number of stimuli, if 0 or omitted, will be determined from first non-empty entry in coords
%
%        fields relevant to data_out.sas
%     typenames: cell array, size [nstims,1], unique labels for the stimuls types, as strings
%             if omitted will be set to opts_import.typename_prefix followed by opts.typename_ndigits         
%    *typename_prefix: string, defaults to 'type_'; prefix for auto-generated typenames
%    *typename_ndigits: (integer) number of digits in auto-generated typenames
%     type_coords: array of size [nstims *], conceptual coordinates, if omitted, will be set depending on opts.type_coords_def
%        to [], eye(nstims), zeros(nstims,1), or ones(nstims,1), 
%    *type_coords_def: 'none' (default),'eye,' or 'zeros', or 'ones', determines how type_coords are filled if not provided
%        fields relevant to data_out.sets
%    *type: text string, overall source, suggest 'data' (default) for originating in experimental data or 'model' for originating in a computational model
%    *paradigm_type: string, overall category of experiment, defaults to 'unknown'
%    *paradigm_name: string, subcategory of paradigm_type, defaults to 'unknown'
%    *subj_id: string, full subject identifier, defaults to 'unknown'
%    *subj_id_short: short version of subj_id, used for plot labels, defaults to subj_id
%    *extra: string, free-form identifier, defaults to []
%    *label_long: string, data source, typically a file path and name, defaults to 'unknown'
%    *label: string, short version of label_long, defaults to label_long
%
%      * Note: The default values for these parameters changed by adding a line such as
%         generic.opts_import.paradigm_type='colors';
%      to rs_aux_defaults_define, running it once, and saving the workspace as rs_aux_defaults.mat
%
%  aux.opts_check: a structure with fields
%     if_warn: defaults to 1, set to 0 to turn off warnings
%     if_warn_traceback: set to 1 to give full traceback of warnings, defaults to value in overall section of rs_aux_defaults, set by rs_aux_customize.
% 
% data_out.ds{1},sas{1},sets{1}:  coordinates after processing
% aux_out: auxiliary outputs and parameter values used, and also
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, PSG_TYPE_COORDS_DEF.
%
if (nargin<=1)
    aux=struct;
end
%set up sub-structure options
aux=filldefault(aux,'opts_import',struct); %options for this module (psg_template)
%
aux=filldefault(aux,'opts_check',struct); %options for this module (psg_template)
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_import');
%
aux.opts_import=filldefault(aux.opts_import,'nstims',0);
%
aux.opts_import=filldefault(aux.opts_import,'typenames',cell(0));
aux.opts_import=filldefault(aux.opts_import,'type_coords',[]);
%
aux.opts_import=filldefault(aux.opts_import,'type','data');
aux.opts_import=filldefault(aux.opts_import,'paradigm_type','unknown');
aux.opts_import=filldefault(aux.opts_import,'paradigm_name',aux.opts_import.paradigm_type);
aux.opts_import=filldefault(aux.opts_import,'subj_id','unknown');
aux.opts_import=filldefault(aux.opts_import,'subj_id_short',aux.opts_import.subj_id);
aux.opts_import=filldefault(aux.opts_import,'extra',[]);
aux.opts_import=filldefault(aux.opts_import,'label_long','unknown');
aux.opts_import=filldefault(aux.opts_import,'label',aux.opts_import.label_long);
%
data_out=struct;
aux_out=struct;
aux_out.opts_import=aux.opts_import;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
set_fields_xfr={'type','paradigm_type','paradigm_name','subj_id','subj_id_short','extra','label_long','label'};
%
dim_list=[];
if iscell(coords)
    coords_use=coords;
else
    nds=size(coords,2);
    coords_use=cell(1,nds);
    for id=1:nds
        coords_use{id}=coords(:,[1:id]);
    end
end
ds=coords_use;
for k=1:length(coords_use)
    if ~isempty(coords_use{k})
        if aux.opts_import.nstims==0
            aux.opts_import.nstims=size(coords_use{k},1);
        end
        dim_list=[dim_list,size(coords_use{k},2)];
    end
end
nstims=aux.opts_import.nstims;
%
sas=struct;
sas.nstims=nstims;
if isempty(aux.opts_import.type_coords)
    sas.type_coords=psg_type_coords_def(nstims,aux.opts_import);
else
    sas.type_coords=aux.opts_import.type_coords;
end
sas.typenames=cell(nstims,1);
for istim=1:nstims
    if istim>length(aux.opts_import.typenames)
        sas.typenames{istim}=cat(2,aux.opts_import.typename_prefix,zpad(istim,aux.opts_import.typename_ndigits));
    else
        sas.typenames{istim}=aux.opts_import.typenames{istim};
    end
end
%
sets=struct;
sets.nstims=nstims;
sets.dim_list=dim_list;
for isf=1:length(set_fields_xfr)
    sets.(set_fields_xfr{isf})=aux.opts_import.(set_fields_xfr{isf});
end
sets.pipeline=[];
%
data_out=struct;
data_out.ds{1}=ds;
data_out.sas{1}=sas;
data_out.sets{1}=sets;
%
[check,opts_used]=rs_check_coordsets(data_out,aux.opts_check);
aux_out.warnings=check.warnings;
aux_out.warn_bad=check.warn_bad;
%
aux_out.opts_import=aux.opts_import;
%
if aux_out.warn_bad>0
    disp('cannot proceed');
    data_out=struct();
end
return
end
