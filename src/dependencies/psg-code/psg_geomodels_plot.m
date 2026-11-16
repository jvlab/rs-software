function opts_used=psg_geomodels_plot(results,opts)
% opts_used=psg_geomodels_plot(results,opts) creates summaryy plots of goodness
% of fit of geometric models, including comparison of models with nested models, and comparison of models nested by dimension
%
% results: output of psg_geomodels_fit or psg_geomodels_run containing goodness of fit of one or more geometric models
%     results{ref,adj} contains the analysis for transforming an input set with adj dimensions to an output set with ref dimensions
% 
% opts: options
%   if_nestbymodel_show: 1 (default) to show all nested models, -1 to show only maximally nested models, 0 to show none
%   if_nestbydim_show: 1 (default) to show nesting by dimension
%     This sets the defaults for if_nestbydim_in_show and if_nestbydim_out_show, but these can also be separately supplied
%   models_show_select: string, or cell array of strings, that select which models are shown
%      For a model to be shown, at least one of the strings in models_show_select{:} must be present in the model type
%      e.g., {'_offset','affine'} will select any model whose name contains _offset or affine
%      If empty or unspecified, no selection.  Caution: {} is empty, [] is empty, '' is empty, but {''} and {[]} are not.
%      Even if a subset of models are selectd, all models are shown in the 'all_models' plot, along with selected models in 'select_models' plot
%   if_diag: 0 to plot as function of {d_ref,d_adj}}, 1 to only plot diagonal values (results{k,k}),
%      if not provided, will be determined by whether there are any off-diagonal values in results
%   sig_level: significance level
%   if_showsig: which significance flags to show for d (goodness of fit): 0: none, 1: based on original denom, 2 based on shuffle denom, 3: both (default)
%   if_nestbydim_showd: 1 (default) to show d-values for nested-by-dimension models
%     This sets the defaults for if_nestbydim_in_showd and if_nestbydim_out_showd, but these can also be separately supplied
%   if_showquant: 1 to show quantile at significance level sig_level (defaults to 0)
%   ref_label: label for first  coordinate of results{}, defaults to 'ref dim'
%   adj_label: label for second coordinate of results{}, defaults to 'adj dim'
%   dia_label: label for results{}, when diagonal is plotted, defaults to 'ref and adj dim'
%   colors_models: colors to use for model, used in cyclic order, default- {'k','b','c','m','r',[1 0.5 0],[0.7 0.7 0],'g',[.5 .5 .5],[.5 0 0]}
%   sig_symbols: symbols to mark significant values, sig_symbols{1} for original denom, sig_symbols{2} for shuffle denom, default-{'+','x'}
%   sig_symsize: symbol size for significant values, default=14
%   lw_model: line width for model, default=2
%   lw_nest: line width for nested model, default=2
%   lw_quant: line width for quantile, default=1
%
% opts_used: options used
%    also:
%    opts_used.fig_handles is a cell array of handles to the figures created
%    opts_used.fig_names is a cell array of names of the figures created; no special chars, suitable for use in a file name
%    opts_used.models_shown: names of models shown
%
% This is a modularized version of psg_geomodels_summ, with the following main differences:
%   results must be passed, not read from a file
%   results cannot be a cell array of subsidiary results structures ('mode 2' of psg_geomodels_summ)
%   results may be present on any subset of the (ref,adj) pairs
%   can select which models to plot according to model name
%   can plot along a diagonal of (ref==adj)
%
% 23Feb26: add if_nestbydim_in, if_nestbydim_out
%
%   See also: RS_SAVE_FIGS, PSG_GEOMODELS_SUMM, PSG_GEOMODELS_FIT, PSG_GEOMODELS_RUN, PSG_GEOMODELS_DEFINE, SURF_AUGVEC,
%     PSG_GEOMODELS_NESTUTIL, HLID_MDS_COORDS_GEOMODELS.
%
if nargin<=1
    opts=struct();
