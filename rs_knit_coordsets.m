function [data_out,aux_out]=rs_knit_coordsets(data_in,aux)
% [data_out,aux_out]=rs_knit_coordsets(data_in,aux) finds consensus coordinates across one or more datasets
% with partially overlapping stimuli
% data_in.sas{k}.typenames is used to establish stimulus identity
%
% data_in.ds{k},sas{k},sets{k}: the structures of coordinates (ds) and metadata (sas,sets)
%   These are typically created by rs_align_coordsets, but could also be directly from 
%   rs_get_coordsets or rs_read_coorddata if stimuli are identical across
%   datasets, as listed in data_in.sas{k}.typenames
%
% aux.opts_knit:
%  if_log: 1 to log progress
%  allow_reflection: 1 to allow reflection (default=1)
%  allow_offset: 1 to allow offset (default=1) 
%  allow_scale: 1 to allow scale, (default=0)opts_pcon=filldefault(opts_pcon,'allow_scale',0);
%  if_normscale: 1 to normalize consensus to size of data (default=0)
%  if_pca:  1 to rotate consensus into PCA space (default=0)
%  max_iters: max iterations for Procrustes consensus, default=1000
%  if_stats: 1 to do statistics via shuffling labels (0 is default)
%  nshuffs: number of shuffles, defaults to 500 if if_stats=1, 0 if if_stats=0
%  if_plot: 1 to plot statistics, defaults to if_stats
%  dim_max_in: maximum dimension of the component set to use, defaults to max available across all datasets
%  dim_list_in: list of dimensions of component set to use, defaults to [1:max_dim_in]
%  dim_aug: number of dimensions to augment by, defaults to 0
%  dim_list_out: list of dimensions of sets to create, defaults to dim_aug+[dim_list_in]
%    optional, if both are not supplied, they will be computed here
%  aux.sa_pooled, aux_out.sa_pooled, from rs_align_coordsets
%  aux.data_align: data_out, from rs_align_coordsets
%
%  pcon_init_method: initialization method: >0: a specific set, 0 for PCA, -1 for PCA with forced centering, -2 for PCA with forced non-centering', defaults to 0
%  if_initpca_rot: (if pcon_init_method<=0) whether to rotate
%     initialization to match data (1), or not (0), defaults to 1 unless any of dim_list_out> dim_list_in
%  keep_details: 1 to keep details field (defaults to 0)
% 
% data_out.ds{1},sas{1},sets{1}:  consensus coordinates and dataset descriptors after alignment
% aux_out: auxiliary outputs and parameter values used
%    opts_knit: overall options used
%    opts_pcon{id}: options used in Procrustes alignment for model dimension id
%    coords_havedata: [stims x sets] is 1 where data are present.
%       Note that this may differ from aux_out.ovlp_array in rs_align_coordsets,
%       in that if an input file lists a stimulus but the response is NaN, then
%       it will appear as present in rs_align_coordsets output aux_out.ovlp_array,
%       but as absent in rs_knit_coordsets.aux_out.coords_havedata
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%   rayss{1}: ray structure for knitted datasets
%   components.ds{k},sas{k},sets{k},rayss{k}: % coordinates and dataset descriptors of individual dataseets, after rotation/translation to alignment
%       coordinates will be NaN if not present
%   details: details of the convergence towards knitting
%   knit_stats: statistics of knitting, and the transformatoins used
%       see the ra field of psg_[knig|align]_stats for details
%       Note that the transformatoin, knit_stats.ts, does not take into account the transformaton by if_pca
%   knit_stats_setup: statistics parameters, extracted from input, to be used for plotting
%   if if_plot=1 (default if nshuffs>0) figure will be plotted by psg_knit_stats_plot(knit_stats,knit_stats_setup), 
%     but also knit_stats_setup can be customized by setting 
%         knit_stats_setup.dataset_labels
%         knit_stats_setup.stimulus_labels
%         knit_stats_setup.shuff_quantiles
%   knit_stats_fig: handle to figure, if stats are plotted
%
%  See also: RS_ALIGN_COORDSETS, RS_AUX_CUSTOMIZE, RS_FINDRAYS,
%  RS_ALIGN_COORDSETS, PSG_ALIGN_COORDSETS, PSG_KNIT_STATS,
%  PSG_REMNAN_COORDSETS, PSG_COORD_PIPE_UTIL, PROCRUSTES_CONSENSUS.
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_knit',struct);
aux.opts_knit=filldefault(aux.opts_knit,'if_log',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_reflection',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_offset',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_scale',0);
aux.opts_knit=filldefault(aux.opts_knit,'if_normscale',0);
aux.opts_knit=filldefault(aux.opts_knit,'if_pca',0);
aux.opts_knit=filldefault(aux.opts_knit,'max_niters',1000);
aux.opts_knit=filldefault(aux.opts_knit,'pcon_init_method',0);
aux.opts_knit=filldefault(aux.opts_knit,'keep_details',0);
aux.opts_knit=filldefault(aux.opts_knit,'if_stats',0);
aux.opts_knit=filldefault(aux.opts_knit,'if_plot',aux.opts_knit.if_stats);
%
if aux.opts_knit.if_stats
    aux.opts_knit=filldefault(aux.opts_knit,'nshuffs',500);
else
    aux.opts_knit=filldefault(aux.opts_knit,'nshuffs',0);
end
%
aux=filldefault(aux,'opts_pca',struct);
aux.opts_pca=filldefault(aux.opts_pca,'if_log',0);
aux.opts_pca=filldefault(aux.opts_pca,'nd_max',Inf);
%
aux=filldefault(aux,'opts_rays',struct);
%
aux=filldefault(aux,'opts_align',struct);
%
aux=rs_aux_customize(aux,'rs_knit_coordsets');
%
data_out=struct;
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
set_knit_strings={'paradigm_name','subj_id','subj_id_short','extra','label_long','label'}; %fields to be concatenated in knitted metadata
%
nsets=length(data_in.sets);
nstims_each=zeros(1,nsets);
dim_list_each=cell(1,nsets);
dim_list_union=[];
typenames_each=cell(1,nsets);
typenames_union=[];
%validate the datasets
for iset=1:nsets
    nstims_each(iset)=data_in.sets{iset}.nstims;
    typenames_each{iset}=data_in.sas{iset}.typenames;
    dim_list_each{iset}=data_in.sets{iset}.dim_list;
    if iset==1
        typenames_inter=typenames_each{iset};
        dim_list_inter=dim_list_each{iset};
    end
    typenames_union=union(typenames_union,typenames_each{iset});
    typenames_inter=intersect(typenames_inter,typenames_each{iset});
    dim_list_union=union(dim_list_union(:)',dim_list_each{iset});
    dim_list_inter=intersect(dim_list_inter,dim_list_each{iset});
end
if min(nstims_each)~=max(nstims_each)
    wmsg=sprintf('number of stimuli do not agree across files (min: %3.0f, max: %3.0f)',min(nstims_each),max(nstims_each));
    warning(wmsg);
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;
end
if length(typenames_inter)~=length(typenames_union)
    wmsg=sprintf('stimulus names do not agree across files');
    warning(wmsg);
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;
    disp('discrepancies')
    disp(setdiff(typenames_union,typenames_inter));
end
if length(dim_list_union)~=length(dim_list_inter)
    wmsg=sprintf('dimension lists do not agree across files'); %this is OK, process the intersection
    warning(wmsg);
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    disp('discrepancies')
    disp(setdiff(dim_list_union,dim_list_inter));
end
%inspect input data to see where data are missing
%note that a NaN can indicate that stimulus was present and response
%was missing, OR, that the stimulus was not presented
%
nstims_all=min(nstims_each);
coords_isnan=zeros(nstims_all,nsets);
for iset=1:nsets
    for kd=dim_list_each{iset}
        coords_isnan(:,iset)=or(coords_isnan(:,iset),any(isnan(data_in.ds{iset}{kd}),2)); %if data are missing for any dimenison, it's missing
    end
    if aux.opts_knit.if_log
        disp(sprintf(' number of stimuli missing in dataset %3.0f: %4.0f',iset,sum(coords_isnan(:,iset),1)));
    end
end
aux_out.coords_havedata=1-coords_isnan;
if aux.opts_knit.if_log
    disp('data table')
    disp(aux_out.coords_havedata'*aux_out.coords_havedata)
end
if any(all(coords_isnan,2))
    wmsg=sprintf('one or more stimuli never appear');
    warning(wmsg);
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;
end
%
%if aux.sa_pooled is present, use it, otherwise, re=create
if (isfield(aux,'sa_pooled') & isfield(aux,'data_align'))
    if (aux.opts_knit.if_log)
        disp('sa_pooled and data_align are supplied.');
    end
    sa_pooled=aux.sa_pooled;
    data_align=aux.data_align;
else
    if (aux.opts_knit.if_log)
        disp('sa_pooled and data_align will be created.');
    end
    %redo the alignment, but first remove the nans in the aligned file; this would confuse if realigned
    [sets_nonan,ds_nonan,sas_nonan]=psg_remnan_coordsets(data_in.sets,data_in.ds,data_in.sas,[],setfield(struct,'if_log',aux.opts_knit.if_log));
    data_in_nonan=struct;
    data_in_nonan.ds=ds_nonan;
    data_in_nonan.sas=sas_nonan;
    data_in_nonan.sets=sets_nonan;
    [data_align,aux_align]=rs_align_coordsets(data_in_nonan,aux);
    sa_pooled=aux_align.sa_pooled;
end
if length(intersect(sa_pooled.typenames,typenames_union))~=length(union(sa_pooled.typenames,typenames_union))
    wmsg=sprintf('pooled typenames are incompatible with type names from individual datasets');
    aux_out.warn_bad=aux_out.warn_bad+1;
    disp('discrepancies')
    disp(setdiff(typenames_union,sa_pooled.typenames));
end
%
%set up dimension defaults
%
dim_list_all=dim_list_inter;
aux.opts_knit=filldefault(aux.opts_knit,'dim_max_in',max(dim_list_all));
aux.opts_knit=filldefault(aux.opts_knit,'dim_list_in',[1:aux.opts_knit.dim_max_in]);
aux.opts_knit=filldefault(aux.opts_knit,'dim_aug',0);
aux.opts_knit=filldefault(aux.opts_knit,'dim_list_out',aux.opts_knit.dim_aug+aux.opts_knit.dim_list_in);
if length(aux.opts_knit.dim_list_in)~=length(aux.opts_knit.dim_list_out)
    wmsg=sprintf('dim_list_in and dim_list_out have different lengths');
    aux_out.warn_bad=aux_out.warn_bad+1;
else
    if_aug=any(aux.opts_knit.dim_list_out>aux.opts_knit.dim_list_in);
    aux.opts_knit=filldefault(aux.opts_knit,'if_initpca_rot',1-if_aug);
end
if aux_out.warn_bad==0
%process
    typenames_all=typenames_inter;
    dim_list_in=aux.opts_knit.dim_list_in;
    dim_list_out=aux.opts_knit.dim_list_out;
    %
    if aux.opts_knit.if_log
        disp(sprintf('knitting %3.0f stimuli across %3.0f datasets, dimensions %s',nstims_all,nsets,sprintf(' %2.0f',dim_list_in))); 
        disp(sprintf('  allow reflection: %1.0f, allow offset: %1.0f, allow scale: %1.0f, normalize scale: %1.0f, rotate to pcs: %1.0f',...
            aux.opts_knit.allow_reflection,aux.opts_knit.allow_offset,aux.opts_knit.allow_scale,aux.opts_knit.if_normscale,aux.opts_knit.if_pca));
    end
    if aux.opts_knit.if_pca
        c2p_string='-pc';
    else
        c2p_string='';
    end
    if aux.opts_knit.pcon_init_method>0
        aux.opts_knit.initialize_set=aux.opts_knit.pcon_init_method;
    elseif aux.opts_knit.pcon_init_method==0
        aux.opts_knit.initialize_set='pca';
    elseif aux.opts_knit.pcon_init_method==-1
        aux.opts_knit.initialize_set='pca_center';
    else
        aux.opts_knit.initialize_set='pca_nocenter';
    end
    %
    %do a consensus on each model-dimension separately
    %
    opts_pcon=aux.opts_knit;
    [ra,warnings,details]=psg_knit_stats(data_align.ds,data_align.sas,dim_list_in,dim_list_out,opts_pcon);
    if ~isempty(warnings)
        wmsg=strvcat(wmsg,warnings);
    end
    ds_knitted=ra.ds_knitted;
    ds_components=ra.ds_components;
    opts_pcon_used=ra.opts_pcon_eachdim'; %make a column for consistency 
    details=details'; %make a column for consistency
    %
    %if statistics, keep them
    %
    if aux.opts_knit.if_stats
        knit_stats_setup.nsets=nsets;
        knit_stats_setup.dim_list_in_max=max(dim_list_in);
        knit_stats_setup.dim_list_in=dim_list_in;
        knit_stats_setup.dataset_labels=cell(1,nsets);
        for iset=1:nsets
            knit_stats_setup.dataset_labels{iset}=data_in.sets{iset}.label;
        end
        knit_stats_setup.stimulus_labels=typenames_all;
        knit_stats_setup.nshuffs=aux.opts_knit.nshuffs;
        knit_stats_setup.nstims=nstims_all;
        %
        aux_out.knit_stats=ra;
        aux_out.knit_stats_setup=knit_stats_setup;
        if aux.opts_knit.if_plot
            aux_out.knit_stats_fig=psg_knit_stats_plot(aux_out.knit_stats,aux_out.knit_stats_setup);
        end
    end
    %
    %implement PCA rotation if requested:  note that this is applied both to consesnus and components
    %
    if aux.opts_knit.if_pca
        for dptr=1:length(dim_list_out)
            ip=dim_list_out(dptr);
            knitted_centroid=mean(ds_knitted{ip},1,'omitnan');
            [ds_knitted{ip},recon_coords,var_ex,var_tot,coord_maxdiff,opts_used_pca]=psg_pcaoffset(ds_knitted{ip},knitted_centroid,aux.opts_pca);
    %        qu=opts_used_pca.qu;
    %        qs=opts_used_pca.qs;
            v=opts_used_pca.qv;
    %       coords=u*s*v', and recon_coords= u*s, with v'*v=I, so recon_coords=coords*v
            for iset=1:nsets
                consensus_centroid_rep=repmat(mean(ds_components{iset}{1,ip},1,'omitnan'),nstims_all,1);
                ds_components{iset}{1,ip}=consensus_centroid_rep+(ds_components{iset}{1,ip}-consensus_centroid_rep)*v(1:ip,:);
            end
        end %ip
    end
    sas_knitted=sa_pooled;
    %
    %knitted set structure
    sets_knitted=struct;
    sets_knitted.nstims=nstims_all;
    sets_knitted.dim_list=dim_list_all;
    for ifn=1:length(set_knit_strings)
        fn=set_knit_strings{ifn};
        sets_knitted.(fn)=[];
        for iset=1:nsets
            if isfield(data_in.sets{iset},fn)
                sets_knitted.(fn)=cat(2,sets_knitted.(fn),data_in.sets{iset}.(fn),'+');
            end
        end
        if length(sets_knitted.(fn))>1
            sets_knitted.(fn)=sets_knitted.(fn)(1:end-1);
        end
    end
    pipeline_opts=struct;
    pipeline_opts.opts_knit=aux.opts_knit;
    pipeline_opts.opts_pcon=opts_pcon_used;
    sets_knitted.pipeline=psg_coord_pipe_util('knit',pipeline_opts,[],[],data_in.sets);
    %find rays
    [rays,wmsg,opts_rays_used]=rs_findrays(sas_knitted,sets_knitted.label,aux.opts_rays);
    if ~isempty(wmsg)
        wmsg=cat(2,sprintf('set %2.0f: ',iset),wmsg);
        warning(wmsg);
        aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    end
    %
    % %pipeline for component sets
    for iset=1:nsets
        data_in.sets{iset}.pipeline=psg_coord_pipe_util('knit',pipeline_opts,data_in.sets{iset},[],data_in.sets);
    end
    data_out.ds{1}=ds_knitted;
    data_out.sas{1}=sas_knitted;
    data_out.sets{1}=sets_knitted;
    %
    aux_out.rayss{1}=rays;
    aux_out.opts_rays{1}=opts_rays_used;
    aux_out.opts_knit=aux.opts_knit;
    aux_out.opts_pcon=opts_pcon_used;
    %
    aux_out.components.ds=ds_components;
    aux_out.components.sas=data_in.sas;
    aux_out.components.sets=data_in.sets;
    %
    if aux.opts_knit.keep_details
        aux_out.details=details;
    end
else
    disp('cannot proceed');
end
return
end
