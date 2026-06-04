% rs_toygeom_demo: geometric modeling with toy simulated datasets; used by rs_toygeom_scenario*
%
% This illustrates fitting of geometric models via creation of simulated coordinate set structures. 
% It is intended that several of the parameters, especially paradigm_names, transform_names, are edited, 
% or that rs_toygeom_scenario*.m is run first; running as is will be very time-consuming.
%
% Constructs several transformations, designated by the strings in transform_names:
%     null: the identity
%     procrustes: rotation, no offset, inversion forced
%     affine: affine (linear) transformation, no offset
%     projective: projective transformation
%     pwaffine: piecewise affine transformation with one cutplane
%
% Creates several stimulus sets in a space of ncoords dimensions, designated by the strings in paradigm_names
%     Axes: points in positive and negative directions along each of the axes
%     Rings_C12, Rings_C13, Rings_C23: concentric rings in planes (1,2), (1,3), and (2,3)
%     Random: random points that avoid the axes
%     RandomAndAxisEnds: random points and the endponts of Axes
%   These coordinate set structures imported into sims.(paradigm_name).stimspace, using rs_import_coordsets, and
%     are displayed with rs_disp_coordsets or rs_disp_enh_coordsets.
%   Note that coordinate values are always integers, in range [-9:9]
% 
% Sets up nsubjs subjects.  For each subject, the parameters of the above transformations are jittered and applied to stimspace using rs_xform_apply,
%     noise is added, and, optionally, extra dimensions (ncoords_noise) with just noise are added.  These are in sims.(paradigm_name).dataspace.(transform_name).
%     and are displayed with rs_disp_coordsets or rs_disp_enh_coordsets.
%
% Optionally knits together the stimuli across pardigms, creating the
%    coordinate set structure sims.knitted.stimspace, and, for each subject, sims.knitted.dataspace.(transform_name)
% 
% The transformation from stimspace to dataspace are then fitted with geometric models with rs_geofit.
%   The model list defaults to {procrustes_noscale_offset','procrustes_scale_offset','affine_offset','projective'})
%    but can modified by changing model_list
%
% Results of the fitting are displayed with rs_toygeom_disp, which invokes rs_disp_geofit.
%
%  See also:  RS_IMPORT_COORDSETS, RS_DISP_COORDSETS, RS_DISP_GEOFIT,
%  RS_DISP_ENH_COORDSETS, RS_XFORM_APPLY, RS_CONCAT_DATASETS, RS_EXTRACT_COORDSETS, RS_TOYGEOM_DISP.
%
%these are the main simulation parameters that may be edited, or have values set before running
%
if ~exist('transform_names') transform_names={'null','procrustes','affine','projective','pwaffine'}; end %some may be deleted
if ~exist('affine_mag') affine_mag=0.5; end %magnitude of distortion in affine transforms
if ~exist('projective_mag') projective_mag=0.1; end %controls amount of distortion in projective transform
if ~exist('pwaffine_mag') pwaffine_mag=0.25; end %controls difference in linear transforms of piecewise affine
%
if ~exist('paradigm_names') paradigm_names={'Axes','Rings_C12','Rings_C13','Rings_C23','Random','RandomAndAxisEnds'}; end %some may be deleted
if ~exist('axis_samples') axis_samples=[2 4 6 8]; end %sample points in each direction along each axis
if ~exist('ring_radii') ring_radii=[4 6 8]; end %radii for the rings
if ~exist('ring_angles') ring_angles=8; end %number of sample points in a ring
if ~exist('nrandom') nrandom=16; end %number of random stimuli
%
if ~exist('nsubjs') nsubjs=1; end % number of subjects to simulate; at least 1; subjects have progressively more noise
if ~exist('subjs_disp') subjs_disp=unique([1,nsubjs]); end %which subjects to show in plots of response space
%
if ~exist('ncoords') ncoords=3; end %number of coordinates in stimulus set, should be at least 3
if ~exist('ncoords_noise') ncoords_noise=2; end %simulations can have noise on additional coordinates
if ~exist('noise_transform_mag') noise_transform_mag=0; end %set to nonzero (e..g, 0.2) to allow each subject's transformation to differ
if ~exist('noise_transform_subj') noise_transform_subj=[1:nsubjs]; end % multiplies noise_transform_mag to vary transform noise for each subject
if ~exist('noise_add_mag') noise_add_mag=1; end %additive Gaussian noise
if ~exist('noise_add_subj') noise_add_subj=[1:nsubjs]; end % mutliplies noise_add_mag to vary noise for each subject
%
if ~exist('if_disp_coordsets') if_disp_coordsets=1; end %set to 0 to suppress plots of coordinate sets for stimuli and subjects
if ~exist('if_frozen') if_frozen=1; end %set to 0 for random numbers each time, negative integer for fixed alternative seeds
%
if ~exist('if_knit') if_knit=0; end
%
if ~exist('model_list') model_list={'procrustes_noscale_offset','procrustes_scale_offset','affine_offset','projective'}; end
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
noise_transform_base=noise_transform_mag*noise_transform_subj; %subjects have varying amounts of noise in transform
noise_transform=noise_transform_base(1+mod([0:nsubjs-1],length(noise_transform_base))); %in case noise_transform_subj is too short
noise_add_base=noise_add_mag*noise_add_subj; %subjects have varying amounts of additive noise
noise_add=noise_add_base(1+mod([0:nsubjs-1],length(noise_add_base))); %in case noise_add_subj is too short
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
        transforms_noisy{is}.(transform_name).b=1; %scale factor unchanged; redundant with T and it will disrupt pwaffine continuity
        %adjustment for procrustes to ensure that the transform is isotropic
        if strcmp(transform_name,'procrustes')
            [Torth,Torthonormal]=grmscmdt(transforms_noisy{is}.procrustes.T);
            transforms_noisy{is}.procrustes.T=Torthonormal;
        end
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
            sim.nstims=length(ring_radii)*ring_angles+1; %rings in the plane two coords, and the origin
            sim.type_coords=zeros(sim.nstims,ncoords);
            coord_ptr=0;
            if contains(paradigm_name,'C12')
                ring_plane=[1 2];
            elseif contains(paradigm_name,'C13')
                ring_plane=[1 3];
            else
                ring_plane=[2 3];
            end
            angs=2*pi*[0:ring_angles-1]'/ring_angles;
            for ir=1:length(ring_radii)
                ring_locs=ring_radii(ir)*[cos(angs) sin(angs)];
                sim.type_coords(coord_ptr+[1:ring_angles],ring_plane)=ring_locs;
                coord_ptr=coord_ptr+ring_angles;
            end
            sim.if_findrays=1;
            sim.if_rings=1;
        case {'Random','RandomAndAxisEnds'}
            if strcmp(paradigm_name,'RandomAndAxisEnds')
                if_axend=1;
            else
                if_axend=0;
            end
            sim.nstims=nrandom+if_axend*(2*ncoords+nrandom+1); %random samples and possibly (bidirectional samples at the ends of the axes and the origin)
            sim.type_coords=zeros(sim.nstims,ncoords);
            random_vals=[[-random_max:-1] [1:random_max]]; %random values avoid the axes;
            rand_samps=ceil(2*random_max*rand(nrandom,ncoords));
            sim.type_coords(1:nrandom,:)=random_vals(rand_samps);
            if if_axend
                %make the samples at the ends of the axes
                coord_ptr=nrandom;
                for ic=1:ncoords
                    for isign=-1:2:1
                        coord_ptr=coord_ptr+1;
                        sim.type_coords(coord_ptr,ic)=isign*axis_samples(end);
                    end
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
    if if_disp_coordsets %set up a page for each paradigm name
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
        aux_stimdisp.opts_disp.set_labels='stims';
        aux_stimdisp.opts_disp.axis_handles={subplot(fig_rows,1,1)}; %show centered in column
        %
        if sim.if_findrays
            aux_stimdisp.opts_disp_enh.if_rings=sim.if_rings;
            aux_stimdisp.opts_disp_enh.if_points=1; %so legends are set labels
            aux_stimdisp.opts_disp.data_show_method='last'; %last point is random; plotting a point allows rs_disp_enh_coordsets to make simple legend
            sim.stimspace_disp_auxout=rs_disp_enh_coordsets(sim.stimspace,aux_stimdisp,sim.stimspace_rays);
        else
            aux_stimdisp.opts_disp.data_show_method='all'; 
            aux_stimdisp.opts_disp.data_label_method='list';
            aux_stimdisp.opts_disp.data_label_list=find(~contains(sim.stimspace.sas{1}.typenames,' ')); %label only the on-axis points (off-axis point names all have blanks)
            sim.stimspace_disp_auxout=rs_disp_coordsets(sim.stimspace,aux_stimdisp);
        end
       drawnow;
    end 
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
        if if_disp_coordsets
            for is_ptr=1:length(subjs_disp)
                is=subjs_disp(is_ptr);
                aux_datadisp.opts_disp=sim.stimspace_disp_auxout.opts_disp; %starting point for plot is how the transforms were plotted
               % aux_datadisp.opts_disp.axis_handles={subplot(fig_rows,fig_cols,it)}; %show each transform in a separate column
                aux_datadisp.opts_disp=rmfield(aux_datadisp.opts_disp,'axis_labels'); %use default labels
                aux_datadisp.opts_disp.set_labels=sprintf('subj %1.0f %s',is,transform_name);
                aux_datadisp.opts_disp.set_select=is; %just show this subject
                aux_datadisp.opts_disp.set_colors={'k'}; %black
                %
                figure(aux_datadisp.opts_disp.fig_handle); %activate the figure for this paradigm type
                aux_datadisp.opts_disp.axis_handles={subplot(fig_rows,fig_cols,it+is_ptr*fig_cols)}; %show each transform in a separate column
                %
                if sim.if_findrays %setups for which points to label, etc, are inherited from sim.xformspace_disp_auxout
                    aux_datadisp.opts_disp_enh=sim.stimspace_disp_auxout.opts_disp_enh; %had if_rings info
                    sim.dataspace_disp_auxout.(transform_name){is}=rs_disp_enh_coordsets(dataspace,aux_datadisp,sim.stimspace_rays);
                else
                    sim.dataspace_disp_auxout.(transform_name){is}=rs_disp_coordsets(dataspace,aux_datadisp);
                end
                drawnow;
             end %is
         end
         disp(sprintf('dataspace created for paradigm %20s and transform %s',paradigm_name,transform_name));
    end %it
    sims.(paradigm_name)=sim;
end
%
%optinally align and knit the stimuli across paradigms
%
if if_knit
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
end %if_knit
%
%fit models to transformation between stimulus space and data space
%
paradigms_all=fieldnames(sims); %includes original paradigms and knitted
if ~exist('opts_geof') opts_geof=struct; end
opts_geof=filldefault(opts_geof,'model_list',model_list);
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
%
gfs=cell(ntransforms,length(paradigms_all));
xs=cell(ntransforms,length(paradigms_all));
aux_geof_out=cell(ntransforms,length(paradigms_all));
for it=1:ntransforms
    transform_name=transform_names{it};
    disp(' ');
    for ip=1:length(paradigms_all)
        paradigm_name=paradigms_all{ip};
        disp(sprintf('modeling transform %20s from stimulus space to subject space with paradigm %20s',transform_name,paradigm_name));
        data_in=sims.(paradigm_name).stimspace;
        data_out=sims.(paradigm_name).dataspace.(transform_name);
        [gfs{it,ip},xs{it,ip},aux_geof_out{it,ip}]=rs_geofit(data_in,data_out,aux_geof);
    end
end
sims.transform_names=transform_names;
sims.paradigm_names=paradigm_names;
sims.paradigms_all=paradigms_all;
sims.nsubjs=nsubjs;
sims.gfs=gfs;
sims.xs=xs;
sims.aux_geof_out=aux_geof_out;
%
sims.ncoords=ncoords;
sims.ncoords_noise=ncoords_noise;
sims.noise_transform_mag=noise_transform_mag;
sims.noise_transform_subj=noise_transform_subj;
sims.noise_transform=noise_transform;
sims.noise_add_mag=noise_add_mag;
sims.noise_add_subj=noise_add_subj;
sims.noise_add=noise_add;
sims.model_list=model_list;
%
disp('consider saving the structure ''sims'', and using rs_toygeom_demo to display results')
