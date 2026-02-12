function aux_out=rs_disp_geofit(gf,aux)
% aux_out=rs_disp_geofit(gf,aux) displays the goodness of fit and model comparison statistics for a structure of geometric models
%
% This is largely a wrapper for psg_geomodel_plot, but with some defaults are changed, and some consistency checks
%
% gf: a cell array of geometrical fit data, typically gfs{k}.gf, where gfs is the output of rs_geofit
%   gf{d_out,d_in} contains goodness of fit data for transforming a dataset of d_in dimensions to one with d_out dimensions
% aux:
%  aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
%  aux.opts_dgeo: options for display
%   if_nestbymodel_show: 1 to show all nested models, -1 to show only maximally nested models, 0 to show none; will default to 1 if shuffles are present and 0 if not
%   if_nestbydim_show: 1 to show nesting by dimension; will default to 1 if shuffles are present and 0 if not
%   models_show_select: string, or cell array of strings, that select which models are shown
%      For a model to be shown, at least one of the strings in models_show_select{:} must be present in the model type
%      e.g., {'_offset','affine'} will select any model whose name contains _offset or affine
%      If empty or unspecified, no selection.  Caution: {} is empty, [] is empty, '' is empty, but {''} and {[]} are not.
%      Even if a subset of models are selectd, all models are shown in the 'all_models' plot, along with selected models in 'select_models' plot
%   if_diag: 0 to plot as function of {d_ref,d_adj}}, 1 to only plot diagonal values (gf{k,k}),
%      if not provided, will be 1 if all values are on-diagonal, otherwise 0
%   sig_level: significance level
%   if_showsig: which significance flags to show for d (goodness of fit): 0: none, 1: based on original denom, 2 based on shuffle denom, 3: both (default)
%   if_showquant: 1 to show quantile at significance level sig_level (defaults to 0)
%   ref_label: label for first  coordinate of gf{}, defaults to 'output dim'
%   adj_label: label for second coordinate of gf{}, defaults to 'input dim'
%   dia_label: label for gf{}, when diagonal is plotted, defaults to 'dim'
%   colors_models: colors to use for model, used in cyclic order, default- {'k','b','c','m','r',[1 0.5 0],[0.7 0.7 0],'g',[.5 .5 .5],[.5 0 0]}
%   sig_symbols: symbols to mark significant values, sig_symbols{1} for original denom, sig_symbols{2} for shuffle denom, default-{'+','x'}
%   sig_symsize: symbol size for significant values, default=14
%   lw_model: line width for model, default=2
%   lw_nest: line width for nested model, default=2
%   lw_quant: line width for quantile, default=1
% 
% aux_out: auxiliary outputs and parameter values used
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%   aux_out.opts_dgeo: aux.opts_dgeo, as used, and also:
%     opts_dgeo.fig_handles is a cell array of handles to the figures created
%     opts_dgeo.fig_names is a cell array of names of the figures created; no special chars, suitable for use in a file name
%     opts_dgeo.models_shown: names of models shown
%
%  See also: RS_GEOFIT, PSG_GEOMODELS_FIT, PSG_GEOMMODELS_PLOT.
%
if (nargin<=1)
    aux=struct;