end
%plot format options
opts=filldefault(opts,'sig_symbols',{'+','x'});
opts=filldefault(opts,'sig_symsize',14);
opts=filldefault(opts,'quant_lines',{'--','-.'});
opts=filldefault(opts,'colors_mn',{'k','b'});
opts=filldefault(opts,'colors_models',{'k','b','c','m','r',[1 0.5 0],[0.7 0.7 0],'g',[.5 .5 .5],[.5 0 0]});
opts=filldefault(opts,'lw_model',2); %line width for a model
opts=filldefault(opts,'lw_nest',2); %line width for a nested model
opts=filldefault(opts,'lw_quant',1); %line width for quantiles
opts=filldefault(opts,'if_omnicolors',1); %1 to use colors from omnibus plots in comparison plots
opts=filldefault(opts,'adj_label','adj dim');
opts=filldefault(opts,'ref_label','ref dim');
opts=filldefault(opts,'dia_label','ref and adj dim');
%
opts=filldefault(opts,'if_nestbymodel_show',1); %1 for all comparisons, -1 for maximal, 0 for none
opts=filldefault(opts,'if_nestbydim_show',1); %1 to show
opts=filldefault(opts,'if_nestbydim_in_show',opts.if_nestbydim_show);
opts=filldefault(opts,'if_nestbydim_out_show',opts.if_nestbydim_show);
opts=filldefault(opts,'models_show_select',[]); %strings to select models to show
opts=filldefault(opts,'if_diag',[]);
opts=filldefault(opts,'sig_level',0.05);
opts=filldefault(opts,'if_nestbydim_showd',1); %1 (default) to show d-values for nested-by-dim models
opts=filldefault(opts,'if_nestbydim_in_showd',opts.if_nestbydim_showd);
opts=filldefault(opts,'if_nestbydim_out_showd',opts.if_nestbydim_showd);
opts=filldefault(opts,'if_showsig',3); % which significance flags to show(0: none, 1: orig, 2: shuff, 3: both','d',[0 3],3);
opts=filldefault(opts,'if_showquant',0); %1 to show quantile at requested significance level (sig_level)
%
opts=filldefault(opts,'view',3);
%
opts=filldefault(opts,'if_log',0);
%
norm_labels={'orig','shuff'}; %denominator used for normalization of d in significance calculations
%
showsigs(1)=mod(opts.if_showsig,2);
showsigs(2)=double(opts.if_showsig>=2);
%
fig_counter=0;
opts.fig_handles=cell(0);
opts.fig_names=cell(0);
%
%for backwards compatibility for results structures that only contained nest-by-dim on input
%
results=psg_geomodels_nestutil(results);
%
ref_have=[];
adj_have=[];
have_data=zeros(size(results));
for ref_dim=1:size(results,1)
    for adj_dim=1:size(results,2)
        have_data(ref_dim,adj_dim)=isfield(results{ref_dim,adj_dim},'model_types_def');
        if have_data(ref_dim,adj_dim)
            ref_have=ref_dim;
            adj_have=adj_dim;
        end
    end
end
if isempty(ref_have) | isempty(adj_have)
    disp('no modeling data found');
end
if isempty(opts.if_diag)
    if sum(have_data(:))==sum(diag(have_data))
        opts.if_diag=1;
    else
        opts.if_diag=0;
    end
end
ref_dim_list=find(any(have_data,2)'>0);
adj_dim_list=find(any(have_data,1)>0);
if opts.if_log
    disp('reference set dimension list:')
    disp(ref_dim_list);
    disp('adjusted  set dimension list')
    disp(adj_dim_list);
end
%
r=results{ref_have,adj_have};%in case not all values of results are filled in for all pairs of ref_dim_list, adj_dim_list
if isfield(r,'d_shuff')
    nshuff=size(r.d_shuff,2);
else
    nshuff=0;
end
%
model_types_def=r.model_types_def;
n_calc_types=size(r.surrogate_count,3); %typically 2       
if_nestbydim_in=double(isfield(r,'nestdim_in_list'));
if_nestbydim_out=double(isfield(r,'nestdim_out_list'));
clear r
%
model_types=model_types_def.model_types;
if isempty(opts.models_show_select)
    model_numbers_toshow=[1:length(model_types)];
else
    if ~iscell(opts.models_show_select)
        models_show_select=cell(1);
        models_show_select{1}=opts.models_show_select;
        opts.models_show_select=models_show_select;
    end
    model_numbers_toshow=[];
    for k=1:length(opts.models_show_select)
        for m=1:length(model_types)
            if ~isempty(strfind(model_types{m},opts.models_show_select{k}))
                model_numbers_toshow=union(model_numbers_toshow,m);
            end
        end
    end
end
opts.models_shown=model_types(model_numbers_toshow);
%
if opts.if_log
    disp('model types available');
    disp(model_types');
    disp('model types to be shown');
    disp(opts.models_shown');
    disp(sprintf('nest by dimension analysis present for  input: %1.0f',if_nestbydim_in));
    disp(sprintf('nest by dimension analysis present for output: %1.0f',if_nestbydim_out));
end
if isempty(model_numbers_toshow)
    if (opts.if_log)
        disp('no models selected')
    end
    opts_used=opts;
    return
end
compares=zeros(0,2); %list of nested comparisons (each row is a pointer into model_types for model, and nested model)
%build up complete list of comparisons
for imodel=1:length(model_types)
    model_type=model_types{imodel};
    nested_list=model_types_def.(model_type).nested;
    for inest_ptr=1:length(nested_list)
        nested_type=nested_list{inest_ptr};
        inest=strmatch(nested_type,model_types,'exact');
        compares=[compares;[imodel inest]];
        if opts.if_log
            disp(sprintf('model %30s contains %30s as a nested model',model_type,model_types{inest})); %do this to verify proper match
        end
    end %inest_ptr
    if length(nested_list)==0
        if opts.if_log
            disp(sprintf('model %30s has no nested models',model_type));
        end
    end
end %imodel
compares=sortrows(compares,[1 2],{'ascend' 'descend'}); %sort nested models downward
%find maximal nestings, indicate with a flag in third column
compares=[compares,zeros(size(compares,1),1)];
if opts.if_log
    disp('determining which model nestings are maximal')
end
for icompare=1:size(compares,1)
    imodel=compares(icompare,1);
    inest=compares(icompare,2);
    model_type=model_types{imodel};
    nested_type=model_types{inest};
    desc=compares(find(compares(:,1)==imodel),2); %models contained in imodel
    asc=compares(find(compares(:,2)==inest),1); %models that contain inest
    maxnest=double(isempty(intersect(asc,desc)));
    compares(icompare,3)=maxnest;
    if (opts.if_log)
        disp(sprintf('model %30s contains %30s, maximal nesting: %1.0f',model_type,nested_type,maxnest))
    end
end %icompare
%
%collect values of d across all models
%
d_models=nan(length(ref_dim_list),length(adj_dim_list),length(model_types)); %d1: ref_dim_ptr, d2: adj_dim_ptr, dim3: model
d_models_nestdim_in=       nan(length(ref_dim_list),length(adj_dim_list),length(model_types),nshuff,max(adj_dim_list)-1,n_calc_types); %d1: ref_dim_ptr, d2: adj_dim_ptr, dim3: model, d4: shuf, d5: nestdim, d6: n_calc_types
surrogate_count_nestdim_in=zeros(length(ref_dim_list),length(adj_dim_list),length(model_types)       ,max(adj_dim_list)-1,n_calc_types); %d1: ref_dim_ptr, d2: adj_dim_ptr, dim3: model,           d4: nestdim, d5: n_calc_types
%
d_models_nestdim_out=       nan(length(ref_dim_list),length(adj_dim_list),length(model_types),nshuff,max(ref_dim_list),n_calc_types); %d1: ref_dim_ptr, d2: adj_dim_ptr, dim3: model, d4: shuf, d5: nestdim, d6: n_calc_types
surrogate_count_nestdim_out=zeros(length(ref_dim_list),length(adj_dim_list),length(model_types)       ,max(ref_dim_list),n_calc_types); %d1: ref_dim_ptr, d2: adj_dim_ptr, dim3: model,           d4: nestdim, d5: n_calc_types
%
for imodel=1:length(model_types)
    model_type=model_types{imodel};
    %
    %collect values of d across all dimensions and models
    %
    for ref_dim_ptr=1:length(ref_dim_list)
        ref_dim=ref_dim_list(ref_dim_ptr);
        for adj_dim_ptr=1:length(adj_dim_list)
            adj_dim=adj_dim_list(adj_dim_ptr);
            rz=results{ref_dim,adj_dim};
            if have_data(ref_dim,adj_dim)
                if adj_dim>=model_types_def.(model_type).min_inputdims
                    d_models(ref_dim_ptr,adj_dim_ptr,imodel)=rz.d(imodel);
                end
                %
                if if_nestbydim_in
                    if size(rz.nestdim_in_list,2)>0
                        d_models_nestdim_in(ref_dim_ptr,adj_dim_ptr,:,:,rz.nestdim_in_list,:)=...
                            reshape(rz.d_shuff_nestdim_in,[1 1 length(model_types) nshuff length(rz.nestdim_in_list) n_calc_types]);
                        surrogate_count_nestdim_in(ref_dim_ptr,adj_dim_ptr,:,rz.nestdim_in_list,:)=...
                            reshape(rz.surrogate_count_nestdim_in,[1 1 length(model_types) length(rz.nestdim_in_list) n_calc_types]);
                    end
                end %if_nestbydim_in
                %
                if if_nestbydim_out
                    if size(rz.nestdim_out_list,2)>0
                        ndout=length(rz.nestdim_out_list); %number of nested values
                        d_models_nestdim_out(ref_dim_ptr,adj_dim_ptr,:,:,1+rz.nestdim_out_list,:)=... %note 1+rs.nestdim_out_list, since nestdim_out_list begins with 0
                           reshape(rz.d_shuff_nestdim_out(:,:,1:ndout,:),[1 1 length(model_types) nshuff ndout n_calc_types]);
                        surrogate_count_nestdim_out(ref_dim_ptr,adj_dim_ptr,:,1+rz.nestdim_out_list,:)=...
                             reshape(rz.surrogate_count_nestdim_out(:,1:ndout,:),[1 1 length(model_types) ndout n_calc_types]);
                    end
                end %if_nestbydim_out
            end
        end %adj_dim_ptr
    end %ref_dim_ptr
end
%
%make omnibus plot
%
if length(model_numbers_toshow)==length(model_types)
    if_select=0;
else
    if_select=1;
end
for iselect=0:if_select
    figure;
    if iselect==0
        figname_tstring='all-models';
        model_list=[1:length(model_types)];
        legend_list=model_types;
    else
        figname_tstring='select-models';
        model_list=model_numbers_toshow;
        legend_list=opts.models_shown;
    end
    set(gcf,'Position',[100 100 1200 800]);
    set(gcf,'NumberTitle','off');
    set(gcf,'Name',figname_tstring);
    hold on;
    for imodel_ptr=1:length(model_list)
        imodel=model_list(imodel_ptr);
        h_model=surf_augvec_do(adj_dim_list,ref_dim_list,d_models(:,:,imodel),have_data,opts);
        set(h_model,'FaceColor','none');
        set(h_model,'EdgeColor',opts.colors_models{1+mod(imodel-1,length(opts.colors_models))});
        set(h_model,'LineWidth',opts.lw_model);
    end
    hl=legend(strvcat(legend_list));
    set(hl,'Interpreter','none');
    %
    fig_counter=fig_counter+1;
    opts.fig_handles{1,fig_counter}=gcf;
    opts.fig_names{1,fig_counter}=figname_tstring;
end
%
%plot nested model comparisons
%
if opts.if_log
    disp(' ');
end
for icompare=1:size(compares,1)
    imodel=compares(icompare,1);
    if ismember(imodel,model_numbers_toshow)
        inest=compares(icompare,2);
        %d_shuff dim 3 is indexed by serial order of nested model
        allnested=unique(compares(find(compares(:,1)==imodel),2));
        inest_dshuff_index=find(allnested==inest); %26Jan26: where to find nested-model data in d_shuff dim 3
        % inest
        % inest_dshuff_index
        %
        model_type=model_types{imodel};
        nested_type=model_types{inest};
        if opts.if_showsig>0
            text_string=sprintf('nshuff %5.0f p=%5.3f  normalization:',nshuff,opts.sig_level);
        else
            text_string=sprintf('nshuff %5.0f',nshuff);
        end
        if ((compares(icompare,3)==1 & opts.if_nestbymodel_show~=0) | opts.if_nestbymodel_show==1)
            if opts.if_log
                disp(sprintf('model %30s contains %30s: displaying',model_type,nested_type))
            end
            %
            d_model=d_models(:,:,imodel);
            d_nest=d_models(:,:,inest);
            if_sig=zeros(length(ref_dim_list),length(adj_dim_list),n_calc_types); %d3 is normalization type
            d_shuffs=zeros(length(ref_dim_list),length(adj_dim_list),nshuff,n_calc_types);
            %
            %collect values of d across all dimensions
            nest_ptr=strmatch(nested_type,model_types_def.model_types,'exact'); %added 26Jan26, pointer to surrogates are based on search order
            for ref_dim_ptr=1:length(ref_dim_list)
                ref_dim=ref_dim_list(ref_dim_ptr);
                for adj_dim_ptr=1:length(adj_dim_list)
                    adj_dim=adj_dim_list(adj_dim_ptr);
                    rz=results{ref_dim,adj_dim};
                    if have_data(ref_dim,adj_dim)
                        for calc_type=1:n_calc_types
                            if adj_dim>=model_types_def.(model_type).min_inputdims
                                if_sig(ref_dim_ptr,adj_dim_ptr,calc_type)=double(rz.surrogate_count(imodel,nest_ptr,calc_type)<opts.sig_level*nshuff); %inest->nest_ptr, 26Jan26
                            end
                            d_shuffs(ref_dim_ptr,adj_dim_ptr,:,calc_type)=reshape(rz.d_shuff(imodel,:,inest_dshuff_index,calc_type),[1 1 nshuff]); %inest->inest_dshuff_index, 26Jan26
                        end
                    end
                end
            end
            figure;
            figname_tstring=cat(2,'model-',model_type,'-nested-',nested_type);
            figname_tstring=strrep(figname_tstring,' ','-');
            figname_tstring=strrep(figname_tstring,'_','-');
            figname_tstring=strrep(figname_tstring,'procrustes','proc');
            figname_tstring=strrep(figname_tstring,'affine','aff');
            figname_tstring=strrep(figname_tstring,'projective','proj');
            %
            set(gcf,'Position',[100 100 1200 800]);
            set(gcf,'NumberTitle','off');
            set(gcf,'Name',figname_tstring);
            hold on;
            h_model=surf_augvec_do(adj_dim_list,ref_dim_list,d_model,have_data,opts);
            set(h_model,'FaceColor','none');
            set(h_model,'LineWidth',opts.lw_model);
            h_nest=surf_augvec_do(adj_dim_list,ref_dim_list,d_nest,have_data,opts);
            set(h_nest,'FaceColor','none');
            set(h_nest,'LineWidth',opts.lw_nest);
            %
            if (opts.if_omnicolors) %use colors from ombnibus ;plots?
                set(h_model,'EdgeColor',opts.colors_models{1+mod(imodel-1,length(opts.colors_models))});
                set(h_nest,'EdgeColor',opts.colors_models{1+mod(inest-1,length(opts.colors_models))});
            else
                set(h_model,'EdgeColor',opts.colors_mn{1});
                set(h_nest,'EdgeColor',opts.colors_mn{2});
            end
            %
            legend_labels=strvcat(model_type,nested_type);
            %plot quantile at significance level
            if opts.if_showquant
                qstring=sprintf('p=%6.3f, den: ',opts.sig_level);
                for calc_type=1:n_calc_types
                    if showsigs(calc_type)
                        h_quant=surf_augvec_do(adj_dim_list,ref_dim_list,quantile(d_shuffs(:,:,:,calc_type),opts.sig_level,3),have_data,opts);
                        set(h_quant,'FaceColor','none');
                        set(h_quant,'EdgeColor',get(h_model,'EdgeColor'));
                        set(h_quant,'LineStyle',opts.quant_lines{calc_type});
                        set(h_quant,'LineWidth',opts.lw_quant);
                        legend_labels=strvcat(legend_labels,cat(2,qstring,norm_labels{calc_type}));
                    end
                end
            end
            %plot significance flags
            for calc_type=1:n_calc_types
                if showsigs(calc_type)
                    for ref_dim_ptr=1:length(ref_dim_list)
                        for adj_dim_ptr=1:length(adj_dim_list)
                            if if_sig(ref_dim_ptr,adj_dim_ptr,calc_type)
                                hsig=[];
                                if opts.if_diag
                                     if adj_dim_list(adj_dim_ptr)==ref_dim_list(ref_dim_ptr)
                                        hsig=plot3(adj_dim_list(adj_dim_ptr),0,d_model(ref_dim_ptr,adj_dim_ptr),opts.sig_symbols{calc_type});
                                     end
                                else
                                    hsig=plot3(adj_dim_list(adj_dim_ptr),ref_dim_list(ref_dim_ptr),d_model(ref_dim_ptr,adj_dim_ptr),opts.sig_symbols{calc_type});
                                end
                                if ~isempty(hsig)
                                    set(hsig,'MarkerSize',opts.sig_symsize);
                                    set(hsig,'Color',get(h_model,'EdgeColor')); %color of model
                                end
                            end
                        end %adj_dim_ptr
                    end %ref_dim_ptr
                    text_string=cat(2,text_string,sprintf('%s denom (%s) ',norm_labels{calc_type},opts.sig_symbols{calc_type}));
                end
            end
            hl=legend(legend_labels);
            set(hl,'Interpreter','none');
            %
            axes('Position',[0.01,0.05,0.01,0.01]); %for text
            text(0,0,text_string,'Interpreter','none');
            axis off;
            %
            figname=figname_tstring;
            fig_counter=fig_counter+1;
            opts.fig_handles{1,fig_counter}=gcf;
            opts.fig_names{1,fig_counter}=figname;
        end
    end %model_numbers_toshow
end %icompare
%
% plot nested comparisons by dimension
%
for inout=1:2
    switch inout
        case 1
            inout_string='in';
            if_show=and(if_nestbydim_in,opts.if_nestbydim_in_show);
            if_showd=opts.if_nestbydim_in_showd;
        case 2
            inout_string='out';
            if_show=and(if_nestbydim_out,opts.if_nestbydim_out_show);
            if_showd=opts.if_nestbydim_out_showd;
    end
    if if_show
        if opts.if_log
            disp(' ');
        end
        for imodel=1:length(model_types)
            if ismember(imodel,model_numbers_toshow)
                model_type=model_types{imodel};
                if opts.if_showsig>0
                    text_string=sprintf('nshuff %5.0f p=%5.3f  normalization:',nshuff,opts.sig_level);
                else
                    text_string=sprintf('nshuff %5.0f',nshuff);
                end
                if opts.if_log
                    disp(sprintf('comparing model %30s and same model with lower dimension (%sput)',model_type,inout_string))
                end
                d_model=d_models(:,:,imodel);
                if_sig=zeros(length(ref_dim_list),length(adj_dim_list),n_calc_types); %d3 is normalization type
                 %
                 %collect values of d across all dimensions
                 d_nestdim=NaN(length(ref_dim_list),length(adj_dim_list));
                 d_shuffs_nestdim=NaN(length(ref_dim_list),length(adj_dim_list),nshuff,n_calc_types);
                 for ref_dim_ptr=1:length(ref_dim_list)
                     ref_dim=ref_dim_list(ref_dim_ptr);
                     for adj_dim_ptr=1:length(adj_dim_list)
                        adj_dim=adj_dim_list(adj_dim_ptr);
                        if have_data(ref_dim,adj_dim)
                            rz=results{ref_dim,adj_dim};
                            switch inout
                                case 1 %input nesting
                                if (adj_dim_ptr>1) 
                                    for calc_type=1:n_calc_types
                                         if adj_dim_list(adj_dim_ptr-1)>=model_types_def.(model_type).min_inputdims
                                            if_sig(ref_dim_ptr,adj_dim_ptr,calc_type)=double(surrogate_count_nestdim_in(ref_dim_ptr,adj_dim_ptr,imodel,adj_dim_list(adj_dim_ptr-1),calc_type)<opts.sig_level*nshuff);
                                         end
                                    end %calc_type
                                    d_shuffs_nestdim(ref_dim_ptr,adj_dim_ptr,:,:)=reshape(d_models_nestdim_in(ref_dim_ptr,adj_dim_ptr,imodel,:,adj_dim_list(adj_dim_ptr-1),:),[1 1 nshuff n_calc_types]);
                                    d_nestdim(ref_dim_ptr,adj_dim_ptr)=d_model(ref_dim_ptr,adj_dim_ptr-1);
                                end %adj_dim_ptr>1
                                case 2 % output nesting
                                    for calc_type=1:n_calc_types
                                        if_sig(ref_dim_ptr,adj_dim_ptr,calc_type)=double(surrogate_count_nestdim_out(ref_dim_ptr,adj_dim_ptr,imodel,1+rz.nestdim_out_list(end),calc_type)<opts.sig_level*nshuff);
                                    end %calc_type
                                    d_shuffs_nestdim(ref_dim_ptr,adj_dim_ptr,:,:)=reshape(d_models_nestdim_out(ref_dim_ptr,adj_dim_ptr,imodel,:,1+rz.nestdim_out_list(end),:),[1 1 nshuff n_calc_types]);
                                    if ref_dim_ptr>1
                                        d_nestdim(ref_dim_ptr,adj_dim_ptr)=d_model(ref_dim_ptr-1,adj_dim_ptr);
                                    else
                                        d_nestdim(ref_dim_ptr,adj_dim_ptr)=1; %null model
                                    end
                            end %inout
                        end %havedata
                     end %adj_dim_ptr
                 end %ref_dim_ptr
                figure;
                figname_tstring=cat(2,'model-',model_type,'-nested-by-dim-',inout_string);
                figname_tstring=strrep(figname_tstring,' ','-');
                figname_tstring=strrep(figname_tstring,'_','-');
                figname_tstring=strrep(figname_tstring,'procrustes','proc');
                figname_tstring=strrep(figname_tstring,'affine','aff');
                figname_tstring=strrep(figname_tstring,'projective','proj');
                set(gcf,'Position',[100 100 1200 800]);
                set(gcf,'NumberTitle','off');
                set(gcf,'Name',figname_tstring);
                hold on;
                h_model=surf_augvec_do(adj_dim_list,ref_dim_list,d_model,have_data,opts);
                set(h_model,'FaceColor','none');
                set(h_model,'LineWidth',opts.lw_model);
                legend_labels=model_type;
                if if_showd
                    h_nestdim=surf_augvec_do(adj_dim_list,ref_dim_list,d_nestdim,have_data,opts);
                    set(h_nestdim,'FaceColor','none');
                    set(h_nestdim,'LineWidth',opts.lw_nest);
                    set(h_nestdim,'LineStyle',':');
                    legend_labels=strvcat(legend_labels,'lower dim');
                end
                %
                if (opts.if_omnicolors) %use colors from ombnibus plots?
                    set(h_model,'EdgeColor',opts.colors_models{1+mod(imodel-1,length(opts.colors_models))});
                    if if_showd
                        set(h_nestdim,'EdgeColor',opts.colors_models{1+mod(imodel-1,length(opts.colors_models))});
                    end
                else
                    set(h_model,'EdgeColor',opts.colors_mn{1});
                    if if_showd
                        set(h_nestdim,'EdgeColor',opts.colors_mn{1});
                    end
                end
                %plot quantile at significance level
                if opts.if_showquant
                    qstring=sprintf('p=%6.3f, den: ',opts.sig_level);
                    for calc_type=1:n_calc_types
                        if showsigs(calc_type)
                            h_quant=surf_augvec_do(adj_dim_list,ref_dim_list,quantile(d_shuffs_nestdim(:,:,:,calc_type),opts.sig_level,3),have_data,opts);
                            set(h_quant,'FaceColor','none');
                            set(h_quant,'EdgeColor',get(h_model,'EdgeColor'));
                            set(h_quant,'LineStyle',opts.quant_lines{calc_type});
                            set(h_quant,'LineWidth',opts.lw_quant);
                            legend_labels=strvcat(legend_labels,cat(2,qstring,norm_labels{calc_type}));
                        end
                    end
                end
                 %plot significance flags
                 for calc_type=1:n_calc_types
                     if showsigs(calc_type)
                         for ref_dim_ptr=1:length(ref_dim_list)
                             for adj_dim_ptr=1:length(adj_dim_list)
                                 if if_sig(ref_dim_ptr,adj_dim_ptr,calc_type)
                                     hsig=[];
                                     if opts.if_diag
                                         if adj_dim_list(adj_dim_ptr)==ref_dim_list(ref_dim_ptr)
                                            hsig=plot3(adj_dim_list(adj_dim_ptr),0,d_model(ref_dim_ptr,adj_dim_ptr),opts.sig_symbols{calc_type});
                                         end
                                     else
                                         hsig=plot3(adj_dim_list(adj_dim_ptr),ref_dim_list(ref_dim_ptr),d_model(ref_dim_ptr,adj_dim_ptr),opts.sig_symbols{calc_type});
                                     end
                                     if ~isempty(hsig)
                                         set(hsig,'Color',get(h_model,'EdgeColor')); %color of model
                                        set(hsig,'MarkerSize',opts.sig_symsize);
                                     end
                                 end
                             end %adj_dim_ptr
                         end %ref_dim_ptr
                         text_string=cat(2,text_string,sprintf('%s denom (%s) ',norm_labels{calc_type},opts.sig_symbols{calc_type}));
                     end
                 end
                 hl=legend(legend_labels);
                set(hl,'Interpreter','none');
                %
                axes('Position',[0.01,0.05,0.01,0.01]); %for text
                text(0,0,text_string,'Interpreter','none');
                axis off;
                %
                fig_counter=fig_counter+1;
                opts.fig_handles{1,fig_counter}=gcf;
                opts.fig_names{1,fig_counter}=figname_tstring;
            end
        end %dim to show
    end %if_show
end %inout
opts_used=opts;
return
end

function h=surf_augvec_do(adj_dim_list,ref_dim_list,d,have_data,opts)
opts=filldefault(opts,'view',3);
%do a standard surface plot or a wireframe plot with a one-dimensional domain
if opts.if_diag
    dia_dim_list=find(diag(have_data)==1);
    if length(dia_dim_list)==1
        xlim_dia=dia_dim_list+[-0.5 0.5];
    else
        xlim_dia=dia_dim_list([1 end]);
    end
    ylim=[-0.5 0.5];
    dvals=NaN(1,length(dia_dim_list));
    for k=1:length(dia_dim_list)
        dvals(k)=d(find(dia_dim_list(k)==ref_dim_list),find(dia_dim_list(k)==adj_dim_list));
    end
    h=surf_augvec(dia_dim_list,0,dvals);
    xlabel(opts.dia_label);
    ylabel(' ');
    set(gca,'XLim',xlim_dia);
    set(gca,'YLim',ylim);
    set(gca,'XTick',dia_dim_list);
    set(gca,'YTick',ylim);
else
    if length(adj_dim_list)==1
        xlim_adj=adj_dim_list+[-0.5 0.5];
    else
        xlim_adj=adj_dim_list([1 end]);
    end
    if length(ref_dim_list)==1
        ylim_ref=ref_dim_list+[-0.5 0.5];
    else
        ylim_ref=ref_dim_list([1 end]);
    end
    h=surf_augvec(adj_dim_list,ref_dim_list,d);
    xlabel(opts.adj_label);
    ylabel(opts.ref_label);
    set(gca,'XLim',xlim_adj);
    set(gca,'YLim',ylim_ref);
    set(gca,'XTick',adj_dim_list);
    set(gca,'YTick',ref_dim_list);
end
zlabel('d');
set(gca,'ZLim',[0 1]);
grid on;
box on;
view(opts.view);
return
end
