% rs_disp_coordsets_test3: demonstrate display of datasets with rays, and other enhanced plotting options
%
%  Note: when using data from components, rays also need to be taken from components (as is done here)
%
%  See also:  RS_DISP_COORDSETS, RS_DISP_ENH_COORDSETS, RS_DISP_COORDSETS_DEMO, RS_DISP_COORDSETS_DEMO3,
%   PSG_TYPENAMES2COLORS, RS_SAVE_FIGS.
%
%testing is in several sets, each of which contains (by rs_auto_test) one test, so ntests=1 but testset may be > 1
rs_module='disp_coordsets';
%
%section to force btc defaults, even if rs_aux_deefaults.mat has been created or modified
if ~exist('aux_force_filename') aux_force_filename='rs_aux_defaults_btc.mat'; end
auxs_force=struct;
opts_needed={'opts_read','opts_rays','opts_check','opts_qpred','opts_align','opts_import','opts_knit','opts_disp','opts_disp_enh','opts_tn2c'};
for k=1:length(opts_needed)
    auxs_force.(opts_needed{k})=rs_aux_force(opts_needed{k},[],aux_force_filename);
end
%
testset=3; 
ntests=1;
%
if ~exist('if_save_and_close')
    if_save_and_close=0;
end
if if_save_and_close==0
    if_save_and_close=getinp('1 to save and close all figures','d',[0 1]);
end
if if_save_and_close
    close all;
end
aux_outs=cell(1);
%
    filename_gps{1}={'./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat'};
    filename_gps{2}={'./samples/bwtextures/bcpm24pt_coords_MC_sess01_10.mat'};
    filename_gps{3}={'./samples/bwtextures/bcpp55qpt_coords_MC_sess01_10.mat'};
    filename_gps{4}={'./samples/bwtextures/dgea3pt_coords_MC_sess01_10.mat'};
    filename_gps{5}={... 
        './samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat',... 
        './samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat',... 
        './samples/bwtextures/bgca3pt_coords_NF_sess01_10.mat'};
    filename_gps{6}=filename_gps{5}; %this will be for multiple dims on the same plot
igp_spec=6; %will be treated specially
opts_tn2c=auxs_force.opts_tn2c; %for psg_typenames2colors
nvars=5; %for variants such as with and without rings or axes
ngps=length(filename_gps);
%
aux_outs{1}.aux_out_std=cell(2,ngps); %dim 1 is if_pca+1
aux_outs{1}.aux_out_enh=cell(nvars,2,ngps); % dim 2 is if_pca+1
%
if ~exist('gp_list')
    gp_list=[1:6];
