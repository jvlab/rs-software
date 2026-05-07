% rs_align_disp_enh_coordsets_demo: demonstrate display of datasets with offsets, rays, and other enhanced plotting options
%
% workflow_ read, align, and display coordinate sets
% plot options illustrated:
%  choice of dimension and coordinates to plot
%  several plots into same figure
%  custom arrangement of subplots
%  rotation of raw data coordinates into a consensus
%  custom axis labels
%  custom labeling of datasets based on subject ID and paradigm name
%  custom selection of which points to label
%  rays, rings, and nearest neighbor connections
%  selection of data points to label based on length of stimulus name, and how this interacts with plotting rays
%  extra panel with just legend
%  custom plot size
%  custom data label font size
%
% Also illustrates:
%  silencing logging for rs_[get|align|knit]_coordsets,
%  rotation of consensus data into principal components via rs_knit_coordsets
%
%  Note: when using data from components, rays also need to be taken from components (as is done here)
%
%  See also:  RS_DISP_COORDSETS, RS_DISP_ENH_COORDSETS, PSG_TYPENAMES2COLORS, RS_SAVE_FIGS.
%


%%section to force btc defaults, even if rs_aux_deefaults.mat has been created or modified
if ~exist('aux_force_filename') aux_force_filename='rs_aux_defaults_btc.mat'; end
auxs_force=struct;
opts_needed={'opts_read','opts_rays','opts_check','opts_align','opts_qpred','opts_knit','opts_disp','opts_disp_enh'};
for k=1:length(opts_needed)
    auxs_force.(opts_needed{k})=rs_aux_force(opts_needed{k},[],aux_force_filename);
end
%
filename_paradigms{1}={... 
        './samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat',... 
        './samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat',... 
        './samples/bwtextures/bgca3pt_coords_NF_sess01_10.mat'};
filename_paradigms{2}={
    './samples/bwtextures/bcpm3pt_coords_BL_sess01_10.mat',...
    './samples/bwtextures/bcpm3pt_coords_MC_sess01_10.mat',...
    './samples/bwtextures/bcpm3pt_coords_ZK_sess01_10.mat'};
filename_paradigms{3}={
    './samples/bwtextures/bcpp55qpt_coords_BL_sess01_10.mat',...
    './samples/bwtextures/bcpp55qpt_coords_MC_sess01_10.mat',...
    './samples/bwtextures/bcpp55qpt_coords_ZK_sess01_10.mat'};
filename_paradigms{4}={
    './samples/bwtextures/bcpm24pt_coords_BL_sess01_10.mat',...
    './samples/bwtextures/bcpm24pt_coords_MC_sess01_10.mat',...
    './samples/bwtextures/bcpm24pt_coords_ZK_sess01_10.mat'};
