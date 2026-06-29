function [vara_stats,aux_out]=rs_vara_coordsets(data_in,groupings,aux)
% [vara_stats,aux_out]=rs_vara_coordsets(data_in,groupings,aux) does an analysis of variance across groups of `dataset structures` via shuffling by trials, and provides and displays statistics
%
% Basic strategy:  records are grouped, consensus is found within each group, and the variance around the consensus is computed.
% Then, records are shuffled between groups. The shuffling can also be constrained by assigning tags to each dataset, e.g., according to the subject ID, and only shuffling within records that have the same tag.
% For each shuffle, the variance around the consensus within each group is again calculated, and compared tothat of the original data.
%
% Note that in contrast to `rs_knit_coordsets`, in which shuffling permutes the coordinates of the stimuli within a record, here the shuffling permutes the records across groups.
%
% Also in contrast to `rs_knit_coordsets`, there is no attempt made to combine all of the records into a consensus.
%
% Args:
%   data_in (struct): `dataset structure` to be processed, with fields
%
%     - ds (cell array): `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas (cell array): `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets (cell array): `set metadata structure`, sets{k} is the response metadata for the kth record
%
%   groupings (struct):  structure specifying assignment of records to groups, and, optionally, tags to restrict shuffling
%     
%     - gps (int 1-D array): gps(k) is the group assignment of record k, an integer from 1 to the number of groups (ngps);  All groups must have at least one record.
%     - tags (int 1-D array): tags(k) is the tag assigned to record k.  If non-empty, shuffles will only swap a record with a record of the same tag.  Defaults to empty ([]),  
%
%   aux (struct): auxiliary inputs, may be omitted, with fields
%
%     - opts_vara (struct): options for knitting and consistency checking, with fields
%
%         - **Transformations**
%         - allow_offset (int): 1 to allow translational offset, 0 does not allow; default is 1
%         - allow_scale (int): 1 to allow scaling of each dataset into the consensus, 0 does not allow; default is 0
%         - allow_reflection (int): 1 to allow reflection, 0 does not allow; default is 1
%         - if_normscale (int): 1 to normalize consensus to size of `data_in` (determined by geometric mean of scale factors for each dataset), 0 does not, has no effect if allow_scale=0; default is allow_scale
%         - if_pca (int): 1 to rotate the consensus coordinates in data_out into its principal components, 0 does not; default is 0
%
%         - **Statistics and shuffles**
%         - if_stats (int): 1 to do statistics of variance explained, 0 does not; default is 1
%         - if_exhaust (int): 1 to attempt to use exhaustive set of shuffles, otherwise will use nshuffs random shuffles if number required is > nshuffs_nax; default is if_stats
%         - nshuffs (int): number of shuffles requested; less will be made if if_exhaust=1 and number needed for exhaustive list is grater than nshuffs_exhaust_max; default is 500 if if_stats=1, 0 if if_stats=0; see note below regarding statistics and plots
%         - shuffs_supplied (int 2-D array): user-supplied shuffles to be used; default is empty ([]), in which case nshuffs random shuffles or exhaustive shuffles (depending on if_exhaust) will be
%         generated. If non-empty, shuffs_supplied(ishuff,irec) will be the record number to be used in place of original record irec in shuffle ishuff.  It is If non-empty, it is checked to be sure that each row is a permutation, but it is not checked for consistency with groupings.
%         - nshuffs_max (int): maximum number shuffles that can be generated; use random shuffles if more than this number are required; defaul is 10^4
%         - if_plot (int): 1 to plot statistics, 0 does not; default is if_stats
%         - shuff_quantiles (float 1-D array): quantiles to plot; default is [0.01 0.05 0.5 0.95 0.99]
% 
%         - **Dimension selection**
%         - dim_max_in (int): maximum dimension of data_in.ds to use; default is maximum available across all datasets
%         - dim_list_in (int 1-D array): list of dimensions to use from data_in.ds; default is [1:dim_max_in]
%         - dim_aug (int): number of dimensions to add for consensus datasets; default is 0; see note below regarding Procrustes consensus algorithm
%         - dim_list_out (int 1-D array): list of dimensions for consensus datasets, must have same length as dim_list_in; default is [1:dim_list_in]+dim_aug
%
%         - **Replotting ??**
%         - knit_stats (struct): include to replot a previous analysis, otherwise omit; see note below regarding replotting
%         - knit_stats_setup (struct): include to replot a previous analysis, otherwise omit; see note below regarding replotting
%
%         - **Logging and optimization**
%         - if_log (int): 1 to log progress, 0 to suppress; default is 1
%         - pcon_init_method (int or char): typically omitted; default is 0, leading to 'pca' method for initializing `procrustes_consensus`; see note below regarding Procrustes consensus algorithm
%         - if_initpca_rot (int): typically omitted, default is 1 unless any of dim_list_out>dim_list_in; see note below regarding Procrustes consensus algorithm
%         - max_iters (int): maximum number of iterations for Procrustes consensus; default is 1000; see note below regarding Procrustes consensus algorithm
%         - max_rmstol (int): maximum change ofcoordinates for consensus solution; default is 10^-5; see note below regarding Procrustes consensus algorithm
%         - keep_details (int): 1 to return details of Procrustes consensus minimization, 0 does not; default is 0; see note below regarding Procrustes consensus algorithm
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
%     - opts_align (struct): options for alignment of data, typically omitted
%
%     - sa_pooled (struct): include to avoid recalculation of alignment, otherwise omit; see note below regarding recalculation of alignment
%     - data_align (struct): include to avoid recalculation of align ment, otherwise omit; see note below regarding recalculation of alignment
% 
% Returns:
%   vara_stats(struct): statistics and analysis parameters
%
%     - groupings (struct): grouping information
%
%         - ngps (int): number of groups
%         - gps (int 1-D array): gps(k) is the group assignment of record k, an integer from 1 to ngps
%         - gp_list (cell array): gp_list{igp} are the indices of the records in group igp
%         - nsets_gp (int 1-D array): nsets_gp(igp) is the number of records in group igp
%         - nsets_gp_max (int): maximum size of a group
%         - tage (int 1-D array): tags(k) is the tag for record k
%
%   aux_out (struct): auxiliary outputs and parameter values used
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%
%     - opts_vara (struct): aux.opts_vara, with defaults filled in
%     - opts_check (struct): aux.opts_check, with defaults filled in
%     - opts_pcon (cell array): opts_pcon{idim} are the options used in Procrustes alignment for model dimension idim
%     - opts_pca (struct): aux.opts_pca, with defaults filled in
%     - opts_align (struct): aux.opts_align, with defaults filled in
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
%         - ts (cell array): ts{idim}{k} is the Procrustes transformation
%         for record k. The transformation is
%         [consensus]=ts.scaling*[component]*ts.orthog+ts.translation; see `transformation structures` for further details.
%         If dim_list_out>dim_list_in, then [component] needs to be right-padded by columns of zeros for missing dimensions.
%     
% Note: ?? Note regarding Procrustes consensus algorithm
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
% Note: ??Note regarding replotting a previous analysis
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
% See also:
%   RS_ALIGN_COORDSETS, RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS
%   ?? PSG_ALIGN_COORDSETS, PSG_KNIT_STATS,
%   ?? PSG_REMNAN_COORDSETS, PSG_COORD_PIPE_UTIL, PROCRUSTES_CONSENSUS, PSG_ALIGN_STATS_PLOT.
%   ?? MULTI_SHUFF_GROUPS
%
if (nargin<=2)
    aux=struct;
