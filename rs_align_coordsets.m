function [data_out,aux_out]=rs_align_coordsets(data_in,aux)
% [data_out,aux_out]=rs_align_coordsets(data_in,aux): align coordinate datasets with partially overlapping stimuli
% data_in.sas{k}.typenames is used to establish stimulus identity
% 
% for each entry in data_in, there is an entry in data_out, listed in alphabetical order (evenif no alignment is needed)
% * this only aligns the datasets so that the stimuli are in identical order, it does not change the coordinates
% * stimulus identity is determined by typenames
% * coordinates for missing stimuli are NaN
% * see rs_knit_coordsets for finding a consensus set of coordinates 
%
% data_in.ds{k},sas{k},sets{k}: the structures of coordinates (ds) and metadata (sas,sets) returned by rs_get_coordsets or rs_read_coorddata
%      sas{k}.typenames is a strvcat, and is used to determine stimulus identity
% aux.opts_align.if_log: 1 to log progress
% aux.opts_align.min: minimum number of datasets that must contain a stimulus, in order for the stimulus to be included
%   default is 1 (legacy behavior: all stimuli used), can also be 'any'; 
%   'all': stimuli must be present in all datasets to be kept
% aux.opts_align.if_btc_specoords_remake:  this usually can be ignored or set to [].
%   Setting to 0 forces a merging of the stimulus coordinates, this is
%     appropriate if the stimuli have meaningful a priori coordinates in the setup file, and then in btc_specoords
%     (e.g., binary textures, faces)
%   Setting to 1 forces btc_specoords of the aligned data to be remade as unique rows of an identity matrix
%     this is appropriate if the stimuli do NOT have meaningful a priori coordinates in the setup file,
%     and then in sa.btc_specoords (e.g, animals)
%   An empty entry (default) determines the behavior from the coordinates of the component datasets: 
%     if they are an identity matrix, then type 1 behavior is executed; if they are not, then type 0 behavior is executed.
%   The behavior used is reported in aux_out.opts_align.if_btc_specoords_remake
% aux.opts_align.if_btcremz: set to 1 (default) to simplify augmented coordinates
% aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
% 
% data_out.ds{k},sas{k},sets{k}:  coordinates and dataset descriptors after alignment
%    coordinates will be NaN if not present
% aux_out: auxiliary outputs and parameter values used
%    ovlp_array: [stims x sets] each row is a stimulus in data_out, kth column is a 1 if
%       stimulus is present in dataset k, even if the response is NaN
%    sa_pooled: sa metadata structure (stimulus params and coords) for pooled data
%       This can differ from data_out.sas{k}, which will have NaN's for stimulus coords if stimuli are  missing
%    opts*: values used for opts_align, opts_rays
%    warnings: warnings generated in creating arguments for psg_get_coordsets
%    warn_bad: count of warnings that prevent further processing
%    rayss{k}: ray structure for dataset k
%
%  06Nov25: check internal consistency of data files with rs_check_coordsets.
%
%  See also: RS_AUX_CUSTOMIZE, RS_FINDRAYS, PSG_ALIGN_COORDSETS, PSG_COORD_PIPE_UTIL, PSG_BTCREMZ, RS_CHECK_COORDSETS.
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
        disp(check.warnings);
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
            if length(change_list)>0
                for k=1:length(change_list)
                    kch=change_list(k);
                    disp(sprintf('%15s -> %15s',data_in.sas{iset}.typenames{kch},sas_new.typenames{kch}));
                end
                data_in.sas{iset}=sas_new;
            end
        end
    end %paradigm type=btc
end
if paradigm_match==0
    wmsg=sprintf('paradigm types disagree');
    warning(wmsg);
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;
    if aux.opts_align.if_log
        disp([types paradigm_types])
    end
end
if aux_out.warn_bad==0
    paradigm_type=paradigm_types{1};
    if aux.opts_align.if_log
        disp(sprintf('proceeding with alignment of %3.0f datasets, paradigm type %s, stimuli must be present in %s',nsets,paradigm_type,min_string));
    end
    [sets_align,ds_align,sas_align,ovlp_array,sa_pooled,opts_align_used]=...
        psg_align_coordsets(data_in.sets,data_in.ds,data_in.sas,aux.opts_align);
    %
    for iset=1:nsets
        [rays,wmsg,opts_rays_used]=rs_findrays(sas_align{iset},sets_align{iset}.label,aux.opts_rays);
        if ~isempty(wmsg)
            wmsg=cat(2,sprintf('set %2.0f: ',iset),wmsg);
            warning(wmsg);
            aux_out.warnings=strvcat(aux_out.warnings,wmsg);
        end
        aux_out.opts_rays{iset}=opts_rays_used;
        aux_out.rayss{iset}=rays;
    end
    data_out.ds=ds_align;
    data_out.sas=sas_align;
    data_out.sets=sets_align;
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
end
return
end