nparas=length(filename_paradigms);
nenh=4; %varieties of enhanced plots
ncgps=2; %number of coordinate groups ([1 2 3],[1 2 3]) from 'keeplow')
label_maxlength=6; %max length of a stimulus label
haxes_all=cell(ncgps,1+nenh); %standard plot in first column, enhanced plots in other columns
haxes=cell(ncgps,1);
aux_outs=cell(nparas,1+nenh); 
for ipara=1:nparas
    filenames=filename_paradigms{ipara};
    nfiles=length(filenames);
    aux_in=auxs_force;
    aux_in.opts_read=setfields(aux_in.opts_read,{'input_type','if_auto','if_log'},{1,1,0});
    aux_in.nsets=nfiles;
    disp(sprintf(' group %1.0f: %2.0f files',ipara,nfiles))
    [data_read,aux_read]=rs_get_coordsets(filenames,aux_in);
    if_ok=1;
    for ifile=1:nfiles
        rays=aux_read.rayss{ifile};
        if isempty(rays)
            disp(sprintf(' file %1.0f: %70s: ray structure not created',ifile,filenames{ifile}))
            if_ok=0;
        else
            disp(sprintf(' file %1.0f: %70s: %3.0f rays, %3.0f rings, %3.0f pairs',ifile,filenames{ifile},rays.nrays,rays.nrings,rays.npairs))
        end
    end
    if (if_ok)
        %align data, rotate to consensus, and rotate consensus into pca coords
        aux_align_def=auxs_force.opts_align;
        aux_align_def.opts_align.if_log=0;
        [data_align,aux_align]=rs_align_coordsets(data_read,aux_align_def);
        aux_knit_def=auxs_force.opts_knit;
        aux_knit_def.opts_knit.if_log=0;
        aux_knit_def.opts_knit.if_pca=1; %rotate to PCA
        [data_consensus,aux_knit]=rs_knit_coordsets(data_align,aux_knit_def);
        data_disp=aux_knit.components;
        rays_use=aux_knit.rayss{1};
        %choose datapoints to label:  only if stim name is <=6 chars
        %
        data_label_list=[];
        nstims=data_disp.sas{1}.nstims;
        for istim=1:nstims
            if length(data_disp.sas{1}.typenames{istim})<=label_maxlength
                data_label_list(end+1)=istim;
            end
        end
        %
        hfig=figure;
        for icgp=1:ncgps+1
            for icol=1:nenh+1
                haxes_all{icgp,icol}=subplot(ncgps+1,1+nenh,icol+(icgp-1)*(nenh+1));
            end
        end
        opts_disp=auxs_force.opts_disp;
        opts_disp.fig_handle=hfig;
        for icgp=1:ncgps+1 %extra panel for legend
            opts_disp.axis_handles{icgp}=haxes_all{icgp,1};
        end
        opts_disp.fig_name=sprintf('group %1.0f: %s',ipara,data_read.sets{1}.paradigm_name);
        for ifile=1:nfiles
            opts_disp.set_labels{ifile}=data_read.sets{ifile}.subj_id;
        end
        opts_disp.data_label_method='list';
        opts_disp.data_label_list=data_label_list;
        opts_disp.data_label_font_size=7;
        opts_disp.axis_label_prefix='pc';
        opts_disp.dim_select=4;
        opts_disp.coord_group_method='keeplow';
        opts_disp.if_legend=-1; %extra panel just for legend
        aux_outs{ipara,1}=rs_disp_coordsets(data_disp,setfield(struct,'opts_disp',opts_disp));
        %
        opts_disp2=opts_disp;
        opts_disp2.fig_position=[50 80 1400 800];
        opts_disp2.set_offsets='margin_fraction';
        opts_disp2.set_offsets_margin_fraction=1;
        opts_disp2.set_offsets_coordchoices='last';
        for ienh=1:nenh
            for icgp=1:ncgps+1
                opts_disp2.axis_handles{icgp}=haxes_all{icgp,1+ienh};
            end
            opts_disp_enh=auxs_force.opts_disp_enh;
            switch ienh %show rays, rings, and nearest-neighbors in separate plots
                case 1
                    opts_disp_enh.if_points=1;
                    opts_disp_enh.if_rays=1;
                    opts_disp_enh.if_rings=0;
                    opts_disp_enh.if_nbrs=0;
                case 2
                    opts_disp_enh.if_points=1;
                    opts_disp_enh.if_rays=0;
                    opts_disp_enh.if_rings=1;
                    opts_disp_enh.if_nbrs=0;
                case 3
                    opts_disp_enh.if_points=1;
                    opts_disp_enh.if_rays=0;
                    opts_disp_enh.if_rings=0;
                    opts_disp_enh.if_nbrs=1;
                case 4
                    opts_disp_enh.if_points=0;
                    opts_disp_enh.if_rays=1;
                    opts_disp_enh.if_rings=0;
                    opts_disp_enh.if_nbrs=1;
            end
            opts_disp2.data_label_method='list';
            opts_disp2.data_label_list=data_label_list;
            if opts_disp_enh.if_rays==1 %if rays are not plotted, select labeling based on size; otherwise, ends of rays will be labeled
                opts_disp2=rmfield(opts_disp2,'data_label_method');
                opts_disp2=rmfield(opts_disp2,'data_label_list');
            end
            aux_outs{ipara,1+ienh}=rs_disp_enh_coordsets(data_disp,setfields(struct,{'opts_disp','opts_disp_enh'},{opts_disp2,opts_disp_enh}),rays_use);
        end %ienh
    end %if_ok
end %ipara
