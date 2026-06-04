%rs_toygeom_scenarioA: geometric transformations, without statistics: procrustes, affine, projective, piecewise affine
%
% Scenario A for rs_toygeom_demo: 
% general illustration of geometric models, without statistics
%
% Geometric models simulated: procrustes, affine, projective, and piecewise affine (3 dimensions each)
% Shows that:
% * geometric models can be distinguished
% * procurstes is also fit by affine, projective, and piecewise affine
% * affine is also fit by projective and piecewise affine
% * projective and piecewise affine can be distinguished, but not as readily
%
scenario_name='scenario A';
%transform selection
transform_names={'procrustes','affine','projective','pwaffine'};
projective_mag=0.07;
affine_mag=0.3;
%
%paradigm customizations
paradigm_names={'Axes','Random'};
nrandom=48;
%
%subject customizations
nsubjs=1;
ncoords_noise=0;
noise_transform_mag=0;
noise_add_subj=0.05; %small amount of noise
%
%geometric model selection
model_list={'procrustes_scale_offset','affine_offset','projective','pwaffine'};
%
opts_geof=struct;
opts_geof.if_stats=0;
%
rs_toygeom_demo; %create the stimuli and datasets, and fit the models
%
%gemoetric model fit display customizations
paradigms_fit_show={'Axes','Random'};
subjs_fit_show=[1:nsubjs];
opts_dgeo=struct;
opts_dgeo.view=[-40 20];
%
rs_toygeom_disp; %display model-fitting results
