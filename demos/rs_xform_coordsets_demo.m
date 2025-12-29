% rs_xform_coordsets_demo: demonstrate specification and application of simple linear transformations
%
%****also try out generic transformations and buff up documentation in rs_xform_apply
%
% plot options illustrated:
%  choice of dimension and coordinates to plot
%  several plots into same figure
%  custom arrangement of subplots
%  custom colors for data points
%  custom marker sizes for points
%  custom axis labels
%  custom axis ranges
%  selection of data points to label based on length of stimulus name
%  custom choice of data points to connect between sets
%  custom line style and color for connections between sets
%  rotation of raw data coordinates into a consensus
%
% Also illustrates:
%  silencing logging for rs_[get|align|knit]_coordsets,
%  saving intermediate results from alignment so that alignment is not repeated by rs_knit_coordsets
%
%  See also:  RS_XFORM_SPECIFY, RS_XFORM_APPLY, RS_DISP_COORDDSETS.
%
filenames={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S6'};
nsets=length(filenames);
aux_in=struct;
aux_in.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,0});
aux_in.nsets=nsets;
%raw dataset
[data_read,aux_read]=rs_get_coordsets(filenames,aux_in);
%align data
aux_align_def=struct;
aux_align_def.opts_align.if_log=0; %turn off logging
[data_align,aux_align]=rs_align_coordsets(data_read,aux_align_def);
%keep intermediate results from alignment so that alignment isn't redone
aux_knit_def=struct;  
aux_knit_def.data_align=data_align;
aux_knit_def.sa_pooled=aux_align.sa_pooled;
aux_knit_def.opts_knit.if_log=0; %turn off logging
[data_consensus,aux_knit]=rs_knit_coordsets(data_align,aux_knit_def);
aux_knit_pc=aux_knit_def;
aux_knit_pc.opts_knit.if_pca=1; %turn on pca rotation
%rotate to consensus and pc rotation
[data_consensus_pc,aux_knit_pc]=rs_knit_coordsets(data_align,aux_knit_pc);
%
subj_ids=cell(1,nsets);
for iset=1:nsets
    subj_ids{iset}=data_read.sets{iset}.subj_id;
end
%label the stimuli with short names
label_maxlength=5; %max length of a stimulus label
data_label_list=[];
nstims=data_align.sas{1}.nstims;
for istim=1:nstims
    if length(data_align.sas{1}.typenames{istim})<=label_maxlength
        data_label_list(end+1)=istim;
    end
