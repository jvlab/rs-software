% rs_toygeom_demo: demonstrate geometric modeling with toy simulated datasets
%
% set up several stimulus sets: three axes, rings and one axis, axis ends and random
% The stimulus domain has three conceptual coordinates, 'f','g','h'
% They can have values in [-9:1:9].
%
% Shows rings, rays; could use this to illustrate typenames2colors.  
%
% sets up several subjects:  affine transformations, with some variation,
% and jitter, in 3d -- create these by xform_apply, (affine) add noise in 4d
%
% simulated data are first n dimensions
% 
% ??? apply pca to those 
%
% with rays and rings, or withouit
%write the files
% frozen random numbers 
% adjustable jitters for transforms and additive noise
% maybe illustrate
% PSG_TYPENAMES2COLORS, RS_SAVE_FIGS.
%
%
% then create additional datasets that trnsform these, via piecewise affine or projective
% then model them, show results of modeling statistics, show model fits
%
%  See also:  RS_IMPORT_COORDSETS, RS_DISP_COORDSETS,
%  RS_DISP_ENH_COORDSETS, RS_XFORM_APPLY, RS_CONCAT_DATASETS.
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
if ~exist('ncoords') ncoords=3; end %can be modified to larger than 3
ncoords=max(3,ncoords);
%
paradigm_types='toygeom';
paradigm_names={'Axes','Rings_C12','Rings_C13','Rings_C23','RandomAndAxisEnds'}; %if this is edited, then change the computation of stimulus sets
coord_labels=cell(1,ncoords);
for ic=1:ncoords
    coord_labels{ic}=char('a'+ic-1);
end
sign_chars={'m','z','p'}; %tokens for negative, zero, or positive
axis_samples=[2 4 6 8]; %sample points in each direction along each axis
nangles=8; %number of sample points in a ring
ring_radii=[4 6 8]; %radii for the rings
nrandom=20; %number of random stimuli
random_max=9; %maximum random value
%
%define the simulations: several transformations of the stimulus space, of dimension ncoords
%
if ~exist('ncoords_noise') ncoords_noise=2; end %simulations can have added noise on additional coordinates
ncoords_tot=ncoords+ncoords_noise;
%
transform_names={'null','procrustes','affine'};
%null transformation
transforms.null.T=eye(ncoords);
transforms.null.b=1;
transforms.null.c=zeros(1,ncoords);
%
transforms.procrustes.T=eye(ncoords);
transforms.procrustes.T(1,1)=-1; %invert
for ic=1:ncoords-1
    for jc=ic+1:ncoords
        ang=2*pi*rand(1);
        rot=zeros(ncoords);
        rot([ic jc],[ic jc])=[cos(ang) sin(ang);-sin(ang) cos(ang)];
        roteye=setdiff(1:ncoords,[ic jc]);
        rot(roteye,roteye)=eye(ncoords-2);
        transforms.procrustes.T=transforms.procrustes.T*rot;
    end
