function [data_out,aux_out]=rs_knit_coordsets(data_in,aux)
% [data_out,aux_out]=rs_knit_coordsets(data_in,aux)
% knits a `dataset structure` into a consensus, and provides and displays statistics
%
% Each of the records in the `dataset structure` `data_in` should contain the same stimuli, 
% and in the same order, as determined by the strings in data_in.sas{k}.typenames for the record k.
% Missing data (e.g., for the stimulus s labeled by data_in.sas{k}.typenames{s}) should be indicated by 
% NaN's in the row data_in.sets{k}{idim}(s,:), a row of length idim.  The `dataset structure` returned by `rs_align_coordsets` 
% meets these requirements.
%
% Args:
%   data_in (struct): `dataset structure` to be processed, with fields
%
%     - ds (cell array): `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas (cell array): `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets (cell array): `set metadata structure`, sets{k} is the response metadata for the kth record
%
%   aux (struct): auxiliary inputs, may be omitted, with fields
%
%     - opts_knit (struct): options for knitting and consistency checking, with fields
%
%         - **Transformations**
%         - allow_offset (int): 1 to allow translational offset, 0 does not allow; default is 1
%         - allow_scale (int): 1 to allow scaling of each dataset into the consensus, 0 does not allow; default is 0
%         - allow_reflection (int): 1 to allow reflection, 0 does not allow; default is 1
%         - if_normscale (int): 1 to normalize consensus to size of `data_in` (determined by geometric mean of scale factors for each dataset), 0 does not, has no effect if allow_scale=0; default is allow_scale
%         - if_pca (int): 1 to rotate the consensus coordinates in data_out into its principal components, 0 does not; default is 0
%
%         - **Statistics**
%         - if_stats (int): 1 to do statistics of variance explained, 0 does not; default is 0
%         - if_plot (int): 1 to plot statistics, 0 does not; default is if_stats
%         - nshuffs (int): number of shuffles for calculating statistics; default is 500 if if_stats=1, 0 if if_stats=0; see note below regarding statistics and plots
%         - shuff_quantiles (float 1-D array): quantiles to plot; default is [0.01 0.05 0.5 0.95 0.99]
%
%         - **Dimension selection**
%         - dim_max_in (int): maximum dimension of data_in.ds to use; default is maximum available across all datasets
%         - dim_list_in (int 1-D array): list of dimensions to use from data_in.ds; default is [1:dim_max_in]
%         - dim_aug (int): number of additional dimensions in data_out.ds; default is 0; see note below regarding Procrustes consensus algorithm
%         - dim_list_out (int 1-D array): list of dimensions to create in data_out.ds; if specified, must have same length as dim_list_in; default is [1:dim_list_in]+dim_aug
%
%         - **Replotting**
%         - knit_stats (struct): include to replot a previous analysis, otherwise omit; see note below regarding replotting
%         - knit_stats_setup (struct): include to replot a previous analysis, otherwise omit; see note below regarding replotting
%
%         - **Logging and optimization**
%         - if_log (int): 1 to log progress, 0 to suppress; default is 1
%         - pcon_init_method (int or char): typically omitted; default is 0, leading to 'pca' method for initializing `procrustes_consensus`; see note below regarding Procrustes consensus algorithm
%         - if_initpca_rot (int): typically omitted, default is 1 unless any of dim_list_out>dim_list_in; see note below regarding Procrustes consensus algorithm
%         - max_iters (int): maximum number of iterations for Procrustes consensus; default is 1000; see note below regarding Procrustes consensus algorithm
%         - max_rmstol (int): maximum change ofcoordinates for consensus solution; default is 10^-5; see note below regarding Procrustes consensus algorithm
%         - keep_details (int): 1 to return details of Procrustes consensus mimimization, 0 does not; default is 0; see note below regarding Procrustes consensus algorithm
%         - pcon_initial_guess (cell array): specified initial guess for Proccrustes minimization, typically omitted; see note below regarding Procrustes consensus algorithm
%         - pcon_alignment (cell array): specified alignment for Procrustes minimization, typically omitted; see note below regarding Procrustes consensus algorithm
%         - if_frozen (int): random number control for shuffles and initialization; 1 for same numbers every run, 0 for different random numbers each run, negative integer for a fixed seed each run; 
%         default is 1; see notes below regarding statistics and Procrustes consensus algorithm
%
%     - opts_check (struct): options for consistency checking, with field
%
%         - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
%
%     - opts_pca (struct): options for principal components analysis of consensus, typically omitted, only relevant if if_pca=1
%     - opts_align (struct): options for alignment of data, typically; see note below regarding recalculation of alignment
%     - opts_rays (struct): options for rays, typically omitted; see note below regarding rays
%
%     - sa_pooled (struct): include to avoid recalculation of alignment, otherwise omit; see note below regarding recalculation of alignment
%     - data_align (struct): include to avoid recalculation of align ment, otherwise omit; see note below regarding recalculation of alignment
% 
% Returns:
%   data_out (struct): `dataset structure` with a single record consisting of the consensus coordinates from `data_in`, same format as  as `data_in`
%
%   aux_out: auxiliary outputs and parameter values used
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%
%     - opts_knit (struct): aux.opts_knit, with defaults filled in
%     - opts_check (struct): aux.opts_check, with defaults filled in
%     - opts_pcon (cell array): opts_pcon{idim} are the options used in Procrustes alignment for model dimension idim
%     - opts_pca (struct): aux.opts_pca, with defaults filled in
%     - opts_align (struct): aux.opts_align, with defaults filled in
%     - opts_rays (cell array with one element): opts_rays{1} is a structure which contains the options used for creating rays in data_out
%     - rayss (cell array with one element): rayss{1} is the `ray structure` for data_out; see note below regarding rays
%     - coords_havedata (int 2-D array): coords_havedata(s,k)=1 if the stimulus data_out.sets{:}.typenames{s} is present and not NaN in record k of `data_in`, 0 otherwise
%     - components (struct): a `dataset structure`, the kth record corresponds to the kth record of `data_in` after transformation to the consensus; all stimuli in
%     data_out will be included but coordinates for stimuli not in data_in.sas{k} will be NaN
%     - knit_stats (struct): statistics of knitting; see notes below regarding statistics and replotting a previous analysis
%     - knit_stats_setup: parameters extracted from aux.opts_knit, along with the additional fields below; see note below regarding replotting a previous analysis
%
%         - nsets (int): number of records in `data_in`
%         - nstims (int): number of stimuli
%         - dataset_labels (cell array of char): dataset labels, from data_in.sets{:}.label
%         - stimulus_labels (cell array of char): stimulus labels, from data_out.sas{1}.typenames
%
%     - fig_handle (handle): handle to figure created (present only if statistics are plotted)
%     - ts_pca (cell array): ts_pca{idim}{k} is the transformation from data_in.ds{k}{idim} to the consensus, taking into account final pca; present only if aux.opts_knit.if_pca=1
%     The transformation is
%     [consensus]=ts.scaling*[component]*ts.orthog+ts.translation. If dim_list_out>dim_list_in, then [component] needs to be right-padded by columns of zeros for missing dimensions.
%     - details (cell array of struct): details{idim} contains details of
%     the convergence towards knitting for data_in.ds{:}{idim}; present only if aux.opts_knit.keep_details=1; fields include, for each iteration m,
%
%         - ts_cum (cell array): ts_cum{m}{k} is the transformation found from record k, i.e., from data_in.ds{k}(istim,:), to the current consensus
%         - rms_change (float 1-D array): rms_change(m) is the rms change of the consensus coordinates from the previous iteration
%         - consensus (float 3-D array): consensus(istim,:,m) are the current consensus coordinates 
%         - z (float 4-D array): consensus(istim,:,k,m) are the coordinates data_in.ds{k}(istim,:) transformed to match the current consensus
%         - rms_dev (float 2-D array): rms_dev(k,m) is the rms deviation of record k from the consensus, after the current transformation
%
% Note: General notes
%     - For all records with data_in.sets{k}.type='data', the strings in data_in.sets{k}.paradigm_type must agree.
%     - Pipeline: data_out.sets{1}.pipeline.sets_combined{:} contains metadata from all records of `data_in`;
%     data_out.sets{1}.pipeline.type='knit'.
%     - The 'type' field of data_in.sets{1} is propagated to data_out.sets{1}
%
% Note: Note regarding statistics and plots
%     - If aux.opts_knit.if_stats=1, variance explained by the consensus
%     coordinates are calculated and returned in aux_out.knit_stats, in the following fields:
%
%         - rmsdev_overall (float 1-D array): rmsdev_overall(idim) is the root-mean-squared deviation across all records and stimuli
%         - rmsdev_setwise (float 2-D array): rmsdev_setwise(idim,k): root-mean-squared deviation within record k, across stimuli
%         - rmsdev_stmwise (float 2-D array): rmsdev_stmwise(idim,istim): rood-mean-squared deviation within stimulus istim, across records
%
%     - The counts for each of these calculations are counts_[overall|setwise|stmwise], and the available rms deviation (from the centroid) is given by rmsavail_[overall|setwise|stimwise].
%     - If aux.opts_knit.nshuffs>0 (default is 500), then a parallel computation is done after random shuffles of the stimulus labels within each record,
%     and the results are returned in
%     rmsdev_[overall|setwise|stimwise]_shuff.
%     For the shuffled quantities, the first two dimensions are the same as the unshuffled quantities; dimension 3 is
%     always 1; dimension 4 (length: nshuffs) is which shuffle; dimension 5 (length: 2) is the mode: 1 for last coordinate only shuffled, 2 for all coordinates shuffled.
%     To control whether the same random number seed is used on each run, use aux.opts_knit.if_frozen (default is 1).
%     - if aux.opts_knit.if_plot=1 (default if if_stats=1), then a figure is created, with four panels:
%
%         - a heatmap of rmsdev_setwise
%         - a heatmap of rmsdev_stmwise
%         - a comparison of rmsdev_overall (black) to quantiles of
%         rmsdev_overall_shuff (mode 1: magenta, mode 2: red); quantiles are specified by shuff_quantiles; if
%         nshuffs=0, then the shuffled values will not be plotted
%         - a comparison of the explained rms deviation, parallel to the above, with avilable rms deviation in blue
%
%     - Other fields in aux_out.knit_stats are the following.  Note that for ds_components ts does not include the rotation to principal components (if
%     requested by aux.opt_knit.if_pca=1) is not included; for a transformation that includes the rotation, see aux_out.ts_pca.
%
%         - opts_pcon (struct): supplied options for Procrustes consensus algorithm
%         - opts_pcon_eachdim (cell array of struct): opts_pcon_eachdim{idim} are the options used for dimension idim
%         - ds_knitted (cell array): ds_knitted{idim} are the consensus coordinates
%         - ds_components (cell array): ds_components{k}{idim} are the coordinates for record k
%         - ts (cell array): ts{idim}{k} is the Procrustes transformation for record k.
%         The transformation is [consensus]=ts.scaling*[component]*ts.orthog+ts.translation.
%         If dim_list_out>dim_list_in, then [component] needs to be right-padded by columns of zeros for missing dimensions.
%     
% Note: Note regarding recalculation of alignment
%     The first step in forming a consensus is alignment, which identifies the common stimuli among the records of `data_in`, and to 
%     place them in the same order. By default, this is carried out in rs_knit_coordsets by a call to rs_align_coordsets, using options aux.align_opts.
%     This recalculation can be avoided by supplying aux_out from a
%     previous call to rs_align_coordsets, as follows: aux.sa_pooled=aux_out.sa_pooled, aux.data_align=aux_out.data_out
%
% Note: Note regarding Procrustes consensus algorithm
%     - To find a consensus set of coordinates, the coordinates in each record of `data_in` are rotated, and optionally translated (if allow_offset=1),
%     scaled (if allow_scale=1), and reflected (if allow_reflection=1). These transformations are carried out for separately for each set dimension
%     for which coordinates are present in all of the records, i.e., for which data_in.ds{k}{idim} exists for all k.
%     - The algorithm, in procrustes_consensus.m, is iterative.  Briefly, after an initial guess is determined, a Procrustes 
%     transformation is found that minimizes the rms deviation between each record and the current guess. The guess is then
%     revised by setting each stimulus' coordinates equal to the centroid of the coordinates of that stimulus across the records.  To avoid drift of the updated guess, it is Procrustes-transformed for closest match
%     to an alignment coordinate set (the alignment set, unless otherwise specified, is equal to the initial guess).
%     - The iteration ends when either the number of iterations exceeds max_niters (default=1000),
%     or the rms change of the guess is less than max_rmstol (default=10^-5)
%     - There are several choices for initialization and alignment.
%
%         - For most purposes, the default initialization method (aux.opts_knit.pcon_init_method=0) can be used, which uses the principal components of all the stimulus coordinates in all of the records.
%         These can be optionally forced to be centered (pcon_init_method=-1) or not (pcon_init_method=-2); if unspecified (default), centering is determined by allow_offset.
%         For these choices, if_initpca_rot=1 rotates the initial guess to match the data, or
%         not. The default for if_init_pca is 1 unless any of dim_list_out>dim_list_in, in which case it is 0.
%         The heuristic for not rotating if dim_list_out>dim_list_in, i.e., two or more sets of coordinates are to be knit together to construct a coordinate set with a greater number of dimensions,
%         is that without rotation, the principal components reflect projections of the coordinates that are present in any of the records.
%         -  Alternatively, pcon_init_method=r, r>0, specifies that the coordinates in data_in{r}{idim} are used.
%         -  If pcon_init_method='specify', then pcon_initial_guess{idim} is an array of size [npts ids] for the
%         initial guess, and pcon_alignment{idim}, which defaults to
%         pcon_initial_guess, is used for the alignment at the end of each iteration.  pcon_initial_guess and pcon_alignment may be omitted, in which case random values are used.
%         To control whether the same random number seed is used on each run, use aux.opts_knit.if_frozen (default is 1).
%         - The solution is only unique up to rotation (and translation and reflection, if these components are allowed).  The ambiguity is resolved by
%         matching the consensus solution to the initial guess (or, pcon_alignment{idim} if separately supplied with pcon_init_method=0), as described above.
%         - Under some circumstances (e.g., several solutions that are nearly equally good), the solution found by the algorithm may depend on
%         the initialization choice.  A simple strategy to check for this is to compare the results with the default pcon_init_method=0 to the results with
%         pcon_init_method='specify' and if_frozen=0. There are two ways that this dependency can happen.
%
%             - One is that the number of overlapping stimuli is too small. For example,
%             at least m points are required to determine a rotation and translation in an m-dimensional space; if there are fewer overlaps, then a consensus will
%             still be found but there are many other consensus datasets that fit equally well.
%             - A second way is that there are a sufficient number of points, but there are several solutions that are approximately equally good. 
%             Under these circumstances, the algorithm may get stuck in a local minimum. This possibility only occurs when there are at least three records in `data_in`, as the procedure reduces to
%             the standard Procrustes algorithm, which finds the consensus when there are only two records, is deterministic other than does rotational ambiguity.
% 
% Note: Note regarding replotting a previous analysis
%     - To replot a a previous calculation with additional customizatior to make a composite figure, `data_in` should be equal to that used in the previous calculation.
%     aux.knit_stats should be equal to aux_out.knit_stats from the previous calculation
%     aux.knit_stats_setup should be equal to aux_out.knit_stats_setup from
%     the previous calculation with the following modifications allowed in fields of knit_stats_setup:
%
%         - dataset_labels (cell array of char): dataset labels; default is data_in.sets{:}.label
%         - stimulus_labels (cell array of char): stimulus labbels; default is data_out.sas{1}.typenames
%         - shuff_quantiles (float 1-d array): quantiles to show; default is 0.01 0.05 0.5 0.95 0.99
%         - fig_handle (handle): figure handle to plot into; figure will be created if not supplied
%         - row (int): row to plot into; default is 1
%         - nrows (int): number of rows in the figure; default is row
%
%     -  No further calculations are done
%     -  On return, data_out will be empty, and aux_out.fig_handle will be the figure handle
%     -  In creating a composite figure, rows should be plotted in order from top to bottom, as plotting the bottom row triggers an equalization of the color scale. See `rs_knit_coordsets_demo` for an example.
%
% Note: Note regarding rays
%     - The `ray structure` describes relationships among the simulus coordinates: 
%     `rays`, i.e., sets of stimuli that lie along an axis or a ray from the origin,
%     `rings`, stimuli that lie at an approximately equal distance from the origin, and nearest neighbors.
%     It is only created if there is a valid set of stimulus coordinates.  
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
aux_out.opts_check=aux.opts_check;
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
    aux_out.components.sas=data_align.sas;
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