end
%
dlist=[2 3]; %dimensions to show
nds=length(dlist);
data_start={'raw','raw','consensus','consensus','consensus_pc'};
nxforms=length(data_start);
aux_outs=cell(2,nds,nxforms); %d1: init or transformed, d2: dimension, d3: which transform
%
xform=cell(1,nxforms);
aux_spec_outs=cell(1,nxforms);
aux_xform_outs=cell(1,nxforms);
%
for ixform=1:nxforms
    switch data_start{ixform}
        case 'raw'
            data_use=data_align; %same as data_read, but stimuli in same order as consensus
            axis_label_prefix='dim';
        case 'consensus'
            data_use=aux_knit.components;
            axis_label_prefix='dim (consensus)';
        case 'consensus_pc'
            data_use=aux_knit_pc.components;
            axis_label_prefix='pc (consensus)';
    end
    opts_xform=struct;
    switch ixform
        case 1
            opts_xform.mode='translate';
            opts_xform.source='global';
            opts_xform.centering_specifier='value';
            opts_xform.centering_value=0.5*[1:10];
        otherwise
            opts_xform.mode='translate';
            opts_xform.source='global';
            opts_xform.centering_specifier='value';
            opts_xform.centering_value=-0.5*[1:10];
    end
    %specify the transformation
    xform_name=sprintf('transformation %1.0f, starting with %s',ixform,data_start{ixform});
    [xform{ixform},aux_spec_outs{ixform}]=rs_xform_specify(data_use,setfield(struct(),'opts_xform',opts_xform));
    %do the transformations
    [data_xform,aux_xform_outs{ixform}]=rs_xform_apply(data_use,xform{ixform},struct());
    %plot: top row is untransformed data, dims 2 and 3; bottom row is transfornmed data
    hfig=figure;
    haxes=cell(2,nds);
    for ix=1:2
        for id=1:nds
            haxes{ix,id}=subplot(2,nds,id+(ix-1)*nds);
        end
    end
    opts_disp_init=struct;
    opts_disp_init.fig_handle=hfig;
    opts_disp_init.fig_name=xform_name;
    opts_disp_init.axis_label_prefix=axis_label_prefix;
    opts_disp_init.set_labels=subj_ids;
    opts_disp_init.set_colors={'r',[0 0.6 0.1]'};
    opts_disp_init.set_markersizes=12;
    opts_disp_init.data_label_method='list';
    opts_disp_init.data_label_list=data_label_list;
    opts_disp_init.data_label_font_size=7;
    opts_disp_init.connect_sets_data_method='labeled';
    opts_disp_init.connect_sets_linestyles={':'};
    opts_disp_init.connect_sets_color_mode='list';
    opts_disp_init.connect_sets_colors='k';
    %
    if strcmp(data_start{ixform},'raw')
        opts_disp_init.data_label_setsel_method='all';
        opts_disp_init.connect_sets_method='none';
        opts_disp_init.axis_range='tight';
    else
        opts_disp_init.data_label_setsel_method='first';
        opts_disp_init.connect_sets_method='all';
        opts_disp_init.axis_range='list';
        opts_disp_init.axis_range_list=[-3 3]; %fixed scales to make transforms easier to see

    end
    for id=1:nds
        opts_disp_init.axis_handles=haxes(1,id);
        opts_disp_init.dim_select=dlist(id);
        aux_outs{1,id,ixform}=rs_disp_coordsets(data_use,setfield(struct,'opts_disp',opts_disp_init));
    end
    %
    opts_disp_xform=opts_disp_init;
    opts_disp_xform.if_legend=0; %don't need a legend
    for id=1:nds
        opts_disp_xform.axis_handles=haxes(2,id);
        opts_disp_xform.dim_select=dlist(id);
        aux_outs{2,id,ixform}=rs_disp_coordsets(data_xform,setfield(struct,'opts_disp',opts_disp_xform));
    end
end %ixform

% 
% test_descs=cell(1,ntests);
% filenames_examples=cell(1,ntests);
% auxs=cell(1,ntests);
% signflips=cell(1,ntests);
% ignore=cell(nsubmodules,ntests);
% data_reads=cell(1,ntests);
% aux_ins=cell(1,ntests);
% xforms=cell(1,ntests);
% aux_outs=cell(nsubmodules,ntests);
% auxs=cell(1,ntests);
% data_outs=cell(1,ntests);
% %
% test_descs{1}='three binary texture coordinate files, second file is a model, no centering';
% filenames_examples{1}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
% aux_ins{1}=struct;
% aux_ins{1}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{[1 2],1,1});
% aux_ins{1}.nsets=3;
% auxs{1}=struct;
% signflips{1}={{'data_read','ds'},{'data_out','ds'}};
% %
% test_descs{2}='four animal-domain files, centering by typename, global, translate';
% filenames_examples{2}={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S4','./samples/animals/image_coords_S5','./samples/animals/image_coords_S6'};
% aux_ins{2}=struct;
% aux_ins{2}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
% aux_ins{2}.nsets=4;
% auxs{2}=struct;
% auxs{2}.opts_xform.mode='translate';
% auxs{2}.opts_xform.source='global';
% auxs{2}.opts_xform.centering_specifier='typename';
% auxs{2}.opts_xform.centering_typename='ant';
% %
% test_descs{3}='four animal-domain files, centering by typename, local, translate';
% filenames_examples{3}=filenames_examples{2};
% aux_ins{3}=aux_ins{2};
% auxs{3}=struct;
% auxs{3}.opts_xform.mode='translate';
% auxs{3}.opts_xform.source='local';
% auxs{3}.opts_xform.centering_specifier='typename';
% auxs{3}.opts_xform.centering_typename='ant';
% %
% test_descs{4}='four animal-domain files, centering by centroid, source = set 2, translate';
% filenames_examples{4}=filenames_examples{2};
% aux_ins{4}=aux_ins{2};
% auxs{4}=struct;
% auxs{4}.opts_xform.mode='translate';
% auxs{4}.opts_xform.source=2;
% auxs{4}.opts_xform.centering_specifier='centroid';
% %
% test_descs{5}='four animal-domain files, centering by fixed value, translate';
% filenames_examples{5}=filenames_examples{2};
% aux_ins{5}=aux_ins{2};
% auxs{5}=struct;
% auxs{5}.opts_xform.mode='translate';
% auxs{5}.opts_xform.source='global';
% auxs{5}.opts_xform.centering_specifier='value';
% auxs{5}.opts_xform.centering_value=0.1*[1:10];
% %
% test_descs{6}='four animal-domain files, centering by index, global, offset_pca';
% filenames_examples{6}=filenames_examples{2};
% aux_ins{6}=aux_ins{2};
% auxs{6}=struct;
% auxs{6}.opts_xform.mode='offset_pca';
% auxs{6}.opts_xform.source='global';
% auxs{6}.opts_xform.centering_specifier='index';
% auxs{6}.opts_xform.centering_index=17;
% if if_ignore_svdambig
%     ignore{1,6}={{'xform_out','ts'}};
%     ignore{2,6}={{'xform_out','ts'},{'data_out','ds'}};
% end
% %
% test_descs{7}='four animal-domain files, centering by index, global, translate_then_pca';
% filenames_examples{7}=filenames_examples{2};
% aux_ins{7}=aux_ins{2};
% auxs{7}=struct;
% auxs{7}.opts_xform.mode='translate_then_pca';
% auxs{7}.opts_xform.source='local';
% auxs{7}.opts_xform.centering_specifier='index';
% auxs{7}.opts_xform.centering_index=17;
% if if_ignore_svdambig
%     ignore{1,7}={{'xform_out','ts'}};
%     ignore{2,7}={{'xform_out','ts'},{'data_out','ds'}};
% end
% %
% test_descs{8}='three binary texture coordinate files, no models, centering by typename, local, translate_then_pca';
% filenames_examples{8}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
% aux_ins{8}=struct;
% aux_ins{8}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
% aux_ins{8}.nsets=3;
% auxs{8}=struct;
% auxs{8}.opts_xform.mode='translate_then_pca';
% auxs{8}.opts_xform.source='local';
% auxs{8}.opts_xform.centering_specifier='typename';
% auxs{8}.opts_xform.centering_typname='bp0600';
% if if_ignore_svdambig
%     ignore{1,8}={{'xform_out','ts'}};
%     ignore{2,8}={{'xform_out','ts'},{'data_out','ds'}};
% end
% %
% fns=cell(nsubmodules,ntests);
% ifdif=cell(nsubmodules,ntests);
% for itest=1:ntests
%     if ((aux_ins{itest}.opts_read.if_auto==1) | (if_auto_skip==0))
%         aux_ins{itest}.opts_read.if_log=0;
%         [data_reads{itest},aux_reads{itest}]=rs_get_coordsets(filenames_examples{itest},aux_ins{itest});
%         %
%         %xform_specify
%         [xforms{itest},aux_outs{1,itest}]=rs_xform_specify(data_reads{itest},auxs{itest});
%         %
%         fns{1,itest}=sprintf('rs_%s_test_%1.0f',rs_submodules{1},itest);
%         s=struct;
%         s.data_read=data_reads{itest};
%         s.aux_out=aux_outs{1,itest};
%         s.xform_out=xforms{itest};
%         rs_save_mat(cat(2,'tests',filesep,fns{1,itest}),s);
%         %
%         %xform_apply
%         [data_outs{itest},aux_outs{2,itest}]=rs_xform_apply(data_reads{itest},xforms{itest},struct());
%         %
%         fns{2,itest}=sprintf('rs_%s_test_%1.0f',rs_submodules{2},itest);
%         s=struct;
%         s.data_out=data_outs{itest};
%         s.aux_out=aux_outs{2,itest};
%         s.xform_out=xforms{itest};
%         rs_save_mat(cat(2,'tests',filesep,fns{2,itest}),s);
%     end
% end
