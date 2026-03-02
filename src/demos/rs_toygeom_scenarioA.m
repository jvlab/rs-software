% rs_toygeom_scenarioA.m
%sets up a scenario for rs_toygeom_demo: general illustration
scenario_name='scenario A';
paradigm_names={'Axes'}; 
transform_names={'procrustes','affine','projective','pwaffine'};
nsubjs=1;
ncoords_noise=0;
noise_add_mag=0.1;
model_list={'procrustes_noscale_offset','procrustes_scale_offset','affine_offset','projective','pwaffine'};
opts_geof=struct;
opts_geof.if_stats=0;
%
rs_toygeom_demo;
paradigms_fit_show={'Axes'};
subjs_fit_show=[1:nsubjs];

rs_toygeom_disp;
