# rs_toygeom_scenarioA
Geometric transformations, without statistics: procrustes, affine, projective, piecewise affine

Scenario A for rs_toygeom_sim:
general illustration of geometric models, without statistics

Geometric models simulated: procrustes, affine, projective, and piecewise affine (3 dimensions each)
Shows that:
* geometric models can be distinguished
* procurstes is also fit by affine, projective, and piecewise affine
* affine is also fit by projective and piecewise affine
* projective and piecewise affine can be distinguished, but not as readily

```matlab
clear; %parameters are read from the workspace, so start from a clean one
scenario_name='scenario A';
```

transform selection

```matlab
transform_names={'procrustes','affine','projective','pwaffine'};
projective_mag=0.07;
affine_mag=0.3;
```

paradigm customizations

```matlab
paradigm_names={'Axes','Random'};
nrandom=48;
```

subject customizations

```matlab
nsubjs=1;
ncoords_noise=0;
noise_transform_mag=0;
noise_add_subj=0.05; %small amount of noise
```

geometric model selection

```matlab
model_list={'procrustes_scale_offset','affine_offset','projective','pwaffine'};
```

```matlab
opts_geof=struct;
opts_geof.if_stats=0;
```

```matlab
rs_toygeom_sim; %create the stimuli and datasets, and fit the models
```

Output:

```text
  4 transforms set up, on   3 coordinates.
jittered transformations created for  1 subjects
coordinate sets created for paradigm Axes
coordinate sets created for paradigm Random
ray structure created for paradigm Axes
ray structure skipped for paradigm Random
dataspace created for paradigm                 Axes and transform procrustes
dataspace created for paradigm                 Axes and transform affine
dataspace created for paradigm                 Axes and transform projective
dataspace created for paradigm                 Axes and transform pwaffine
dataspace created for paradigm               Random and transform procrustes
dataspace created for paradigm               Random and transform affine
dataspace created for paradigm               Random and transform projective
dataspace created for paradigm               Random and transform pwaffine
 
modeling transform           procrustes from stimulus space to subject space with paradigm                 Axes
modeling transform           procrustes from stimulus space to subject space with paradigm               Random
 
modeling transform               affine from stimulus space to subject space with paradigm                 Axes
modeling transform               affine from stimulus space to subject space with paradigm               Random
 
modeling transform           projective from stimulus space to subject space with paradigm                 Axes
modeling transform           projective from stimulus space to subject space with paradigm               Random
 
modeling transform             pwaffine from stimulus space to subject space with paradigm                 Axes
modeling transform             pwaffine from stimulus space to subject space with paradigm               Random
consider saving the structure 'sims', and using rs_toygeom_disp to display results
```

![rs_toygeom_scenarioA_chunk07_fig1](../../images/demos/rs_toygeom_scenarioA_chunk07_fig1.png)

![rs_toygeom_scenarioA_chunk07_fig2](../../images/demos/rs_toygeom_scenarioA_chunk07_fig2.png)

geometric model fit display customizations

```matlab
paradigms_fit_show={'Axes','Random'};
subjs_fit_show=[1:nsubjs];
opts_dgeo=struct;
opts_dgeo.view=[-40 20];
```

```matlab
rs_toygeom_disp; %display model-fitting results
```

![rs_toygeom_scenarioA_chunk09_fig1](../../images/demos/rs_toygeom_scenarioA_chunk09_fig1.png)

![rs_toygeom_scenarioA_chunk09_fig2](../../images/demos/rs_toygeom_scenarioA_chunk09_fig2.png)

![rs_toygeom_scenarioA_chunk09_fig3](../../images/demos/rs_toygeom_scenarioA_chunk09_fig3.png)

![rs_toygeom_scenarioA_chunk09_fig4](../../images/demos/rs_toygeom_scenarioA_chunk09_fig4.png)

![rs_toygeom_scenarioA_chunk09_fig5](../../images/demos/rs_toygeom_scenarioA_chunk09_fig5.png)

![rs_toygeom_scenarioA_chunk09_fig6](../../images/demos/rs_toygeom_scenarioA_chunk09_fig6.png)

![rs_toygeom_scenarioA_chunk09_fig7](../../images/demos/rs_toygeom_scenarioA_chunk09_fig7.png)

![rs_toygeom_scenarioA_chunk09_fig8](../../images/demos/rs_toygeom_scenarioA_chunk09_fig8.png)

![rs_toygeom_scenarioA_chunk09_fig9](../../images/demos/rs_toygeom_scenarioA_chunk09_fig9.png)