end
transforms.procrustes.b=1;
transforms.procrustes.c=zeros(1,ncoords);
%
if ~exist('affine_mag') affine_mag=0.5; end %magnitude of distortion in affine transforms
T=(1-affine_mag)*eye(ncoords)+affine_mag*randn(ncoords,ncoords); %mix the identity with a random matrix
transforms.affine.T=T/sqrt(max(eig(T'*T))); %limit the max dilation to keep in range
transforms.affine.b=1;
transforms.affine.c=affine_mag*randn(1,ncoords);
ntransforms=length(transform_names);
%
%define the subjects
%
if ~exist('nsubjs') nsubjs=4; end
if ~exist('subjs_show') subjs_show=unique([1,nsubjs]); end %which subjects to show
if ~exist('noise_transform_mag') noise_transform_mag=0.1; end %range of Gaussian jitter for each subject's transformation 
noise_transform=noise_transform_mag*[0:nsubjs-1]/nsubjs; %sugbjects have increasing amounts of noise
if ~exist('noise_add_mag') noise_add_mag=0.1; end %rande of additive Gaussian noise for each subject
noise_add=noise_add_mag*[1 2]; %subjects alternate in amount of additive noise
%
nparadigms=length(paradigm_names);
sims=struct;
%
%create the conceptual coordinates of the stimulus sets
%
for ip=1:length(paradigm_names)
    paradigm_name=paradigm_names{ip};
    sim=struct;
    switch paradigm_name
        case 'Axes'
            sim.nstims=2*ncoords*length(axis_samples)+1; %bidirectional samples on each axis, and the origin
            sim.type_coords=zeros(sim.nstims,ncoords);
            coord_ptr=0;
            for ic=1:ncoords
                for isamp=1:length(axis_samples)
                    for isign=-1:2:1
                        coord_ptr=coord_ptr+1;
                        sim.type_coords(coord_ptr,ic)=isign*axis_samples(isamp);
                    end
                end
            end
            sim.if_findrays=1;
            sim.if_rings=0;
        case {'Rings_C12','Rings_C13','Rings_C23'}
            sim.nstims=length(ring_radii)*nangles+1; %rings in the plane two coords, and the origin
            sim.type_coords=zeros(sim.nstims,ncoords);
            coord_ptr=0;
            if contains(paradigm_name,'C12')
                ring_plane=[1 2];
            elseif contains(paradigm_name,'C13')
                ring_plane=[1 3];
            else
                ring_plane=[2 3];
            end
            angs=2*pi*[0:nangles-1]'/nangles;
            for ir=1:length(ring_radii)
                ring_locs=ring_radii(ir)*[cos(angs) sin(angs)];
                sim.type_coords(coord_ptr+[1:nangles],ring_plane)=ring_locs;
                coord_ptr=coord_ptr+nangles;
            end
            sim.if_findrays=1;
            sim.if_rings=1;
        case 'RandomAndAxisEnds'
            sim.nstims=2*ncoords+nrandom+1; %bidirectional samples at the ends of the axes, random samples, and the origin
            sim.type_coords=zeros(sim.nstims,ncoords);
            random_vals=[[-random_max:-1] [1:random_max]]; %random values avoid the axes;
            rand_samps=ceil(2*random_max*rand(nrandom,ncoords));
            sim.type_coords(1:nrandom,:)=random_vals(rand_samps);
            %make the samples at the ends of the axes
            coord_ptr=nrandom;
            for ic=1:ncoords
                for isign=-1:2:1
                    coord_ptr=coord_ptr+1;
                    sim.type_coords(coord_ptr,ic)=isign*axis_samples(end);
                end
            end
            sim.if_findrays=0;
            sim.if_rings=0;
        otherwise
            rs_warning('unrecognized paradigm name',1);
    end
    sims.(paradigm_name)=sim;
end
%
%create the type names, e.g., conceptual coordinate [-3 0 4] -> 'am3 cp4'
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
        tn=' ';
        for ic=1:ncoords
            cval=sim.type_coords(istim,ic);
            if abs(cval)>0.5 %omit zeros from stimulus names to shorten them
                tn=cat(2,tn,coord_labels{ic},sign_chars{2+sign(cval)},sprintf('%1.0f',round(abs(cval))),' ');
            end
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
    import_coords=cell(1,ncoords);
    for ic=1:ncoords
        import_coords{ic}=sim.type_coords(:,1:ic);
    end
    [sim.stimspace,sim.stimspace_import_auxout]=rs_import_coordsets(import_coords,aux_stimspace);
    %
    if sim.if_findrays
        [sim.stimspace_rays,wmsg,sim.stimspace_findrays_auxout]=rs_findrays(sim.stimspace.sas{1},[],ray_opts);
    else
        sim.stimspace_rays=struct();
    end
    sims.(paradigm_name)=sim;
end
%
%set up a page for each paradigm, with space for multiple subplots,
%and plot the conceptual coordinates
%
fig_rows=length(subjs_show)+1; %show 
fig_cols=ntransforms;
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
    aux_stimdisp.opts_disp.axis_range='list';
    aux_stimdisp.opts_disp.axis_range_list=[-1 1]*(1+random_max);
    aux_stimdisp.opts_disp.callout_amount=0.3;
    aux_stimdisp.opts_disp.axis_labels=coord_labels;
    for it=1:ntransforms
        %
        transform_name=transform_names{it};
        xforms=struct;
        xforms.ts{1}{ncoords}=transforms.(transform_name);
        %
        xformspace=rs_xform_apply(sim.stimspace,xforms);
        %fill in lower and higher dimensions
        for ic=1:ncoords_tot
            xformspace.ds{1}{ic}=[xformspace.ds{1}{ncoords}(:,1:min(ic,ncoords)),zeros(sim.nstims,max(0,ic-ncoords))];
        end
        %adjust metadata
        xformspace.sets{1}.dim_list=[1:ncoords_tot];
        aux_stimdisp.opts_disp.set_labels=cat(2,'stims ',transform_name);
        aux_stimdisp.opts_disp.axis_handles={subplot(fig_rows,fig_cols,it)}; %show each transform in a separate column
        if sim.if_findrays
            aux_stimdisp.opts_disp_enh.if_rings=sim.if_rings;
            sim.xformspace_disp_auxout=rs_disp_enh_coordsets(xformspace,aux_stimdisp,sim.stimspace_rays);
        else
            aux_stimdisp.opts_disp.data_label_method='list';
            aux_stimdisp.opts_disp.data_label_list=find(~contains(sim.stimspace.sas{1}.typenames,' ')); %label only the on-axis points (off-axis point names all have blanks)
            sim.xformspace_disp_auxout=rs_disp_coordsets(xformspace,aux_stimdisp);
        end
        sim.xformspace.(transform_name)=xformspace;
    end %it: transforms
    sims.(paradigm_name)=sim;
end
%
% apply each subject's transform to the stimuli in each stimulus set
%
for ip=1:length(paradigm_names)
    paradigm_name=paradigm_names{ip};
    sim=sims.(paradigm_name);
    %
    data_xform_eachsubj=cell(1,nsubjs);
    for is=1:nsubjs
        xforms=struct;
        xforms.ts{1}{ncoords}=xforms_subj{is};
        data_xform_eachsubj{is}=rs_xform_apply(sim.stimspace,xforms);
        %add noise, and fill in lower and higher dimensions
        noise_subj=noise_add(1+mod(is-1,length(noise_add)));
        data_nonoise=data_xform_eachsubj{is}.ds{1}{ncoords};
        for ic=1:ncoords_tot
            if ic<=ncoords
                data_xform_eachsubj{is}.ds{1}{ic}=data_nonoise(:,[1:ic])+noise_subj*randn(sim.nstims,ic);
            else
                data_xform_eachsubj{is}.ds{1}{ic}=[data_nonoise,zeros(sim.nstims,ic-ncoords)]+noise_subj*randn(sim.nstims,ic);
            end
        end
        %adjust metadata
        sets=data_xform_eachsubj{is}.sets{1};
        sets.dim_list=[1:ncoords_tot]; %since we added lower and higher dimensions
        sets.subj_id=sprintf('%s%s','subject ',zpad(is,2));
        sets.subj_id_short=sprintf('%s%s','s',zpad(is,2));
        sets.label_long=sprintf('simulation: affine transform');
        sets.label='affine';
        data_xform_eachsubj{is}.sets{1}=sets;
    end
    %concatenate datasets aross subjects
    data_xform_allsubjs=data_xform_eachsubj{1};
    for is=2:nsubjs
        data_xform_allsubjs=rs_concat_coordsets(data_xform_allsubjs,data_xform_eachsubj{is});
    end
    sim.data_xform_eachsubj=data_xform_eachsubj;
    sim.data_xform_allsubjs=data_xform_allsubjs;
    sims.(paradigm_name)=sim;
end

%next is to apply the transformation and plot
% [data_out,aux_out]=rs_xform_apply(data_in,xforms,aux) applies transformation(s) to datasets
%
% 
% xforms=cell(1,n_subjs);
% for is=1:n_subjs
%     noise_subj=+noise_xform(1+mod(is-1,length(noise_xform)));
%     xforms{is}.T=xform_base.T+noise_subj*randn(ncoords,ncoords);
%     xforms{is}.c=xform_base.c+noise_subj*randn(1,ncoords);
%     xforms{is}.b=xform_base.b+noise_subj*randn(1);
% end

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

