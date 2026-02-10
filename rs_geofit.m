function [gfs,xs,aux_out]=rs_geofit(data_in,data_out,aux)
% [gfs,xs,aux_out]=rs_geofit(data_in,data_out,aux) fits one or more geometrical transformations
% to coordinate sets
%
% data_in.ds{k},sas{k},sets{k}: dataset structures that are the starting points for the transformation
% data_out.ds{k},sas{k},sets{k}: dataset structures that are the targets of the transformation
%  They must have same number of stimuli, and a warning is given if the number matches but the names do not.
% aux:
%  aux.opts_check
%    if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
%  aux.opts_geof
%   model_list: a string, or a cell array of strings, consisting of one or more of the model types to be fitted.
%     These the strings in getfield(psg_geomodels_define,'model_types'), and currently are the following
%     If empty, the list is requested interactively; if omitted is given by model_list_default
%    'mean'                       : all input values mapped to mean of output
%    'procrustes_noscale_nooffset': rotation (and possibly reflection), no rescaling     , no translation
%    'procrustes_scale_nooffset   : rotation (and possibly reflection), rescaling allowed, no translation
%    'procrustes_noscale_offset'  : rotation (and possibly reflection), no rescaling     , translation allowed
%    'procrustes_scale_offset     : rotation (and possibly reflection), rescaling allowed, translation allowed
%    'affine_nooffset'            : linear transformation, no translation
%    'affine_offset'              : linear transformation, translation allowed
%    'projective'                 : projective transformation
%    'pwaffine'                   : piecwise affine with one cutplane; two linear transformations with agreement on the cut
%    'pwaffine_2'                 : piecwise affine with two cutplanes: four linear transformations, with agreement on the cuts
%     Note: if empty, this is requested interactively.
%  model_list_default: models when model_list is not specified, can modify in rs_aux_defaults_define
%  dimpairs_method: pairs of dimensions considered between input and ouptut datasets
%    'all': all pairings up to min(available dimensions, dim_max_[in|out]
%    'equal': input dimension= output dimension (default)
%    'din_lteq_dout': input dimension less than or equal to output dimension
%    'din_gteq_dout': input dimension greater than or equal to output dimension
%    'list': a two-column list of pairs (in, out)
%  dim_max_in:  maximum dimension of input dataset to use, defaults to 10
%  dim_max_out: maximum dimension of output dataset to use, defaults to dim_max_in
%  dimpairs_list:  two-column array of pairs of dimensions for input and output, defaults to repmat([1:dim_max_in]',[1 2])
%  if_stats: 1 to enable statistics (0 is default; will override if_nestbymodel and if_nestbydim)
%  nshuffs:         number of shuffles, defaults to 100 if if_stats=1, 0 if if_stats=0
%  if_plot: 1 to plot statistics, defaults to if_stats
%  if_nestbymodel:  1 (default) to do statistics on nesting by model, 0 to omit, -1 to only do statistics for maximally nested models
%  if_nestbydim: +/-1 to do statistics for nesting by dimension within input dataset, 0 to omit
%    Use +1 if the input dataset is built up, one dimension at a time, and each successive dimension
%      matches the lower-dimensional model except for the added dimension -- that is, data_in.ds{k}{idim}=data_in.ds{k}{idim-1}.
%      This will always be the case if the input dataset is created by multidimensional scaling of the same distance matrix,
%      or by principal components analysis of a data matrix.
%      But it will not be the case in general, e.g., if the coordinates from each dimension are created by a consensus procedure.
%    Use -1 if this is not the case. For testing each added dimension, PCA around the centroid will be performed prior to the nesting calculation
%    This option is only recommended if, whenever a model is fit for (din,dout), it is also fit for (din-1,dout). This is guaranteed for  dimpairs_method='all' or 'din_lteq_dout;
%  if_center: 1 (default) to center the data
%  if_frozen: 1 (default) to use frozen random numbers, 0 for random each time, <0 to specify a seed
%  if_fit_summary: 1 (default) to log summary of fitting
%  if_fit_log: 1 (0: default) for detailed log
%  if_log: 1 (default) to log progress
%  if_warn: 1 (default) to show warnings
%    
% gfs{k}.results{din,dout} is a structure containing the results of the analysis, including fitted transformations, residuals, statistics
%    from data_in.ds{k} to data_out.ds{k}, for dimensions din and dout.
%    Subfields are:
%      model_types_def: model_types_def.model_types is a cell array of the models fitted; model_types_def.(model).nested is the names of the nested models tested
%      ref_dim: dimension of reference dataset used for fitting (=dout)
%      adj_dim: dimension of adjusted dataseet used for fitting (=din)
%      d_shuff_dims: metadata for d_shuff and d_shuff_nestdim (normalization type 1: denom for d from surrogate, type 2: denom for d from data)
%               d_shuff_dims: 'd1: model, d2: shuffle, d3: nested model, d4: normalization type'  
%      surrogate_count_dims: metadata for surrogate_count and surrogate_count_nestdim
%               surrogate_count_dims: 'd1: model, d2: nested model, d3: normalization type'
%      opts_geofit: supplied options for rs_geofit
%      d: dimensionless goodness of fit, for each of the models (length=length(model_types_def.model_types));
%      transforms: the transforms for each of the models
%      opts_model_used: model options, e.g., if_offset, if_scale, and fitting options
%      d_shuff: goodness of fit for nesting by model (dims as in d_shuff_dims, d3 is indexed by position in model_types_def.(model_name).nested)
%      surrogate_count: number of times surrogate (nesting by model) yields a smaller d than data (dims as in surrogate_count_dims, d3 is indexed by position in model_types_def.model_names)
%      nestdim_list: the lower dimensions used in nesting by dimension
%      opts_model_shuff_used_nestdim: options used for each model, shuffle, and nested model
%      d_shuff_nestdim: goodness of fit, for each model, shuffle, nested dim, and normalization type (dims as in d_shuff_dims)
%      surrogate_count_nestdim: number of times that surrogate (nesting by dim) yields a smaller d than data (dims as in surrogate_count_dims)
%
% xs: the transformations, in a format compatible with rs_xform_apply
%   xs.(model_name).class: the transformation class ('mean','procrustes','affine', 'projective','pwaffine','pwprojective')
%   xs.(model_name}.xforms.ts{k}{idim}: the transformation to be applied to dataset k, coordinate set of dimension idim
%     (this will be empty if there is no transformation in gfs{k}.results{idim,idim}
%
% aux_out: auxiliary outputs and parameter values used
%    opts_geofit: overall options used
%    warnings: warnings generated in creating arguments for psg_get_coordsets
%    warn_bad: count of warnings that prevent further processing
%
%   Note: mdef=rs_geofit() returns a model definition structure
%     mdef.model_types is a cell array {model_name1,model_name2,...} of the names of available models
%     mdef.(model_name) defines each model 
%     mdef.(model_name).nested lists the names of the nested models
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, PSG_GEOMODELS_FIT, PSG_GEOMODELS_PLOT, PSG_GEOMODELS_DEFINE,
%    PSG_GEOMODELS_NESTORDER, RS_DISP_GEOFIT.
%
psg_geomodels_def=psg_geomodels_define();
%special case: display available models
if nargin==0shuff
    [nr,order_ptrs,model_types_nested]=psg_geomodels_nestorder(psg_geomodels_def);
    gfs=model_types_nested';
    disp(model_types_nested');
    xs=struct;
    aux_out=struct;
    return
end
if (nargin<=1)
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
aux.opts_geof=filldefault(aux.opts_geof,'if_plot',aux.opts_geof.if_stats);
aux.opts_geof=filldefault(aux.opts_geof,'if_nestbymodel',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_nestbydim',0);
aux.opts_geof=filldefault(aux.opts_geof,'if_center',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_frozen',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_fit_summary',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_fit_log',0);
aux.opts_geof=filldefault(aux.opts_geof,'if_warn',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_log',1);
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
opts_psgfit_base.if_nestbymodel=z.if_nestbymodel;
opts_psgfit_base.if_center=z.if_center;
opts_psgfit_base.if_frozen=z.if_frozen;
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
    [results,opts_psgfit_used]=psg_geomodels_fit(d_ref,d_adj,opts_psgfit);
    gfs{iset}.results=results;
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
        for idim=1:min(size(results))
            if ~isempty(results{idim,idim})
                if isfield(results{idim,idim},'transforms')
                    xs.(model_name).xforms.ts{iset}{1,idim}=results{idim,idim}.transforms{k};
                end
            end
        end
    end
%   xs.(model_name).class: the transformation class ('affine', 'projective','pwaffine','pwprojective')
%   xs.(model_name).xforms.ts{k}{idim}: the transformation to be applied to dataset k, coordinate set of dimension idim
%     (this will be empty if there is no transformation in gfs{k}.results{idim,idim}

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
