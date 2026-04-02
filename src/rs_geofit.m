function [gfs,xs,aux_out]=rs_geofit(data_in,data_out,aux)
% [gfs,xs,aux_out]=rs_geofit(data_in,data_out,aux)
% fits geometrical models to the transformation between coordinates in two `dataset structures`
%
% Args:
%   data_in (struct): `dataset structure` that is the starting point of the transformations, with fields
%
%     - ds (cell array): `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas (cell array): `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets (cell array): `set metadata structure`, sets{k} is the response metadata for the kth record
%
%   data_out (struct): `dataset structure` that is the target of the transformations, same format as  as `data_in`;
%     number of stimuli must be the same as data_in;
%     stimulus names in data_in.sas{k}.typenames and data_out.sas{k}.typenames need not match but a warning is issued if they do not
%
%   aux (struct): auxiliary options, may be omitted, with fields
%
%     - opts_geof (struct): specification of transformations to find, with fields
%
%          - model_list (char or cell array of char): model types to be fitted; default is values given in `model_list_default`; if [],
%          then requested interactively; see notes below regarding geometric models and model definition structure
%          - model_list_default (char or cell array of char): model types to be fitted when 'model_list' is not specified; default is {'procrustes_scale_offset','affine_offset','projective'};
%            see note below regarding customization
%          - dim_max_in (int):  maximum dimension of input dataset to use, defaults to 10
%          - dim_max_out (int): maximum dimension of output dataset to use, defaults to `dim_max_in`
%          - dimpairs_method (char): specifies pairing of dimensions between `data_in` and `data_out`, default is 'equal'
%
%              - 'equal': input dimension = output dimension
%              - 'all': all pairings of dimensions available in `data_in` up to `dim_max_in`, with all and dimensions available i `data_out`, up to `dim_max_out`
%              - 'din_lteq_dout': as in 'all', but input dimension must be less than or equal to output dimension
%              - 'din_gteq_dout': as in 'all', but input dimension must be greater than or equal to output dimension
%              - 'list': the pairings specified by aux.opts_geof.dimpairs_list
%
%          - dimpairs_list (int 2-D array): two-column array of pairs of dimensions for input and output, default is repmat([1:dim_max_in]',[1 2])
%          - if_stats (int): 1 to enable statistics, 0 to omit; default is 1; a value of 0 will override a nonzero `if_nestbymodel` and `if_nestbydim`
%          - nshuffs (int): number of shuffles for `if_nestbymodel` and `if_nestbydim`; default is 100 if if_stats=1, 0 if if_stats=0
%          - if_nestbymodel (int): 1 to do statistics on nesting by model, 0 to omit, -1 to only do statistics for maximally nested models; default is 1; see note below regarding nesting
%          - if_nestbydim (int): +/-1 to do statistics for nesting by dimension, 0 to omit; default is 0; see note below regarding nesting
%          - if_nestbydim_in (int): +/-1 to do statistics for nesting by dimension of input, 0 to omit; default is if_nestbydim; see note below regarding nesting
%          - if_nestbydim_out (int): +/-1 to do statistics for nesting by dimension of output, 0 to omit; default is if_nestbydim; see note below regarding nesting
%          - if_center (int): 1 to center the data, i.e., subtract the mean across stimuli from `data_in` and `data_out` before fitting models, 0 to omit; default is 1; 
%          note that if if_center=1, the transformations returned in `gfs` and `xs` apply to the centered data.
%          - if_frozen (int): 1 to use frozen random numbers, 0 for random each time, <0 to specify a seed; default is 1
%          - if_log (int): 1 to log overall progress, 0 to omit; default is 1
%          - if_fit_summary(int): 1 to log a summary of fits, 0 to omit; default is 1
%          - if_fit_log (int): 1 for a detailed log of fitting, 0 to omit; default is 0
%          - if_warn (int): 1 to show warnings, 0 to omit; default is 1
%          - persp_method (char): method for finding projective transformations, options are 'fmin','oneshot', or 'best'; default is 'best'
%
%              - 'fmin': uses an iterative method to search for the denominator; for each trial denominator, numerator parameters are determined by standard least-squares
%              - 'oneshot': uses method 2 of Zhengyhou Zhang, Microsoft Research Techical Report MSR-TR-2010-63 (1993, revised 2010); well-suited if the projective transformation is a close fit
%              - 'best' uses both methods and chooses the best-fit
%
%     - opts_check (struct): options for consistency checking, with field
%
%          - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
%
% Returns:
%   gfs (cell array of struct): gfs{k}.gf{dim_out,dim_in} contains results for the transformations from record k of `data_in` to record k of `data_out`,
%   for the coordinates data_in.ds{k}{dim_in} to data_out.ds{k}{dim_out}. If there is no fitting requested for this dimension pair (see 'dimpairs_method' above), then gfs{k}.gf{dim_out,dim_in} will be empty.
%   It contains the following fields (note that fields with 'shuff' will be absent if if_nestbymodel=0, and fields with 'shuff_nestdim_in' 
%   and 'shuff_nestdim_out' will be absent if if_nestbydim_in or if_nestbydim_out are absent)
%
%     - model_types_def (struct): model_types_def.model_types is a cell array of the models fitted;model_types_def.(model).nested is a cell array of the names of the nested models tested
%     - ref_dim (int): dimension of the input dataset (same as dim_out)
%     - adj_dim (int): dimension of output dataset (same as dim_in)
%     - opts_geofit (struct): options used for fitting
%     - d (float 1-D array): d(m) is the normlizded error for model m, equal to the sum of the squares of the deviations of data_out.ds{k}{dim_out} from the modeled values, normalized by the sum of their distances from their centroid.
%     Here and below, the index m denotes fits for the model type listed in model_types_def.model_types{m}; 
%     - transforms (1-D cell array}: transforms{m} are the parameters for the transformation; see `transformation structure` for details on how these are parameterized
%     - d_shuff (float 4-D array): d_shuff(m,shuff,nest,normtype) is the normalized error for each shuffle of the nested model; normtype=1  normalizes by the centroid of the shuffled data, normtype=2 normalizes by the centroid of the original data
%     - surrogate_count (int 3-D array): surrogate_count(m,nest,normtype) counts the number of shuffles for which d_shuff(m,shuff,nest,normtype) is less than d(m)
%     - nestdim_in_list (int): list of the lower dimensions used for nesting by input dimension
%     - d_shuff_nestdim_in (float 4-D array): d_shuff_nestbydim_in(m,shuff,nest,normtype) is the normalized error for each shuffle for a model with fewer input dimensions; normtype=1  normalizes by the centroid of  the shuffled data, normtype=2 normalizes by the centroid of the original data
%     - surrogate_count_nestdim_in (int 3-D array): surrogate_count_nestdim_in(m,nest,normtype) counts the number of shuffles for which d_shuff_nestdim_in(m,shuff,nest,normtype) is less than d(m)
%     - nestdim_out_list (int): list of the lower dimensions used for nesting by output dimension
%     - d_shuff_nestdim_out (float 4-D array): d_shuff_nestbydim_out(m,shuff,nest,normtype) is the normalized error for each shuffle for a model with fewer output dimensions; normtype=1  normalizes by the centroid of the shuffled data, normtype=2 normalizes by the centroid of the original data
%     - surrogate_count_nestdim_out (int 3-D array): surrogate_count_nestdim_out(m,nest,normtype) counts the number of shuffles for which d_shuff_nestdim_out(m,shuff,nest,normtype) is less than d(m)
%
%   xs (struct): the transformations, in a format compatible with `rs_xform_apply` [how to hyperlink?]  xs.(model_name), where model_name is one of the models specified by model_list, has fields
%
%     - class (char): the transformation class ('mean','procrustes','affine', 'projective','pwaffine','pwprojective')
%     - xforms (struct): xforms.ts{k}{dim_in}: the transformation to be
%     applied to coordinates in data_in.ds{k}{dim_in} to fit coordinates in
%     data_out.ds{k}{dim_out}. If there no fitting is requested for this dimension pair, then this will be empty.
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_geof (struct): aux.opts_geof, with defaults filled in
%     - opts_check (struct): aux.opts_check, with defaults filled in
%
% Note regarding geometric models:
%    - Model types to be fit are specified by the entries in opts_geof.model_list. The following model types are available:
%
%        - 'mean': all input values mapped to a single output value 
%        - 'procrustes_noscale_nooffset': rotation (and possibly reflection), no rescaling     , no translation
%        - 'procrustes_scale_nooffset': rotation (and possibly reflection), rescaling allowed, no translation
%        - 'procrustes_noscale_offset': rotation (and possibly reflection), no rescaling     , translation allowed
%        - 'procrustes_scale_offset': rotation (and possibly reflection), rescaling allowed, translation allowed
%        - 'affine_nooffset' : linear transformation, no translation
%        - 'affine_offset': linear transformation, translation allowed
%        - 'projective': projective transformation
%        - 'pwaffine': piecewise affine with one cutplane; two linear transformations with agreement on the cut
%        - 'pwaffine_2': piecewise affine with two cutplanes; four linear transformations, with agreement on the cuts
%
%    - The list of available model types can be obtained by getfield(psg_geomodels_define,'model_types')
%    - To determine the model class (see `transformation structure`) for model type mt: m=psg_models_define; getfield(m.(mt),'class')
%    - To determine the models nested in model type mt:  m=psg_models_define; getfield(m.(mt),'nested') [?? how to indicate code snippet]
%    - See `transformation structure` for details on how the models are parameterized
%
% Note regarding customization:
%    The default model list can be changed by editing the line containing generic.opts_geof.model_list_default in 'rs_aux_defaults_define' [??how to hyperlink], running it 
%    once, and saving the workspace as rs_aux_defaults.mat.
%   
% Note regarding model definition structure: 
%    - mdef=rs_geofit() returns a model definition structure, which defines the available models and their characteristics.
%    - mdef.model_types is a cell array {model_name1,model_name2,...} of the names of available models
%    - mdef.(model_name) defines each model
%    - mdef.(model_name).class is the model class: 'mean','procrusetes,'affine','projective','pwaffine' (see `rs_xform_apply` ??how to hyperlink)
%    - mdef.(model_name).nested lists the names of the nested models
%
% Note regarding nesting:
%    - Nesting by model type: Some models are extensions of others. For example, the affine_offset model extends the affine_noofset model, by allowing offsets.
%    The more general model will always provide a fit that is at least as good as the less-general model, but will have more parameters.  The if_nestbymodel option provides a way to determine
%    whether the improvement in fit is better than would be expected by chance.
%
%        - To do this, rs_geofit (i) fits with the less-general model, then (ii) shuffles the residuals (the difference between the predicted
%        coordinates in ds_out and the actual coordinates) among the stimuli, and (iii) refits with the more general model. If the more general
%        model provides a fit to the original data that is better than chance, this should rarely result in an improved fit.
%        - Goodness of fit values and tallies are provided in
%        gfs{k}{dim_out,dim_in}.d_shuff and gfs{k}{dim_out,dim_in}.surrogate_count
%        - Fine-tuning: if_nestbymodel=+1 vs -1
%
%            - With if_nestbymodel=+1, all nested models specified by model_list are examined
%            - with if_nestbymodel=-1, only the maximally nested models are examined. (Model B is considered to be maximally nested in model A if there is no intermediate nested model, i.e., no model X for which B is nested in X, and X is nested in A.)
%    
%    - Nesting by dimension: Models with more coordinates have a greater number of parameters than models with fewer coordinates, and thus may also be viewed as extensions.
%    The if_nestbydim_in and if_nestbydim_out options provide a way to determine whether an improvement due to adding dimensions is better than would be expected by chance.
%   
%        - To do this, rs_geofit (i) fits a model with fewer coordinates, then (ii) shuffles the added coordinates among the stimuli, and (iii) refits with the more general model. If the more general
%        model provides a fit to the original data that is better than chance, this should rarely result in an improved fit.
%        - Goodness of fit values and tallies are provided in gfs{k}{dim_out,dim_in}.d_shuff_nestdim_[in|out] and gfs{k}{dim_out,dim_in}.surrogate_count_nestdim_[in|out].
%        - Fine-tuning: if_nestbydim_[in|out]=+1 vs -1
%
%            - With if_nestbydim_[in|out]=+1, input and output coordinates are
%            used as is for the nesting calculations.  This is appropriate if the input and output coordinates themselves are nested, i.e., if data_in.ds{k}{dim_in}(:,1:r)=data_in.ds{k}{r}, for dim_in>r (and similarly for dim_out)
%            - However, if this is not the case (for example, if each each set of
%            coordinates data_in.ds{k}{dim_in} is arbitrarily rotated), this analysis could be misleading, since a coordinate in a low-dimensional coordinate set data_in.ds{k}{r} could be rotated into a higher coordinate in data_in.ds{k}(idim}, for idim>r.
%            - To avoid this possible pitfall, use if_nestbydim_[in|out]=-1.  This applies  principal components analysis to the coordinates prior to the analysis of nesting.
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, PSG_GEOMODELS_FIT, PSG_GEOMODELS_PLOT, PSG_GEOMODELS_DEFINE,
%    PSG_GEOMODELS_NESTORDER, RS_DISP_GEOFIT.
%
psg_geomodels_def=psg_geomodels_define();
%special case: display available models
if nargin==0
    gfs=psg_geomodels_def;
    xs=struct;
    aux_out=struct;
    return
end
if (nargin<=2)
    aux=struct;
end
%
%set up sub-structure options
%
aux=filldefault(aux,'opts_geof',struct); %options for this module
aux.opts_geof=filldefault(aux.opts_geof,'dimpairs_method','equal');
aux.opts_geof=filldefault(aux.opts_geof,'dim_max_in',10);
aux.opts_geof=filldefault(aux.opts_geof,'dim_max_out',aux.opts_geof.dim_max_in);
aux.opts_geof=filldefault(aux.opts_geof,'dimpairs_list',repmat([1:aux.opts_geof.dim_max_in]',[1 2]));
aux.opts_geof=filldefault(aux.opts_geof,'if_stats',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_nestbymodel',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_nestbydim',0);
aux.opts_geof=filldefault(aux.opts_geof,'if_nestbydim_in',aux.opts_geof.if_nestbydim);
aux.opts_geof=filldefault(aux.opts_geof,'if_nestbydim_out',aux.opts_geof.if_nestbydim);
aux.opts_geof=filldefault(aux.opts_geof,'if_center',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_frozen',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_fit_summary',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_fit_log',0);
aux.opts_geof=filldefault(aux.opts_geof,'if_warn',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_log',1);
aux.opts_geof=filldefault(aux.opts_geof,'persp_method','best');
%
aux=filldefault(aux,'opts_check',struct); %options for other modules called
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
if aux.opts_geof.if_stats
    aux.opts_geof=filldefault(aux.opts_geof,'nshuffs',100);
else
    aux.opts_geof=filldefault(aux.opts_geof,'nshuffs',0);
    aux.opts_geof.if_nestbymodel=0;
    aux.opts_geof.if_nestbydim=0;
end
%
aux=rs_aux_customize(aux,'rs_geofit');
%
aux.opts_geof=filldefault(aux.opts_geof,'model_list',aux.opts_geof.model_list_default);
%
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
xs=[];
gfs=[];
%
%parse model names and determine order of models to compute
%
[aux,aux_out]=rs_geofit_getmodels(aux,psg_geomodels_def,aux_out);
%aux.opts_geof.model_list is model models in order to be evaluated
%aux.opts_geof.model_definitions is the model definition structure
nmodels=length(aux.opts_geof.model_list);
%
%check consistency within input and output
%
check_in=rs_check_coordsets(data_in,aux.opts_check);
aux_out.warnings=strvcat(aux_out.warnings,check_in.warnings);
check_out=rs_check_coordsets(data_out,aux.opts_check);
aux_out.warnings=strvcat(aux_out.warnings,check_out.warnings);
if aux_out.warn_bad>0
    disp('cannot proceed');
    return
end
dim_list_in=check_in.dim_list_union;
dim_list_out=check_out.dim_list_union;
%
%check consistency between input and output
%
nstims_in=check_in.nstims_each;
nstims_out=check_out.nstims_each;
if nstims_in~=nstims_out
    wmsg=sprintf('mismatch in number of stimuli: input dataset has %3.0f stimuli, output dataset has %3.0f stimuli',nstims_in,nstims_out);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
end
if length(union(check_in.typenames_union,check_out.typenames_union))~=length(intersect(check_in.typenames_inter,check_out.typenames_inter))
    wmsg=sprintf('data_in and data_out have different typenames');
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
if aux_out.warn_bad>0
    disp('cannot proceed');
    return
end
z=aux.opts_geof;
[dpx,dpy]=meshgrid(1:min(z.dim_max_in,max(dim_list_in)),1:min(z.dim_max_out,max(dim_list_out)));
dimpairs_all=[dpx(:),dpy(:)];
if ((ndims(z.dimpairs_list)~=2) | (size(z.dimpairs_list,2)~=2))
    wmsg=sprintf('dimension pairing list has unexpected shape; default pairing '' equal'' used');
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',z.if_warn));
    z.dimpairs_method='equal';
end
switch z.dimpairs_method %determine coordinate groups
    case 'all'
        z.dimpairs_list=dimpairs_all;
    case 'equal'
        z.dimpairs_list=dimpairs_all(find(dimpairs_all(:,1)==dimpairs_all(:,2)),:);
    case 'din_lteq_dout'
        z.dimpairs_list=dimpairs_all(find(dimpairs_all(:,1)<=dimpairs_all(:,2)),:);
    case 'din_gteq_dout'
        z.dimpairs_list=dimpairs_all(find(dimpairs_all(:,1)>=dimpairs_all(:,2)),:);
    case 'list'
    otherwise
        wmsg=sprintf('dimension pairing method  (%s) not recognized; ''equal'' used',z.dimpairs_method);
        z.dimpairs_method='equal';
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',z.if_warn));
end
dp_bad=union(find(any(z.dimpairs_list<1,2)),find(any(z.dimpairs_list~=round(z.dimpairs_list),2)));
if ~isempty(dp_bad)
    wmsg=sprintf('dimension pairing list has non-integer values or values less than 1, ignored');
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',z.if_warn));
    z.dimpairs_list=z.dimpairs_list(setdiff(1:size(z.dimpairs_list,1),dp_bad),:);
end
dp_sel=intersect(find(z.dimpairs_list(:,1)<=z.dim_max_in),find(z.dimpairs_list(:,2)<=z.dim_max_out));
z.dimpairs_list=z.dimpairs_list(dp_sel,:);
%
nsets=max(check_in.nsets,check_out.nsets);
gfs=cell(1,nsets);
xs=struct;
for k=1:nmodels
    model_name=z.model_list{k};
    xs.(model_name)=struct;
    xs.(model_name).class=z.model_definitions.(model_name).class;
    xs.(model_name).xforms=struct;
end    
%
opts_psgfit_base=struct;
opts_psgfit_base.model_types_def=z.model_definitions;
opts_psgfit_base.if_log=z.if_fit_log;
opts_psgfit_base.if_summary=z.if_fit_summary;
%fields copied with no change
opts_psgfit_base.nshuffs=z.nshuffs;
opts_psgfit_base.if_nestbydim=z.if_nestbydim;
opts_psgfit_base.if_nestbydim_in=z.if_nestbydim_in;
opts_psgfit_base.if_nestbydim_out=z.if_nestbydim_out;
opts_psgfit_base.if_nestbymodel=z.if_nestbymodel;
opts_psgfit_base.if_center=z.if_center;
opts_psgfit_base.if_frozen=z.if_frozen;
opts_psgfit_base.persp_method=z.persp_method;
%
for iset=1:nsets
    iset_in=1+mod(iset-1,check_in.nsets);
    iset_out=1+mod(iset-1,check_out.nsets);
    d_adj=data_in.ds{iset_in};
    d_ref=data_out.ds{iset_out};
    if z.if_log
        disp(sprintf('geometric model fits: input set %2.0f, output set %2.0f',iset_in,iset_out));
    end
    %
    %do the fits
    %
    opts_psgfit=opts_psgfit_base;
    opts_psgfit.dimpairs_list=z.dimpairs_list;
    opts_psgfit.if_keep_opts_model_used=0; %eliminate some un-needed fields
    [gf,opts_psgfit_used]=psg_geomodels_fit(d_ref,d_adj,opts_psgfit);
    gfs{iset}.gf=gf;
    z.warnings_fit{iset}=opts_psgfit_used.warnings;
    if (z.if_warn & ~isempty(z.warnings_fit{iset}))
        disp('warnings encountered during fits:')
        disp(z.warnings_fit{iset});
    end
    %
    %format the transformations
    %
    for k=1:nmodels
        model_name=z.model_list{k};
        for idim=1:min(size(gf))
            if ~isempty(gf{idim,idim})
                if isfield(gf{idim,idim},'transforms')
                    xs.(model_name).xforms.ts{iset}{1,idim}=gf{idim,idim}.transforms{k};
                end
            end
        end
    end
%   xs.(model_name).class: the transformation class ('affine', 'projective','pwaffine','pwprojective')
%   xs.(model_name).xforms.ts{k}{idim}: the transformation to be applied to dataset k, coordinate set of dimension idim
%     (this will be empty if there is no transformation in gfs{k}.gf{idim,idim}
end
% 
% return options as used
%
aux_out.opts_check=aux.opts_check;
aux_out.opts_geof=z;
return
end

function [aux_new,aux_out_new]=rs_geofit_getmodels(aux,psg_geomodels_def,aux_out)
%parse the model names, request if none are supplied, check that they are
%recognized, determine nesting and maximal nesting, and log if requested
[nest_rank,order_ptrs,model_types_nested]=psg_geomodels_nestorder(psg_geomodels_def); %determine model types in nesting order
if_interactive=double(isempty(aux.opts_geof.model_list));
if_ok=0;
if if_interactive
    model_ptrs=[];
    for k=1:length(aux.opts_geof.model_list_default)
        model_ptrs(1,end+1)=strmatch(aux.opts_geof.model_list_default{k},model_types_nested,'exact'); %starting point for interactive
    end
end
while(if_ok==0)
    if ~if_interactive
        if ~iscell(aux.opts_geof.model_list)
            aux.opts_geof.model_list{1}=aux.opts_geof.model_list;
        end
        models_used=cell(0);
        model_ptrs=[];
        for k=1:length(aux.opts_geof.model_list) %check that model names are recognized
            model_ptr=strmatch(aux.opts_geof.model_list{k},model_types_nested,'exact');
            if isempty(model_ptr)
                wmsg=sprintf('model type %s not recognized, will be ignored',aux.opts_geof.model_list{k});
                aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_geof.if_warn));
            else
                models_used{1,end+1}=model_types_nested{model_ptr};
                model_ptrs(1,end+1)=model_ptr;
            end
        end
    else %get model list interactively
        for k=1:length(model_types_nested)
            disp(sprintf('model %2.0f: %s',k,model_types_nested{k}));
        end
        model_ptrs=getinp('choice(s)','d',[1 length(model_types_nested)],model_ptrs);
        models_used=cell(1,length(model_ptrs)); %models used, but not necessarily in nesting order
        for k=1:length(model_ptrs)
            models_used{k}=model_types_nested{model_ptrs(k)};
        end
    end
    %
    %create a model definition structure based only on the models used
    %
    nmodels=length(models_used);
    mdef=struct;
    models_ordered=cell(1,nmodels);
    ko=0;
    for k=1:length(model_types_nested) %now work in nesting order
        if strmatch(model_types_nested{k},models_used,'exact')
            model_type=model_types_nested{k};
            ko=ko+1;
            models_ordered{ko}=model_type;
            mdef.(model_type)=rmfield(psg_geomodels_def.(model_type),'nested');
            nested_all=psg_geomodels_def.(model_type).nested;
            nested_used=cell(0);
            for kn=1:nmodels
                if ~isempty(strmatch(models_used{kn},nested_all,'exact'))
                    nested_used{1,end+1}=models_used{kn};
                end
            end
            mdef.(model_type).nested=nested_used;
        end
    end
    mdef.model_types=models_ordered; %complete the model definition structure
    aux.opts_geof.model_list=models_ordered; %models in order of evaluation
    aux.opts_geof.model_definitions=mdef; %model definition structure
    [nest_rank,order_ptrs,models_ordered,opts_nestorder_used]=psg_geomodels_nestorder(mdef); %recreate the ordered list and obtain maximally nested models
    mdef_max=opts_nestorder_used.mdef0; %model definitions with maximally nested model
    if aux.opts_geof.if_log | if_interactive
        disp('models, in order of evaluation')
        for k=1:nmodels
            disp(sprintf(' model: %s',models_ordered{k}))
            if aux.opts_geof.if_nestbymodel~=0
                switch aux.opts_geof.if_nestbymodel
                    case 1
                        nesteds=mdef.(models_ordered{k}).nested;
                        nest_string='nested';
                    case -1
                        nesteds=mdef_max.(models_ordered{k}).nested;
                        nest_string='maximally nested';
                end
                if length(nesteds)>0
                    disp(sprintf('  %s models:',nest_string))
                    disp(nesteds);
                else
                    disp('  no nested models');
                end
            end
        end
    end
    if (if_interactive)
        if_ok=getinp('1 if ok','d',[0 1]);
    else
        if_ok=1;
    end
end
aux_new=aux;
aux_out_new=aux_out;
return
end
