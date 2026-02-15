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
% Key params can be configured by running rs_toygeom_scenario*.m first
%
% adjustable jitters for transforms and additive noise
% maybe illustrate PSG_TYPENAMES2COLORS, RS_SAVE_FIGS.
%
% then create additional datasets that trnsform these, via piecewise affine or projective
% then model them, show results of modeling statistics, show model fits
%
%  See also:  RS_IMPORT_COORDSETS, RS_DISP_COORDSETS, RS_DISP_GEOFIT,
%  RS_DISP_ENH_COORDSETS, RS_XFORM_APPLY, RS_CONCAT_DATASETS, RS_EXTRACT_COORDSETS.
%
%these are the main parameters that may be edited, or have values set before running
%
if ~exist('paradigm_names') paradigm_names={'Axes','Rings_C12','Rings_C13','Rings_C23','RandomAndAxisEnds'}; end %some may be deleted
if ~exist('transform_names') transform_names={'null','procrustes','affine','projective','pwaffine'}; end %some may be deleted
if ~exist('affine_mag') affine_mag=0.5; end %magnitude of distortion in affine transforms
if ~exist('projective_mag') projective_mag=0.03; end %controls amount of distortion in projective transform
if ~exist('pwaffine_mag') pwaffine_mag=0.25; end %controls difference in linear transforms of piecewise affine
%
if ~exist('ncoords') ncoords=3; end %number of coordinates in stimulus set, should be at least 3
if ~exist('ncoords_noise') ncoords_noise=2; end %simulations can have noise on additional coordinates
if ~exist('noise_transform_mag') noise_transform_mag=0.1; end %range of Gaussian jitter for each subject's transformation 
if ~exist('noise_add_mag') noise_add_mag=0.1; end %range of additive Gaussian noise for each subject
%
if ~exist('nsubjs') nsubjs=4; end % number of subjects to simulate; at least 1; subjects have progressively more noise
if ~exist('subjs_disp') subjs_disp=unique([1,nsubjs]); end %which subjects to show in plots
%
if ~exist('if_plots') if_plots=1; end %set to 0 to suppress plots
if ~exist('if_frozen') if_frozen=1; end %set to 0 for random numbers each time, negative integer for fixed alternative seeds
%
if (if_frozen~=0) 
    rng('default');
    if (if_frozen<0)
        rand(1,abs(if_frozen));
    end
else
    rng('shuffle');
end
%define the coordinates
ncoords=max(3,ncoords);
coord_labels=cell(1,ncoords);
for ic=1:ncoords
    coord_labels{ic}=char('a'+ic-1);
end
ncoords_tot=ncoords+ncoords_noise;
%
%define the paradigm (stimulus choices within each paradigm)
%
paradigm_type='toygeom';
%
axis_samples=[2 4 6 8]; %sample points in each direction along each axis
nangles=8; %number of sample points in a ring
ring_radii=[4 6 8]; %radii for the rings
nrandom=16; %number of random stimuli
random_max=9; %maximum random value; plotted range will be [-1,1]*(random_max+1)
%
%define the simulations: several transformations of the stimulus space, of dimension ncoords
%
transform_names_avail={'null','procrustes','affine','projective','pwaffine'};
ntransforms=length(transform_names);
transform_class_table=struct;
transform_class_table.null='affine';
transform_class_table.procrustes='affine';
transform_class_table.affine='affine';
transform_class_table.projective='projective';
transform_class_table.pwaffine='pwaffine';
for it=1:ntransforms
    transform_classes{it}=transform_class_table.(transform_names{it});
