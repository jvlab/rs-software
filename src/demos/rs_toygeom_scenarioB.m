% rs_toygeom_scenarioB.m
%sets up a scenario for rs_toygeom_demo: rings have inadequate number of dimensions
%scenario_name='scenario B';
ncoords=4;
paradigm_names={'Axes','Rings_C12','Rings_C13','Rings_C23'}; 
transform_names={'affine'};
nsubjs=1;
opts_geof=struct;
opts_geof.nshuffs=20;
%these are the main custoomizable params
% opts_geof=filldefault(opts_geof,'model_list',{'procrustes_scale_offset','affine_offset','projective','pwaffine'});
% opts_geof=filldefault(opts_geof,'dimpairs_method','all');
% opts_geof=filldefault(opts_geof,'if_stats',1);
% opts_geof=filldefault(opts_geof,'nshuffs',20);
% opts_geof=filldefault(opts_geof,'if_nestbymodel',-1);
% opts_geof=filldefault(opts_geof,'if_nestbydim',-1);
% opts_geof=filldefault(opts_geof,'if_log',0);
% opts_geof=filldefault(opts_geof,'if_fit_summary',0);
if_disp_geofit=1;
if ~exist('opts_dgeo') opts_dgeo=struct; end
opts_dgeo.if_nestbymodel_show=0;
opts_dgeo.models_show_select={'affine_offset'};
rs_toygeom_demo;
