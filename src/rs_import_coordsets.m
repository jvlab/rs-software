function [data_out,aux_out]=rs_import_coordsets(coords,aux)
% [data_out,aux_out]=rs_import_coordsets(data_in,aux) imports coordinates into a `dataset structure`  with one record
%
% This is the preferred method for bringing coordinates (as arrays) into the rs package, to create a `dataset structure` with one record, suitable for display and geometrical analysis.
%
%  - If more than one record is to be combined into a single `dataset structure`, then  `rs_concat_coordsets` can be used to
%    combine several one-record `dataset structures` created here into a single `dataset structure`.
%  - If the record is in a file, `rs_read_coorddata` can be used for a single record, or `rs_get_coordsets` for multiple files.
%  - For multiple coordinate sets collected with the same experimental paradigm, use `rs_get_coordsets`, or use this routine and combine multiple `dataset structures` 
%    into a single `dataset structure` with `rs_concat_coordsets`.
%  - No `ray structure` will be created; to do so, use rs_findrays
%  - To createa a `coordinate structure` based on a `quadratic form model`, use `rs_findrays` and supply 'type_coords' to indicate the stimulus coordinates
%
% Args:
%   coords (float 2-D array, or cell array of float 2-D arrays): the coordinates; see note below regarding coordinates.
%
%   aux (struct): a structure, can be omitted, with fields 
%
%     - opts_import (struct): metadata, can be omitted, with fields listed below.  Fields nstims, typenames, and type_coords are used
%     to create the `stimulus metadata structure`; fields type, paradigm_type, paradigm_name,extra, subj_id, subj_id_short, label, and label_long are used to create the `set metadata structure`.  Any or all can be omitted.
%
%         - nstims (int): number of stimuli; default determined from first non-empty entry in coords
%         - typenames (cell array): unique labels for stimuli; length should be equal to nstims; default is opts_import.typename_prefix followed by a sequential number, formatted with opts_import.typename_ndigits
%         - typename_prefix (char): prefix auto-generated stimulus names; default is 'type_'; see note below regarding customization
%         - typename_ndigits (int): number of digits in suffix for auto-generated stimulus names; default is 2; see note below regarding customization
%         - type_coords (float 2-d array): array with nstims rows specifing the `stimulus coordinates`; default is determined by opts_import.type_coords_def
%         - type_coords_def (char): method for auto-generation of `stimulus coordinates`; default is 'none'; see note below regarding customization
%
%             - 'none': type_coords=[]
%             - 'zeros': type_coords=zeros(nstims,1)
%             - 'ones': type_coords=ones(nstims,1)
%             - 'eye': type_coords=eye(nstims)
%
%         - type (char): overall category of coordinates; default is 'data'; alternatively, 'model' for coordinates originating in a computational model
%         - paradigm_type (char): overall category of experiment; default is 'unknown'; see note below regarding customization
%         - paradigm_name (char): subcategory of paradigm_type; default is opts_import.paradigm_type; see note below regarding customization
%         - subj_id (char): full subject identifier; default is 'unknown'; see note below regarding customization
%         - subj_id_short (char): short form of subj_id, e.g., for plot labels; default is opts_import.subj_id; see note below regarding customization
%         - extra (char): free-form identifier; default is []; see note below regarding customization
%         - label_long (char): data source, typically a file path and name; default is 'unknown'; see note below regarding customization
%         - label (char): short form of label_long; default is opts_import.label_long; see note below regarding customization
%
%     - opts_check: options for consistency checking, with field
%
%         - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
% 
% Returns:
%   data_out (struct): `dataset structure` with one record, and fields
%
%     - ds (singleton cell array): `coordinate structure`, ds{1}{idim} is an array of [nstims idim] of coordinates
%     - sas (singleton cell array): `stimulus metadata structure`, sas{1} is the stimulus metadata for the record
%     - sets (singleton cell array): `set metadata structure`, sets{1} is the response metadata for the record
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_import (struct): aux.opts_import, with defaults filled in
%     - opts_check (struct): aux.opts_check, with defaults filled in
%
% Note regarding coordinates:
%    - if 'coords' is a 2-dimensional array of size [nstims dmax], then coords(:,1:k) is taken to be the coordinate set data_out.ds{1}{:,idim},
%    for each idim=1,...,dmax
%    - if 'coords' is a cell array, then coords{idim} should be of size [nstims idim] or empty, and, if non-empty, is taken to be the coordinate set for dimension idim.
%
% Note regarding customization:
%    The default values of these parameters can be changed by editing `rs_aux_defaults_define`, running it 
%    once, and saving the workspace as rs_aux_defaults.mat.
%    For example, to change the default paradigm
%    type to 'cars', add the line generic.opts_import.paradigm_type='cars'
%    to the section in which generic.opts_import fields are defined.
%
%  See also: RS_CONCAT_COORDSETS, RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, PSG_TYPE_COORDS_DEF.
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
aux.opts_import=filldefault(aux.opts_import,'paradigm_name',aux.opts_import.paradigm_type);
aux.opts_import=filldefault(aux.opts_import,'subj_id_short',aux.opts_import.subj_id);
aux.opts_import=filldefault(aux.opts_import,'extra',[]);
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
aux_out.opts_check=aux.opts_check;
%
if aux_out.warn_bad>0
    disp('cannot proceed');
    data_out=struct();
end
return
end