end
for igp_ptr=1:length(gp_list)
    igp=gp_list(igp_ptr);
    filenames=filename_gps{igp};
    nfiles=length(filenames);
    aux_in=auxs_force;
    aux_in.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,0});
    aux_in.nsets=nfiles;
    disp(sprintf(' group %1.0f: %2.0f files',igp,nfiles))
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
        %
        aux_align_def=auxs_force.opts_align;
        aux_align_def.opts_align.if_log=0;
        [data_align,aux_align]=rs_align_coordsets(data_read,aux_align_def);
        aux_knit_def=auxs_force.opts_knit;
        aux_knit_def.opts_knit.if_log=0;
        aux_knit_def.opts_knit.if_pca=1; %rotate to PCA
        [data_consensus,aux_knit]=rs_knit_coordsets(data_align,aux_knit_def);
        %
        opts_disp=auxs_force;
        opts_disp.fig_name=sprintf('group %1.0f: %s',igp,data_read.sets{1}.paradigm_name);
        for ifile=1:nfiles
            opts_disp.set_labels{ifile}=data_read.sets{ifile}.subj_id;
        end
        %
        %standard plot
        %
        if ~ismember(igp,igp_spec)
            opts_disp.fig_handle=figure;
            set(gcf,'Name',cat(2,opts_disp.fig_name,', standard'));
            set(gcf,'Position',[50 100 1200 800]);
            set(gcf,'NumberTitle','off');       
            for if_pca=0:1
                opts_disp_std=opts_disp;
                if (if_pca==0)
                    data_disp=data_read;
                    rays_use=aux_read.rayss{1};
                else %use component data and rays
                    data_disp=aux_knit.components;
                    opts_disp_std.axis_label_prefix='pc';
                    opts_disp_std.connect_sets_method='all';
                    rays_use=aux_knit.rayss{1};
                end
                opts_disp_std.axis_handles{1}=subplot(1,2,1+if_pca);
                aux_outs{1}.aux_out_std{1+if_pca,igp}=rs_disp_coordsets(data_disp,setfield(struct,'opts_disp',opts_disp_std));
            end
        end
        %
        %plot variants
        %
        opts_disp.fig_handle=figure;
        set(gcf,'Name',cat(2,opts_disp.fig_name,', variants'));
        set(gcf,'Position',[100 100 1400 800]);
        set(gcf,'NumberTitle','off');
        if ismember(igp,igp_spec)
            nvars_adj=1;
            nsbvs_adj=6;
        else
            nvars_adj=nvars;
            nsbvs_adj=2;
        end       
        for ivar=1:nvars_adj
            for isbv=1:nsbvs_adj
                if_pca=isbv-1;
                opts_disp_var=opts_disp;
                if (if_pca==0) & ~ismember(igp,igp_spec)
                    data_disp=data_read;
                    opts_disp_var.axis_label_prefix='dim';
                    rays_use=aux_read.rayss{1};
                else %use component data and rays
                    data_disp=aux_knit.components;
                    opts_disp_var.axis_label_prefix='pc';
                    rays_use=aux_knit.rayss{1};
                end
                if isbv==1 & ~ismember(igp,igp_spec)
                    opts_disp_var.connect_sets_method='all';
                end
                opts_disp_enh=auxs_force.opts_disp_enh;
                npanels=1;
                switch ivar
                    case 1
                        if ismember(igp,igp_spec)
                            opts_disp_var.dim_select=4;
                            opts_disp_var.coord_group_size=3;
                            opts_disp_var.coord_group_method='list';
                            opts_disp_var.coord_groups=[[1 2 3];[2 3 4]];
                            npanels=size(opts_disp_var.coord_groups,1);
                            switch isbv
                                case 1
                                    opts_disp_var.set_select=[1 3];
                                case 2
                                    opts_disp_var.set_offsets=([-1 -.5 1]'*2*[1 2 3 4]);
                                case 3
                                    opts_disp_var.set_offsets='margin_amount';
                                    opts_disp_var.set_offsets_coordchoices='first';
                                case 4
                                    opts_disp_var.set_offsets='margin_amount';
                                    opts_disp_var.set_offsets_coordchoices={3,2};
                                case 5
                                    opts_disp_var.set_offsets='margin_amount';
                                    opts_disp_var.set_offsets_coordchoices='last';
                                case 6
                                    opts_disp_var.set_offsets='margin_fraction';
                                    opts_disp_var.set_offsets_margin_fraction=repmat(0.5,1,4);
                                    opts_disp_var.set_offsets_coordchoices='last';
                            end
                        else 
                            opts_disp_enh.if_points=1;
                            opts_disp_enh.if_rays=0;
                            opts_disp_enh.if_rings=0;
                            opts_disp_enh.if_nbrs=0;
                        end
                    case 2
                        opts_disp_enh.if_points=1;
                        opts_disp_enh.if_rays=1;
                        opts_disp_enh.if_rings=0;
                        opts_disp_enh.if_nbrs=0;
                    case 3
                        opts_disp_enh.if_points=1;
                        opts_disp_enh.if_rays=0;
                        opts_disp_enh.if_rings=1;
                        opts_disp_enh.if_nbrs=0;
                    case 4 %rays, but nonstandard callouts
                        opts_disp_enh.if_points=0;
                        opts_disp_enh.if_rays=1;
                        opts_disp_enh.if_rings=1;
                        opts_disp_enh.if_nbrs=0;
                        opts_disp_var.callout_amount=2;
                        opts_disp_var.callout_colors={[.2 .7 .1]};
                        opts_disp_var.callout_linewidths=3;
                        opts_disp_var.callout_linestyles=':';
                    case 5
                        opts_disp_enh.if_points=0;
                        opts_disp_enh.if_rays=1;
                        opts_disp_enh.if_rings=0;
                        opts_disp_enh.if_nbrs=1;
                end
                if ismember(igp,igp_spec)
                    for ip=1:npanels
                        opts_disp_var.axis_handles{ip}=subplot(npanels,nsbvs_adj,(ip-1)*nsbvs_adj+isbv);
                    end
                else
                    opts_disp_var.axis_handles{1}=subplot(nsbvs_adj,nvars,if_pca*nvars+ivar);
                end
                aux_disp_enh=auxs_force;
                aux_disp_enh.opts_disp=opts_disp_var;
                aux_disp_enh.opts_disp_enh=opts_disp_enh;
                aux_disp_enh.opts_tn2c=opts_tn2c;
                aux_outs{1}.aux_out_enh{ivar,1+if_pca,igp}=rs_disp_enh_coordsets(data_disp,aux_disp_enh,rays_use);
            end
        end % ivar
    end %if_ok
end %igp
%
if if_save_and_close
    rs_save_figs(sprintf('./tests/rs_disp_coordsets_testset%1.0f',testset),'all',setfield(struct(),'if_log',1));
else
    getinp('1 when ready to close and compare','d',[1 1],1);
end
close all;
%
fns{1}=sprintf('rs_%s_testset%1.0f',rs_module,testset);
s=struct;
s.aux_out=aux_outs;
rs_save_mat(cat(2,'tests',filesep,fns{1}),s);
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
disp(sprintf('testing rs_%s: %s',rs_module,sprintf('testset %1.0f',testset)));
opts_compare=struct;
[ifdif{1},opts_used{1}]=rs_benchmark_compare(fns{1},opts_compare);