![rs_toygeom_scenarioA_chunk09_fig10](../../images/demos/rs_toygeom_scenarioA_chunk09_fig10.png)

![rs_toygeom_scenarioA_chunk09_fig11](../../images/demos/rs_toygeom_scenarioA_chunk09_fig11.png)

![rs_toygeom_scenarioA_chunk09_fig12](../../images/demos/rs_toygeom_scenarioA_chunk09_fig12.png)

![rs_toygeom_scenarioA_chunk09_fig13](../../images/demos/rs_toygeom_scenarioA_chunk09_fig13.png)

![rs_toygeom_scenarioA_chunk09_fig14](../../images/demos/rs_toygeom_scenarioA_chunk09_fig14.png)

![rs_toygeom_scenarioA_chunk09_fig15](../../images/demos/rs_toygeom_scenarioA_chunk09_fig15.png)

![rs_toygeom_scenarioA_chunk09_fig16](../../images/demos/rs_toygeom_scenarioA_chunk09_fig16.png)

![rs_toygeom_scenarioA_chunk09_fig17](../../images/demos/rs_toygeom_scenarioA_chunk09_fig17.png)

![rs_toygeom_scenarioA_chunk09_fig18](../../images/demos/rs_toygeom_scenarioA_chunk09_fig18.png)

![rs_toygeom_scenarioA_chunk09_fig19](../../images/demos/rs_toygeom_scenarioA_chunk09_fig19.png)

![rs_toygeom_scenarioA_chunk09_fig20](../../images/demos/rs_toygeom_scenarioA_chunk09_fig20.png)

![rs_toygeom_scenarioA_chunk09_fig21](../../images/demos/rs_toygeom_scenarioA_chunk09_fig21.png)

![rs_toygeom_scenarioA_chunk09_fig22](../../images/demos/rs_toygeom_scenarioA_chunk09_fig22.png)

![rs_toygeom_scenarioA_chunk09_fig23](../../images/demos/rs_toygeom_scenarioA_chunk09_fig23.png)

![rs_toygeom_scenarioA_chunk09_fig24](../../images/demos/rs_toygeom_scenarioA_chunk09_fig24.png)

![rs_toygeom_scenarioA_chunk09_fig25](../../images/demos/rs_toygeom_scenarioA_chunk09_fig25.png)

![rs_toygeom_scenarioA_chunk09_fig26](../../images/demos/rs_toygeom_scenarioA_chunk09_fig26.png)

![rs_toygeom_scenarioA_chunk09_fig27](../../images/demos/rs_toygeom_scenarioA_chunk09_fig27.png)

![rs_toygeom_scenarioA_chunk09_fig28](../../images/demos/rs_toygeom_scenarioA_chunk09_fig28.png)

![rs_toygeom_scenarioA_chunk09_fig29](../../images/demos/rs_toygeom_scenarioA_chunk09_fig29.png)

![rs_toygeom_scenarioA_chunk09_fig30](../../images/demos/rs_toygeom_scenarioA_chunk09_fig30.png)

![rs_toygeom_scenarioA_chunk09_fig31](../../images/demos/rs_toygeom_scenarioA_chunk09_fig31.png)

![rs_toygeom_scenarioA_chunk09_fig32](../../images/demos/rs_toygeom_scenarioA_chunk09_fig32.png)

![rs_toygeom_scenarioA_chunk09_fig33](../../images/demos/rs_toygeom_scenarioA_chunk09_fig33.png)

![rs_toygeom_scenarioA_chunk09_fig34](../../images/demos/rs_toygeom_scenarioA_chunk09_fig34.png)

![rs_toygeom_scenarioA_chunk09_fig35](../../images/demos/rs_toygeom_scenarioA_chunk09_fig35.png)

![rs_toygeom_scenarioA_chunk09_fig36](../../images/demos/rs_toygeom_scenarioA_chunk09_fig36.png)

![rs_toygeom_scenarioA_chunk09_fig37](../../images/demos/rs_toygeom_scenarioA_chunk09_fig37.png)

![rs_toygeom_scenarioA_chunk09_fig38](../../images/demos/rs_toygeom_scenarioA_chunk09_fig38.png)

![rs_toygeom_scenarioA_chunk09_fig39](../../images/demos/rs_toygeom_scenarioA_chunk09_fig39.png)

![rs_toygeom_scenarioA_chunk09_fig40](../../images/demos/rs_toygeom_scenarioA_chunk09_fig40.png)

