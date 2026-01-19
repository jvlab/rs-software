% rs_toygeom_demo: demonstrate geometric modeling with toy simulated datasets
%
% Creates several stimulus sets ('paradigm types'): three axes, rings, axis ends and random
% The stimulus domain has ncoords coordinates, 'a','b','c',..., which can have values in [-9:9].
% This is stimspace.
%
% Considers ntransforms transformations:  null, procrustes (rotation with inversion), affine (with offset)
% Applies each of these to the coordinate sets.  This is xformspace.
%
% Sets up nsubjs subjects.  Each applies a jittered version of the transformations, and also adds noise,
% and optionally adds extra dimensions (ncoords_noise) that are just noise. This is dataspace.
% 
% Main data structures in sims.(paradigm_name)
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
%  RS_DISP_ENH_COORDSETS, RS_XFORM_APPLY, RS_CONCAT_DATASETS
%  PSG_GEO_TRANSFORMS_GETC.
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
transform_names_avail={'null','procrustes','affine','projective','pwaffine'};
transform_classes_avail={'affine','affine','affine','projective','pwaffine'};
%
if ~exist('transforms_use_list') transforms_use_list=[1:5];end
for itptr=1:length(transforms_use_list)
    transform_names{itptr}=transform_names_avail{transforms_use_list(itptr)};
    transform_classes{itptr}=transform_classes_avail{transforms_use_list(itptr)};