end
vara_stats=struct;
aux_out=struct;
%
aux=filldefault(aux,'opts_vara',struct);
aux.opts_vara=filldefault(aux.opts_vara,'if_log',1);
aux.opts_vara=filldefault(aux.opts_vara,'allow_reflection',1);
aux.opts_vara=filldefault(aux.opts_vara,'allow_offset',1);
aux.opts_vara=filldefault(aux.opts_vara,'allow_scale',0);
aux.opts_vara=filldefault(aux.opts_vara,'if_normscale',aux.opts_vara.allow_scale);
aux.opts_vara=filldefault(aux.opts_vara,'if_stats',1);
aux.opts_vara=filldefault(aux.opts_vara,'if_plot',aux.opts_vara.if_stats);
aux.opts_vara=filldefault(aux.opts_vara,'if_pca',0);
aux.opts_vara=filldefault(aux.opts_vara,'max_niters',1000);
aux.opts_vara=filldefault(aux.opts_vara,'max_rmstol',10^-5);
aux.opts_vara=filldefault(aux.opts_vara,'pcon_init_method',0);
aux.opts_vara=filldefault(aux.opts_vara,'keep_details',0);
aux.opts_vara=filldefault(aux.opts_vara,'pcon_initial_guess',[]);
aux.opts_vara=filldefault(aux.opts_vara,'pcon_alignment',aux.opts_vara.pcon_initial_guess);
aux.opts_vara=filldefault(aux.opts_vara,'if_frozen',1);
if aux.opts_vara.if_stats
    aux.opts_vara=filldefault(aux.opts_vara,'nshuffs',500);