![rs_toygeom_scenarioA_chunk09_fig41](../../images/demos/rs_toygeom_scenarioA_chunk09_fig41.png)

![rs_toygeom_scenarioA_chunk09_fig42](../../images/demos/rs_toygeom_scenarioA_chunk09_fig42.png)

![rs_toygeom_scenarioA_chunk09_fig43](../../images/demos/rs_toygeom_scenarioA_chunk09_fig43.png)

![rs_toygeom_scenarioA_chunk09_fig44](../../images/demos/rs_toygeom_scenarioA_chunk09_fig44.png)

![rs_toygeom_scenarioA_chunk09_fig45](../../images/demos/rs_toygeom_scenarioA_chunk09_fig45.png)

![rs_toygeom_scenarioA_chunk09_fig46](../../images/demos/rs_toygeom_scenarioA_chunk09_fig46.png)

![rs_toygeom_scenarioA_chunk09_fig47](../../images/demos/rs_toygeom_scenarioA_chunk09_fig47.png)

![rs_toygeom_scenarioA_chunk09_fig48](../../images/demos/rs_toygeom_scenarioA_chunk09_fig48.png)

![rs_toygeom_scenarioA_chunk09_fig49](../../images/demos/rs_toygeom_scenarioA_chunk09_fig49.png)

![rs_toygeom_scenarioA_chunk09_fig50](../../images/demos/rs_toygeom_scenarioA_chunk09_fig50.png)

![rs_toygeom_scenarioA_chunk09_fig51](../../images/demos/rs_toygeom_scenarioA_chunk09_fig51.png)

![rs_toygeom_scenarioA_chunk09_fig52](../../images/demos/rs_toygeom_scenarioA_chunk09_fig52.png)

![rs_toygeom_scenarioA_chunk09_fig53](../../images/demos/rs_toygeom_scenarioA_chunk09_fig53.png)

![rs_toygeom_scenarioA_chunk09_fig54](../../images/demos/rs_toygeom_scenarioA_chunk09_fig54.png)

![rs_toygeom_scenarioA_chunk09_fig55](../../images/demos/rs_toygeom_scenarioA_chunk09_fig55.png)

![rs_toygeom_scenarioA_chunk09_fig56](../../images/demos/rs_toygeom_scenarioA_chunk09_fig56.png)

![rs_toygeom_scenarioA_chunk09_fig57](../../images/demos/rs_toygeom_scenarioA_chunk09_fig57.png)

![rs_toygeom_scenarioA_chunk09_fig58](../../images/demos/rs_toygeom_scenarioA_chunk09_fig58.png)

![rs_toygeom_scenarioA_chunk09_fig59](../../images/demos/rs_toygeom_scenarioA_chunk09_fig59.png)

![rs_toygeom_scenarioA_chunk09_fig60](../../images/demos/rs_toygeom_scenarioA_chunk09_fig60.png)

![rs_toygeom_scenarioA_chunk09_fig61](../../images/demos/rs_toygeom_scenarioA_chunk09_fig61.png)

![rs_toygeom_scenarioA_chunk09_fig62](../../images/demos/rs_toygeom_scenarioA_chunk09_fig62.png)

![rs_toygeom_scenarioA_chunk09_fig63](../../images/demos/rs_toygeom_scenarioA_chunk09_fig63.png)

![rs_toygeom_scenarioA_chunk09_fig64](../../images/demos/rs_toygeom_scenarioA_chunk09_fig64.png)

![rs_toygeom_scenarioA_chunk09_fig65](../../images/demos/rs_toygeom_scenarioA_chunk09_fig65.png)

![rs_toygeom_scenarioA_chunk09_fig66](../../images/demos/rs_toygeom_scenarioA_chunk09_fig66.png)

![rs_toygeom_scenarioA_chunk09_fig67](../../images/demos/rs_toygeom_scenarioA_chunk09_fig67.png)

![rs_toygeom_scenarioA_chunk09_fig68](../../images/demos/rs_toygeom_scenarioA_chunk09_fig68.png)

![rs_toygeom_scenarioA_chunk09_fig69](../../images/demos/rs_toygeom_scenarioA_chunk09_fig69.png)

![rs_toygeom_scenarioA_chunk09_fig70](../../images/demos/rs_toygeom_scenarioA_chunk09_fig70.png)

![rs_toygeom_scenarioA_chunk09_fig71](../../images/demos/rs_toygeom_scenarioA_chunk09_fig71.png)

![rs_toygeom_scenarioA_chunk09_fig72](../../images/demos/rs_toygeom_scenarioA_chunk09_fig72.png)