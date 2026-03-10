function [data_out,aux_out]=rs_align_coordsets(data_in,aux)
% Aligns a `dataset structure` with partially overlapping stimuli
%
% Each of the records in the `dataset structure` data_in contains the responses to one or more stimuli,
% with stimulus identity in record k determined by the strings in data_in.sas{k}.typenames. The stimuli
% in each of the records may differ, and may overlap.
%
% Each of the corresponding records in the `dataset structure` data_out contains an entry a stimulus set
% equal to the union of all of the stimuli in any of the records of data_in.  For a stimulus in the kth record of
% data_out for which there is no entry in data_in, the coordinates are NaN. See note below regarding stimulus coordinates.
%
% The stimulus labels in data_out.sas{k}.typenames are in alphabetical order, and are identical for all of the records
% Thus, even if there is complete overlap between the stimuli in data_in, the `dataset structure` data_out may differ.
%
% The stimulus coordinates in data_out.sas{k} are correspondingy aligned; see note below regarding stimulus coordinates.
%
% Args:
%   data_in (struct): `dataset structure` to be aligned containing n records, with fields
%
%     - ds (cell array): `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas (cell array): `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets (cell array): `set metadata structure`, sets{k} is the response metadata for the kth record
% 
%   aux (struct): auxiliary options, may be omitted, with fields
%
%     - opts_align (struct): options for consistency checking, with fields
%
%       - if_log (int): 1 to log progress, 0 to suppress; default is o.
%       - min (int or char): minimum number of datasets that must contain a stimulus, in order for the stimulus to be included in data_out;
%             default is 1, equivalent to 'any';  can also be 'all', meaning that stimuli must be present in all datasets to be included in data_out
%       - if_type_coords_remake:  controls alignment of stimulus coordinates, typically omitted or set to [], see note below regarding stimulus coordinates
%       - if_btcremz (int): typically omitted, defaults to 1, see note below regarding labels for binary texture coordinates
%
%     - opts_check (struct): options for consistency checking, with field
%
%       - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
%
%     - opts_import (struct): options for stimulus coordinates, typically omitted, see note below regarding stimulus coordinates
%     - opts_rays (struct): options for rays, typically omitted, see note below regarding rays
%
% Returns:
%   data_out (struct): aligned `dataset structure` with n records, same format as  as `data_in`
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_align (struct): aux.opts_align, with defaults filled in
%
%       - aux_out.opts_align.ovlp_array_all (integer array): the overlap array for the pooled dataset.  Each row corresponds to one of the 
%       typenames (see sa_pooled below) contained in any of the input records; ovlp_array_all(s,k)=1 if the stmulus is present in record
%       k of data_in
%
%     - opts_check (struct): aux.opts_check, with defaults filled in
%     - opts_import (struct): aux.opts_import, with defaults filled in
%     - opts_rays (cell array): opts_rays{k} is a structure which contains the options used for creating rays in record k in data_out
%     - ovlp_array (integer array): overlap array: ovlp_array(s,k)=1 if the stimulus data_out.sets{:}.typenames{s} is present in record k of data_in, 0 otherwise
%     - sa_pooled (struct): the `stimulus metadata structure` for the pooled stimulus set; see note below regarding stimulus coordinates
%     - rayss (cell array): rayss{k} is the `ray structure` for record k in data_out; see note below regarding rays
%     - opts_btcremz (cell array): see note below regarding labels for binary texture coordinates
%
% General notes:
%     - For all records with data_in.sets{k}.type='data', the strings in data_in.sets{k}.paradigm_type must agree.
%     - Pipeline: data_out.sets{k}.pipeline.sets{1} contains metadata for the kth record of data_in;
%       data_out.sets{k}.pipeline.sets_combined{:} contains metadata from all records of data_in.
%
% Note regarding stimulus coordinates:
%     - Stimulus coordinates are optionally present in data_in.sas{k} in the fields type_coords, btc_specoords, or btc_augcoords.
%     Their treatment is governed by aux.opts_align.if_type_coords_remake.
%     If this field is omitted or [], behavior is determined by the stimulus coordinates supplied in data_in.sas{k}.
%     A value of 0 attempts to merge the coordinates, a value of 1 does not.
%
%     - Merging (if_type_coords_remake=0, or, stimulus coordinates are not all 0 or 1, or a non-square array with at least 2 columns):
%     In the aligned `stimulus metadata structure` data_out.sas{k}, if the stimulus typename is not present in data_in.sas{k}, stimulus coordinates are NaN.
%     In the pooled `stimulus metadata structure` aux_out.sa_pooled, stimulus coordinates are taken from the first occurence of the typename in data_in.sas{:} is used.
%     A similar behavior is applied to other subfields of the stimulus
%     metadata structure that relate to individual stimuli.  These fields are listed in aux_out.opts_align.fields_align, which defaults in psg_align_coordsets
%     to {'specs'  'spec_labels'  'btc_augcoords'  'btc_specoords'  'type_coords'}
%
%     - No merging (if_type_coords_remake=1, or stimulus coordinates absent, or, stimulus coordinates do not meet above requirements):
%       In the aligned `stimulus metadata structure` data_out.sas{k}, dummy coordinates are created in one of the fields
%       type_coords, btc_specoords, or btc_augcoords (the field chosen is determined by the first of that list that is found in data_in.sas{:}).
%       The dummy coordinates can be an empty matrix, zeros, ones, or the identity,
%       as determined by aux.opts_import.type_coords_def.  This defaults to 'none', can be 'zeros','ones', or 'eye', and the value used is
%       reported in aux_out.opts_import.type_coords_def and aux_out.opts_align.type_coords_def.
% 
%     - The behavior taken is reported in aux_out.opts_align.if_type_coords_remake.
%
% Note regarding rays:
%     - The `ray structure` describes relationships among the simulus coordinates: 
%     `rays`, i.e., sets of stimuli that lie along an axis or a ray from the origin,
%     `rings`, stimuli that lie at an appxorimately equal distance from the origin, and nearest neighbors.
%     It is only created if there is a valid set of stimulus coordinates.  
%
% Note regarding labels for binary texture coordinates:
%     - if_btcremz is only relevant for datasets with binary texture coordinate metadata, and controls whether an attempt should be made to simplify fields sas{k}.spec_labels and sas{k}.typenames
%     prior to matching and alignmnent.  If 1 (default), coordinates that are specified as zero are removed, provided
%     that this does not change the stimulus after maximum-entropy extension.  For example, in data_in.sas{k}.spec_labels, 'b=-0.00 c=-0.40' becomes 'c=-0.40'
%     the corresponding entry in data_in.sas{k}.typenames, 'bm0000cm0400' becomes 'cm0400'.  An
%     all-zero coordinate becomes 'rand'. Results for simplification of record k are returned in opts_btcremz{k}.
% 
%  See also: RS_AUX_CUSTOMIZE, RS_FINDRAYS, PSG_ALIGN_COORDSETS, RS_IMPORT_COORDSETS, PSG_COORD_PIPE_UTIL, PSG_BTCREMZ, RS_CHECK_COORDSETS.
%
if (nargin<=1)
    aux=struct;
