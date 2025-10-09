function [data_out,aux_out]=rs_knit_coordsets(data_in,aux)
% [data_out,aux_out]=rs_knit_coordsets(data_in,aux) finds consensus coordinates across one or more datasets
% with partially overlapping stimuli
% data_in.sas{k}.typenames is used to establish stimulus identity
% 
% data_in.ds{k},sas{k},sets{k}: the structures of coordinates (ds) and metadata (sas,sets)
%   These are typically created by rs_align_coordsets, but could also be directly from 
%   rs_get_coordsets or rs_read_coorddata if stimuli are identical across
%   datasets, as listed in data_in.sas{k}.typenames
%
% aux.opts_knit:
%  if_log: 1 to log progress
%  allow_reflection: 1 to allow reflection (default=1)
%  allow_offset: 1 to allow offset (default=1) 
%  allow_scale: 1 to allow scale, (default=0)opts_pcon=filldefault(opts_pcon,'allow_scale',0);
%  if_normscale: 1 to normalize consensus to size of data (default=0)
%  if_pca:  1 to rotate consensus into PCA space (default=0)
%  max_iters: max iterations for Procrustes consensus, default=1000
%  pcon_dim_max: maximum dimension for the consensus alignment dataset to be created, defaults to max available across all datasets
%  pcon_dim_max_comp: maximum dimension for component datasets to use; higher dimensions will be zero-padded, defaults to max available across all datasets
%  pcon_init_method: initialization method: >0: a specific set, 0 for PCA, -1 for PCA with forced centering, -2 for PCA with forced non-centering', defaults to 0
% 
% data_out.ds{1},sas{1},sets{1}:  consensus coordinates and dataset descriptors after alignment
% aux_out: auxiliary outputs and parameter values used
%    opts_knit: overall options used
%    opts_pcon{id}: options used in Procrustes alignment for model dimension id
%    coords_havedata: [stims x sets] is 1 where data are present.
%       Note that this may differ from aux_out.ovlp_array in rs_align_coordsets,
%       in that if an input file lists a stimulus but the response is NaN, then
%       it will appear as prseent in rs_align_coordsets output aux_out.ovlp_array,
%       but as absent in rs_knit_coordsets.aux_out.coords_havedata
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   rayss{1}: ray structure for knitted datasets
%   components.ds{k},sas{k},sets{k},rayss{k}: % coordinates and dataset descriptors of individual dataseets, after rotation/translation to alignment
%       coordinates will be NaN if not present
%
%  See also: RS_ALIGN_COORDSETS, RS_AUX_CUSTOMIZE, RS_FINDRAYS, RS_ALIGN_COORDSETS, PSG_REMNAN_COORDSETS, PROCRUSTES_CONSENSUS.
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_knit',struct);
aux.opts_knit=filldefault(aux.opts_knit,'if_log',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_reflection',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_offset',1);
aux.opts_knit=filldefault(aux.opts_knit,'allow_scale',0);
aux.opts_knit=filldefault(aux.opts_knit,'if_normscale',0);
aux.opts_knit=filldefault(aux.opts_knit,'if_pca',0);
aux.opts_knit=filldefault(aux.opts_knit,'max_niters',1000);
aux.opts_knit=filldefault(aux.opts_knit,'pcon_dim_max',Inf);
aux.opts_knit=filldefault(aux.opts_knit,'pcon_dim_max_comp',Inf);
aux.opts_knit=filldefault(aux.opts_knit,'pcon_init_method',0);
%
aux=filldefault(aux,'opts_pca',struct);
aux.opts_pca=filldefault(aux.opts_pca,'if_log',0);
aux.opts_pca=filldefault(aux.opts_pca,'nd_max',Inf);
%
aux=filldefault(aux,'opts_rays',struct);
aux=filldefault(aux,'opts_align',struct);
%
aux=rs_aux_customize(aux,'rs_knit_coordsets');
%
%
set_knit_strings={'paradigm_name','subj_id','subj_id_short','extra','label_long','label'}; %fields to be concatenated in knitted metadata
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
%inspect input data to see where data are missing
%note that a NaN can indicate that stimulus was present and response
%was missing, OR, that the stimulus was not presented
%
nstims_all=min(nstims_each);
coords_isnan=zeros(nstims_all,nsets);
for iset=1:nsets
    for kd=dim_list_each{iset}
        coords_isnan(:,iset)=or(coords_isnan(:,iset),any(isnan(data_in.ds{iset}{kd}),2)); %if data are missing for any dimenison, it's missing
    end
    if aux.opts_knit.if_log
        disp(sprintf(' number of stimuli missing in dataset %3.0f: %4.0f',iset,sum(coords_isnan(:,iset),1)));
    end
