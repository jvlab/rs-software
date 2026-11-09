function [results,opts_geofit_used]=psg_geomodels_fit(d_ref,d_adj,opts_geofit)
% [results,opts_geofit_used]=psg_geomodels_fit(d_ref,d_adj,opts_geofit) fits geometric models
% (scale, affine, projective, piecewise affine) across a range of dimensions, and do statistis
%
% This is the modularized version of psg_geomodels_run, in turn derived from psg_geomodels_test, 
% steps throgh a range of dimensions for reference and adjusted dataset
%
% d_adj: dataset to be adjusted, k-dimensional model is in d_adj{k}, one row per stimulus
% d_ref: reference dataset; k-dimensional model is in d_ref{k}
% opts_geofit: a structure with these fields:
%   model_types_def:  model type definitions, typically returned by psg_geomodels_define
%      specifies which models are to be fit; if empty, requested interactively
%   ref_dim_list: reference dataset dimensions to analyze, defaults to [2 3].  Ignored if dimpairs_list is present.
%   adj_dim_list: adjusted dataset dimensions to analyze, defaults to ref_dim_list.  Ignored if dimpairs_list is present.
%   dimpairs_list: two-column array of pairs of dimensions to test [adj, ref].  
%   if_center: 1 (default) to center the data
%   if_frozen: 1 (default) to use frozen random numbers, 0 for random each time, <0 to specify a seed)
%   if_log: 1 (default) to log
%   if_summary: 1 (default) to show a summary
%   nshuffs: number of shuffles, defaults to 100
%   if_nestbydim: +/-1 or 0 (default) to also do statistics for nesting by dimension within each k-dimensional model of the adjusted dataset,
%       i.e., whether the k dimensions of the k-dimensional model have greater explanatory power than the first m dimensions of that model.   
%     Use +1 if, for each k-dimensional model, the lower m dimensions (m<k) should be considered as nested.
%     Use -1 if PCA should be applied within each k-dimensional model, to ensure that the lower m dimensions (m<k)
%        explain as much of the variance as possible.
%   This sets the defaults for if_nestbydim_in, which applies to nesting of the input (adjusted) dataset, and if_nestbydim_out, which applies to nesting of the output dataset,
%     though these can be separately set.
%     A choice of +1 is appropriate if each k-dimensional is created by MDS of a distance matrix, or by PCA of a response matrix,
%       (though not necessarily the same distance matrix or response matrix for each k)
%       It is also appropriate if for each k, d_adj{k} and d_adj{k-1} agree on the first k-1 dimensions
%     A choice of -1 is appropriate if a k-dimensional model is an arbitrary rotation of a coordinate set.  By applying PCA
%       to the k-dimensional model to obtain the coords for m<k, this ensures that it is tested against models that account for 
%       as much as posible of the variance
%     Note that to compare the explanatory power of the k-dimensional coords in d_adj{k} against the coordinates in a lower dimensional model, e.g., d_adj{m},
%       then one should ensure that d_adj{k}(:,1:m)=d_adj{m} and use if_nestbydim=+1
%   if_nestbymodel: 1 (default) to nest by models, -1 to only look at maximally nested model, 0 for none
%
%  [not typically needed]
%   if_geomodel_check: 1 (default: 0) to recheck computation of transform via psg_geomodels_apply
%   if_pwaffine_details: 1 (default: 0) to show details in summary for piecewise-affine minimizations)
%   persp_method: 'fmin' (default) or 'oneshot' (Zhang method, see persp_xform_find)
%   persp_if_cycle: 1 (default), or 0, variants of Zhang method
%   if_keep_opts_model_used: 0 to eliminate return of opts_model_used, opts_model_shuff_used_nestdim, 1 (default) to keep
%
%  results: cell(max(ref_dim_list),max(adj_dim_list)), a structure with results
%     if dimension pairs are specified by dimpairs_list, then those maxima are used.
%  opts_geofit_used: options used, and warnings field
%
% 27Jan26: use psg_geomodels_nestorder to determine order of model computations, add options for nest by model
% 06Feb26: mods to allow for arbitrary pairs of dimensions
% 10Feb26: option to not return opts_model_used, opts_model_shuff_used_nestdim
% 23Feb26: add if_nestbydim_in, if_nestbydim_out and resulting computations
% 27Mar26: fix pointer in saving options for ref nest by dim
% 01Jun26: save transformations for nested comparisons
%
%   See also:  PSG_GEOMODELS_RUN, PSG_GEO_GENERAL, PSG_GEOMODELS_DEFINE, PSG_PCAOFFSET, PSG_GEOMODELS_NESTORDER, PSG_GEOMODELS_NESTUTIL.
%
if (nargin<=2)
    opts_geofit=struct;