end
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
%construct by adding a linear transformation to a rectification
%params needed to ensure continuity across boundary
pw_vcut=randn(1,ncoords);
pw_vcut=pw_vcut./sqrt(pw_vcut*pw_vcut'); %random direction of unit normal to cutplane
pw_acut=randn(1); %random offset
pw_h=randn(1,ncoords); %the output of the rectification
%the cutplane is x*pw_cut'=pw_acut.  
Tcut=pw_vcut'*pw_h; %if x*pw_vcut'=pw_acut, then x*Tcut=a*pw_h,so x*Tcut-pw_acut*pw_h is zero on the boundary
transforms.pwaffine.T=repmat((1-pwaffine_mag)*transforms.affine.T,[1 1 2])+pwaffine_mag*cat(3,Tcut,-Tcut);
transforms.pwaffine.c_off=randn(1,ncoords);
transforms.pwaffine.c=pwaffine_mag*pw_acut*[-pw_h;pw_h]+repmat(transforms.pwaffine.c_off,2,1);
transforms.pwaffine.b=1;
transforms.pwaffine.acut=pw_acut;
transforms.pwaffine.vcut=pw_vcut;
transforms.pwaffine.h=pw_h;
%
disp(sprintf(' %2.0f transforms set up, on %3.0f coordinates.',ntransforms,ncoords));
%
%define the number of subjects and levels of noise for each
%
noise_transform=noise_transform_mag*[0:nsubjs-1]/nsubjs; %sugbjects have increasing amounts of noise
noise_add_base=noise_add_mag*[1 2]; %subjects alternate in amount of additive noise
noise_add=noise_add_base(1+mod(0:nsubjs-1,2));
%
%create the transformations for each subject by corrupting the parameters of the basic transforms by noise
%note that all transforms are treatd, even if they won't be used, since some transforms are dependent on others
%
transforms_noisy=cell(1,nsubjs);
for it=1:length(transform_names_avail)
    transform_name=transform_names_avail{it};
    transform=transforms.(transform_name);
    fns=fieldnames(transform);
    for is=1:nsubjs
         for ifn=1:length(fns)
            if strcmp(fns{ifn},'p')
                noise_param_mult=projective_mag;
            else
                noise_param_mult=1;
            end
            transforms_noisy{is}.(transform_name).(fns{ifn})=transform.(fns{ifn})+noise_param_mult*noise_transform(is)*randn(size(transform.(fns{ifn})));
        end %fn
        transforms_noisy{is}.(transform_name).b=1; %scale factor unchanged; redundant with T and it will disrupt pwaffine contiunity
        %adjustments for pwaffine to ensure continuity at boundary       
        if strcmp(transform_name,'pwaffine')
            pw_vcut=transforms_noisy{is}.pwaffine.vcut;
            pw_acut=transforms_noisy{is}.pwaffine.acut;
            pw_h=transforms_noisy{is}.pwaffine.h;
            %
            pw_vcut=pw_vcut./sqrt(pw_vcut*pw_vcut'); %random direction of unit normal to cutplane
            Tcut=pw_vcut'*pw_h; %if x*pw_vcut'=pw_acut, then x*Tcut=a*pw_h
            transforms_noisy{is}.pwaffine.T=repmat((1-pwaffine_mag)*transforms_noisy{is}.affine.T,[1 1 2])+pwaffine_mag*cat(3,Tcut,-Tcut);
            transforms_noisy{is}.pwaffine.c=pwaffine_mag*pw_acut*[-pw_h;pw_h]+repmat(transforms_noisy{is}.pwaffine.c_off,2,1);
            transforms_noisy{is}.pwaffine.vcut=pw_vcut;
        end %pwaffine
    end %is
end %it
disp(sprintf('jittered transformations created for %2.0f subjects',nsubjs));
%
%define the coordinates of the stimulus sets
%
nparadigms=length(paradigm_names);
sims=struct;
sign_chars={'m','z','p'}; %tokens for negative, zero, or positive
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
    aux_stimspace.opts_import.paradigm_type=paradigm_type;
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
    if if_plots
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
    end
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
        if if_plots
            aux_stimdisp.opts_disp.set_labels=cat(2,'stims ',transform_name);
            aux_stimdisp.opts_disp.axis_handles={subplot(fig_rows,fig_cols,it)}; %show each transform in a separate column
            %
            if sim.if_findrays
                aux_stimdisp.opts_disp_enh.if_rings=sim.if_rings;
                aux_stimdisp.opts_disp_enh.if_points=1; %so legends are set labels
                aux_stimdisp.opts_disp.data_show_method='last'; %last point is random; plotting a point allows rs_disp_enh_coordsets to make simple legend
                sim.xformspace_disp_auxout.(transform_name)=rs_disp_enh_coordsets(xformspace,aux_stimdisp,sim.stimspace_rays);
            else
                aux_stimdisp.opts_disp.data_show_method='all'; 
                aux_stimdisp.opts_disp.data_label_method='list';
                aux_stimdisp.opts_disp.data_label_list=find(~contains(sim.stimspace.sas{1}.typenames,' ')); %label only the on-axis points (off-axis point names all have blanks)
                sim.xformspace_disp_auxout.(transform_name)=rs_disp_coordsets(xformspace,aux_stimdisp);
            end
        end
        sim.xformspace.(transform_name)=xformspace;
    end %it: transforms
    sims.(paradigm_name)=sim;
end
%
% apply each subject's transform to the stimuli in each stimulus set, and display
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
        if if_plots
            for is_ptr=1:length(subjs_disp)
                is=subjs_disp(is_ptr);
                aux_datadisp.opts_disp=sim.xformspace_disp_auxout.(transform_name).opts_disp; %starting point for plot is how the transforms were plotted
                aux_datadisp.opts_disp=rmfield(aux_datadisp.opts_disp,'axis_labels'); %use default labels
                aux_datadisp.opts_disp.set_labels=sprintf('subj %1.0f',is);
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
         end
         disp(sprintf('dataspace created for paradigm %20s and transform %s',paradigm_name,transform_name));
    end %it
    sims.(paradigm_name)=sim;
end
%
%align and knit the stimuli across paradigms
%
check_nowarn=setfield(struct,'opts_check',setfield(struct,'if_warn',0));
sims.knitted=struct;
aux_align=struct;
aux_align.opts_align.if_log=0;
aux_knit=struct;
aux_knit.opts_knit.if_log=0;
%
disp(' ');
for ip=1:length(paradigm_names)
    paradigm_name=paradigm_names{ip};
    stim_data=sims.(paradigm_name).stimspace;
    if ip==1
        concat=stim_data;
    else
        concat=rs_concat_coordsets(concat,stim_data,check_nowarn);
    end
end
disp('aligning stimuli across paradigms');
aligned=rs_align_coordsets(concat,aux_align);
disp('knitting data across paradigms');
knitted=rs_knit_coordsets(aligned,aux_knit);
sims.knitted.stimspace=knitted;
%
%for each transformation, align and knit the transformed space across paradigms
%
sims.knitted.xformspace=struct();
for it=1:ntransforms
    transform_name=transform_names{it};
    for ip=1:length(paradigm_names)
        paradigm_name=paradigm_names{ip};
        xform_data=sims.(paradigm_name).xformspace.(transform_name);
        if ip==1
            concat=xform_data;
        else
            concat=rs_concat_coordsets(concat,xform_data,check_nowarn);
        end
    end
    disp(' ');
    disp(sprintf('aligning transform %s across paradigms',transform_name))
    aligned=rs_align_coordsets(concat,aux_align);
    disp(sprintf('knitting data from transform %s across paradigms',transform_name))
    knitted=rs_knit_coordsets(aligned,aux_knit);
    sims.knitted.xformspace.(transform_name)=knitted;
end
%
%for each transformation and subject, align and knit the data across paradigms
%
sims.knitted.dataspace=struct();
for it=1:ntransforms
    transform_name=transform_names{it};
    concat_knitted=struct;
    for is=1:nsubjs
        concat=struct;
        for ip=1:length(paradigm_names)
            paradigm_name=paradigm_names{ip};
            subj_data=rs_extract_coordsets(sims.(paradigm_name).dataspace.(transform_name),is); %extract this subject's data
            if ip==1
                concat=subj_data;
            else
                concat=rs_concat_coordsets(concat,subj_data,check_nowarn);
            end
        end
        disp(' ');
        disp(sprintf('aligning data from subject %1.0f, transform %s, across paradigms',is,transform_name))
        aligned=rs_align_coordsets(concat,aux_align);
        disp(sprintf('knitting data from subject %1.0f, transform %s, into a single dataset',is,transform_name))
        knitted=rs_knit_coordsets(aligned,aux_knit);
        if is==1
            concat_knitted=knitted;
        else
            concat_knitted=rs_concat_coordsets(concat_knitted,knitted);
        end
    end
    sims.knitted.dataspace.(transform_name)=concat_knitted;
end
%
%fit models to transformation between stimulus space and data space
%
paradigms_all=fieldnames(sims); %includes original paradigms and knitted
if ~exist('opts_geof') opts_geof=struct; end
aux_geof.opts_geof=struct;
opts_geof=filldefault(opts_geof,'model_list',{'procrustes_scale_offset','affine_offset','projective','pwaffine'});
opts_geof=filldefault(opts_geof,'dimpairs_method','all');
opts_geof=filldefault(opts_geof,'if_stats',1);
opts_geof=filldefault(opts_geof,'nshuffs',20);
opts_geof=filldefault(opts_geof,'if_nestbymodel',-1);
opts_geof=filldefault(opts_geof,'if_nestbydim',-1);
opts_geof=filldefault(opts_geof,'if_log',0);
opts_geof=filldefault(opts_geof,'if_fit_summary',0);
aux_geof=struct;
aux_geof.opts_geof=opts_geof;
%
if ~exist('if_disp_geofit') if_disp_geofit=0; end
if ~exist('opts_dgeo') opts_dgeo=struct; end
aux_dgeo=struct;
aux_dgeo.opts_dgeo=opts_dgeo;
%
gfs=cell(ntransforms,length(paradigms_all));
aux_geof_out=cell(ntransforms,length(paradigms_all));
if ~exist('transforms_fit_show') transforms_fit_show=transform_names; end
if ~exist('paradigms_fit_show') paradigms_fit_show=paradigms_all; end
if ~exist('subjs_fit_show') subjs_fit_show=[1:nsubjs]; end
for it=1:ntransforms
    transform_name=transform_names{it};
    disp(' ');
    for ip=1:length(paradigms_all)
        paradigm_name=paradigms_all{ip};
        disp(sprintf('modeling transform %20s from stimulus space to subject space with paradigm %20s',transform_name,paradigm_name));
        data_in=sims.(paradigm_name).stimspace;
        data_out=sims.(paradigm_name).dataspace.(transform_name);
        [gfs{it,ip},aux_geof_out{it,ip}]=rs_geofit(data_in,data_out,aux_geof);
        if (if_disp_geofit)
            for is=1:nsubjs
                if ~isempty(strmatch(transform_name,transforms_fit_show,'exact'))  & ~isempty(strmatch(paradigm_name,paradigms_fit_show,'exact')) & ismember(is,subjs_fit_show)
                    aux_dgeo_out=rs_disp_geofit(gfs{it,ip}{is}.gf,aux_dgeo);
                    fig_handles=aux_dgeo_out.opts_dgeo.fig_handles;
                    fig_names=aux_dgeo_out.opts_dgeo.fig_names;
                    for ifig=1:length(fig_handles)
                        figure(fig_handles{ifig});
                        set(gcf,'Name',cat(2,fig_names,' subj %1.0f',is));
                        axes('Position',[0.50,0.05,0.01,0.01]); %for text
                        text(0,0,fig_names{ifig},'Interpreter','none');
                        axis off;
                        axes('Position',[0.50,0.02,0.01,0.01]); %for text
                        text(0,0,sprintf('transform: %s, paradigm %s, subj %1.0f',transform_name,paradigm_name,is),'Interpreter','none');
                        axis off;
                    end 
                end
            end %subject
        end %if_disp_geofit
    end
end