else
    aux.opts_vara=filldefault(aux.opts_vara,'nshuffs',0);
end
aux.opts_vara=filldefault(aux.opts_vara,'shuffs_supplied',[]);
aux.opts_vara=filldefault(aux.opts_vara,'if_exhaust',1);
aux.opts_vara=filldefault(aux.opts_vara,'shuff_quantiles',[0.01 0.05 0.5 0.95 0.99]);
aux.opts_vara=filldefault(aux.opts_vara,'nshuffs_max',10^4);
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=filldefault(aux,'opts_pca',struct);
aux.opts_pca=filldefault(aux.opts_pca,'if_log',0);
aux.opts_pca=filldefault(aux.opts_pca,'nd_max',Inf);
%
aux=filldefault(aux,'opts_align',struct);
%
aux=rs_aux_customize(aux,'rs_vara_coordsets');
%
vara_stats=struct;
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
set_knit_strings={'paradigm_name','subj_id','subj_id_short','extra','label_long','label'}; %fields to be concatenated in knitted metadata
%
% %
% % replot mode
% %
% if isfield(aux,'knit_stats') & isfield(aux,'knit_stats_setup')
%     knit_stats_setup_use=aux.knit_stats_setup;
%     if isfield(knit_stats_setup_use,'fig_handle') %psg_knit_stats_plot expects figure handle in figh
%         knit_stats_setup_use.figh=knit_stats_setup_use.fig_handle;
%     end
%     aux_out.fig_handle=psg_knit_stats_plot(aux.knit_stats,knit_stats_setup_use);
%     return
% end
% 
%
%check group information
%
nsets=length(data_in.sets);
if length(groupings.gps)~=nsets
    wmsg=sprintf('group assignment list length (%2.0f) does not match number of records (%2.0f)',length(groupings.gps),nsets);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
end
if any(~ismember(groupings.gps,[1:nsets]))
    wmsg=sprintf('group assignment list has elements not in [1:%2.0f]',nsets);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
end
groupings.ngps=max(groupings.gps);
groupings.gp_list=cell(1,groupings.ngps);
groupings.nsets_gp=zeros(1,groupings.ngps);
for igp=1:groupings.ngps
    groupings.gp_list{igp}=find(groupings.gps==igp);
    groupings.nsets_gp(igp)=length(groupings.gp_list{igp});
end
groupings.nsets_gp_max=max(groupings.nsets_gp);
if any(groupings.nsets_gp==0)
    wmsg=sprintf('at least one group has no records');
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
end
%
%check tag information
%
groupings=filldefault(groupings,'tags',[]);
if ~isempty(groupings.tags)
    if length(groupings.tags)~=nsets
        wmsg=sprintf('tag list length (%2.0f) does not match number of records (%2.0f)',length(groupings.tags),nsets);
        aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
    end
    if any(~ismember(groupings.tags,[1:max(groupings.tags)]))
        wmsg=sprintf('tag list has non-integer or non-positive values');
        aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
    end
