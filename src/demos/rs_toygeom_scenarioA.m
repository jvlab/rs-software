% rs_toygeom_scenarioA.m
%sets up a scenario for rs_toygeom_demo: general illustration
scenario_name='scenario A';
paradigm_names={'Axes'}; 
transform_names={'affine','projective'};
nsubjs=3;
opts_geof=struct;
opts_geof.nshuffs=10;
%these are the main customizable params
% opts_geof=filldefault(opts_geof,'model_list',{'procrustes_scale_offset','affine_offset','projective','pwaffine'});
% opts_geof=filldefault(opts_geof,'dimpairs_method','all');
% opts_geof=filldefault(opts_geof,'if_stats',1);
% opts_geof=filldefault(opts_geof,'nshuffs',20);
% opts_geof=filldefault(opts_geof,'if_nestbymodel',-1);
% opts_geof=filldefault(opts_geof,'if_nestbydim',-1);
% opts_geof=filldefault(opts_geof,'if_log',0);
% opts_geof=filldefault(opts_geof,'if_fit_summary',0);
if_disp_geofit=1;
paradigms_fit_show={'Axes'};
subjs_fit_show=[1 3];
rs_toygeom_demo;
