% rs_xform_specify_apply_test: test rs_xform_specify and rs_xform_apply
%
% Note that for any nontrivial transformation, no btc model is used,
% to avoid system-dependent variations in the results of svd when qform models are created
%
%  See also:  RS_XFORM_SPECIFY, RS_XFORM_SPECIFY_TEST, RS_XFORM_APPLY, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='xform_specify_apply';
rs_submodules={'xform_specify','xform_apply'};
nsubmodules=length(rs_submodules);
if ~exist('if_auto_skip') %set to 1 to skip non-interactive tests
    if_auto_skip=0;
end
if ~exist('if_ignore_svdambig')
    if_ignore_svdambig=0;
end
%
ntests=8;
%
test_descs=cell(1,ntests);
filenames_examples=cell(1,ntests);
auxs=cell(1,ntests);
signflips=cell(1,ntests);
ignore=cell(nsubmodules,ntests);
data_reads=cell(1,ntests);
aux_ins=cell(1,ntests);
xforms=cell(1,ntests);
aux_outs=cell(nsubmodules,ntests);
auxs=cell(1,ntests);
data_outs=cell(1,ntests);
%
test_descs{1}='three binary texture coordinate files, second file is a model, no centering';
filenames_examples{1}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
aux_ins{1}=struct;
aux_ins{1}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{[1 2],1,1});
aux_ins{1}.nsets=3;
auxs{1}=struct;
signflips{1}={{'data_read','ds'},{'data_out','ds'}};
%
test_descs{2}='four animal-domain files, centering by typename, global, translate';
filenames_examples{2}={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S4','./samples/animals/image_coords_S5','./samples/animals/image_coords_S6'};
aux_ins{2}=struct;
aux_ins{2}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{2}.nsets=4;
auxs{2}=struct;
auxs{2}.opts_xform.mode='translate';
auxs{2}.opts_xform.source='global';
auxs{2}.opts_xform.centering_specifier='typename';
auxs{2}.opts_xform.centering_typename='ant';
%
test_descs{3}='four animal-domain files, centering by typename, local, translate';
filenames_examples{3}=filenames_examples{2};
aux_ins{3}=aux_ins{2};
auxs{3}=struct;
auxs{3}.opts_xform.mode='translate';
auxs{3}.opts_xform.source='local';
auxs{3}.opts_xform.centering_specifier='typename';
auxs{3}.opts_xform.centering_typename='ant';
%
test_descs{4}='four animal-domain files, centering by centroid, source = set 2, translate';
filenames_examples{4}=filenames_examples{2};
aux_ins{4}=aux_ins{2};
auxs{4}=struct;
auxs{4}.opts_xform.mode='translate';
auxs{4}.opts_xform.source=2;
auxs{4}.opts_xform.centering_specifier='centroid';
%
test_descs{5}='four animal-domain files, centering by fixed value, translate';
filenames_examples{5}=filenames_examples{2};
aux_ins{5}=aux_ins{2};
auxs{5}=struct;
auxs{5}.opts_xform.mode='translate';
auxs{5}.opts_xform.source='global';
auxs{5}.opts_xform.centering_specifier='value';
auxs{5}.opts_xform.centering_value=0.1*[1:10];
%
test_descs{6}='four animal-domain files, centering by index, global, offset_pca';
filenames_examples{6}=filenames_examples{2};
aux_ins{6}=aux_ins{2};
auxs{6}=struct;
auxs{6}.opts_xform.mode='offset_pca';
auxs{6}.opts_xform.source='global';
auxs{6}.opts_xform.centering_specifier='index';
auxs{6}.opts_xform.centering_index=17;
if if_ignore_svdambig
    ignore{1,6}={{'xform_out','ts'}};
    ignore{2,6}={{'xform_out','ts'},{'data_out','ds'}};
end
%
test_descs{7}='four animal-domain files, centering by index, global, translate_then_pca';
filenames_examples{7}=filenames_examples{2};
aux_ins{7}=aux_ins{2};
auxs{7}=struct;
auxs{7}.opts_xform.mode='translate_then_pca';
auxs{7}.opts_xform.source='local';
auxs{7}.opts_xform.centering_specifier='index';
auxs{7}.opts_xform.centering_index=17;
if if_ignore_svdambig
    ignore{1,7}={{'xform_out','ts'}};
    ignore{2,7}={{'xform_out','ts'},{'data_out','ds'}};
end
%
test_descs{8}='three binary texture coordinate files, no models, centering by typename, local, translate_then_pca';
filenames_examples{8}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
aux_ins{8}=struct;
aux_ins{8}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{8}.nsets=3;
auxs{8}=struct;
auxs{8}.opts_xform.mode='translate_then_pca';
auxs{8}.opts_xform.source='local';
auxs{8}.opts_xform.centering_specifier='typename';
auxs{8}.opts_xform.centering_typename='bp0600';
if if_ignore_svdambig
    ignore{1,8}={{'xform_out','ts'}};
    ignore{2,8}={{'xform_out','ts'},{'data_out','ds'}};
end
%
fns=cell(nsubmodules,ntests);
ifdif=cell(nsubmodules,ntests);
for itest=1:ntests
    if ((aux_ins{itest}.opts_read.if_auto==1) | (if_auto_skip==0))
        aux_ins{itest}.opts_read.if_log=0;
        [data_reads{itest},aux_reads{itest}]=rs_get_coordsets(filenames_examples{itest},aux_ins{itest});
        %
        %xform_specify
        [xforms{itest},aux_outs{1,itest}]=rs_xform_specify(data_reads{itest},auxs{itest});
        %
        fns{1,itest}=sprintf('rs_%s_test_%1.0f',rs_submodules{1},itest);
        s=struct;
        s.data_read=data_reads{itest};
        s.aux_out=aux_outs{1,itest};
        s.xform_out=xforms{itest};
        rs_save_mat(cat(2,'tests',filesep,fns{1,itest}),s);
        %
        %xform_apply
        [data_outs{itest},aux_outs{2,itest}]=rs_xform_apply(data_reads{itest},xforms{itest},struct());
        %
        fns{2,itest}=sprintf('rs_%s_test_%1.0f',rs_submodules{2},itest);
        s=struct;
        s.data_out=data_outs{itest};
        s.aux_out=aux_outs{2,itest};
        s.xform_out=xforms{itest};
        rs_save_mat(cat(2,'tests',filesep,fns{2,itest}),s);
    end
end
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
for itest=1:ntests
    if ~isempty(data_reads{itest})
         for isub=1:nsubmodules
            disp(sprintf('testing rs_%s: %s (sequential test %3.0f, sub-module %3.0f)',rs_module,test_descs{itest},itest,isub));
            opts_compare=struct;
            opts_compare.signflips=signflips{itest};
            opts_compare.ignore=ignore{isub,itest};
            [ifdif{isub,itest},opts_used{isub,itest}]=rs_benchmark_compare(fns{isub,itest},opts_compare);
            if ~isempty(aux_outs{isub,itest}.warnings)
                disp('warnings encountered during test:')
                disp(aux_outs{isub,itest}.warnings)
            end
        end
    end
end