end
%
%show setup
%
if aux.opts_vara.if_log
    disp(' ');
    disp('variance analysis');
    for iset=1:nsets
        if ~isempty(groupings.tags)
            disp(sprintf('dataset %2.0f (group %2.0f, tag %2.0f): %s',iset,groupings.gps(iset),groupings.tags(iset),data_in.sets{iset}.label));
        else
            disp(sprintf('dataset %2.0f (group %2.0f): %s',iset,groupings.gps(iset),data_in.sets{iset}.label));
        end
    end
end
%
%set up random number generator
%
if_frozen=aux.opts_vara.if_frozen;
if (if_frozen~=0) 
    rng('default');
    if (if_frozen<0)
        rand(1,abs(if_frozen));
    end
else
    rng('shuffle');
end
%
%create shuffle list via multi_shuff_groups or use supplied shuffles
%
if aux.opts_vara.nshuffs>0
    if isempty(aux.opts_vara.shuffs_supplied)
        opts_multi=struct();
        opts_multi.if_log=0;
        opts_multi.if_exhaust=aux.opts_vara.if_exhaust;
        opts_multi.if_ask=0; %non-interactive
        opts_multi.if_reduce=1; %shuffles that differ only by group order are not included
        opts_multi.if_justcount=0; %don't just count
        opts_multi.if_nowarn=1;
        opts_multi.nshuffs=min(aux.opts_vara.nshuffs,aux.opts_vara.nshuffs_max);
        opts_multi.exhaust_raw_max=aux.opts_vara.nshuffs_max;
        opts_multi.exhaust_reduced_max=aux.opts_vara.nshuffs_max;
        opts_multi.nshuffs_max=aux.opts_vara.nshuffs_max;
        opts_multi.tags=groupings.tags;
        %
        [shuffs,gp_info,opts_multi_used]=multi_shuff_groups(groupings.gps,opts_multi);
        if aux.opts_vara.if_log
            disp(sprintf('shuffles made:  %6.0f, requested:%6.0f',size(shuffs,1),aux.opts_vara.nshuffs));
            disp(sprintf('exhautive mode used: %1.0f, requested:     %1.0f',opts_multi_used.if_exhaust,aux.opts_vara.if_exhaust));
        end
    else %user-supplied shuffles
        shuffs=aux.opts_vara.shuffs_supplied;
        opts_multi_used=struct();
        if  size(shuffs,1)~=aux.opts_vara.nshuffs
            wmsg=sprintf('number of supplied shuffles (%6.0f) does not match number of shuffles requested (%6.0f)',size(shuffs,1),aux.opts_vara.nshuffs);
            aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
        end
        if  size(shuffs,2)~=nsets
            wmsg=sprintf('number of elements in supplied shuffles (%6.0f) does not match number of records (%6.0f)',size(shuffs,2),nsets);
            aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
        end
        no_perm=0;
        for ishuff=1:size(shuffs,1)
            if any(sort(shuffs(ishuff,:))~=[1:size(shuffs,2)])
                no_perm=no_perm+1;
            end
        end
        if no_perm>0
            wmsg=sprintf('supplied shuffles are illegal: %3.0f fail to be permutations of the number of records',no_perm);
            aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
        end
        if aux.opts_vara.if_log
            disp(sprintf('shuffles supplied:  %6.0f, requested:%6.0f',size(shuffs,1),aux.opts_vara.nshuffs));
        end
    end
else
    shuffs=[];
    opts_multi_used=struct;
end
vara_stats.shuffs=shuffs;
vara_stats.opts_multi_used=opts_multi_used;
vara_stats.nshuffs_used=size(shuffs,1);
%
% tally missing stimuli in input datasets and align according to all stimuli
%
nstims_each=zeros(1,nsets);
stims_nan=cell(1,nsets);
if aux.opts_vara.if_log
    disp('before alignment of stimuli')