end
%
%set up sub-structure options
%
aux=filldefault(aux,'opts_dgeo',struct); %options for this module
%
%plot format options
%
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbymodel_show',[]); %1 for all comparisons, -1 for maximal, 0 for none, set to 1 below if shuffles are present
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_show',[]); %1 to show; default to 1 set below if shuffles are present
aux.opts_dgeo=filldefault(aux.opts_dgeo,'models_show_select',[]); %strings to select models to show
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_diag',[]);
aux.opts_dgeo=filldefault(aux.opts_dgeo,'sig_level',0.05);
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_showsig',3); % which significance flags to show(0: none, 1: orig, 2: shuff, 3: both','d',[0 3],3);
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_showquant',0); %1 to show quantile at requested significance level (sig_level)
%
aux.opts_dgeo=filldefault(aux.opts_dgeo,'sig_symbols',{'+','x'});
aux.opts_dgeo=filldefault(aux.opts_dgeo,'sig_symsize',14);
aux.opts_dgeo=filldefault(aux.opts_dgeo,'quant_lines',{'--','-.'});
aux.opts_dgeo=filldefault(aux.opts_dgeo,'colors_mn',{'k','b'});
aux.opts_dgeo=filldefault(aux.opts_dgeo,'colors_models',{'k','b','c','m','r',[1 0.5 0],[0.7 0.7 0],'g',[.5 .5 .5],[.5 0 0]});
aux.opts_dgeo=filldefault(aux.opts_dgeo,'lw_model',2); %line width for a model
aux.opts_dgeo=filldefault(aux.opts_dgeo,'lw_nest',2); %line width for a nested model
aux.opts_dgeo=filldefault(aux.opts_dgeo,'lw_quant',1); %line width for quantiles
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_omnicolors',1); %1 to use colors from omnibus plots in comparison plots
aux.opts_dgeo=filldefault(aux.opts_dgeo,'adj_label','input dim');
aux.opts_dgeo=filldefault(aux.opts_dgeo,'ref_label','output dim');
aux.opts_dgeo=filldefault(aux.opts_dgeo,'dia_label','dim');
%
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_log',0);
%
aux=filldefault(aux,'opts_check',struct); %options for other modules called
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_disp_geofit');
%
data_out=struct;
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
%consistency checks
%
have_data=zeros(size(gf));
gr_fill=struct;
dim_pairs=zeros(0,2);
for ref_dim=1:size(gf,1)
    for adj_dim=1:size(gf,2);
        have_data(ref_dim,adj_dim)=isfield(gf{ref_dim,adj_dim},'model_types_def');
        if have_data(ref_dim,adj_dim)
            dim_pairs(end+1,:)=[ref_dim,adj_dim];
        end
    end
end
ref_dim_list=find(any(have_data,2)'>0);
adj_dim_list=find(any(have_data,1)>0);
npairs=size(dim_pairs,1);
if npairs==0
    wmsg=sprintf('no model fits are present');
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1)); %to force a warning output; second argument is a 1 if a bad warning
    disp('cannot proceed');
    disp(aux_out.warnings);
    return;
end
if_onlydiag=double(sum(have_data(:))==sum(diag(have_data)));
if if_onlydiag & (aux.opts_dgeo.if_diag==0)
    wmsg=sprintf('only data for input dim = output dim are available, but 2D plot requested (if_diag=0)');
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn)); %to accumulate warnings and log based on aux_out
end
gf_example=gf{dim_pairs(1,1),dim_pairs(1,2)};
nshuffs=size(gf_example.d_shuff,2);
if nshuffs==0
    if ~isempty(aux.opts_dgeo.if_nestbymodel_show) & aux.opts_dgeo.if_nestbymodel_show~=0
        wmsg=sprintf('no shuffes are present, but analysis of nesting by models requested; ignored');
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn)); %to accumulate warnings and log based on aux_out
    end
    aux.opts_dgeo.if_nestbymodel_show=0;
    if ~isempty(aux.opts_dgeo.if_nestbydim_show) & aux.opts_dgeo.if_nestbydim_show~=0
        wmsg=sprintf('no shuffes are present, but analysis of nesting by dimension requested; ignored');
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn)); %to accumulate warnings and log based on aux_out
    end
    aux.opts_dgeo.if_nestbydim_show=0;
else
    aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbymodel_show',1); %1 for all comparisons, -1 for maximal, 0 for none
    aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_show',1); %1 to show
end
%
%create the plots
%
if aux_out.warn_bad>0
    disp('cannot proceed');
    disp(aux_out.warnings);
else
    aux.opts_dgeo=psg_geomodels_plot(gf,aux.opts_dgeo);
    aux_out.opts_dgeo=aux.opts_dgeo;
end
%
return
end
