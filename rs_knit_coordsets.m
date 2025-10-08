function [data_out,aux_out]=rs_knit_coordsets(data_in,aux)
% [data_out,aux_out]=rs_knit_coordsets(data_in,aux) finds consensus coordinates across one or more datasets
% with partially overlapping stimuli
% data_in.sas{k}.typenames is used to establish stimulus identity
% 
% data_in.ds{k},sas{k},sets{k}: the structures of coordinates (ds) and metadata (sas,sets)
%   These could be returned by rs_get_coordsets or rs_read_coorddata, or,
%   after alignment by rs_align_coordsets
%
% aux.opts_knit:
%  if_log: 1 to log progress
%  allow_reflection: 1 to allow reflection (default=1)
%  allow_offset: 1 to allow offset (default=1) 
%  allow_scale: 1 to allow scale, (default=0)opts_pcon=filldefault(opts_pcon,'allow_scale',0);
%  if_normscale: 1 to normalize consensus to size of data (default=0)
%  if_c2p:  1 to rotate consensus into PCA space (default=0)
%  max_iters: max iterations for Procrustes consensus, default=1000
%  pcon_dim_max: maximum dimension for the consensus alignment dataset to be created, defaults to max available across all datasets
%  pcon_dim_max_comp: maximum dimension for component datasets to use; higher dimensions will be zero-padded, defaults to max available across all datasets
%  pcon_init_method: initialization method: >0: a specific set, 0 for PCA, -1 for PCA with forced centering, -2 for PCA with forced non-centering', defaults to 0
% 
% data_out.ds{k},sas{k},sets{k}:  coordinates and dataset descriptors after alignment
%    coordinates will be NaN if not present
% aux_out.ovlp_array: each row is a stimulus in data_out, kth column is a 1 if stimulus is present in dataset k
% aux_out.sa_pooled: sa metadata structure (stimulus params and coords) for pooled data
%    This can differ from data_out.sas{k}, which will have NaN's for stimulus coords if stimuli are  missing
% aux_out.opts_align: options used in psg_align_coordsets
%
%  See also: RS_AUX_CUSTOMIZE, RS_ALIGN_COORDSETS, PROCRUSTES_CONSENSUS.
%

