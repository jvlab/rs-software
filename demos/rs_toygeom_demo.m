% rs_toygeom_demo: demonstrate geometric modeling with toy simulated datasets
%
% set up several stimulus sets: three axes, rings and one axis, axis ends and random
% The stimulus domain has three conceptual coordinates, 'f','g','h'
% They can have values in [-9:1:9].
%
% Shows rings, rays; could use this to illustrate typenames2colors.  
%
% set up several subjects:  affine transformations, with some variation,
% and jitter, in 3d -- create these by xform_apply, (affine) add noise in 4d
%
% simulated data are first n dimensions, but after PCA
%
% with rays and rings, or withouit
%write the files
% frozen random numbers 
% adjustable jitters for transforms and additive noise
%
% then create additional datasets that trnsform these, via piecewise affine or projective
% then model them, show results of modeling statistics, show model fits
%
%  See also:  RS_IMPORT_COORDSETS, RS_DISP_COORDSETS, RS_DISP_ENH_COORDSETS, PSG_TYPENAMES2COLORS, RS_SAVE_FIGS.
%
if ~exist('if_frozen') if_frozen=1; end %set to 0 for random numbers each time, negative integer for fixed alternative seeds
if (if_frozen~=0) 
    rng('default');
    if (if_frozen<0)
        rand(1,abs(if_frozen));
    end
else
    rng('shuffle');
end
%
%define the stimuli
%
paradigm_types='toygeom';
paradigm_names={'Axes','Rings_C12','Rings_C13','Rings23','RandomAndAxisEnds'}; %if this is edited, then change the computation of stimulus sets
coord_labels={'f','g','h'}; %any strings will do
n_coords=length(coord_labels);
sign_chars={'m','z','p'}; %tokens for negative, zero, or positive
axis_samples=[2 4 6 8]; %sample points in each direction along each axis
n_angles=8; %number of sample points in a ring
ring_radii=[4 6 8]; %radii for the rings
n_random=20; %number of random stimuli
random_max=9; %maximum random value
%
%define the simulations:  each subject's perceptual space is a linear transformation of the stimulus coordinates.
%there is noise in the transformation and additive noise
%
if ~exist('n_subjs') n_subjs=3; end
noise_xform=[0.1 0.2 0.2]; %Gaussian jitter for each subject's transformation
noise_add=[0.2 0.1 0.2]; %Gaussian additive noise after transform
xform_base.T=[1.1 0.3 -0.2;-0.4 0.9 -0.1; 0.2 0.5 0.7];
xform_base.c=zeros(1,n_coords);
xform_base.b=1;
%each subject's representation of the conceptual coords 
xforms=cell(1,n_subjs);
for is=1:n_subjs
    noise_subj=+noise_xform(1+mod(is-1,length(noise_xform)));
    xforms{is}.T=xform_base.T+noise_subj*randn(n_coords,n_coords);
    xforms{is}.c=xform_base.c+noise_subj*randn(1,n_coords);
    xforms{is}.b=xform_base.b+noise_subj*randn(1);
end
%
n_paradigms=length(paradigm_names);
sims=struct;
%
%create the conceptual coordinates of the stimulus sets
%
for ip=1:length(paradigm_names)
    paradigm_name=paradigm_names{ip};
    sim=struct;
    switch paradigm_name
        case 'Axes'
            sim.nstims=2*n_coords*length(axis_samples)+1; %bidirectional samples on each axis, and the origin
            sim.type_coords=zeros(sim.nstims,n_coords);
            coord_ptr=0;
            for ic=1:n_coords
                for isamp=1:length(axis_samples)
                    for isign=-1:2:1
                        coord_ptr=coord_ptr+1;
                        sim.type_coords(coord_ptr,ic)=isign*axis_samples(isamp);
                    end
                end
            end
            sim.if_findrays=1;
            sim.if_rings=0;
        case {'Rings_C12','Rings_C13','Rings23'}
            sim.nstims=length(ring_radii)*n_angles+1; %rings in the plane two coords, and the origin
            sim.type_coords=zeros(sim.nstims,n_coords);
            coord_ptr=0;
            if contains(paradigm_name,'C12')
                ring_plane=[1 2];
            elseif contains(paradigm_name,'C13')
                ring_plane=[1 3];
            else
                ring_plane=[2 3];
            end
            angs=2*pi*[0:n_angles-1]'/n_angles;
            for ir=1:length(ring_radii)
                ring_locs=ring_radii(ir)*[cos(angs) sin(angs)];
                sim.type_coords(coord_ptr+[1:n_angles],ring_plane)=ring_locs;
                coord_ptr=coord_ptr+n_angles;
            end
            sim.if_findrays=1;
            sim.if_rings=1;
        case 'RandomAndAxisEnds'
            sim.nstims=2*n_coords+n_random+1; %bidirectional samples at the ends of the axes, random samples, and the origin
            sim.type_coords=zeros(sim.nstims,n_coords);
            random_vals=[[-random_max:-1] [1:random_max]]; %random values avoid the axes;
            %
            [rand_x,rand_y,rand_z]=meshgrid(random_vals);
            rand_xyz=[rand_x(:),rand_y(:),rand_z(:)]; %all distinct points and not on the axes or the origin
            rand_select=randperm(size(rand_xyz,1),n_random);
            sim.type_coords(1:n_random,:)=rand_xyz(rand_select,:);
            %make the samples at the ends of the axes
            coord_ptr=n_random;
            for ic=1:n_coords
                for isign=-1:2:1
                    coord_ptr=coord_ptr+1;
                    sim.type_coords(coord_ptr,ic)=isign*axis_samples(end);
                end
            end
            sim.if_findrays=0;
            sim.if_rings=0;
            clear rand_*
        otherwise
            rs_warning('unrecognized paradigm name',1);
    end
    sims.(paradigm_name)=sim;