end
%
aux=filldefault(aux,'opts_align',struct);
aux.opts_align=filldefault(aux.opts_align,'if_log',1);
aux.opts_align=filldefault(aux.opts_align,'min',1);
aux.opts_align=filldefault(aux.opts_align,'if_btcremz',1);
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=filldefault(aux,'opts_rays',struct);
aux=filldefault(aux,'opts_import',struct); %alignment needs to know how to set up type_coords if none are supplied
%
aux=rs_aux_customize(aux,'rs_align_coordsets');
%
data_out=struct;
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
%
if isnumeric(aux.opts_align.min)
    min_string=sprintf('%1.0f',aux.opts_align.min);
else
    min_string=aux.opts_align.min;
end
%
nsets=length(data_in.sets);
%
%check internal consistency
%
for iset=1:nsets
    data_check=struct;
    data_check.ds{1}=data_in.ds{iset};
    data_check.sas{1}=data_in.sas{iset};
    data_check.sets{1}=data_in.sets{iset};
    check=rs_check_coordsets(data_check,setfield(aux.opts_check,'set_num_offset',iset-1));
    if ~isempty(check.warnings) %since strvcat([],[])~=[]       
        aux_out.warnings=strvcat(aux_out.warnings,check.warnings);
        warn_leadin=getfield(getfield(rs_aux_customize(struct()),'overall'),'warn_leadin');
        for k=1:size(aux_out.warnings,1)
            disp(cat(2,warn_leadin,aux_out.warnings(k,:)));
        end
    end
    aux_out.warn_bad=aux_out.warn_bad+check.warn_bad;