end
opts_geofit=filldefault(opts_geofit,'model_types_def',[]);
opts_geofit=filldefault(opts_geofit,'ref_dim_list',[2 3]);
opts_geofit=filldefault(opts_geofit,'adj_dim_list',opts_geofit.ref_dim_list);
opts_geofit=filldefault(opts_geofit,'if_center',1);
opts_geofit=filldefault(opts_geofit,'if_frozen',1);
opts_geofit=filldefault(opts_geofit,'if_log',1);
opts_geofit=filldefault(opts_geofit,'if_summary',1);
opts_geofit=filldefault(opts_geofit,'nshuffs',100);
opts_geofit=filldefault(opts_geofit,'if_nestbydim',0);
opts_geofit=filldefault(opts_geofit,'if_nestbydim_in',opts_geofit.if_nestbydim);
opts_geofit=filldefault(opts_geofit,'if_nestbydim_out',opts_geofit.if_nestbydim);
opts_geofit=filldefault(opts_geofit,'if_nestbymodel',1);
opts_geofit=filldefault(opts_geofit,'persp_method','fmin');
opts_geofit=filldefault(opts_geofit,'persp_if_cycle',1);
opts_geofit=filldefault(opts_geofit,'if_geomodel_check',0);
opts_geofit=filldefault(opts_geofit,'if_geomodel_check_tol',10^-6); %tolerance for if_geomodel_check
opts_geofit=filldefault(opts_geofit,'if_pwaffine_details',0);
opts_geofit=filldefault(opts_geofit,'if_keep_opts_model_used',1);
%
opts_geofit=filldefault(opts_geofit,'if_keep_transforms',0);
opts_geofit=filldefault(opts_geofit,'if_keep_transforms_nestbymodel',opts_geofit.if_keep_transforms*abs(opts_geofit.if_nestbymodel));
opts_geofit=filldefault(opts_geofit,'if_keep_transforms_nestbydim_in',opts_geofit.if_keep_transforms*abs(opts_geofit.if_nestbydim_in));
opts_geofit=filldefault(opts_geofit,'if_keep_transforms_nestbydim_out',opts_geofit.if_keep_transforms*abs(opts_geofit.if_nestbydim_out));
%
%set up ref_dim_each, adj_dim_each
% ref_dim_each is list of ref dimensions
% adj_dim_each{rd} is list of adj dimensions to be tested with ref dimension rd
%
if ~isfield(opts_geofit,'dimpairs_list')
    ref_dim_each=unique(opts_geofit.ref_dim_list);
    adj_dim_each=cell(1,max(ref_dim_each));
    for ird=1:length(ref_dim_each)
        rd=ref_dim_each(ird);
        adj_dim_each{rd}=unique(opts_geofit.adj_dim_list(:))';
    end
    adj_dim_list=opts_geofit.adj_dim_list;
    ref_dim_list=opts_geofit.ref_dim_list;
else
    ref_dim_each=unique(opts_geofit.dimpairs_list(:,2));
    adj_dim_each=cell(1,max(ref_dim_each));
    for ird=1:length(ref_dim_each)
        rd=ref_dim_each(ird);
        adj_dim_each{rd}=unique(opts_geofit.dimpairs_list(opts_geofit.dimpairs_list(:,2)==rd))'; %the adj dims used for each ref dim
    end
    adj_dim_list=unique(opts_geofit.dimpairs_list(:,1)); %all adj dims used
    ref_dim_list=unique(opts_geofit.dimpairs_list(:,2)); %all ref dims used
end
if ~isstruct(opts_geofit.model_types_def)
    opts_geofit.model_types_def=psg_geomodels_define(1);
end
%for compatibility with psg_geomodels_run
ref_dim_list=unique(ref_dim_list);
adj_dim_list=unique(adj_dim_list);
if_center=opts_geofit.if_center;
if_frozen=opts_geofit.if_frozen;
nshuff=opts_geofit.nshuffs;
model_types_def=opts_geofit.model_types_def;
if_nestbydim_in=opts_geofit.if_nestbydim_in;
if_nestbydim_out=opts_geofit.if_nestbydim_out;
if_geomodel_check=opts_geofit.if_geomodel_check;
if_pwaffine_details=opts_geofit.if_pwaffine_details;
%
opts_geofit_used=opts_geofit;
opts_geofit_used.warnings=[];
%
model_types=model_types_def.model_types;
nmodels=length(model_types);
%
results=cell(max(ref_dim_each),max(adj_dim_list));
%
%set up model nesting
[nest_rank,order_ptrs,model_types_nested,opts_nest_used]=psg_geomodels_nestorder(model_types_def); %determine order in which models should be analyzed, so that nested models are analyzed first
switch opts_geofit.if_nestbymodel
    case 1 %keep mode_types_def as is
    case 0 %remove all nested models
        for imodel=1:nmodels
            model_types_def.(model_types{imodel}).nested={};
        end
    case -1 %use a modified model definition structure with only maximal nested models
        model_types_def=opts_nest_used.mdef0;
        opts_geofit_used.model_types_def=model_types_def;
