function [data_out,aux_out]=rs_knit_coordsets(data_in,aux)
% Knits a `dataset structure` into a consensus, and provides and displays statistics
%
% Each of the records in the `dataset structure` data_in should contain the same stimuli, 
% and in the same order, as determined by the strings in data_in.sas{k}.typenames for the record k.
% Missing data (e.g., for the stimulus s labeled by data_in.sas{k}.typenames{s}) should be indicated by 
% NaN's in the row data_in.sets{k}{idim}(s,:), a row of length idim.  This
% form of data_in is provided by the `dataset structure` returned by `rs_align_coordsets` [how to hyperlink?].
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
%     - opts_knit (struct): options for knitting and consistency checking, with fields
%
%       - if_log (int): 1 to log progress, 0 to suppress; default is 1
%       - allow_reflection (int): 1 to allow reflection, 0 does not allow; default is 1
%       - allow_offset (int): 1 to allow translational offset, 0 does not allow; default is 1
%       - allow_scale (int): 1 to allow scaling, 0 does not allow; default is 0
%       - if_normscale (int): 1 to normalize consensus to RMS size of data, 0 does not, has no effect if allow_scale=0; default is 0
%       - if_pca (int): 1 to rotate the consensus data_out.ds{1}.{idim} so that the dimensions correspond to principal components, 0 does not; default is 0
%
%     - opts_check (struct): options for consistency checking, with field
%
%       - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
%
%     - opts_rays (struct): options for rays, typically omitted, see note below regarding rays
%
% aux.opts_knit:
%  max_iters: max iterations for Procrustes consensus, default=1000
%  if_stats: 1 to do statistics of variance explained (0 is default)
%  nshuffs: number of shuffles, defaults to 500 if if_stats=1, 0 if if_stats=0
%     Note that to just compute statistics of variance explained, without shuffles, set if_stats=1, nshuffs=0.
%  if_plot: 1 to plot statistics, defaults to if_stats
%  shuff_quantiles: quantiles to plot, defaults to [0.01 0.05 0.5 0.95 0.99];
%  dim_max_in: maximum dimension of the component set to use, defaults to max available across all datasets
%  dim_list_in: list of dimensions of component set to use, defaults to [1:max_dim_in]
%  dim_aug: number of dimensions to augment by, defaults to 0
%  dim_list_out: list of dimensions of sets to create, defaults to dim_aug+[dim_list_in]
%  knit_stats, knit_stats setup:  only include to replot.  
%
%  aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
%
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
%    warnings: warnings generated in creating arguments for psg_get_coordsets
%    warn_bad: count of warnings that prevent further processing
%    opts_knit: aux.opts_knit, as used
%    opts_rays: options used for finding rays in the kniited set
%    opts_pcon{id}: options used in Procrustes alignment for model dimension id
%    coords_havedata: [stims x sets] is 1 where data are present.
%       Note that this may differ from aux_out.ovlp_array in rs_align_coordsets,
%       in that if an input file lists a stimulus but the response is NaN, then
%       it will appear as present in rs_align_coordsets output aux_out.ovlp_array,
%       but as absent in rs_knit_coordsets.aux_out.coords_havedata
%    rayss{1}: ray structure for knitted datasets
%    components.ds{k},sas{k},sets{k},rayss{k}: % coordinates and dataset descriptors of individual dataseets, after rotation/translation to alignment
%       coordinates will be NaN if not present
%    knit_stats: statistics of knitting, and the transformations used from the component sets data_in.ds{iset} to consensus data_out.ds{1}
%       The transformation is  [consensus]=ts.scaling*[component]*ts.orthog+ts.translation
%          If dim_list_out>dim_list_in, then component needs to be right-padded by columns of zeros for missing dimensions
%       The transformation in knit_stats.ts{ip}{iset} is the transformation from the component set to the consensus
%       This does *not* take into account the further rotation of the consensus carried out if if_pca=1.
%       For this, see aux_out.ts_pca{ip}{iset} 
%       See the ra field of psg_[knit|align]_stats for details on statistics
%    knit_stats_setup: statistics parameters, extracted from input, to be used for plotting
%       if if_plot=1 (default if if_stats=1) figure will be plotted.
%    fig_handle: handle to figure (present only if stats are plotted)
%    details: details of the convergence towards knitting (present only if aux.opts_knit.keepd_details=1)
%    ts_pca{ip}{iset}: transformation from components to consensus, taking into account final pca if if_pca=1 (present only if if_pca=1) 
%
%
% This can also be used to replot a previous calculation, with greater customization. To do this:
%   data_in should be equal to that used in the previous calculation.
%   aux.knit_stats should be equal to aux_out.knit_stats from the previous calculation.
%   aux.knit_stats_setup should be equal to aux_out.knit_stats_setup from
%   the previous calculation, with the following possible modifications:
%   In this mode, no further calculations are done, and data_out will be empty, and aux_out.fig_handle will be the figure handle.
%     but also aux.knit_stats_setup can be customized by setting the following fields
%         knit_stats_setup.dataset_labels, as a cell array (defaults to data_in.sets{:}.label)
%         knit_stats_setup.stimulus_labels, as a cell array (defaults to the typenames of the aligned datasets)
%         knit_stats_setup.shuff_quantiles, as a vector (defaults to[0.01 0.05 0.5 0.95 0.99]);
%         knit_stats_setup.fig_handle: figure handle to plot into
%         knit_stats_setup.nrows: number of rows in the figure
%         knit_stats_setup.row: row to plot into
%             Note: rows should be plotted in order, as plotting final row triggers an equalization of the color scale
%
%           warnings: 'dimension lists do not agree across datasets; intersection is available for processing'
%        warn_bad: 0
% coords_havedata: [25×3 double]
%           rayss: {[1×1 struct]}
%       opts_rays: {[1×1 struct]}
%       opts_knit: [1×1 struct]
%       opts_pcon: {7×1 cell}
%        opts_pca: [1×1 struct]
%      components: [1×1 struct]
% 
% 
%
% General notes, first two are to be edited:
%     - For all records with data_in.sets{k}.type='data', the strings in data_in.sets{k}.paradigm_type must agree.
%     - Pipeline: data_out.sets{k}.pipeline.sets{1} contains metadata for the kth record of data_in;
%       data_out.sets{k}.pipeline.sets_combined{:} contains metadata from all records of data_in.
%     - The 'type' field of data_in.sets{1} is propagated to data_out.sets{1}
%
%  See also: RS_ALIGN_COORDSETS, RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, RS_FINDRAYS,
%  RS_ALIGN_COORDSETS, PSG_ALIGN_COORDSETS, PSG_KNIT_STATS,
%  PSG_REMNAN_COORDSETS, PSG_COORD_PIPE_UTIL, PROCRUSTES_CONSENSUS, PSG_ALIGN_STATS_PLOT.
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
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
if aux.opts_knit.if_stats
    aux.opts_knit=filldefault(aux.opts_knit,'nshuffs',500);
