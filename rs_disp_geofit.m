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
%   if_nestbymodel_show: 1 (default) to show all nested models, -1 to show only maximally nested models, 0 to show none
%   if_nestbydim_show: 1 (default) to show nesting by dimension
%   models_show_select: string, or cell array of strings, that select which models are shown
%      For a model to be shown, at least one of the strings in models_show_select{:} must be present in the model type
%      e.g., {'_offset','affine'} will select any model whose name contains _offset or affine
%      If empty or unspecified, no selection.  Caution: {} is empty, [] is empty, '' is empty, but {''} and {[]} are not.
%      Even if a subset of models are selectd, all models are shown in the 'all_models' plot, along with selected models in 'select_models' plot
%   if_diag: 0 to plot as function of {d_ref,d_adj}}, 1 to only plot diagonal values (gf{k,k}),
%      if not provided, will be determined by whether there are any off-diagonal valuesresults
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
%   aux_out.opts_dgeo: aux.opts_dgeo, as used
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
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbymodel_show',1); %1 for all comparisons, -1 for maximal, 0 for none
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_show',1); %1 to show
aux.opts_dgeo=filldefault(aux.opts_dgeo,'models_show_select',[]); %strings to select models to show
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_diag',[]);
aux.opts_dgeo=filldefault(aux.opts_dgeo,'sig_level',0.05);
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_showsig',3); % which significance flags to show(0: none, 1: orig, 2: shuff, 3: both','d',[0 3],3);
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_showquant',0); %1 to show quantile at requested significance level (sig_level)
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
for ref_dim=1:size(gf,1)
    for adj_dim=1:size(gf,2);
        have_data(ref_dim,adj_dim)=isfield(gf{ref_dim,adj_dim},'model_types_def');
    end
end
% if isempty(opts.if_diag)
%     if sum(have_data(:))==sum(diag(have_data))
%         opts.if_diag=1;
%     else
%         opts.if_diag=0;
%     end
% end
ref_dim_list=find(any(have_data,2)'>0);
adj_dim_list=find(any(have_data,1)>0);
if aux.opts_dgeo.if_log
    disp('reference set dimension list:')
    disp(ref_dim_list);
    disp('adjusted  set dimension list')
    disp(adj_dim_list);
end

% %
% %for custom warnings with rs leadin
% %
% if (condition)
%     wmsg=sprintf('dim_list_in and dim_list_out have different lengths');
%     aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1)); %to force a warning output; second argument is a 1 if a bad warning
%     %or%
%     aux_out=rs_warning(wmsg,0,aux_out); %to accumulage warnings and log based on aux_out, first force a warning output
% end
%
%
%create the plots
%
aux.opts_dgeo=psg_geomodels_plot(gf,aux.opts_dgeo);
aux_out.opts_dgeo=aux.opts_dgeo;
%
return
end
%
%r=results{ref_dim_list(1),adj_dim_list(1)};
% if isfield(r,'d_shuff')
%     nshuff=size(r.d_shuff,2);
% else
%     nshuff=0;
% end
% %