end
%
ntransforms=length(transform_names);
if ~exist('affine_mag') affine_mag=0.5; end %magnitude of distortion in affine transforms
if ~exist('projective_mag') projective_mag=0.03; end %controls amount of distortion in projective transform
if ~exist('pwaffine_mag') pwaffine_mag=0.5; end %controls difference in linear transforms of piecewise affine
%
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
T=(1-affine_mag)*eye(ncoords)+affine_mag*randn(ncoords,ncoords); %mix the identity with a random matrix
transforms.affine.T=T/sqrt(max(eig(T'*T))); %limit the max dilation to keep in range
transforms.affine.b=1;
transforms.affine.c=affine_mag*randn(1,ncoords);
%
transforms.projective=transforms.affine;
transforms.projective.p=projective_mag*randn(ncoords,1);
%
transforms.pwaffine=transforms.affine;
%params needed to ensure continuity across boundary
ncuts=1; %just one cut
transforms.pwaffine.tdif=randn(1,ncoords);
vcut=randn(1,ncoords);
vcut=vcut./sqrt(vcut*vcut');
transforms.pwaffine.vcut=vcut./sqrt(vcut*vcut'); %a random normalized vector
T1=transforms.affine.T;
T2=T1+vcut'*transforms.pwaffine.tdif;
transforms.pwaffine.T=cat(3,T1,T2);
transforms.pwaffine.b=1;
transforms.pwaffine.acut=randn(1); %random cutpoint
transforms.pwaffine.cadd=randn(1,ncoords); %random offset so that cutpoint does not get mapped to zero
transforms.pwaffine.c=repmat(transforms.pwaffine.cadd,2^ncuts,1)+...
    psg_geo_transforms_getc(ncoords,transforms.pwaffine.T,transforms.pwaffine.vcut,transforms.pwaffine.acut); %find c so that transforms agree on cutpoint
%
disp(sprintf(' %2.0f transforms set up, on %3.0f coordinates.',ntransforms,ncoords));
%
%define the number of subjects and levels of noise for each
%
if ~exist('nsubjs') nsubjs=4; end
if ~exist('subjs_disp') subjs_disp=unique([1,nsubjs]); end %which subjects to show
if ~exist('noise_transform_mag') noise_transform_mag=0.1; end %range of Gaussian jitter for each subject's transformation 
noise_transform=noise_transform_mag*[0:nsubjs-1]/nsubjs; %sugbjects have increasing amounts of noise
if ~exist('noise_add_mag') noise_add_mag=0.1; end %range of additive Gaussian noise for each subject
noise_add_base=noise_add_mag*[1 2]; %subjects alternate in amount of additive noise
noise_add=noise_add_base(1+mod(0:nsubjs-1,2));
%create the transformed parameters corrupted by transform noise
transforms_noisy=cell(1,nsubjs);
for it=1:ntransforms
    transform=transforms.(transform_names{it});
    fns=fieldnames(transform);
    for is=1:nsubjs
         for ifn=1:length(fns)
            if strcmp(fns{ifn},'p')
                noise_param_mult=projective_mag;
            else
                noise_param_mult=1;
            end
            transforms_noisy{is}.(transform_names{it}).(fns{ifn})=transform.(fns{ifn})+noise_param_mult*noise_transform(is)*randn(size(transform.(fns{ifn})));
        end %fn
        %adjustments for pwaffine to ensure continuity at boundary       
        if strcmp(transform_names{it},'pwaffine')
            vcut_noisy=transforms_noisy{is}.pwaffine.vcut;
            acut_noisy=transforms_noisy{is}.pwaffine.acut;
            tdif_noisy=transforms_noisy{is}.pwaffine.tdif;
            cadd_noisy=transforms_noisy{is}.pwaffine.cadd;
            vcut_noisy=vcut_noisy./sqrt(vcut_noisy*vcut_noisy');
            T1=transforms_noisy{is}.pwaffine.T(:,:,1);
            T2=T1+vcut_noisy'*tdif_noisy;
            %
            transforms_noisy{is}.T=cat(3,T1,T2);
            transforms_noisy{is}.pwaffine.vcut=vcut_noisy;
            transforms_noisy{is}.pwaffine.c=repmat(cadd_noisy,2^ncuts,1)+...
                psg_geo_transforms_getc(ncoords,transforms_noisy{is}.pwaffine.T,vcut_noisy,acut_noisy); %find c so that transforms agree on cutpoint
        end %pwaffine
    end %is
end %it
disp(sprintf('jittered transformations created for %2.0f subjects',nsubjs));
%
%create the conceptual coordinates of the stimulus sets
%
nparadigms=length(paradigm_names);
sims=struct;
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
    disp(sprintf('coordinate sets created for paradigm %s',paradigm_name));
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
        disp(sprintf('ray structure created for paradigm %s',paradigm_name));
    else
        sim.stimspace_rays=struct();
        disp(sprintf('ray structure skipped for paradigm %s',paradigm_name));
    end
    sims.(paradigm_name)=sim;
end
%
%set up a page for each paradigm, with space for multiple subplots,
%and plot the conceptual coordinates
%
fig_rows=length(subjs_disp)+1; %show 
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
    aux_stimdisp.opts_disp.legend_location='North';
    for it=1:ntransforms
        transform_name=transform_names{it};
        xforms=struct;
        xforms.ts{1}{ncoords}=transforms.(transform_name);
        %
        opts_xform=struct;
        opts_xform.class=transform_classes{it};
        xformspace=rs_xform_apply(sim.stimspace,xforms,setfield(struct,'opts_xform',opts_xform));
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
            sim.xformspace_disp_auxout.(transform_name)=rs_disp_enh_coordsets(xformspace,aux_stimdisp,sim.stimspace_rays);
        else
            aux_stimdisp.opts_disp.data_label_method='list';
            aux_stimdisp.opts_disp.data_label_list=find(~contains(sim.stimspace.sas{1}.typenames,' ')); %label only the on-axis points (off-axis point names all have blanks)
            sim.xformspace_disp_auxout.(transform_name)=rs_disp_coordsets(xformspace,aux_stimdisp);
        end
        sim.xformspace.(transform_name)=xformspace;
    end %it: transforms
    sims.(paradigm_name)=sim;
end
%
% apply each subject's transform to the stimuli in each stimulus set, and plot
%
for ip=1:length(paradigm_names)
    paradigm_name=paradigm_names{ip};
    sim=sims.(paradigm_name);
    %
    for it=1:ntransforms
        transform_name=transform_names{it};
        xform_subj=cell(1,nsubjs);
        for is=1:nsubjs
            xforms=struct;
            xforms.ts{1}{ncoords}=transforms_noisy{is}.(transform_name);
            opts_xform=struct;
            opts_xform.class=transform_classes{it};
            xform_subj{is}=rs_xform_apply(sim.stimspace,xforms,setfield(struct,'opts_xform',opts_xform));
            %fill in lower and higher dimensions and add noise
            for ic=1:ncoords_tot
                xform_subj{is}.ds{1}{ic}=noise_add(is)*randn(sim.nstims,ic)+...
                    [xform_subj{is}.ds{1}{ncoords}(:,1:min(ic,ncoords)),zeros(sim.nstims,max(0,ic-ncoords))];
            end
            %adjust metadata
            sets=xform_subj{is}.sets{1};
            sets.dim_list=[1:ncoords_tot]; %since we added lower and higher dimensions
            sets.subj_id=sprintf('%s%s','subject ',zpad(is,2));
            sets.subj_id_short=sprintf('%s%s','s',zpad(is,2));
            sets.label_long=sprintf('simulation: %s',transform_names{it});
            sets.label=transform_names{it};
            xform_subj{is}.sets{1}=sets;
        end
        %concatenate datasets aross subjects
        dataspace=xform_subj{1};
        for is=2:nsubjs
            dataspace=rs_concat_coordsets(dataspace,xform_subj{is});
        end
        sim.dataspace.(transform_name)=dataspace;
        %plot
        aux_datadisp=struct;
        for is_ptr=1:length(subjs_disp)
            is=subjs_disp(is_ptr);
            aux_datadisp.opts_disp=sim.xformspace_disp_auxout.(transform_name).opts_disp; %starting point for plot is how the transforms were plotted
            aux_datadisp.opts_disp=rmfield(aux_datadisp.opts_disp,'axis_labels'); %use default labels
            aux_datadisp.opts_disp=rmfield(aux_datadisp.opts_disp,'set_labels');; %use defaults
            aux_datadisp.opts_disp.set_select=is; %just show this subject
            aux_datadisp.opts_disp.set_colors={'k'}; %black
            %
            figure(aux_datadisp.opts_disp.fig_handle); %activate the figure for this paradigm type
            aux_datadisp.opts_disp.axis_handles={subplot(fig_rows,fig_cols,it+is_ptr*fig_cols)}; %show each transform in a separate column
            %
            if sim.if_findrays %setups for which points to label, etc, are inherited from sim.xformspace_disp_auxout
                aux_datadisp.opts_disp_enh=sim.xformspace_disp_auxout.(transform_name).opts_disp_enh; %had if_rings info
                sim.dataspace_disp_auxout.(transform_name){is}=rs_disp_enh_coordsets(dataspace,aux_datadisp,sim.stimspace_rays);
            else
                sim.dataspace_disp_auxout.(transform_name){is}=rs_disp_coordsets(dataspace,aux_datadisp);
            end
         end %is
         disp(sprintf('dataspace created for paradigm %20s and transform %s',paradigm_name,transform_name));
    end %it
    sims.(paradigm_name)=sim;
end