end
%set up pca version of adj if needed for nesting on input
if if_nestbydim_in~=0
    d_nbd_adj=cell(size(d_adj));
    for k=1:length(d_adj)
        if ~isempty(d_adj{k})
            if if_nestbydim_in==1
                d_nbd_adj{k}=d_adj{k};
            else %need to create datasets for nesting by dim
                d_nbd_adj{k}=psg_pcaoffset(d_adj{k},mean(d_adj{k},1),setfield(struct(),'if_log',0));
            end
        end
        if if_center
            d_nbd_adj{k}=d_nbd_adj{k}-repmat(mean(d_nbd_adj{k}),size(d_nbd_adj{k},1),1);
        end
    end
end %nesting by input dimension
%set up pca version of ref if needed for nesting on output
if if_nestbydim_out~=0
    d_nbd_ref=cell(size(d_ref));
    for k=1:length(d_ref)
        if ~isempty(d_ref{k})
            if if_nestbydim_out==1
                d_nbd_ref{k}=d_ref{k};
            else %need to create datasets for nesting by dim
                d_nbd_ref{k}=psg_pcaoffset(d_ref{k},mean(d_ref{k},1),setfield(struct(),'if_log',0));
            end
        end
        if if_center
            d_nbd_ref{k}=d_nbd_ref{k}-repmat(mean(d_nbd_ref{k}),size(d_nbd_ref{k},1),1);
        end
    end