end
%
%check that data paradigms are the same (model paradigms may differ)
paradigm_types=cell(1,nsets);
types=cell(1,nsets);
paradigm_type=[];
paradigm_match=1;
for iset=1:nsets
    types{iset}=data_in.sets{iset}.type;
    data_in.sets{iset}=filldefault(data_in.sets{iset},'paradigm_type','unrecognized');
    paradigm_types{iset}=data_in.sets{iset}.paradigm_type;
    if strcmp(types{iset},'data')
        if isempty(paradigm_type)
            paradigm_type=paradigm_types{iset};
        else
            if ~strcmp(paradigm_types{iset},paradigm_type)
                paradigm_match=0;
            end
        end
    end
    if strcmp(paradigm_type,'btc')
        if aux.opts_align.if_btcremz
            [sas_new,change_list,opts_btcremz_used]=psg_btcremz(data_in.sas{iset});
            aux_out.opts_btcremz{iset}=opts_btcremz_used;
            if aux.opts_align.if_log
                disp(sprintf(' set %3.0f: simplification attempted, %3.0f coords simplified (label: %s)',iset,length(change_list),data_in.sets{iset}.label));
            end
            if length(change_list)>0
                if aux.opts_align.if_log
                    for k=1:length(change_list)
                        kch=change_list(k);
                        disp(sprintf('%15s -> %15s',data_in.sas{iset}.typenames{kch},sas_new.typenames{kch}));
                    end
                end
                data_in.sas{iset}=sas_new;
            end
        end
    end %paradigm type=btc
end
if paradigm_match==0
    wmsg=sprintf('paradigm types disagree');
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
    if aux.opts_align.if_log
        disp([types paradigm_types])
    end
end
aux_out.opts_check=aux.opts_check;
aux_out.opts_import=aux.opts_import;
if aux_out.warn_bad==0
    paradigm_type=paradigm_types{1};
    if aux.opts_align.if_log
        disp(sprintf('proceeding with alignment of %3.0f datasets, paradigm type %s, stimuli must be present in %s',nsets,paradigm_type,min_string));
    end
    %alignment needs to know how to set up type_coords if none are supplied
    [sets_align,ds_align,sas_align,ovlp_array,sa_pooled,opts_align_used]=...
        psg_align_coordsets(data_in.sets,data_in.ds,data_in.sas,setfield(aux.opts_align,'type_coords_def',aux.opts_import.type_coords_def));
    %
    for iset=1:nsets
        [rays,wmsg,opts_rays_used]=rs_findrays(sas_align{iset},sets_align{iset}.label,aux.opts_rays);
        if ~isempty(wmsg)
            aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
        end
        aux_out.opts_rays{iset}=opts_rays_used;
        aux_out.rayss{iset}=rays;
    end
    data_out.ds=ds_align;
    data_out.sas=sas_align;
    data_out.sets=sets_align;
    data_out.sets{1}.type=data_in.sets{1}.type;
    aux_out.ovlp_array=ovlp_array;
    aux_out.sa_pooled=sa_pooled;
    aux_out.opts_align=opts_align_used;
    %
    pipeline_opts=struct;
    pipeline_opts.opts_align=opts_align_used;
    for iset=1:nsets
        data_out.sets{iset}.pipeline=psg_coord_pipe_util('align',pipeline_opts,data_in.sets{iset},[],data_in.sets);
    end
else
    disp('cannot proceed');
    disp(aux_out.warnings);
end
return
end