end
for iset=1:nsets
    nstims_each(iset)=data_in.sas{iset}.nstims;
    stims_nan{iset}=find(isnan(data_in.ds{iset}{1}));
    disp(sprintf('set %2.0f: %2.0f stimuli (%2.0f are NaN), label: %s',iset,nstims_each(iset),length(stims_nan{iset}),data_in.sets{iset}.label))
end
%
%align and check consistency
%
aux2=aux;
aux2.opts_align.if_log=aux.opts_vara.if_log;
[data_align,aux_align]=rs_align_coordsets(data_in,aux2);
%
%check consistency of data files
%
check=rs_check_coordsets(data_align,aux.opts_check);
if ~isempty(check.warnings)
    aux_out.warnings=strvcat(aux_out.warnings,check.warnings); %kludge since strvcat([],[])='', but we want [] if both warnings are empty
end
aux_out.warn_bad=aux_out.warn_bad+check.warn_bad;
%
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
nstims=min(nstims_each);
if aux.opts_vara.if_log
    disp('after alignment of stimuli')
    disp(sprintf('total stimuli: %3.0f',nstims));
end
%
%set up dimension defaults
%
aux.opts_vara=filldefault(aux.opts_vara,'dim_max_in',max(dim_list_inter));
aux.opts_vara=filldefault(aux.opts_vara,'dim_list_in',[1:aux.opts_vara.dim_max_in]);
aux.opts_vara=filldefault(aux.opts_vara,'dim_aug',0);
aux.opts_vara=filldefault(aux.opts_vara,'dim_list_out',aux.opts_vara.dim_aug+aux.opts_vara.dim_list_in);
if length(aux.opts_vara.dim_list_in)~=length(aux.opts_vara.dim_list_out)
    wmsg=sprintf('dim_list_in and dim_list_out have different lengths');
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
else
    if_aug=any(aux.opts_vara.dim_list_out>aux.opts_vara.dim_list_in);
    aux.opts_vara=filldefault(aux.opts_vara,'if_initpca_rot',1-if_aug);
end
%
if ischar(aux.opts_vara.pcon_init_method)
    if strcmp(aux.opts_vara.pcon_init_method,'specify')
        aux.opts_vara.initialize_set=0; %opts_vara.pcon_initial_guess and opts_vara.pcon_alignment will be used
    else
        wmsg='initialization method not recognized; default used';
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
        aux.opts_vara.pcon_init_method=0;
        aux.opts_vara.initialize_set='pca';
    end
else
    if aux.opts_vara.pcon_init_method>0
        aux.opts_vara.initialize_set=aux.opts_vara.pcon_init_method;
    elseif aux.opts_vara.pcon_init_method==0
        aux.opts_vara.initialize_set='pca';
    elseif aux.opts_vara.pcon_init_method==-1
        aux.opts_vara.initialize_set='pca_center';
    else
        aux.opts_vara.initialize_set='pca_nocenter';
    end
end
%
%reformat for consensus calculations
%
pcon_dim_max_in=max(dim_list_inter);
pcon_dim_max_out=max(aux.opts_vara.dim_list_out);
z=cell(pcon_dim_max_in,1);
for ip=1:pcon_dim_max_in
    if ismember(ip,dim_list_inter)
        z{ip}=zeros(nstims,ip,nsets);
        for iset=1:nsets
            z{ip}(:,:,iset)=data_align.ds{iset}{ip}(:,[1:ip]); %only include data up to pcon_dim_use
            z{ip}(aux_align.opts_align.which_common(:,iset)==0,:,iset)=NaN; % pad with NaN's if no data
        end
    end
