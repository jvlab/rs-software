function aux_out=rs_disp_geofit(gfs,aux)
% aux_out=rs_disp_geofit(gfs,aux) displays the goodness of fit and model comparison statistics for a structure of geometric models
%
% aux:
%  aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
%  aux.opts_dgeo: options for display
% 
% aux_out: auxiliary outputs and parameter values used
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%   aux_out.opts_dgeo: aux.opts_dgeo, as used
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
%change these to dgeo, and incorporate options from psg_geomodels_fit;

% aux.opts_geof=filldefault(aux.opts_geof,'dimpairs_method','equal');
% aux.opts_geof=filldefault(aux.opts_geof,'dim_max_in',10);
% aux.opts_geof=filldefault(aux.opts_geof,'dim_max_out',aux.opts_geof.dim_max_in);
% aux.opts_geof=filldefault(aux.opts_geof,'dimpairs_list',repmat([1:aux.opts_geof.dim_max_in]',[1 2]));
% aux.opts_geof=filldefault(aux.opts_geof,'if_stats',1);
% aux.opts_geof=filldefault(aux.opts_geof,'if_plot',aux.opts_geof.if_stats);
% aux.opts_geof=filldefault(aux.opts_geof,'if_nestbymodel',1);
% aux.opts_geof=filldefault(aux.opts_geof,'if_nestbydim',0);
% aux.opts_geof=filldefault(aux.opts_geof,'if_center',1);
% aux.opts_geof=filldefault(aux.opts_geof,'if_frozen',1);
% aux.opts_geof=filldefault(aux.opts_geof,'if_fit_summary',1);
% aux.opts_geof=filldefault(aux.opts_geof,'if_fit_log',0);
% aux.opts_geof=filldefault(aux.opts_geof,'if_warn',1);
% aux.opts_geof=filldefault(aux.opts_geof,'if_log',1);
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
%for custom warnings with rs leadin
if (condition)
    wmsg=sprintf('dim_list_in and dim_list_out have different lengths');
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1)); %to force a warning output; second argument is a 1 if a bad warning
    %or%
    aux_out=rs_warning(wmsg,0,aux_out); %to accumulage warnings and log based on aux_out, first force a warning output
end
%% call psg_geomodels
aux.opts_dgeo=psg_geomodels_plot(gfs,aux.opts_dgeo);
aux_out.opts_dgeo=aux.opts_dgeo;
%
return
end
%use code from here to see if nshuff is nonzero (and warn if trying to plot stats)

% 
% 
% function opts_used=psg_geomodels_plot(results,opts)
% % opts_used=psg_geomodels_plot(results,opts) creates summaryy plots of goodness
% % of fit of geometric models, including comparison of models with nested models, and comparison of models nested by dimension
% %
% % results: output of psg_geomodels_fit or psg_geomodels_run containing goodness of fit of one or more geometric models
% %     results{ref,adj} contains the analysis for transforming an input set with adj dimensions to an output set with ref dimensions
% % 
% % opts: options
% %   if_nestbymodel_show: 1 (default) to show all nested models, -1 to show only maximally nested models, 0 to show none
% %   if_nestbydim_show: 1 (default) to show nesting by dimension
% %   models_show_select: string, or cell array of strings, that select which models are shown
% %      For a model to be shown, at least one of the strings in models_show_select{:} must be present in the model type
% %      e.g., {'_offset','affine'} will select any model whose name contains _offset or affine
% %      If empty or unspecified, no selection.  Caution: {} is empty, [] is empty, '' is empty, but {''} and {[]} are not.
% %      Even if a subset of models are selectd, all models are shown in the 'all_models' plot, along with selected models in 'select_models' plot
% %   if_diag: 0 to plot as function of {d_ref,d_adj}}, 1 to only plot diagonal values (results{k,k}),
% %      if not provided, will be determined by whether there are any off-diagonal valuesresults
% %   sig_level: significance level
% %   if_showsig: which significance flags to show for d (goodness of fit): 0: none, 1: based on original denom, 2 based on shuffle denom, 3: both (default)
% %   if_showquant: 1 to show quantile at significance level sig_level (defaults to 0)
% %   ref_label: label for first  coordinate of results{}, defaults to ','ref dim'
% %   adj_label: label for second coordinate of results{}, defaults to ','adj dim'
% %   dia_label: label for results{}, when diagonal is plotted, defaults to 'ref and adj dim'
% %   colors_models: colors to use for model, used in cyclic order, default- {'k','b','c','m','r',[1 0.5 0],[0.7 0.7 0],'g',[.5 .5 .5],[.5 0 0]}
% %   sig_symbols: symbols to mark significant values, sig_symbols{1} for original denom, sig_symbols{2} for shuffle denom, default-{'+','x'}
% %   sig_symsize: symbol size for significant values, default=14
% %   lw_model: line width for model, default=2
% %   lw_nest: line width for nested model, default=2
% %   lw_quant: line width for quantile, default=1
% %
% % opts_used: options used
% %    also:
% %    opts_used.fig_handles is a cell array of handles to the figures created
% %    opts_used.fig_names is a cell array of names of the figures created; no special chars, suitable for use in a file name
% %    opts_used.models_shown: names of models shown
% %
% % This is a modularized version of psg_geomodels_summ, with the following main differences:
% %   results must be passed, not read from a file
% %   results cannot be a cell array of subsidiary results structures ('mode 2' of psg_geomodels_summ)
% %   results may be present on any subset of the (ref,adj) pairs
% %   can select which models to plot according to model name
% %   can plot along a diagonal of (ref==adj)
% %
% %   See also: RS_SAVE_FIGS, PSG_GEOMODELS_SUMM, PSG_GEOMODELS_FIT, PSG_GEOMODELS_RUN, PSG_GEOMODELS_DEFINE, SURF_AUGVEC, HLID_MDS_COORDS_GEOMODELS.
% %
% if nargin<=1
%     opts=struct();
% end
% %plot format options
% opts=filldefault(opts,'sig_symbols',{'+','x'});
% opts=filldefault(opts,'sig_symsize',14);
% opts=filldefault(opts,'quant_lines',{'--','-.'});
% opts=filldefault(opts,'colors_mn',{'k','b'});
% opts=filldefault(opts,'colors_models',{'k','b','c','m','r',[1 0.5 0],[0.7 0.7 0],'g',[.5 .5 .5],[.5 0 0]});
% opts=filldefault(opts,'lw_model',2); %line width for a model
% opts=filldefault(opts,'lw_nest',2); %line width for a nested model
% opts=filldefault(opts,'lw_quant',1); %line width for quantiles
% opts=filldefault(opts,'if_omnicolors',1); %1 to use colors from omnibus plots in comparison plots
% opts=filldefault(opts,'adj_label','adj dim');
% opts=filldefault(opts,'ref_label','ref dim');
% opts=filldefault(opts,'dia_label','ref and adj dim');
% %
% opts=filldefault(opts,'if_nestbymodel_show',1); %1 for all comparisons, -1 for maximal, 0 for none
% opts=filldefault(opts,'if_nestbydim_show',1); %1 to show
% opts=filldefault(opts,'models_show_select',[]); %strings to select models to show
% opts=filldefault(opts,'if_diag',[]);
% opts=filldefault(opts,'sig_level',0.05);
% opts=filldefault(opts,'if_showsig',3); % which significance flags to show(0: none, 1: orig, 2: shuff, 3: both','d',[0 3],3);
% opts=filldefault(opts,'if_showquant',0); %1 to show quantile at requested significance level (sig_level)
% %
% opts=filldefault(opts,'if_log',0);
% %
% norm_labels={'orig','shuff'}; %denominator used for normalization of d in significance calculations
% %
% showsigs(1)=mod(opts.if_showsig,2);
% showsigs(2)=double(opts.if_showsig>=2);
% %
% fig_counter=0;
% opts.fig_handles=cell(0);
% opts.fig_names=cell(0);
% %
% have_data=zeros(size(results));
% for ref_dim=1:size(results,1)
%     for adj_dim=1:size(results,2);
%         have_data(ref_dim,adj_dim)=isfield(results{ref_dim,adj_dim},'model_types_def');
%     end
% end
% if isempty(opts.if_diag)
%     if sum(have_data(:))==sum(diag(have_data))
%         opts.if_diag=1;
%     else
%         opts.if_diag=0;
%     end
% end
% ref_dim_list=find(any(have_data,2)'>0);
% adj_dim_list=find(any(have_data,1)>0);
% if opts.if_log
%     disp('reference set dimension list:')
%     disp(ref_dim_list);
%     disp('adjusted  set dimension list')
%     disp(adj_dim_list);
% end
%
r=results{ref_dim_list(1),adj_dim_list(1)};
% if isfield(r,'d_shuff')
%     nshuff=size(r.d_shuff,2);
% else
%     nshuff=0;
% end
% %
