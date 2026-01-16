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
%
%define the stimuli
%
paradigm_types='toygeom';
paradigm_names={'Axes','Rings_C12','Rings_C13','RandomAndAxisEnds'}; %if this is edited, then change the computation of stimulus sets
coord_labels={'f','g','h'}; %any strings will do
n_coords=length(coord_labels);
sign_chars={'m','z','p'}; %tokens for negative, zero, or positive
axis_samples=[2 4 6 8]; %sample points in each direction along each axis
n_angles=8; %number of sample points in a ring
ring_radii=[4 6 8]; %radii for the rings
n_random=20; %number of random stimuli
random_max=9; %maximum random value
%
%define the simulations
%
if ~exist('n_subjs') n_subjs=3; end
%
if (if_frozen~=0) 
    rng('default');
    if (if_frozen<0)
        rand(1,abs(if_frozen));
    end
else
    rng('shuffle');
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
        case {'Rings_C12','Rings_C13'}
            sim.nstims=length(ring_radii)*n_angles+1; %rings in the plane two coords, and the origin
            sim.type_coords=zeros(sim.nstims,n_coords);
            coord_ptr=0;
            if contains(paradigm_name,'C12')
                ring_plane=[1 2];
            else
                ring_plane=[1 3];
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

%

%    sims.(paradigm_name)=sim;