end
%
%overlaps indicates same stimulus (from ovlp_array) and also that the coordinates are not NaN's
coords_isnan=reshape(isnan(z{1}),[nstims,nsets]);
opts_pcon.overlaps=aux_align.ovlp_array.*(1-coords_isnan);
if aux.opts_vara.if_log
    disp(sprintf('number of overlapping stimuli in component removed because coordinates are NaN'));
    disp(sum(coords_isnan.*aux_align.ovlp_array,1));
    disp('overlap matrix from stimulus matches, without regard as to whether stimulus coordinates coordinates are NaN')
    disp(aux_align.ovlp_array'*aux_align.ovlp_array);
    disp('overlap matrix from stimulus matches, but excluding stimuli for which coordinates that are NaN')
    disp(opts_pcon.overlaps'*opts_pcon.overlaps);
end
%
%define results structures
%
results=struct;
consensus=cell(pcon_dim_max_out,1); %d1: dimnension
znew=cell(pcon_dim_max_out,1);
ts=cell(pcon_dim_max_out,1);
details=cell(pcon_dim_max_out,1);
opts_pcon_used=cell(pcon_dim_max_out,1);
%
nshuffs=aux.opts_vara.nshuffs;
nsets_gp_max=groupings.nsets_gp_max;
ngps=groupings.ngps;
%
%these are vector distances, taking all coordinates into account
%note that the "allow scale" coordinate in psg_align_vara_demo is omitted,
%
rmsdev_setwise=zeros(pcon_dim_max_out,nsets); %d1: dimension, d2: set
rmsdev_stmwise=zeros(pcon_dim_max_out,nstims); %d1: dimension, d2: stim
rmsdev_overall=zeros(pcon_dim_max_out,1); %rms distance, across all datasets and stimuli
%
rmsdev_setwise_gp=zeros(pcon_dim_max_out,nsets_gp_max,ngps); %d1: dimension, d2: set (within group), d3: gp
rmsdev_stmwise_gp=zeros(pcon_dim_max_out,nstims,1,ngps); %d1: dimension, d2: stim, d3: gp
rmsdev_overall_gp=zeros(pcon_dim_max_out,1,ngps); %d1: dimension, d2: dummy, d3: gp
%
counts_setwise=zeros(1,nsets);
counts_stmwise=zeros(1,nstims);
counts_overall=zeros(1);
%
counts_setwise_gp=zeros(1,nsets_gp_max,ngps);
counts_stmwise_gp=zeros(1,nstims,ngps);
counts_overall_gp=zeros(1,1,ngps);
%
%for setwise and stmwise, use NaN so that missing data won't affect averages
rmsdev_setwise_gp_shuff=NaN(pcon_dim_max_out,nsets_gp_max,ngps,nshuffs); %d1: dimension, d2: set, d3: gp, d4: shuffle
rmsdev_stmwise_gp_shuff=NaN(pcon_dim_max_out,nstims,ngps,nshuffs); %d1: dimension, d2: stim, d3: gp, d4: shuffle
rmsdev_overall_gp_shuff=zeros(pcon_dim_max_out,1,ngps,nshuffs); %d1: dimension, d3: gp, d4: shuffle
%
%rms variance available in original data
rmsavail_setwise=zeros(pcon_dim_max_out,nsets);
rmsavail_stmwise=zeros(pcon_dim_max_out,nstims);
rmsavail_overall=zeros(pcon_dim_max_out,1);
for ip=1:pcon_dim_max_out
    sqs=sum(z{ip}.^2,2);
    rmsavail_setwise(ip,:)=reshape(sqrt(mean(sqs,1,'omitnan')),[1 nsets]);
    rmsavail_stmwise(ip,:)=reshape(sqrt(mean(sqs,3,'omitnan')),[1 nstims]);
    rmsavail_overall(ip,:)=sqrt(mean(sqs(:),'omitnan'));
end
%
aux_out.opts_check=aux.opts_check;
if aux_out.warn_bad==0 %     %process
    %
    for ip=1:pcon_dim_max_out
        if ismember(ip,dim_list_inter)

%%%%%%%%%%%%%%%%%%%%%%%%%        
        
        end %dim is available in all datasets
    end %ip
    aux_out.opts_vara=aux.opts_vara;
    aux_out.opts_pcon=opts_pcon_used;
    aux_out.opts_pca=aux.opts_pca;
    aux_out.opts_align=aux_align.opts_align;
    vara_stats.groupings=groupings;
else %cannot process
    aux_out.opts_vara=aux.opts_vara;
    vara_stats.groupings=groupings;
    disp('cannot proceed');
    disp(aux_out.warnings);
end
return
end
