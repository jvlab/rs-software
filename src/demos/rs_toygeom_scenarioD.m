%rs_toygeom_scenarioD: geometric transformations, affine model, with statistical analysis of nesting by input dimension
%
% Scenario D for rs_toygeom_demo: 
% illustration of gemoetric models, focusing on nesting by input dimension and "knitting" datasets together 
%
% Geometric model simulated: affine (3 dimensions)
% Shows that:
%   With sampling in dimensions 1 and 2 (Rings_C12), adding a third dimension to the model does not improve the fit
%   With sampling in dimensions 1 and 3 (Rings_C13), adding the second dimension does not improve the fit but adding the third dimension does
%   With sampling in dimensions 2 and 3 (Rings_C23), the first dimension does not improve the fit but the other two dimensions do
%   With knitting together all datasets ('knitted'), all dimensions contribute to the fit
%
scenario_name='scenario D';
%transform selection
transform_names={'affine'};
affine_mag=0.3;
%
%paradigm customizations
paradigm_names={'Rings_C12','Rings_C13','Rings_C23'};
%
%subject customizations
nsubjs=1;
ncoords=3;
ncoords_noise=1;
noise_add_subj=0.3; % moderate noise
%
%geometric model selection
model_list={'affine_offset'};
if_knit=1;
%
opts_geof=struct;
opts_geof.if_stats=1;
%
rs_toygeom_demo; %create the stimuli and datasets, and fit the models
%
%gemoetric model fit display customizations
subjs_fit_show=[1:nsubjs];
opts_dgeo=struct;
opts_dgeo.view=[-15 45];
opts_dgeo.if_nestbydim_out_show=0;
%
rs_toygeom_disp; %display model-fitting results
