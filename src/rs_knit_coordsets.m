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
%       - allow_offset (int): 1 to allow translational offset, 0 does not allow; default is 1
%       - allow_scale (int): 1 to allow scaling of each dataset into the consensus, 0 does not allow; default is 0
%       - allow_reflection (int): 1 to allow reflection, 0 does not allow; default is 1
%       - if_normscale (int): 1 to normalize consensus to size of data_in (determined by geometric mean of scale factors for each dataset), 0 does not, has no effect if allow_scale=0; default is allow_scale
%       - if_pca (int): 1 to rotate the consensus coordinates in data_out into its principal components, 0 does not; default is 0
%       - if_stats (int): 1 to do statistics of variance explained, 0 does not; default is 0
%       - if_plot (int): 1 to plot statistics, 0 does not; default is if_stats
%       - nshuffs (int): number of shuffles for calculating statistics; default is 500 if if_states=1, 0 if if_stats=0; see note below regarding statistics and plots
%       - shuff_quantiles (float 1-D array): quantiles to plot; default is [0.01 0.05 0.5 0.95 0.99]
%       - dim_max_in (int): maximum dimension of data_in.ds to use; default is maximum available across all datasets
%       - dim_list_in (int 1-D array): list of dimensions to use from data_in.ds; default is [1:dim_max_in]
%       - dim_aug (int): number of additional dimensions in data_out.ds; default is 0; see note below regarding Procrustes consensus algorithm
%       - dim_list_out (int 1-D array): list of dimensions to create in data_out.ds; if specified, must have same length as dim_list_in; default is [1:dim_list_in]+dim_aug
%       - knit_stats (struct): include to replot a previous analysis, otherwise omit; see note below regarding replotting
%       - knit_stats_setup (struct): include to replot a previous analysis, oterwise omit; see note below regarding replotting
%       - max_niters (int): maximum number of iterations for Procrustes consensus; default is 1000; see note below regarding Procrustes consensus algorithm
%       - pcon_init_method (int or char): typically omitted; default is 0; see note below regarding Procrustes consensus algorithm
%       - if_initpca_rot (int): typically omitted, default is 1 unless any of dim_list_out>dim_list_in; see note below regarding Procrustes consensus algorithm
%       - max_iters (int): maximum number of iterations for Procrustes consensus; default is 1000; see note below regarding Procrustes consensus algorithm
%       - max_rmstol (int): maximum change ofcoordinates for consensus solution; default is 10^-5; see note below regarding Procrustes consensus algorithm
%       - keep_details (int): 1 to return details of Procrustes consensus mimimization, 0 does not; default is 0; see note below regarding Procrustes consensus algorithm
%       - pcon_initial_guess (cell array): specified initial guess for Proccrustes minimization, typically omitted; see note below regarding Procrustes consensus algorithm
%       - pcon_alignment (cell array): specified alignment for Procrustes minimization, typically omitted; see note below regarding Procrustes consensus algorithm
%       - if_frozen (int): `random number control`, used for shuffles and initialization, 1 for same numbers every run, 0 for different random numbers each run, negative integer for a fixed seed each run; 
%        default is 1; see notes below regarding statistics and Procrustes consensus algorithm
%
%     - opts_check (struct): options for consistency checking, with field
%
%       - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
%
%     - opts_pcon (struct): options used in Procrustes alignment; see note below regarding Procrustes consensus algorithm
%     - opts_pca (struct): options for principal components analysis of consensus, typically omitted, only relevant if if_pca=1
%     - opts_rays (struct): options for rays, typically omitted; see note below regarding rays
%     - opts_align (struct): options for alignment of data, typically; see note below regarding recalculation of alignment
%
%     - sa_pooled (struct): include to avoid recalculation of alignment, otherwise omit; see note below regarding recalculation of alignment
%     - data_align (struct): include to avoid recalculation of align ment, otherwise omit; see note below regarding recalculation of alignment
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
% aux_outs{5}.knit_stats
% ans = 
%   struct with fields:
% 
%                opts_pcon: [1×1 struct]
%        opts_pcon_eachdim: {[1×1 struct]  [1×1 struct]  [1×1 struct]  [1×1 struct]  [1×1 struct]  [1×1 struct]  [1×1 struct]}
%               ds_knitted: {[37×1 double]  [37×2 double]  [37×3 double]  [37×4 double]  [37×5 double]  [37×6 double]  [37×7 double]}
%            ds_components: {{1×7 cell}  {1×7 cell}}
%                       ts: {{1×2 cell}  {1×2 cell}  {1×2 cell}  {1×2 cell}  {1×2 cell}  {1×2 cell}  {1×2 cell}}
%           counts_overall: 50
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
% Note regarding statistics and plots:
%     - If aux.opts_knit.if_stats=1, variance explained by the consensus
%     coordinates are calculated and returned in aux_outs.knit_stats, in the following fields:
%
%       - rmsdev_overall(idim): root-mean-squared deviation across all records and stimuli
%       - rmsdev_setwise(idim,irec): root-mean-squared deviation within each record, across stimuli
%       - rmsdev_stmwise(idim,istim): rood-mean-squared deviation within each stimulis, across records
%
%     - The counts for each of these calculations are counts_[overall|setwise|stmwise], and the available rms deviation (from the centroid) is given by rmsavail_[overall|setwise|stimwise].
%     - If aux.opts_knit.nshuffs>0 (default is 500), then a parallel computation is done after random shuffles of the stimulus labels within each record,
%     and the results are returned in
%     rmsdev_[overall|setwise|stimwise]_shuff.
%     For the shuffled quantities, the first two dimensions are the same as the unshuffled quantities; dimension 3 is
%     always 1; dimension 4 (length: nshuffs) is which shuffle; and dimension 5 (length: 2) is the mode: in mode 1, all coordinates
%     are shuffled, in mode 2 only the last coordinate is shuffled.
%     To control whether the same random number seed is used on each run, use aux.opts_knit.if_frozen (default is 1).
%     - if aux.opts_knit.if_plot=1 (default if if_stats=1), then a figure is created, with four panels:
%
%       - a heatmap of rmsdev_setwise
%       - a heatmap of rmsdev_stmwise
%       - a comparison of rmsdev_overall (black) to quantiles of
%       rmsdev_overall_shuff (mode 1: magenta, mode 2: red); quantiles are specified by shuff_quantiles; if
%       nshuffs=0, then the shuffled values will not be plotted
%       - a comparison of the explained rms deviation, parallel to the above, with avilable rms deviation in blue
%     
% Note regarding recalculation of alignment:
%     The first step in forming a consensus is alignment, which identifies the common stimuli among the records of data_in, and to 
%     place them in the same order. By default, this is carried out in rs_knit_coordsets by a call to rs_align_coordsets, using options aux.align_opts.
%     This recalculation can be avoided by supplying aux_out from a
%     previous call to rs_align_coordsets, as follows: aux.sa_pooled=aux_out.sa_pooled, aux.data_align=aux_out.data_out
%
% Note regarding Procrustes consensus algorithm:
%     - To find a consensus set of coordinates, the coordinates in each record of data_in are rotated, and optionally translated (based on allow_offset),
%     scaled (based on allow_scale), and reflected (based on allow_reflection). These transformatoins are carried out for separately for each set dimension
%     for which coordinates are present in all of the records, i.e., for which data_in.ds{k}{idim} exists for all k.
%     - The algorithm, in procrustes_consensus.m, is iterative.  Briefly, after an initial guess is determined, a Procrustes 
%     transformation is found that minimizes the rms deviation between that dataset and the current guess. The guess is then
%     revised by setting each stimulus' coordinates equal to the centroid of the coordinates of that stimulus across the records, and then Procrustes-transformed for closest match
%     to an alignment coordinate set (so that the guess does not drift), which, unless otherwise specified, is equal to the initial guess.
%     - The iteration ends when either the number of iterations exceeds max_niters (default=1000),
%     or the rms change of the guess is less than max_rmstol (default=10^-5)
%     - There are several choices for initialization and alignment.
%
%       - For most purposes, the default initialization method (aux.opts_knit.pcon_init_method=0) can be used, which uses the principal components of all the stimulus coordinates in all of the records.
%       These can be optionally forced to be centered (pcon_init_method=-1) or not (pcon_init_method=-2); if unspecified (default), centering is determined by allow_offset.
%       For these choices, if_initpca_rot=1 rotates the initial guess to match the data, or
%       not. The default for if_init_pca is 1 unless any of dim_list_out>dim_list_in, in which case it is 0.
%       The heuristic for not rotating if dim_list_out>dim_list_in, i.e., two or more sets of coordinates are to be knit together to construct a coordinate set with a greater number of dimensions,
%       is that without rotation, the principal components reflect projections of the coordinates that are present in any of the records.
%       -  Alternatively, pcon_init_method=r, r>0, specifies that the coordinates in data_in{r}{idim} are used.
%       -  If pcon_init_method='specify', then pcon_initial_guess{idim} is an array of size [npts ids] for the
%       initial guess, and pcon_alignment{idim}, which defaults to
%       pcon_initial_guess, is used for the alignment at the end of each iteration.  pcon_initial_guess and pcon_alignment may be omitted, in which case random values are used.
%       To control whether the same random number seed is used on each run, use aux.opts_knit.if_frozen (default is 1).
%     - The solution is only unique up to rotation (and translation and reflection, if these components are allowed).  The ambiguity is resolved by
%     matching the consensus solution to the initial guess (or, pcon_alignment{idim} if separately supplied with pcon_init_method=0), as described above.
%     - Under some circumstances (e.g., several solutions that are nearly equally good), the solution found by the algorithm may depend on
%     the initialization choice.  A simple strategy to check for this is to compare the results with the default pcon_init_method=0 to the results with
%     pcon_init_method='specify' and if_frozen=0. There are two ways that this dependency can happen.
%
%       - One is that the number of overlapping stimuli is too small. For example,
%       at least n points are required to determine a rotation and translation in an n-dimensional space; if there are fewer overlaps, then a consensus will
%       still be found but there are many other consensus datasets that fit equally well.
%       - A second way is that there are a sufficient number of points, but there are several solutions that are approximately equally good. 
%       Under these circumstances, the algorithm may get stuck in a local minimum. This possibility only occurs when there are at least three records in data_in, as the procedure reduces to
%       the standard Procrustes algorithm, which finds the consensus when there are only two records, is deterministic other than does rotational ambiguity.
% 
% Note regarding replotting a previous analysis:
%     - Brief description: TBD
%     - This is demonstrated in rs_knit_coordsets_demo.
%
% General notes, first two are to be edited:
%     - For all records with data_in.sets{k}.type='data', the strings in data_in.sets{k}.paradigm_type must agree.
%     - Pipeline: data_out.sets{k}.pipeline.sets{1} contains metadata for the kth record of data_in;
%       data_out.sets{k}.pipeline.sets_combined{:} contains metadata from all records of data_in.
%     - The 'type' field of data_in.sets{1} is propagated to data_out.sets{1}
%
% See also:
%   RS_ALIGN_COORDSETS, RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, RS_FINDRAYS,
%   PSG_ALIGN_COORDSETS, PSG_KNIT_STATS,
%   PSG_REMNAN_COORDSETS, PSG_COORD_PIPE_UTIL, PROCRUSTES_CONSENSUS, PSG_ALIGN_STATS_PLOT.
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_knit',struct);
aux.opts_knit=filldefault(aux.opts_knit,'if_log',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_reflection',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_offset',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_scale',0);
aux.opts_knit=filldefault(aux.opts_knit,'if_normscale',aux.opts_knit.allow_scale);
aux.opts_knit=filldefault(aux.opts_knit,'if_stats',0);
aux.opts_knit=filldefault(aux.opts_knit,'if_plot',aux.opts_knit.if_stats);
aux.opts_knit=filldefault(aux.opts_knit,'if_pca',0);
aux.opts_knit=filldefault(aux.opts_knit,'max_niters',1000);
aux.opts_knit=filldefault(aux.opts_knit,'max_rmstol',10^-5);
aux.opts_knit=filldefault(aux.opts_knit,'pcon_init_method',0);
aux.opts_knit=filldefault(aux.opts_knit,'keep_details',0);
aux.opts_knit=filldefault(aux.opts_knit,'pcon_initial_guess',[]);
aux.opts_knit=filldefault(aux.opts_knit,'pcon_alignment',aux.opts_knit.pcon_initial_guess);
aux.opts_knit=filldefault(aux.opts_knit,'if_frozen',1);
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
    opts_align_used=aux.opts_align;
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
    opts_align_used=aux_align.opts_align;
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
    if ischar(aux.opts_knit.pcon_init_method)
        if strcmp(aux.opts_knit.pcon_init_method,'specify')
            aux.opts_knit.initialize_set=0; %opts_knit.pcon_initial_guess and opts_knit.pcon_alignment will be used
        else
            wmsg='initialization method not recognized; default used';
            aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
            aux.opts_knit.pcon_init_method=0;
            aux.opts_knit.initialize_set='pca';
        end
    else
        if aux.opts_knit.pcon_init_method>0
            aux.opts_knit.initialize_set=aux.opts_knit.pcon_init_method;
        elseif aux.opts_knit.pcon_init_method==0
            aux.opts_knit.initialize_set='pca';
        elseif aux.opts_knit.pcon_init_method==-1
            aux.opts_knit.initialize_set='pca_center';
        else
            aux.opts_knit.initialize_set='pca_nocenter';
        end
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
    aux_out.opts_align=opts_align_used;
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