else
    aux.opts_knit=filldefault(aux.opts_knit,'nshuffs',0);
end
aux.opts_knit=filldefault(aux.opts_knit,'shuff_quantiles',[0.01 0.05 0.5 0.95 0.99]);
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
%
set_knit_strings={'paradigm_name','subj_id','subj_id_short','extra','label_long','label'}; %fields to be concatenated in knitted metadata
%
%check consistency and get available stimuli, dimensions, typenames
%
check=rs_check_coordsets(data_in,aux.opts_check);
%
aux_out.warnings=check.warnings;
aux_out.warn_bad=check.warn_bad;
%
% replot mode
%
if isfield(aux,'knit_stats') & isfield(aux,'knit_stats_setup')
    knit_stats_setup_use=aux.knit_stats_setup;
    if isfield(knit_stats_setup_use,'fig_handle') %psg_knit_stats_plot expects figure handle in figh
        knit_stats_setup_use.figh=knit_stats_setup_use.fig_handle;
    end
    aux_out.fig_handle=psg_knit_stats_plot(aux.knit_stats,knit_stats_setup_use);
    return
end
%
nsets=check.nsets;
nstims_each=check.nstims_each;
dim_list_each=check.dim_list_each;
dim_list_union=check.dim_list_union;
dim_list_inter=check.dim_list_inter;
typenames_each=check.typenames_each;
typenames_union=check.typenames_union;
typenames_inter=check.typenames_inter;
%
if min(nstims_each)~=max(nstims_each)
    disp('cannot proceed');
    disp(aux_out.warnings);
    return
end
%
%inspect input data to see where data are missing
%note that a NaN can indicate that stimulus was present and response
%was missing, OR, that the stimulus was not presented
%
nstims_all=min(nstims_each);
coords_isnan=zeros(nstims_all,nsets);
for iset=1:nsets
    for kd=dim_list_each{iset}
        coords_isnan(:,iset)=or(coords_isnan(:,iset),any(isnan(data_in.ds{iset}{kd}),2)); %if data are missing for any dimension, it's missing
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
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
end
%
%if aux.sa_pooled is present, use it, otherwise, re create
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
    aux2=aux;
    aux2.opts_align.if_log=aux.opts_knit.if_log;
    [data_align,aux_align]=rs_align_coordsets(data_in_nonan,aux2);
    sa_pooled=aux_align.sa_pooled;