end
%
%create the type names, e.g., conceptual coordinate [-3 0 4] -> 'fm3 gz0 hp4'
%and create a simulated dataset in which data coordinates are equal to
%conceptual coordinates
%
ray_opts=struct;
ray_opts.ray_minpts=length(ring_radii); %a point on each ring qualifies as a ray
%
for ip=1:length(paradigm_names)
    paradigm_name=paradigm_names{ip};
    sim=sims.(paradigm_name);
    typenames=cell(sim.nstims,1);
    for istim=1:sim.nstims
        tn=[];
        for ic=1:n_coords
            cval=sim.type_coords(istim,ic);
            tn=cat(2,tn,coord_labels{ic},sign_chars{2+sign(cval)},sprintf('%1.0f',round(abs(cval))),' ');
        end
        typenames{istim}=strtrim(tn);
    end
    sims.(paradigm_name).typenames=typenames;
    %
    aux_stimspace=struct;
    aux_stimspace.opts_import.nstims=sim.nstims;
    aux_stimspace.opts_import.typenames=typenames;
    aux_stimspace.opts_import.type_coords=sim.type_coords;
    aux_stimspace.opts_import.paradigm_type='toygeom';
    aux_stimspace.opts_import.paradigm_name=paradigm_name;
    aux_stimspace.opts_import.subj_id='stimspace';
    aux_stimspace.opts_import.subj_id_short='stims';
    aux_stimspace.opts_import.label_long='conceptual coordinates';
    [sim.data_stimspace,sim.auxout_stimspace]=rs_import_coordsets({[],[],sim.type_coords},aux_stimspace);
    %
    if sim.if_findrays
        sim.rays_stimspace=rs_findrays(sim.data_stimspace.sas{1},[],ray_opts);
    else
        sim.rays_stimspace=struct();
    end
    sims.(paradigm_name)=sim;
end
%
%set up a page for each paradigm, with space for multiple subplots,
%and plot the conceptual coordinates
%
fig_rows=2;
fig_cols=n_subjs+1;
aux_stimdisp=struct;
for ip=1:length(paradigm_names)
    paradigm_name=paradigm_names{ip};
    sim=sims.(paradigm_name);
    %
    figure;
    set(gcf,'Position',[100 100 1400 800]);
    set(gcf,'NumberTitle','off');
    set(gcf,'Name',paradigm_name);
    %
    aux_stimdisp.opts_disp.fig_handle=gcf;
    aux_stimdisp.opts_disp.fig_name=paradigm_name;
    aux_stimdisp.opts_disp.axis_handles={subplot(fig_rows,fig_cols,1)};
    aux_stimdisp.opts_disp.set_labels=sim.data_stimspace.sets{1}.subj_id_short;
    aux_stimdisp.opts_disp.axis_range='list';
    aux_stimdisp.opts_disp.axis_range_list=[-1 1]*(1+random_max);
    aux_stimdisp.opts_disp.callout_amount=0.3;
    aux_stimdisp.opts_disp.axis_labels=coord_labels;
    %
    if sim.if_findrays
        aux_stimdisp.opts_disp_enh.if_rings=sim.if_rings;
        sim.auxout_stimdisp=rs_disp_enh_coordsets(sim.data_stimspace,aux_stimdisp,sim.rays_stimspace);
    else
        aux_stimdisp.opts_disp.data_label_method='list';
        aux_stimdisp.opts_disp.data_label_list=find(contains(sim.data_stimspace.sas{1}.typenames,'z0')); %label only the on-axis points
        sim.auxout_stimdisp=rs_disp_coordsets(sim.data_stimspace,aux_stimdisp);
    end
    sims.(paradigm_name)=sim;
end

%next is to apply the transformation and plot
% [data_out,aux_out]=rs_xform_apply(data_in,xforms,aux) applies transformation(s) to datasets
%
% These transformations all preserve the number of dimensions, and consist of a linear transformaton followed by a rotation
% The transformation is typically specified by rs_xform_specify, in which case the linear component (in ts.orthog) is guaranteed to be 
%   orthogonal, but this will also work if the linear component is not orthogonal
%
% data_in.ds{k},sas{k},sets{k}: the structures of coordinates (ds) and metadata (sas,sets)
%   Stimuli should be identical across datasets
% xforms: typically an output structure from rs_xform_specify
%   xforms.ts{k}{idim} are the transformations to be applied to dataset k, dimension idim
%     if length(xforms.ts)<length(data_in), transformations are used in cyclic order
%     if any of xforms.ts{k}{:} are missing, then the original data from coords is passed through unchanged
%   xforms.pipeline is a structure that can serve as a subfield for sets, when the transformations are applied
% aux: auxiliary inputs
%  aux.opts_xform.if_warn: 1 (default) to show warnings
%  aux.opts_xform.if_gen: 0 (default) for a transformation specified by rs_xforms_apply
%                         1 for a general transformation, for future use 
%  aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency

