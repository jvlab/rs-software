function aux_out=rs_disp_geofit(gf,aux)
% aux_out=rs_disp_geofit(gf,aux) 
% displays the goodness of fit and model comparison statistics for geometric models fit by `rs_geofit` [how to hyperlink?]
%
% This will create a wirerame plot of goodness of fit (d, see output gfs of `rs_geofit` [??how to hyperlink] for each model,
% and, optionally, for selected models and comparisons across models that are nested by model type and/or dimension.
%
% Args:
%   gf (2-D cell array): geometrical fit data, typically gfs{k}.gf, where gfs is the output of `rs_geofit`, containing the model fits for the kth record
%      of a pair of `dataset structures`; gf{d_out,d_in} contains the statistics for transforming a dataset of d_in dimensions to one with d_out dimensions
%
%   aux (struct): auxiliary options, may be omitted, with fields
%
%     - opts_dgeo (struct): options for display, with fields
%
%          - if_nestbymodel_show (int): 1 to show all nested models, -1 to show only maximally nested models, 0 to omit; default is 1 if shuffles are present and 0 if not
%          - if_nestbydim_show (int): 1 to show nesting by dimension;, 0 to omit; default is 1 if shuffles are present and 0 if not
%          - if_nestbydim_in_show (int): 1 to show nesting by dimension for input, 0 if not; default is if_nestbydim_show
%          - if_nestbydim_out_show (int): 1 to show nesting by dimension for output, 0 if not; defaults is if_nestbydim_show
%          - models_show_select (char or cell array of char): selects the models to be shown in the plot of selected models;
%          a model will be shown if at least one of the strings in models_show_select{:} is present in the model type;
%          e.g., {'_offset','affine'} will select any model whose name contains _offset or affine;
%          default is [], which displays all models. Caution: {} is empty, [] is empty, '' is empty, but {''} and {[]} are not.
%          - if_diag (int): 0 to plot goodness of fit for all pairs of input and output dimensions, 1 to only plot diagonal values for input dimension equal to ouptut dimension;
%          default is 1 if only on-diagonal values are present, otherwise 0
%          - sig_level (float): significance level for significance flags; default is 0.05
%          - if_showsig (int): 1 to show significance flags based on original denominator, 2 for shuffled denomiator, 3 for both, 0 to omit; default is 3
%          - if_nestbydim_showd (int): 1 to show d-values for models nested by dimension, 0 to omit; default is 1
%          - if_nestbydim_showd_in (int): 1 to show d-values for models nested by input dimension, 0 to omit; default is if_nestbydim_showd
%          - if_nestbydim_showd_out (int): 1 to show d-values for models nested by output dimension, 0 to omit; default is if_nestbydim_showd
%          - if_showquant (int): 1 to show quantile of shuffles for nesting at significance level sig_level, 0 to omit; default is 0
%          - out_label (char): label for first  coordinate of gf{}, default is 'output dim'
%          - in_label (char): label for second coordinate of gf{}, defaulti is 'input dim'
%          - dia_label (char): label for both coordinates of gf{}, when diagonal is plotted, default is 'dim'
%          - colors_models (cell array): seuqnce of colors to use for model wireframes, used in cyclic order, default is {'k','b','c','m','r',[1 0.5 0],[0.7 0.7 0],'g',[.5 .5 .5],[.5 0 0]}
%          - sig_symbols (cell array of char): symbols to mark significant values, sig_symbols{1} for original denominator, sig_symbols{2} for shuffle denominator, default is {'+','x'}
%          - sig_symsize (int): symbol size for significance markers, default is 14
%          - lw_model (int): line width for model, default is 2
%          - lw_nest (int): line width for nested model, default is 2
%          - lw_quant (int): line width for quantiles of shuffles of nested models, default is 1
%          - view (int or 1-D array): 3-D view descriptor, default is 3 (standard 3-d view); can also be azimuth-elevation pair, standard 3-d view is [-37.5 30]
% 
%     - opts_check (struct): options for consistency checking, with field
%
%          - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
%
% Returns:
%   aux_out (struct): auxiliary outputs and parameter values used
%
%     - warnings (char): warnings generated in checking for consistency of plotting options
%     - warn_bad (int): count of warnings that prevent further processing
%     - opts_check (struct): aux.opts_check, with defaults filled in
%     - opts_dgeo (struct): aux.opts_dgeo with defaults filled in, and also fields
%
%         - fig_handles (cell array):  handles to the figures created
%         - fig_names (cell array): names of the figures created; no special chars, suitable for use in a file name
%         - models_shown (cell array of char): names of models shown
%
%  See also: RS_GEOFIT, PSG_GEOMODELS_FIT, PSG_GEOMODELS_PLOT.
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
aux.opts_dgeo=filldefault(aux.opts_dgeo,'models_show_select',[]); %strings to select models to show
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_diag',[]);
aux.opts_dgeo=filldefault(aux.opts_dgeo,'sig_level',0.05);
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_showsig',3); % which significance flags to show(0: none, 1: orig, 2: shuff, 3: both','d',[0 3],3);
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_showd',1); %1 to show nested-by-dim d-values
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_in_showd',aux.opts_dgeo.if_nestbydim_showd);
aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_out_showd',aux.opts_dgeo.if_nestbydim_showd);
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
aux.opts_dgeo=filldefault(aux.opts_dgeo,'out_label','input dim');
aux.opts_dgeo=filldefault(aux.opts_dgeo,'in_label','output dim');
aux.opts_dgeo=filldefault(aux.opts_dgeo,'dia_label','dim');
aux.opts_dgeo=filldefault(aux.opts_dgeo,'view',3);
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
%
%check that requests for nesting display are consistent with presence of statistics
if nshuffs==0
    aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbymodel_show',[]); %1 for all comparisons, -1 for maximal, 0 for none, set to 1 below if shuffles are present
    ask_out=0;
    if ~isempty(aux.opts_dgeo.if_nestbymodel_show)
        ask_out=double(aux.opts_dgeo.if_nestbymodel_show~=0);
    end
    if ask_out
        wmsg=sprintf('no shuffes are present, but display of nesting by models requested; ignored');
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn)); %to accumulate warnings and log based on aux_out
    end
    aux.opts_dgeo.if_nestbymodel_show=0;
    %
    aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_show',[]); %1 to show; default to 1 set below if shuffles are present
    aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_in_show',[]);
    aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_out_show',[]);
    if ~isempty(aux.opts_dgeo.if_nestbydim_show)
        ask_nbd=double(aux.opts_dgeo.if_nestbydim_show~=0);
    else
        ask_nbd=0;
    end
    if ~isempty(aux.opts_dgeo.if_nestbydim_in_show)
        ask_nbd_in=double(aux.opts_dgeo.if_nestbydim_in_show~=0);
    else
        ask_nbd_in=0;
    end
    if ~isempty(aux.opts_dgeo.if_nestbydim_out_show)
        ask_nbd_out=double(aux.opts_dgeo.if_nestbydim_out_show~=0);
    else
        ask_nbd_out=0;
    end
    if ask_nbd | ask_nbd_in | ask_nbd_out
        wmsg=sprintf('no shuffes are present, but display of nesting by dimension requested; ignored');
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn)); %to accumulate warnings and log based on aux_out
    end
    aux.opts_dgeo.if_nestbydim_show=0;
    aux.opts_dgeo.if_nestbydim_in_show=0;
    aux.opts_dgeo.if_nestbydim_out_show=0;
else
    aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbymodel_show',1); %1 for all comparisons, -1 for only maximal, 0 for none
    aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_show',1); %1 to show
    aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_in_show',aux.opts_dgeo.if_nestbydim_show);
    aux.opts_dgeo=filldefault(aux.opts_dgeo,'if_nestbydim_out_show',aux.opts_dgeo.if_nestbydim_show);
end
%
%create the plots
%
if aux_out.warn_bad>0
    disp('cannot proceed');
    disp(aux_out.warnings);
else
    aux.opts_dgeo.ref_label=aux.opts_dgeo.out_label;
    aux.opts_dgeo.adj_label=aux.opts_dgeo.in_label;
    aux.opts_dgeo=psg_geomodels_plot(gf,aux.opts_dgeo);
    aux.opts_dgeo=rmfield(aux.opts_dgeo,'ref_label');
    aux.opts_dgeo=rmfield(aux.opts_dgeo,'adj_label');
    %
    aux_out.opts_check=aux.opts_check;
    %
    aux_out.opts_dgeo=aux.opts_dgeo;
end
%
return
end