% filename_paradigms{1}={... 
%         './samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat',... 
%         './samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat',... 
%         './samples/bwtextures/bgca3pt_coords_NF_sess01_10.mat'};
% filename_paradigms{2}={
%     './samples/bwtextures/bcpm3pt_coords_BL_sess01_10.mat',...
%     './samples/bwtextures/bcpm3pt_coords_MC_sess01_10.mat',...
%     './samples/bwtextures/bcpm3pt_coords_ZK_sess01_10.mat'};
% filename_paradigms{3}={
%     './samples/bwtextures/bcpp55qpt_coords_BL_sess01_10.mat',...
%     './samples/bwtextures/bcpp55qpt_coords_MC_sess01_10.mat',...
%     './samples/bwtextures/bcpp55qpt_coords_ZK_sess01_10.mat'};
% filename_paradigms{4}={
%     './samples/bwtextures/bcpm24pt_coords_BL_sess01_10.mat',...
%     './samples/bwtextures/bcpm24pt_coords_MC_sess01_10.mat',...
%     './samples/bwtextures/bcpm24pt_coords_ZK_sess01_10.mat'};
% nparas=length(filename_paradigms);
% nenh=4; %varieties of enhanced plots
% ncgps=2; %number of coordinate groups ([1 2 3],[1 2 3]) from 'keeplow')
% label_maxlength=6; %max length of a stimulus label
% haxes_all=cell(ncgps,1+nenh); %standard plot in first column, enhanced plots in other columns
% haxes=cell(ncgps,1);
% aux_outs=cell(nparas,1+nenh); 
% for ipara=1:nparas
%     filenames=filename_paradigms{ipara};
%     nfiles=length(filenames);
%     aux_in=struct;
%     aux_in.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,0});
%     aux_in.nsets=nfiles;
%     disp(sprintf(' group %1.0f: %2.0f files',ipara,nfiles))
%     [data_read,aux_read]=rs_get_coordsets(filenames,aux_in);
%     if_ok=1;
%     for ifile=1:nfiles
%         rays=aux_read.rayss{ifile};
%         if isempty(rays)
%             disp(sprintf(' file %1.0f: %70s: ray structure not created',ifile,filenames{ifile}))
%             if_ok=0;
%         else
%             disp(sprintf(' file %1.0f: %70s: %3.0f rays, %3.0f rings, %3.0f pairs',ifile,filenames{ifile},rays.nrays,rays.nrings,rays.npairs))
%         end
%     end
%     if (if_ok)
%         %align data, rotate to consensus, and rotate consensus into pca coords
%         aux_align_def=struct;
%         aux_align_def.opts_align.if_log=0;
%         [data_align,aux_align]=rs_align_coordsets(data_read,aux_align_def);
%         aux_knit_def=struct;
%         aux_knit_def.opts_knit.if_log=0;
%         aux_knit_def.opts_knit.if_pca=1; %rotate to PCA
%         [data_consensus,aux_knit]=rs_knit_coordsets(data_align,aux_knit_def);
%         data_disp=aux_knit.components;
%         rays_use=aux_knit.rayss{1};
%         %choose datapoints to label:  only if stim name is <=6 chars
%         %
%         data_label_list=[];
%         nstims=data_disp.sas{1}.nstims;
%         for istim=1:nstims
%             if length(data_disp.sas{1}.typenames{istim})<=label_maxlength
%                 data_label_list(end+1)=istim;
%             end
%         end
%         %
%         hfig=figure;
%         for icgp=1:ncgps+1
%             for icol=1:nenh+1
%                 haxes_all{icgp,icol}=subplot(ncgps+1,1+nenh,icol+(icgp-1)*(nenh+1));
%             end
%         end
%         opts_disp=struct;
%         opts_disp.fig_handle=hfig;
%         for icgp=1:ncgps+1 %extra panel for legend
%             opts_disp.axis_handles{icgp}=haxes_all{icgp,1};
%         end
%         opts_disp.fig_name=sprintf('group %1.0f: %s',ipara,data_read.sets{1}.paradigm_name);
%         for ifile=1:nfiles
%             opts_disp.set_labels{ifile}=data_read.sets{ifile}.subj_id;
%         end
%         opts_disp.data_label_method='list';
%         opts_disp.data_label_list=data_label_list;
%         opts_disp.data_label_font_size=7;
%         opts_disp.axis_label_prefix='pc';
%         opts_disp.dim_select=4;
%         opts_disp.coord_group_method='keeplow';
%         opts_disp.if_legend=-1; %extra panel just for legend
%         aux_outs{ipara,1}=rs_disp_coordsets(data_disp,setfield(struct,'opts_disp',opts_disp));
%         %
%         opts_disp2=opts_disp;
%         opts_disp2.fig_position=[50 80 1400 800];
%         opts_disp2.set_offsets='margin_fraction';
%         opts_disp2.set_offsets_margin_fraction=1;
%         opts_disp2.set_offsets_coordchoices='last';
%         for ienh=1:nenh
%             for icgp=1:ncgps+1
%                 opts_disp2.axis_handles{icgp}=haxes_all{icgp,1+ienh};
%             end
%             opts_disp_enh=struct;
%             switch ienh %show rays, rings, and nearest-neighbors in separate plots
%                 case 1
%                     opts_disp_enh.if_points=1;
%                     opts_disp_enh.if_findrays=1;
%                     opts_disp_enh.if_rings=0;
%                     opts_disp_enh.if_nbrs=0;
%                 case 2
%                     opts_disp_enh.if_points=1;
%                     opts_disp_enh.if_findrays=0;
%                     opts_disp_enh.if_rings=1;
%                     opts_disp_enh.if_nbrs=0;
%                 case 3
%                     opts_disp_enh.if_points=1;
%                     opts_disp_enh.if_findrays=0;
%                     opts_disp_enh.if_rings=0;
%                     opts_disp_enh.if_nbrs=1;
%                 case 4
%                     opts_disp_enh.if_points=0;
%                     opts_disp_enh.if_findrays=1;
%                     opts_disp_enh.if_rings=0;
%                     opts_disp_enh.if_nbrs=1;
%             end
%             opts_disp2.data_label_method='list';
%             opts_disp2.data_label_list=data_label_list;
%             if opts_disp_enh.if_findrays==1 %if rays are not plotted, select labeling based on size; otherwise, ends of rays will be labeled
%                 opts_disp2=rmfield(opts_disp2,'data_label_method');
%                 opts_disp2=rmfield(opts_disp2,'data_label_list');
%             end
%             aux_outs{ipara,1+ienh}=rs_disp_enh_coordsets(data_disp,setfields(struct,{'opts_disp','opts_disp_enh'},{opts_disp2,opts_disp_enh}),rays_use);
%         end %ienh
%     end %if_ok
% end %ipara