if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_align',struct);
aux=rs_aux_customize(aux,'rs_align_coordsets');
aux.opts_knit=filldefault(aux.opts_knit,'if_log',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_reflection',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_offset',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_scale',0);
aux.opts_knit=filldefault(aux.opts_knit,'if_normscale',0);
aux.opts_knit=filldefault(aux.opts_knit,'if_c2p',0);
aux.opts_knit=filldefault(aux.opts_knit,'max_niters',1000);
aux.opts_knit=filldefault(aux.opts_knit,'pcon_dim_max',Inf);
aux.opts_knit=filldefault(aux.opts_knit,'pcon_dim_max_comp',Inf);
aux.opts_knit=filldefault(aux.opts_knit,'pcon_init_method',0);
%
data_out=struct;
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
nsets=length(data_in.sets);
nstims_each=zeros(1,nsets);
dim_list_each=cell(1,nsets);
dim_list_union=[];
typenames_each=cell(1,nsets);
typenames_union=[];
%validate the datasets
for iset=1:nsets
    nstims_each(iset)=data_in.sets{iset}.nstims;
    typenames_each{iset}=data_in.sas{iset}.typenames;
    dim_list_each{iset}=data_in.sets{iset}.dim_list;
    if iset==1
        typenames_inter=typenames_each{iset};
        dim_list_inter=dim_list_each{iset};
    end
    typenames_union=union(typenames_union,typenames_each{iset});
    typenames_inter=intersect(typenames_inter,typenames_each{iset});
    dim_list_union=union(dim_list_union(:)',dim_list_each{iset});
    dim_list_inter=intersect(dim_list_inter,dim_list_each{iset});
end
if min(nstims_each)~=max(nstims_each)
    wmsg=sprintf('number of stimuli do not agree across files (min: %3.0f, max: %3.0f)',min(nstims_each),max(nstims_each));
    warning(wmsg);
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;
end
if length(typenames_inter)~=length(typenames_union)
    wmsg=sprintf('stimulus names do not agree across files');
    warning(wmsg);
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;
    disp('discrepancies')
    disp(setdiff(typenames_union,typenames_inter));
end
if length(dim_list_union)~=length(dim_list_inter)
    wmsg=sprintf('dimension lists do not agree across files'); %this is OK, process the intersection
    warning(wmsg);
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    disp('discrepancies')
    disp(setdiff(dim_list_union,dim_list_inter));
end
%
if aux_out.warn_bad==0
%process
    nstims_all=min(nstims_each);
    typenames_all=typenames_inter;
    dim_list_all=dim_list_inter;
    if aux.opts_knit.if_log
        disp(sprintf('knitting %3.0f stimuli across %3.0f datasets, dimensions %s',nstims_all,nsets,sprintf(' %2.0f',dim_list_all))); 
        disp(sprintf('  allow reflection: %1.0f, allow offset: %1.0f, allow scale: %1.0f, normalize scale: %1.0f, rotate to pcs: %1.0f',...
            aux.opts_knit.allow_reflection,aux.opts_knit.allow_offset,aux.opts_knit.allow_scale,aux.opts_knit.if_normscale,aux.opts_knit.if_c2p));
    end
    if aux.opts_knit.if_c2p
        c2p_string='-pc';
    else
        c2p_string='';
    end
    aux.opts_knit.pcon_dim_max=min(aux.opts_knit.pcon_dim_max,max(dim_list_inter));
    aux.opts_knit.pcon_dim_max_comp=min(aux.opts_knit.pcon_dim_max_comp,max(dim_list_inter));
    if aux.opts_knit.pcon_init_method>0
        aux.opts_knit.initiailze_set=aux.opts_knit.pcon_init_method;
    elseif aux.opts_knit.pcon_init_method==0
        aux.opts_knit.pcon_initialize_set='pca';
    elseif aux.opts_knit.pcon_init_method==-1
        aux.opts_knit.pcon_initialize_set='pca_center';
    else
        aux.opts_knit.pcon_initialize_set='pca_nocenter';
    end
    %
    aux_out.opts_knit=aux.opts_knit;
else
    disp('cannot proceed');
end
return
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% %psg_align_knit_demo: demonstration of alignment and knitting together of multiple datasets
% % that have partially overlapping stimuli
% %
% % After like stimuli are aligned, this computes a consensus of the aligned sets, to create a 
% % 'knitted'  dataset with all stimuli, and then optionally writes this consensus data and metadata file.
% % Assumes that this is a raw data or model file, no previous entries in pipeline
% % 
% % all datasets must have dimension lists beginning at 1 and without gaps
% % aligned datasets (ds_align, ds_components) and metadata (sas_align) will have a NaN where there is no stimulus match
% %
% % 13Feb24: fix permute_raynums in opts_rays_knitted to be empty unless all agree in opts_rays_used; minor doc typos
% % 16Feb24: begin mods to dissociate dimension of individual datasets and fitted dimension, and more flexible plotting
% % 26Feb24: modularize psg_coord_pipe_util
% % 06May24: allow for NaN's in input datasets; allow for invoking a dialog box for data input
% % 25May24: adjust overlap array to take into account NaNs in input data
% % 21Nov24: add a check that merged datasets have same number of rays as components, before permuting ray labels
% % 29Nov24: added if_normscale (disabled by default)
% % 21Jan25: added option to write original datasets after alignment (ds_components, ds_align)
% % 23May25: option to embed the setup metadata in the data file; option for shorter pipeline by omitting details of procrustes_consensus
% % 25May25: allow for psg_btcremz to be invoked to simplify coords
% % 09Jun25: add options for not plotting components, and rotating into PC space
% %
% %  See also: PSG_ALIGN_COORDSETS, PSG_COORD_PIPE_PROC, PSG_GET_COORDSETS, PSG_READ_COORDDATA,
% %    PROCRUSTES_CONSENSUS, PROCRUSTES_CONSENSUS_PTL_TEST, PSG_FINDRAYS, PSG_WRITE_COORDDATA, 
% %    PSG_CONSENSUS_DEMO, PSG_COORD_PIPE_UTIL, PSG_ALIGN_STATS_DEMO, PSG_BTCREMZ, BTC_DEFINE, PSG_PCAOFFSET.
% %
% 
% %main structures and workflow:
% %ds{nsets},            sas{nsets}: original datasets and metadata
% %ds_align{nsets},      sas_align{nsets}: datasets with NaN's inserted to align the stimuli
% %ds_knitted,            sa_pooled: consensus rotation of ds_align, all stimuli, and metadata
% %ds_components{nsets}, sas_align{nsets}: components of ds_knitted, corresponding to original datasets, but with NaNs -- these are Procrustes transforms of ds_align
% %ds_nonan{nsets}       sas_nonan{nsets}: components stripped of NaNs.  NaN's in the ds are removed, as are NaN's inserted for alignment
% % 
% if ~exist('opts_read') opts_read=struct();end %for psg_read_coord_data
% if ~exist('opts_rays') opts_rays=struct(); end %for psg_findrays
% if ~exist('opts_align') opts_align=struct(); end %for psg_align_coordsets
% if ~exist('opts_nonan') opts_nonan=struct(); end %for psg_remnan_coordsets
% if ~exist('opts_pcon') opts_pcon=struct(); end % for procrustes_consensus
% if ~exist('opts_btcremz') opts_btcremz=struct(); end % for psg_btcremz
% if ~exist('opts_pca') opts_pca=struct(); end % for psg_pcaoffset
% if ~exist('pcon_dim_max') pcon_dim_max=3; end %dimensions for alignment
% %
% if ~exist('color_list') color_list='rmbcg'; end
% %
% disp('This will attempt to knit together two or more coordinate datasets.');
% %
% opts_read=filldefault(opts_read,'input_type',0); %either experimental data or model
% opts_align=filldefault(opts_align,'if_log',1);
% opts_nonan=filldefault(opts_nonan,'if_log',1);
% %
% opts_pcon=filldefault(opts_pcon,'allow_reflection',1);
% opts_pcon=filldefault(opts_pcon,'allow_offset',1);
% opts_pcon=filldefault(opts_pcon,'allow_scale',0);
% opts_pcon=filldefault(opts_pcon,'max_niters',1000); %nonstandard max
% %
% opts_btcremz=filldefault(opts_btcremz,'tol_spec',10^-4);
% opts_btcremz=filldefault(opts_btcremz,'tol_aug',10^-2);
% %
% opts_pca=filldefault(opts_pca,'if_log',0);
% opts_pca.nd_max=Inf;

% consensus=cell(pcon_dim_max,1);
% z=cell(pcon_dim_max,1);
% znew=cell(pcon_dim_max,1);
% ts=cell(pcon_dim_max,1);
% details=cell(pcon_dim_max,1);
% opts_pcon_used=cell(pcon_dim_max,1);
% %
% ds_knitted=cell(1,pcon_dim_max); %reverse order of dimensions, 21Nov24
% ds_components=cell(1,nsets); %partial datasets, aligned via Procrustes
% %
% disp('overlap matrix from stimulus matches (NaN values considered to be present')
% disp(ovlp_array'*ovlp_array);
% coords_isnan=zeros(nstims_all,nsets);
% for iset=1:nsets
%     coords_isnan(:,iset)=isnan(ds_align{iset}{1});
% end
% disp(sprintf('number of overlapping stimuli in component removed because coordinates are NaN'));
% disp(sum(coords_isnan.*ovlp_array,1));
% ovlp_array=ovlp_array.*(1-coords_isnan); %adjust overlap array to take into account NaNs (25May24)
% opts_pcon.overlaps=ovlp_array;
% disp('overlap matrix after excluding NaN coords in component data files')
% disp(opts_pcon.overlaps'*opts_pcon.overlaps);
% %
% for ip=1:pcon_dim_max
%     z{ip}=zeros(nstims_all,ip,nsets);
%     pcon_dim_use=min(ip,pcon_dim_max_comp); %pad above pcon_dim_pad
%     for iset=1:nsets
%         z{ip}(:,1:pcon_dim_use,iset)=ds_align{iset}{ip}(:,[1:pcon_dim_use]); %only include data up to pcon_dim_use
%         z{ip}(opts_align_used.which_common_kept(:,iset)==0,:,iset)=NaN; % pad with NaN's if no data %changed from which_common to allow for more general behavior of psg_align_coordsets when opts_align.min>1
%     end
%     [consensus{ip},znew{ip},ts{ip},details{ip},opts_pcon_used{ip}]=procrustes_consensus(z{ip},opts_pcon);
%     disp(sprintf(' creating Procrustes consensus for dim %2.0f based on datasets up to dimension %2.0f, iterations: %4.0f, final total rms dev: %8.5f',...
%         ip,pcon_dim_max_comp,length(details{ip}.rms_change),sqrt(sum(details{ip}.rms_dev(:,end).^2))));
%     ds_knitted{ip}=consensus{ip};
%     for iset=1:nsets
%         ds_components{iset}{1,ip}=znew{ip}(:,:,iset);
%     end
% end
% %
% %implement PCA rotation if requested:  note that this is applied both to consensus{ip} and to ds_components{ip}
% %
% ds_knitted_orig=ds_knitted;
% ds_components_orig=ds_components;
% if if_c2p
%     for ip=1:pcon_dim_max
%         knitted_centroid=mean(ds_knitted{ip},1,'omitnan');
%         [ds_knitted{ip},recon_coords,var_ex,var_tot,coord_maxdiff,opts_used_pca]=psg_pcaoffset(ds_knitted{ip},knitted_centroid,opts_pca);
% %        qu=opts_used_pca.qu;
% %        qs=opts_used_pca.qs;
%         v=opts_used_pca.qv;
%         % coords=u*s*v', and recon_coords= u*s, with v'*v=I, so recon_coords=coords*v
%         for iset=1:nsets
%             consensus_centroid_rep=repmat(mean(ds_components{iset}{1,ip},1,'omitnan'),nstims_all,1);
%             ds_components{iset}{1,ip}=consensus_centroid_rep+(ds_components{iset}{1,ip}-consensus_centroid_rep)*v(1:ip,:);
%         end
%     end %ip
% end
% %
% %find the ray descriptors but first make sure that arguments for permuting ray labels agree,
% %otherwise do not permute ray labels
% %
% opts_rays_knitted=rmfield(opts_rays_used{1},'ray_permute_raynums');
% if_match=1;
% for iset=1:nsets
%     disp(sprintf('for original set %1.0f, ray number permutation is:',iset))
%     disp(opts_rays_used{iset}.permute_raynums);
%     if length(opts_rays_knitted.permute_raynums)~=length(opts_rays_used{iset}.permute_raynums)
%         if_match=0;
%     else
%         if any(opts_rays_knitted.permute_raynums~=opts_rays_used{iset}.permute_raynums)
%             if_match=0;
%         end
%     end
%     %added 21Nov24 in case number of rays in knitted dataset is greater than
%     %any of the components, e.g., merging bgca with dgea
%     rays_knitted_prelim=psg_findrays(sa_pooled.btc_specoords);
%     if max(rays_knitted_prelim.whichray)>length(opts_rays_knitted.permute_raynums)
%         if_match=0;
%     end
%     if (if_match==0)
%         opts_rays_knitted.permute_raynums=[];
%     end
% end
% disp('for knitted set, ray number permutation is:')
% disp(opts_rays_knitted.permute_raynums);
% [rays_knitted,opts_rays_knitted_used]=psg_findrays(sa_pooled.btc_specoords,opts_rays_knitted); %ray parameters based on first dataset; finding rays only depends on metadata
% %
% [sets_nonan,ds_nonan,sas_nonan,opts_nonan_used]=psg_remnan_coordsets(sets_align,ds_components,sas_align,ovlp_array,opts_nonan); %remove the NaNs
% %find the rays for sets with nan's removed (since the order has been changed) and use these to plot
% rays_nonan=cell(nsets,1);
% for iset=1:nsets
%     [rays_nonan{iset},opts_rays_nonan_used{iset}]=psg_findrays(sas_nonan{iset}.btc_specoords,opts_rays_used{iset});
% end
% disp('created ray descriptors for knitted and nonan datasets');
% %
% %plot knitted data and individual sets
% dim_con=1;
% while max(dim_con)>0
%     dim_con_signed=getinp('knitted data dimension to plot (0 to end, - to skip plotting components)','d',[-pcon_dim_max pcon_dim_max]);
%     dim_con=abs(dim_con_signed);
%     if max(dim_con)>0
%         dims_to_plot=getinp('dimensions to plot','d',[1 dim_con]);
%         tstring=sprintf('consensus dim %1.0f [%s]',dim_con,sprintf('%1.0f ',dims_to_plot));
%         opts_plot=struct;
%         figure;
%         set(gcf,'Position',[100 100 1200 800]);
%         set(gcf,'Name',cat(2,'knitted ',tstring));
%         set(gcf,'NumberTitle','off');
%         opts_plot_used=psg_plotcoords(ds_knitted{dim_con},dims_to_plot,sa_pooled,rays_knitted,opts_plot);
%         axis equal;
%         axis vis3d;
%         xlims=get(gca,'XLim');
%         ylims=get(gca,'YLim');
%         zlims=get(gca,'ZLim');
%         axes('Position',[0.01,0.05,0.01,0.01]); %for text
%         text(0,0,cat(2,'knitted ',tstring,c2p_string),'Interpreter','none','FontSize',10);
%         axis off;
%         %
%         opts_rays_nonan_used=cell(nsets,1);
%         opts_plot_nonan_used=cell(nsets,1);
%         if dim_con_signed>0
%             for iset=1:nsets
%                 tstringc=sprintf(' component set %1.0f: %s, %s',iset,sets{iset}.label);
%                 figure;
%                 set(gcf,'Position',[100 100 1200 800]);
%                 set(gcf,'Name',cat(2,tstringc,' ',tstring));
%                 set(gcf,'NumberTitle','off');
%                 opts_plot_nonan_used{iset}=psg_plotcoords(ds_nonan{iset}{dim_con},dims_to_plot,sas_nonan{iset},rays_nonan{iset},opts_plot);
%                 axis equal
%                 axis vis3d
%                 set(gca,'XLim',xlims);
%                 set(gca,'YLim',ylims);
%                 set(gca,'ZLim',zlims);
%                 axes('Position',[0.01,0.05,0.01,0.01]); %for text
%                 text(0,0,cat(2,tstringc,' ',tstring,c2p_string),'Interpreter','none','FontSize',10);
%                 axis off;
%             end
%         end %dim_con_signed
%         %plot knitted with components, with black for composite and color order for each component
%         %method 1: rays removed
%         %method 2: using rays and colors_anymatch
%         for im=1:2
%             figure;
%             set(gcf,'Position',[100 100 1200 800]);
%             set(gcf,'Name',cat(2,'composite ',tstring));
%             set(gcf,'NumberTitle','off');
%             %
%             opts_plot_components=cell(1,nsets);
%             %plot, on same axes, each component using color_order
%             opts_plot_knitted=struct;
%             rays_knitted_use=rays_knitted;
%             switch im
%                 case 1
%                     opts_plot_knitted.marker_noray='';
%                     opts_plot_knitted.color_origin='k';
%                     opts_plot_knitted.color_nearest_nbr='k';
%                     opts_plot_knitted.noray_connect=0;
%                     rays_knitted_use.nrays=0;
%                     rayflag='no';
%                 case 2
%                     opts_plot_knitted.colors_anymatch='k';
%                     rayflag='with';
%             end
%             opts_plot_knitted_used{im}=psg_plotcoords(ds_knitted{dim_con},dims_to_plot,sa_pooled,rays_knitted_use,opts_plot_knitted);
%             for iset=1:nsets
%                 rays_nonan_use=rays_nonan{iset};
%                 pcolor=color_list(1+mod(iset-1,length(color_list)));
%                 opts_plot_components=opts_plot_knitted;
%                 opts_plot_components.axis_handle=opts_plot_knitted_used{im}.axis_handle;
%                 switch im
%                     case 1
%                         opts_plot_components.color_origin=pcolor;
%                         opts_plot_components.color_nearest_nbr=pcolor;
%                         rays_nonan_use.nrays=0;
%                     case 2
%                         opts_plot_components.colors_anymatch=pcolor;
%                 end
%                 opts_plot_components_used{im,iset}=psg_plotcoords(ds_nonan{iset}{dim_con},dims_to_plot,sas_nonan{iset},rays_nonan_use,opts_plot_components);
%             end
%             legend off;
%             axis equal
%             axis vis3d
%             set(gca,'XLim',xlims);
%             set(gca,'YLim',ylims);
%             set(gca,'ZLim',zlims);
%             axes('Position',[0.01,0.05,0.01,0.01]); %for text
%             text(0,0,cat(2,'composite [',rayflag,'rays] ',tstring,c2p_string),'Interpreter','none','FontSize',10);
%             axis off;
%         end %next method
%     end
% end
% if getinp('1 to write files: "knitted" (with new setup metadata), "aligned", "components" (aligned and transformed)','d',[0 1])
%     opts_write=struct;
%     opts_write.data_fullname_def='[paradigm]pooled_coords_ID.mat';
%     %
%     sout_knitted=struct;
%     sout_knitted.stim_labels=strvcat(sa_pooled.typenames);
%     %
%     opts=struct;
%     opts.pcon_dim_max=pcon_dim_max; %maximum consensus dimension created   
%     opts.pcon_dim_max_comp=pcon_dim_max_comp; %maximum component dimension used
%     opts.details=details; %details of Procrustes alignment
%     opts.opts_read_used=opts_read_used; %file-reading options
%     opts.opts_qpred_used=opts_qpred_used; %quadratic form model prediction options
%     opts.opts_align_used=opts_align_used; %alignment options
%     opts.opts_nonan_used=opts_nonan_used; %nan removal options
%     opts.opts_pcon_used=opts_pcon_used; %options for consensus calculation for each dataset
%     if_write_knitted=getinp('1 to write "knitted" dataset -- all stimuli combined and transformed into consensus (-1 to embed setup metadata)','d',[-1 1]);
%     if if_write_knitted~=0
%         if if_write_knitted==-1
%             sout_knitted.setup=sa_pooled;
%         end
%         sout_knitted.pipeline=psg_coord_pipe_util(cat(2,'knitted',c2p_string),opts,sets);
%         if getinp('1 to remove details from pipeline to shorten output file','d',[0 1])
%             sout_knitted.pipeline.opts=rmfield(sout_knitted.pipeline.opts,'details');
%         end
%         opts_write_used=psg_write_coorddata([],ds_knitted,sout_knitted,opts_write);
%     end
%     if getinp('1 to write individual datasets, "aligned" (stimuli lined up but not transformed into consensus; uses original setup file)','d',[0 1])
%         for iset=1:nsets
%             disp(sprintf(' set %2.0f',iset));
%             %ds_align{nsets},      sas_align{nsets}: datasets with NaN's inserted to align the stimuli
%             sas_align{iset}.pipeline=psg_coord_pipe_util('aligned',opts,sets);
%             sas_align{iset}.pipeline.opts.source_file=iset;
%             opts_write_used=psg_write_coorddata([],ds_align{iset},sout_knitted,opts_write);
%         end
%     end
%     if getinp('1 to write individual datasets, "components" (stimuli lined up and transformed into consensus; uses original setup file)','d',[0 1])
%         for iset=1:nsets
%             disp(sprintf(' set %2.0f',iset));
%             %ds_components{nsets}, sas_align{nsets}: components of ds_knitted, correcsponding to original datasets, but with NaNs -- these are Procrustes transforms of ds_align
%             sas_align{iset}.pipeline=psg_coord_pipe_util(cat(2,'components',c2p_string),opts,sets);
%             sas_align{iset}.pipeline.opts.source_file=iset;
%             opts_write_used=psg_write_coorddata([],ds_components{iset},sout_knitted,opts_write);
%         end
%     end
%     %
%     if getinp('1 to write metadata (setup file) for "knitted" dataset','d',[0 1])
%         metadata_fullname_def=opts_write_used.data_fullname;
%         metadata_fullname_def=metadata_fullname_def(1:-1+min(strfind(cat(2,metadata_fullname_def,'_coords'),'_coords')));
%         if isfield(sa_pooled,'nsubsamp')
%             metadata_fullname_def=cat(2,metadata_fullname_def,sprintf('%1.0f',sa_pooled.nsubsamp));
%         end
%         metadata_fullname=getinp('metadata file name','s',[],metadata_fullname_def);
%         s=sa_pooled;
%         save(metadata_fullname,'s');
%     end
% end %write files