end
aux_out.coords_havedata=1-coords_isnan;
if aux.opts_knit.if_log
    disp('data table')
    disp(aux_out.coords_havedata'*aux_out.coords_havedata)
end
if any(all(coords_isnan,2))
    wmsg=sprintf('one or more stimuli never appear');
    warning(wmsg);
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;
end
%
%if aux.sa_pooled is present, use it, otherwise, re=create
if isfield(aux,'sa_pooled')
    if (aux.opts_knit.if_log)
        disp('sa_pooled is supplied.');
    end
    sa_pooled=aux.sa_pooled;
else
    if (aux.opts_knit.if_log)
        disp('sa_pooled will be created.');
    end
    %redo the alignment, but first remove the nans in the aligned file; this would confuse if realigned
    [sets_nonan,ds_nonan,sas_nonan]=psg_remnan_coordsets(data_in.sets,data_in.ds,data_in.sas,[],setfield(struct,'if_log',aux.opts_knit.if_log));
    data_in_nonan=struct;
    data_in_nonan.ds=ds_nonan;
    data_in_nonan.sas=sas_nonan;
    data_in_nonan.sets=sets_nonan;
    [data_align,aux_align]=rs_align_coordsets(data_in_nonan,aux);
    sa_pooled=aux_align.sa_pooled;
end
if length(intersect(sa_pooled.typenames,typenames_union))~=length(union(sa_pooled.typenames,typenames_union))
    wmsg=sprintf('pooled typenames are incompatible with type names from individual datasets');
    aux_out.warn_bad=aux_out.warn_bad+1;
    disp('discrepancies')
    disp(setdiff(typenames_union,sa_pooled.typenames));
end
%
if aux_out.warn_bad==0
%process
    typenames_all=typenames_inter;
    dim_list_all=dim_list_inter;
    if aux.opts_knit.if_log
        disp(sprintf('knitting %3.0f stimuli across %3.0f datasets, dimensions %s',nstims_all,nsets,sprintf(' %2.0f',dim_list_all))); 
        disp(sprintf('  allow reflection: %1.0f, allow offset: %1.0f, allow scale: %1.0f, normalize scale: %1.0f, rotate to pcs: %1.0f',...
            aux.opts_knit.allow_reflection,aux.opts_knit.allow_offset,aux.opts_knit.allow_scale,aux.opts_knit.if_normscale,aux.opts_knit.if_pca));
    end
    if aux.opts_knit.if_pca
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
    pcon_dim_max=aux.opts_knit.pcon_dim_max;
    pcon_dim_max_comp=aux.opts_knit.pcon_dim_max_comp;
    consensus=cell(pcon_dim_max,1);
    z=cell(pcon_dim_max,1);
    znew=cell(pcon_dim_max,1);
    ts=cell(pcon_dim_max,1);
    details=cell(pcon_dim_max,1);
    opts_pcon_used=cell(pcon_dim_max,1);
    ds_knitted=cell(1,pcon_dim_max);
    ds_components=cell(1,nsets); %partial datasets, aligned via Procrustes
    %
    %do a consensus on each model-dimension separately
    %
    for ip=1:pcon_dim_max
        if ismember(ip,dim_list_inter)
            z{ip}=zeros(nstims_all,ip,nsets);
            pcon_dim_use=min(ip,pcon_dim_max_comp); %pad above pcon_dim_pad
            for iset=1:nsets
                z{ip}(:,1:pcon_dim_use,iset)=data_in.ds{iset}{ip}(:,[1:pcon_dim_use]); %only include data up to pcon_dim_use
                z{ip}(coords_isnan(:,iset)>0,:,iset)=NaN; % pad with NaN's if data are missing
            end
            [ds_knitted{ip},znew{ip},ts{ip},details{ip},opts_pcon_used{ip}]=procrustes_consensus(z{ip},aux.opts_knit);
            if aux.opts_knit.if_log
                disp(sprintf(' creating Procrustes consensus for dim %2.0f based on component datasets up to dimension %2.0f, iterations: %4.0f, final total rms dev: %8.5f',...
                    ip,pcon_dim_max_comp,length(details{ip}.rms_change),sqrt(sum(details{ip}.rms_dev(:,end).^2))));
            end
            for iset=1:nsets
                ds_components{iset}{1,ip}=znew{ip}(:,:,iset);
            end
        end
    end
    %
    %implement PCA rotation if requested:  note that this is applied both to consesnus and components
    %
    if aux.opts_knit.if_pca
        for ip=1:pcon_dim_max
            if ismember(ip,dim_list_inter)
                knitted_centroid=mean(ds_knitted{ip},1,'omitnan');
                [ds_knitted{ip},recon_coords,var_ex,var_tot,coord_maxdiff,opts_used_pca]=psg_pcaoffset(ds_knitted{ip},knitted_centroid,aux.opts_pca);
        %        qu=opts_used_pca.qu;
        %        qs=opts_used_pca.qs;
                v=opts_used_pca.qv;
        %       coords=u*s*v', and recon_coords= u*s, with v'*v=I, so recon_coords=coords*v
                for iset=1:nsets
                    consensus_centroid_rep=repmat(mean(ds_components{iset}{1,ip},1,'omitnan'),nstims_all,1);
                    ds_components{iset}{1,ip}=consensus_centroid_rep+(ds_components{iset}{1,ip}-consensus_centroid_rep)*v(1:ip,:);
                end
            end
        end %ip
    end
    sas_knitted=sa_pooled;
    %
    %knitted set structure
    sets_knitted=struct;
    sets_knitted.nstims=nstims_all;
    sets_knitted.dim_list=dim_list_inter;
    for ifn=1:length(set_knit_strings)
        fn=set_knit_strings{ifn};
        sets_knitted.(fn)=[];
        for iset=1:nsets
            if isfield(data_in.sets{iset},fn)
                sets_knitted.(fn)=cat(2,sets_knitted.(fn),data_in.sets{iset}.(fn),'+');
            end
        end
        if length(sets_knitted.(fn))>1
            sets_knitted.(fn)=sets_knitted.(fn)(1:end-1);
        end
    end
    %find rays
    [rays,wmsg,opts_rays_used]=rs_findrays(sas_knitted,sets_knitted.label,aux.opts_rays);
    if ~isempty(wmsg)
        wmsg=cat(2,sprintf('set %2.0f: ',iset),wmsg);
        warning(wmsg);
        aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    end
    data_out.ds{1}=ds_knitted;
    data_out.sas{1}=sas_knitted;
    data_out.sets{1}=sets_knitted;
    aux_out.opts_rays{1}=opts_rays_used;
    aux_out.rayss{1}=rays;
    %
    aux_out.components.ds=ds_components;
    aux_out.components.sas=data_in.sas;
    aux_out.components.sets=data_in.sets;
    %
    %%%need add to sets, sas, pipeline to data_out.sets{1}
    %
    aux_out.opts_knit=aux.opts_knit;
    aux_out.opts_pcon=opts_pcon_used;
else
    disp('cannot proceed');
end
return
end

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