end %nesting by output dimension
%
for iref_ptr=1:length(ref_dim_each)
    ref_dim=ref_dim_each(iref_ptr);
    for iadj_ptr=1:length(adj_dim_each{ref_dim})
        adj_dim=adj_dim_each{ref_dim}(iadj_ptr);
        %
        ref=d_ref{ref_dim};
        adj=d_adj{adj_dim};
        if (size(ref,2)~=ref_dim | size(adj,2)~=adj_dim) %make sure dimensions are correct
            wmsg=sprintf('ref dim (%2.0f) or adj dim (%2.0f) not found',ref_dim,adj_dim);
            opts_geofit_used.warnings=strvcat(opts_geofit_used.warnings,wmsg);
            if opts_geofit.if_log
                disp(wmsg);
            end
        else
            r=struct;
            r.model_types_def=model_types_def;
            r.ref_dim=ref_dim;
            r.adj_dim=adj_dim;
            r.d_shuff_dims='d1: model, d2: shuffle, d3: nested model, d4: normalization type';
            r.surrogate_count_dims='d1: model, d2: nested model, d3: normalization type';
            r.opts_geofit=opts_geofit;  
            npts=size(ref,1);
            if opts_geofit.if_log
               disp(' ');
               disp(sprintf('analyzing ref dim %3.0f and adj dim %3.0f, number of data points: %3.0f',ref_dim,adj_dim,npts));
            end
            if if_center
                ref=ref-repmat(mean(ref,1),npts,1);
                adj=adj-repmat(mean(adj,1),npts,1);
            end
            %
            d=zeros(nmodels,1);
            d_nonorth=zeros(nmodels,1);
            d_calc_types={'den: surrogate','den:  original'};
            %    
            transforms=cell(nmodels,1);
            transforms_nonorth=cell(nmodels,1);
            adj_model=cell(nmodels,1);
            adj_model_check=cell(nmodels,1);
            adj_model_nonorth=cell(nmodels,1);
            resids=cell(nmodels,1);
            d_check=zeros(nmodels,1);
            %
            opts_model_used=cell(nmodels,1);
            opts_model_nonorth_used=cell(nmodels,1);
            %
            %quantities for analysis of one model nested in another
            n_ntypes=length(d_calc_types); %normalization types: 1: orig, 2: shuffle
            %
            d_shuff=zeros(nmodels,nshuff,nmodels-1,n_ntypes); %d1: model, d2: shuffle, d3: nested model, d4: normalization type
            opts_model_shuff_used=cell(nmodels,nshuff,nmodels-1);
            model_lastnested=zeros(nmodels,1);
            surrogate_count=zeros(nmodels,nmodels-1,n_ntypes);
            transforms_nestbymodel=cell(nmodels,nshuff,nmodels-1);
            %
            %quantities for analysis of a model with a lower adj dim nested in a higher adj dim
            d_shuff_nestdim_in=zeros(nmodels,nshuff,iadj_ptr-1,n_ntypes); %d1: model, d2: shuffle, d3: nested dim, 4: normalization type
            opts_model_shuff_used_nestdim_in=cell(nmodels,nshuff,iadj_ptr-1); 
            surrogate_count_nestdim_in=zeros(nmodels,iadj_ptr-1,n_ntypes);
            nestdim_in_list=adj_dim_each{ref_dim}(1:iadj_ptr-1);
            transforms_nestbydim_in=cell(nmodels,nshuff,iadj_ptr-1);
            %
            %quantities for analysis of a model with a lower ref dim nested in a higher ref dim
            %note that nested dimension includes zero (all coords shuffled), so d3 is iref_ptr not iref_ptr-1
            d_shuff_nestdim_out=zeros(nmodels,nshuff,iref_ptr,n_ntypes); %d1: model, d2: shuffle, d3: nested dim, 4: normalization type
            opts_model_shuff_used_nestdim_out=cell(nmodels,nshuff,iref_ptr); 
            surrogate_count_nestdim_out=zeros(nmodels,iref_ptr,n_ntypes);
            nestdim_out_list=0; %on output side, nest each lower dimension that occurs with the same input dim
            transforms_nestbydim_out=cell(nmodels,nshuff,iref_ptr);
            %
            for kr=1:ref_dim-1
                if ismember(adj_dim,adj_dim_each{kr})
                   nestdim_out_list=[nestdim_out_list,kr];
                end
            end
            %
            d_den=sum(sum((ref-repmat(mean(ref,1),npts,1)).^2,1));
            if ref_dim<adj_dim
                ref_aug=[ref,zeros(npts,adj_dim-ref_dim)];
            else
                ref_aug=ref;
            end
            %
            if (if_frozen~=0)
                rng('default');
                if (if_frozen<0)
                    rand(1,abs(if_frozen));
                end
            else
                rng('shuffle');
            end
            perms=zeros(nshuff,npts);
            for ishuff=1:nshuff
                perms(ishuff,:)=randperm(npts);
            end
            for imodel_ptr=1:nmodels
                imodel=order_ptrs(imodel_ptr);
                %
                if (if_frozen~=0)
                    rng('default');
                    if (if_frozen<0)
                        rand(1,abs(if_frozen));
                    end
                else
                    rng('shuffle');
                end
                model_type=model_types{imodel};
                tstring=sprintf('model type: %s, adj dim %2.0f ref dim %2.0f',model_type,adj_dim,ref_dim);
                if opts_geofit.if_log
                    disp(tstring);
                end
                if adj_dim<model_types_def.(model_type).min_inputdims
                    if opts_geofit.if_log
                        disp(sprintf(' model type skipped, requires input dimension of at least %2.0f',model_types_def.(model_type).min_inputdims));
                    end
                else
                    opts_model=model_types_def.(model_type).opts;
                    model_class=model_types_def.(model_type).class;
                    opts_model.if_cycle=opts_geofit.persp_if_cycle;
                    opts_model.method=opts_geofit.persp_method;
                    [d(imodel),adj_model{imodel},transforms{imodel},opts_model_used{imodel}]=psg_geo_general(ref,adj,model_class,opts_model);
                    %
                    %verify the model   
                    %
                    switch model_class
                        case {'mean','procrustes','affine'}
                            adj_model_check{imodel}=transforms{imodel}.b*adj*transforms{imodel}.T+repmat(transforms{imodel}.c,npts,1);
                        case 'projective'
                            %note change of variable names between psg_geo_projective and persp_apply
                            adj_model_check{imodel}=persp_apply(transforms{imodel}.T,transforms{imodel}.c,transforms{imodel}.p,adj);
                        case 'pwaffine'
                            adj_model_check{imodel}=psg_pwaffine_apply(transforms{imodel},adj);
                            %also compare orthogonal and non-orthogonal versions
                            [d_nonorth(imodel),adj_model_nonorth{imodel},transforms_nonorth{imodel},opts_model_nonorth_used{imodel}]=psg_geo_general(ref,adj,model_class,setfield(opts_model,'if_orth',0));
                    end
                    if if_geomodel_check
                        adj_model_geo=psg_geomodels_apply(model_class,adj,transforms{imodel});
                        maxdev=max(abs(adj_model_check{imodel}(:)-adj_model_geo(:)));
                        if abs(maxdev)>opts_geofit.if_geomodel_check_tol
                            wmsg=sprintf('%s: geomodel check fails: maxdev=%16.14f, tol: %16.14f',tstring,maxdev,opts_geofit.if_geomodel_check_tol);
                            opts_geofit_used.warnings=strvcat(opts_geofit_used.warnings,wmsg);
                            if opts_geofit.if_log
                                disp(wmsg);
                            end
                        end
                    end
                    %verify model
                    model_check=max(abs(adj_model{imodel}(:)-adj_model_check{imodel}(:)));
                    %calculate residuals and verify d
                    resids{imodel}=ref_aug-adj_model{imodel};
                    d_check(imodel)=sum(resids{imodel}(:).^2)/d_den;
                    if opts_geofit.if_log
                        disp(sprintf('model check: %12.5f',model_check));
                        disp(sprintf('d: %12.7f   d_check: %12.7f   diff: %12.7f',...
                            d(imodel),d_check(imodel),d(imodel)-d_check(imodel)));
                        %check the reconstitution
                        disp('transform parameters:')
                        if isfield(transforms{imodel},'b') disp('b'); disp(transforms{imodel}.b); end
                        %
                        if isfield(transforms{imodel},'T') disp('T'); disp(transforms{imodel}.T); end
                        if isfield(transforms{imodel},'c') disp('c'); disp(transforms{imodel}.c); end
                        %for projective
                        if isfield(transforms{imodel},'p') disp('p transpose'); disp(transforms{imodel}.p'); end
                        %for piecewise
                        if isfield(transforms{imodel},'vcut') disp('vcut'); disp(transforms{imodel}.vcut); end
                        if isfield(transforms{imodel},'acut') disp('acut'); disp(transforms{imodel}.acut); end
                    end
                    %
                    %shuffles
                    %
                    if nshuff>0 & isempty(opts_model_used{imodel}.warnings)
                        nested_types=model_types_def.(model_type).nested; %models nested by type
                        for inest=1:length(nested_types)
                            nested_type=nested_types{inest};
                            nest_ptr=strmatch(nested_type,model_types,'exact');
                            if opts_geofit.if_log
                                disp(sprintf(' doing shuffles with residuals from nested model %2.0f (%s)',nest_ptr,nested_type));
                            end
                            for ishuff=1:nshuff
                                %if perms is trival, shuffled=ref_aug; otherwise the residuals from the nested model are shuffled
                                %note that the denominator used to normalize d has changed.
                                shuffled=adj_model{nest_ptr}+(ref_aug(perms(ishuff,:),:)-adj_model{nest_ptr}(perms(ishuff,:),:));
                                %d_shuff_orig is calculated with surrogate denominator; we also want to calculate it with original denominator
                                %also, turn off fmin display for shuffles
                                [d_shuff_orig,adj_model_shuff,transform_shuffle,opts_model_shuff_used{imodel,ishuff,inest}]=...
                                    psg_geo_general(shuffled,adj,model_class,setfield(opts_model,'if_display',0));
                                resids_shuff=shuffled-adj_model_shuff; %deviation of model from shuffle surrogate
                                d_shuff(imodel,ishuff,inest,1)=d_shuff_orig;
                                d_shuff(imodel,ishuff,inest,2)=sum(resids_shuff(:).^2)/d_den;
                                if opts_geofit.if_keep_transforms_nestbymodel
                                    transforms_nestbymodel{imodel,ishuff,inest}=transform_shuffle;
                                end
                            end
                            for id_calc_type=1:n_ntypes
                                surrogate_count(imodel,nest_ptr,id_calc_type)=sum(double(d(imodel)>=d_shuff(imodel,:,inest,id_calc_type)));
                                if opts_geofit.if_log
                                    disp(sprintf('d is >= d_shuff for %5.0f of %5.0f shuffles (%s), d_shuffles: range [%8.5f %8.5f], mean %8.5f s.d. %8.5f',...
                                        surrogate_count(imodel,nest_ptr,id_calc_type),nshuff,d_calc_types{id_calc_type},...
                                        min(d_shuff(imodel,:,inest,id_calc_type)),max(d_shuff(imodel,:,inest,id_calc_type)),...
                                        mean(d_shuff(imodel,:,inest,id_calc_type)),std(d_shuff(imodel,:,inest,id_calc_type))));
                                end
                            end
                            model_lastnested(imodel)=nest_ptr;
                        end %inest
                        %
                        % nest by input dimension: permute the residuals after fitting with the lower-dim model
                        % note also that the lower-dimensional input may not be a sufficient number of dimensions for the model type
                        %
                        if if_nestbydim_in~=0 %input dimension nesting
                            for iadj_ptr_nest=1:iadj_ptr-1
                                adj_dim_nest=adj_dim_each{ref_dim}(iadj_ptr_nest);
                                if adj_dim_nest<model_types_def.(model_type).min_inputdims %check that the lower-dimensional model can be fit
                                    if opts_geofit.if_log
                                        disp(sprintf('   skipping nesting model type %s with adj dim %2.0f nested in adj dim %2.0f, with ref dim %2.0f',...
                                            model_type,adj_dim_nest,adj_dim,ref_dim))
                                    end
                                else
                                    if opts_geofit.if_log
                                        disp(sprintf(' evaluating nesting model type %s with adj dim %2.0f nested in adj dim %2.0f, with ref dim %2.0f, if_nestbydim_in=%2.0f',...
                                            model_type,adj_dim_nest,adj_dim,ref_dim,if_nestbydim_in))
                                    end
                                    %recover lower-dim data
                                    adj_nest=d_nbd_adj{adj_dim_nest}; %either original data, or nested version from pca already centered if necessary
                                    switch if_nestbydim_in
                                        case 1
                                            transform_nest=results{ref_dim,adj_dim_nest}.transforms{imodel}; %recover previously-computed model
                                        case -1
                                            %recalculate a model from adj_nest
                                            [d_nest,adj_model_nest,transform_nest]=psg_geo_general(ref,adj_nest,model_class,setfield(opts_model,'if_display',0));
                                            %d_old-d_new will be small but could be nonzero
                                            %transform_old=results{ref_dim,adj_dim_nest}.transforms{imodel};
                                            %d_old=results{ref_dim,adj_dim_nest}.d(imodel);
                                            %disp(d_old-d_nest)
                                    end
                                    adj_model_nest=psg_geomodels_apply(model_class,adj_nest,transform_nest); %fit to ref data from adj with fewer dimensions
                                    if size(adj_model_nest,2)<size(ref_aug,2)
                                        %this can happen if size(adj_model_nest,2)<=size(ref,2) but size(ref,2)<size(adj_model,2)
                                        %so ref was augmented to match size(adj_model) but adj_model_nest
                                        %was only fit to a target of dimension size(ref,2)
                                        adj_model_nest=[adj_model_nest,zeros(npts,size(ref_aug,2)-size(adj_model_nest,2))];
                                    end
                                    %now do shuffles, find model params, and tabulate d
                                    for ishuff=1:nshuff
                                       %if perms is trivial, shuffled=ref_aug; otherwise the residuals from the nested model are shuffled
                                       %note that the denominator used to normalize d has changed.
                                       shuffled=adj_model_nest+(ref_aug(perms(ishuff,:),:)-adj_model_nest(perms(ishuff,:),:));
                                       %d_shuff_orig is calculated with surrogate denominator; we also want to calculate it with original denominator
                                       %also, turn off fmin display for shuffles
                                       [d_shuff_orig,adj_model_shuff,transform_shuffle,opts_model_shuff_used_nestdim_in{imodel,ishuff,iadj_ptr_nest}]=...
                                          psg_geo_general(shuffled,adj,model_class,setfield(opts_model,'if_display',0));
                                       resids_shuff=shuffled-adj_model_shuff; %deviation of model from shuffle surrogate
                                       d_shuff_nestdim_in(imodel,ishuff,iadj_ptr_nest,1)=d_shuff_orig;
                                       d_shuff_nestdim_in(imodel,ishuff,iadj_ptr_nest,2)=sum(resids_shuff(:).^2)/d_den;
                                       if opts_geofit.if_keep_transforms_nestbydim_in
                                           transforms_nestbydim_in{imodel,ishuff,iadj_ptr_nest}=transform_shuffle;
                                       end                                       
                                    end %ishuff
                                    for id_calc_type=1:n_ntypes
                                        surrogate_count_nestdim_in(imodel,iadj_ptr_nest,id_calc_type)=sum(double(d(imodel)>=d_shuff_nestdim_in(imodel,:,iadj_ptr_nest,id_calc_type)));
                                        if opts_geofit.if_log
                                            disp(sprintf('d is >= d_shuff for %5.0f of %5.0f shuffles (%s), d_shuffles: range [%8.5f %8.5f], mean %8.5f s.d. %8.5f',...
                                                surrogate_count_nestdim_in(imodel,iadj_ptr_nest,id_calc_type),nshuff,d_calc_types{id_calc_type},...
                                                min(d_shuff_nestdim_in(imodel,:,iadj_ptr_nest,id_calc_type)),max(d_shuff_nestdim_in(imodel,:,iadj_ptr_nest,id_calc_type)),...
                                                mean(d_shuff_nestdim_in(imodel,:,iadj_ptr_nest,id_calc_type)),std(d_shuff_nestdim_in(imodel,:,iadj_ptr_nest,id_calc_type))));
                                        end
                                    end
                               end %enough dimensions for model?
                            end %iadj_ptr_nest
                        end %if_nestbydim_in
                        %
                        %output dimension nesting: permute the dimensions that are not nested
                        %
                        if if_nestbydim_out~=0 
                            for iref_ptr_nest=1:length(nestdim_out_list)
                                ref_dim_nest=nestdim_out_list(iref_ptr_nest);
                                if opts_geofit.if_log
                                    disp(sprintf(' evaluating nesting model type %s with ref dim %2.0f nested in ref dim %2.0f, with adj dim %2.0f, if_nestbydim_out=%2.0f',...
                                        model_type,ref_dim_nest,ref_dim,adj_dim,if_nestbydim_out))
                                end
                                ref_nest=d_nbd_ref{ref_dim}; %original reference data, pca and centered if necessary
                                for ishuff=1:nshuff %now do shuffles, find model params, and tabulate d
                                    shuffled=[ref_nest(:,1:ref_dim_nest),ref_nest(perms(ishuff,:),ref_dim_nest+1:end)];%keep first ref_dim_nest dimensions, shuffle the rest
                                    if adj_dim>ref_dim
                                        shuffled=[shuffled,zeros(npts,adj_dim-ref_dim)]; %augment if needed to match the output from psg_geo_generalcl
                                    end
                                    %d_shuff_orig is calculated with surrogate denominator; we also want to calculate it with original denominator
                                    %also, turn off fmin display for shuffles
                                    [d_shuff_orig,ref_model_shuff,transform_shuffle,opts_model_shuff_used_nestdim_out{imodel,ishuff,iref_ptr_nest}]=... %was iadj_ptr_nest, fixed 27Mar26
                                        psg_geo_general(shuffled,adj,model_class,setfield(opts_model,'if_display',0)); %the ref dataset with permuted coords is now fit with a transform from adj
                                    resids_shuff=shuffled-ref_model_shuff; %deviation of model from shuffle surrogate
                                    d_shuff_nestdim_out(imodel,ishuff,iref_ptr_nest,1)=d_shuff_orig;
                                    d_shuff_nestdim_out(imodel,ishuff,iref_ptr_nest,2)=sum(resids_shuff(:).^2)/d_den;
                                    if opts_geofit.if_keep_transforms_nestbydim_in
                                        transforms_nestbydim_out{imodel,ishuff,iref_ptr_nest}=transform_shuffle;
                                    end                                       
                                end
                                %
                                for id_calc_type=1:n_ntypes
                                    surrogate_count_nestdim_out(imodel,iref_ptr_nest,id_calc_type)=sum(double(d(imodel)>=d_shuff_nestdim_out(imodel,:,iref_ptr_nest,id_calc_type)));
                                    if opts_geofit.if_log
                                        disp(sprintf('d is >= d_shuff for %5.0f of %5.0f shuffles (%s), d_shuffles: range [%8.5f %8.5f], mean %8.5f s.d. %8.5f',...
                                            surrogate_count_nestdim_out(imodel,iref_ptr_nest,id_calc_type),nshuff,d_calc_types{id_calc_type},...
                                            min(d_shuff_nestdim_out(imodel,:,iref_ptr_nest,id_calc_type)),max(d_shuff_nestdim_out(imodel,:,iref_ptr_nest,id_calc_type)),...
                                            mean(d_shuff_nestdim_out(imodel,:,iref_ptr_nest,id_calc_type)),std(d_shuff_nestdim_out(imodel,:,iref_ptr_nest,id_calc_type))));
                                    end
                                end
                            end %iref_ptr_nest
                        end %if_nestbydim_out
                        %
                     end %if shuffled
                end %model input dimension test
            end %imodel
            %final summary
            if opts_geofit.if_summary
                disp(' ');
                disp('summary')
                disp(sprintf('reference dataset dimension: %2.0f',ref_dim));
                disp(sprintf('adjusted  dataset dimension: %2.0f',adj_dim));
                for imodel=1:nmodels
                    model_type=model_types{imodel};
                    model_class=model_types_def.(model_type).class;
                    if nshuff>0
                        disp(' ');
                    end
                    disp(sprintf('primary geometric model  %30s  (class: %20s)      d: %8.5f',model_type,model_class,d(imodel)));
                    if ~isempty(opts_model_used{imodel}) %in case model did not pass dimension test
                        if (nshuff>0)
                            nested_types=model_types_def.(model_type).nested;
                            for inest=1:length(nested_types)
                                nested_type=nested_types{inest};
                                nest_ptr=strmatch(nested_type,model_types,'exact');
                                for id_calc_type=1:n_ntypes
                                    disp(sprintf('nested %40s: d is >= d_shuff for %5.0f of %5.0f shuffles (%s), d_shuffles: range [%8.5f %8.5f], mean %8.5f s.d. %8.5f',...
                                        nested_type,surrogate_count(imodel,nest_ptr,id_calc_type),nshuff,d_calc_types{id_calc_type},...
                                        min(d_shuff(imodel,:,inest,id_calc_type)),max(d_shuff(imodel,:,inest,id_calc_type)),...
                                        mean(d_shuff(imodel,:,inest,id_calc_type)),std(d_shuff(imodel,:,inest,id_calc_type))));
                                end
                            end %inest
                            if if_nestbydim_in~=0 %changed from =1 on 23Feb26
                                for iadj_ptr_nest=1:iadj_ptr-1
                                    adj_dim_nest=adj_dim_each{ref_dim}(iadj_ptr_nest);
                                    if adj_dim_nest>=model_types_def.(model_type).min_inputdims
                                        for id_calc_type=1:n_ntypes
                                            disp(sprintf('%27s: d is >= d_shuff for %5.0f of %5.0f shuffles (%s), d_shuffles: range [%8.5f %8.5f], mean %8.5f s.d. %8.5f',...
                                                sprintf('nested %30s adjdim %2.0f',model_type,adj_dim_nest),surrogate_count_nestdim_in(imodel,iadj_ptr_nest,id_calc_type),nshuff,d_calc_types{id_calc_type},...
                                                min(d_shuff_nestdim_in(imodel,:,iadj_ptr_nest,id_calc_type)),max(d_shuff_nestdim_in(imodel,:,iadj_ptr_nest,id_calc_type)),...
                                                mean(d_shuff_nestdim_in(imodel,:,iadj_ptr_nest,id_calc_type)),std(d_shuff_nestdim_in(imodel,:,iadj_ptr_nest,id_calc_type))));
                                        end %id_calc_type
                                     end %dims OK
                                end
                            end %if_nestbydim_in
                            if if_nestbydim_out~=0
                                for iref_ptr_nest=1:length(nestdim_out_list)
                                    ref_dim_nest=nestdim_out_list(iref_ptr_nest);
                                    for id_calc_type=1:n_ntypes
                                        disp(sprintf('%27s: d is >= d_shuff for %5.0f of %5.0f shuffles (%s), d_shuffles: range [%8.5f %8.5f], mean %8.5f s.d. %8.5f',...
                                            sprintf('nested %30s refdim %2.0f',model_type,ref_dim_nest),surrogate_count_nestdim_out(imodel,iref_ptr_nest,id_calc_type),nshuff,d_calc_types{id_calc_type},...
                                            min(d_shuff_nestdim_out(imodel,:,iref_ptr_nest,id_calc_type)),max(d_shuff_nestdim_out(imodel,:,iref_ptr_nest,id_calc_type)),...
                                            mean(d_shuff_nestdim_out(imodel,:,iref_ptr_nest,id_calc_type)),std(d_shuff_nestdim_out(imodel,:,iref_ptr_nest,id_calc_type))));
                                    end %id_calc_type
                                end
                            end %if_nestbydim_out
                        end
                        if strcmp(model_class,'pwaffine') & (if_pwaffine_details==1)
                            disp(sprintf('standard minimization for %s:',model_type))
                            disp(opts_model_used{imodel}.fmin);
                            disp(opts_model_used{imodel}.fmin.output);
                            disp(transforms{imodel});
                            %
                            disp(sprintf('minimization for %s with if_orth=0:',model_type))
                            disp(opts_model_nonorth_used{imodel}.fmin);
                            disp(opts_model_nonorth_used{imodel}.fmin.output);
                            disp(transforms_nonorth{imodel});
                        end
                    end
                end
            end
            r.d=d;
            r.transforms=transforms;
            %
            if opts_geofit.if_keep_transforms_nestbymodel
                r.transforms_nestbymodel=transforms_nestbymodel;
            end
            if opts_geofit.if_keep_transforms_nestbydim_in
                r.transforms_nestbydim_in=transforms_nestbydim_in;
            end
            if opts_geofit.if_keep_transforms_nestbydim_out
                r.transforms_nestbydim_out=transforms_nestbydim_out;
            end
            %
            if opts_geofit.if_keep_opts_model_used
                r.opts_model_used=opts_model_used;
            end
            r.d_shuff=d_shuff;
            r.surrogate_count=surrogate_count;
            %
            if (if_nestbydim_in)
                r.nestdim_in_list=nestdim_in_list;
                if opts_geofit.if_keep_opts_model_used
                    r.opts_model_shuff_used_nestdim_in=opts_model_shuff_used_nestdim_in;
                end
                r.d_shuff_nestdim_in=d_shuff_nestdim_in;
                r.surrogate_count_nestdim_in=surrogate_count_nestdim_in;
            end
            %
            if (if_nestbydim_out)
                r.nestdim_out_list=nestdim_out_list;
                if opts_geofit.if_keep_opts_model_used
                     r.opts_model_shuff_used_nestdim_out=opts_model_shuff_used_nestdim_out;
                end
                r.d_shuff_nestdim_out=d_shuff_nestdim_out;
                r.surrogate_count_nestdim_out=surrogate_count_nestdim_out;
            end
            %
            results{ref_dim,adj_dim}=r;
        end %dimensions ok
    end %adj_dim_ptr
end %ref_dim_ptr
return
end
