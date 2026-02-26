% rs_toygeom_scenarioA.m
%sets up a scenario for rs_toygeom_demo: general illustration
scenario_name='scenario A';
paradigm_names={'Axes'}; 
transform_names={'affine','projective'};
nsubjs=3;
opts_geof=struct;
opts_geof.nshuffs=10;
%
rs_toygeom_demo;
paradigms_fit_show={'Axes'};
subjs_fit_show=[1 3];
rs_toygeom_disp;