end
if length(intersect(sa_pooled.typenames,typenames_union))~=length(union(sa_pooled.typenames,typenames_union))
    wmsg=sprintf('pooled typenames are incompatible with type names from individual datasets');
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
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
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
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
        warn_leadin=getfield(getfield(rs_aux_customize(struct()),'overall'),'warn_leadin');
        for k=1:size(warnings,1)
            disp(cat(2,warn_leadin,warnings(k,:)));
        end
    end
    ds_knitted=ra.ds_knitted;
    ds_components=ra.ds_components;
    opts_pcon_used=ra.opts_pcon_eachdim'; %make a column for consistency 
    details=details'; %make a column for consistency
    %
    %implement PCA rotation if requested:  note that this is applied both
    %to consensus and components in output, but not in knit_stats.components
    %
    if aux.opts_knit.if_pca
        ts_pca=cell(1,max(dim_list_in));
        for dptr=1:length(dim_list_out)
            ip=dim_list_in(dptr);
            ip_out=dim_list_out(dptr);
            knitted_centroid=mean(ds_knitted{ip_out},1,'omitnan');
            [ds_knitted{ip_out},recon_coords,var_ex,var_tot,coord_maxdiff,opts_used_pca]=psg_pcaoffset(ds_knitted{ip_out},knitted_centroid,aux.opts_pca);
    %        qu=opts_used_pca.qu;
    %        qs=opts_used_pca.qs;
            v=opts_used_pca.qv;
    %       coords=u*s*v', and recon_coords= u*s, with v'*v=I, so recon_coords=coords*v
            for iset=1:nsets
                consensus_centroid_rep=repmat(mean(ds_components{iset}{1,ip_out},1,'omitnan'),nstims_all,1);
                ds_components{iset}{1,ip_out}=consensus_centroid_rep+(ds_components{iset}{1,ip_out}-consensus_centroid_rep)*v(1:ip_out,:);
                %determine transformation to consensus followed by pca
                ts_pca{ip}{iset}.scaling=ra.ts{ip}{iset}.scaling;
                ts_pca{ip}{iset}.orthog=ra.ts{ip}{iset}.orthog*v(1:ip_out,:);
                ts_pca{ip}{iset}.translation=consensus_centroid_rep(1,:)+(ra.ts{ip}{iset}.translation-consensus_centroid_rep(1,:))*v(1:ip_out,:);
            end
        end %dptr
        aux_out.ts_pca=ts_pca;
    end
    %
    %if statistics, keep them
    %
    if aux.opts_knit.if_stats
        knit_stats_setup.nsets=nsets;
        knit_stats_setup.dim_list_in_max=max(dim_list_in);
        knit_stats_setup.dim_list_in=dim_list_in;
        knit_stats_setup.dim_list_out=dim_list_out;
        knit_stats_setup.dataset_labels=cell(1,nsets);
        for iset=1:nsets
            knit_stats_setup.dataset_labels{iset}=data_in.sets{iset}.label;
        end
        knit_stats_setup.stimulus_labels=typenames_all;
        knit_stats_setup.nshuffs=aux.opts_knit.nshuffs;
        knit_stats_setup.shuff_quantiles=aux.opts_knit.shuff_quantiles;
        knit_stats_setup.nstims=nstims_all;
        %
        aux_out.knit_stats=ra;
        aux_out.knit_stats_setup=knit_stats_setup;
        if aux.opts_knit.if_plot
            knit_stats_setup_use=aux_out.knit_stats_setup;
            if isfield(knit_stats_setup_use,'fig_handle')
                knit_stats_setup_use.figh=knit_stats_setup_use.fig_handle; %psg_knit_stats_plot expects figure handle in figh
            end
            aux_out.fig_handle=psg_knit_stats_plot(aux_out.knit_stats,knit_stats_setup_use);
        end
    end
    sas_knitted=sa_pooled;
    %
    %knitted set structure
    sets_knitted=struct;
    sets_knitted.nstims=nstims_all;
    sets_knitted.dim_list=dim_list_out;
    for ifn=1:length(set_knit_strings)
        fn=set_knit_strings{ifn};
        sets_knitted.(fn)=''; % was []
        for iset=1:nsets
            if isfield(data_in.sets{iset},fn)
                sets_knitted.(fn)=cat(2,sets_knitted.(fn),char(data_in.sets{iset}.(fn)),'+');
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
        aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
    end
    %
    %dim list and pipeline for component sets
    for iset=1:nsets
        data_in.sets{iset}.dim_list=dim_list_out;
        data_in.sets{iset}.pipeline=psg_coord_pipe_util('knit',pipeline_opts,data_in.sets{iset},[],data_in.sets);       
    end
    data_out.ds{1}=ds_knitted;
    data_out.sas{1}=sas_knitted;
    data_out.sets{1}=sets_knitted;
    data_out.sets{1}.type=data_in.sets{1}.type;
    %
    aux_out.rayss{1}=rays;
    aux_out.opts_rays{1}=opts_rays_used;
    aux_out.opts_knit=aux.opts_knit;
    aux_out.opts_pcon=opts_pcon_used;
    aux_out.opts_pca=aux.opts_pca;
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
    disp(aux_out.warnings);
end
return
end
