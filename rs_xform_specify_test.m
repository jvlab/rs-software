% rs_xform_specify_test: test rs_xform_specify
%
%  See also:  RS_XFORM_SPECIFY, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='xform_specify';
if ~exist('if_auto_skip') %set to 1 to skip non-interactive tests
    if_auto_skip=0;
end
%
ntests=7;
%
test_descs=cell(1,ntests);
filenames_examples=cell(1,ntests);
auxs=cell(1,ntests);
data_reads=cell(1,ntests);
aux_ins=cell(1,ntests);
xforms=cell(1,ntests);
aux_outs=cell(1,ntests);
auxs=cell(1,ntests);
%
test_descs{1}='three binary texture coordinate files, second file is a model, no centering';
filenames_examples{1}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_NF-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
aux_ins{1}=struct;
aux_ins{1}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{[1 2],1,1});
aux_ins{1}.nsets=3;
auxs{1}=struct;
%
test_descs{2}='three binary texture coordinate files, second file is a model, centering by typename, global, translate';
filenames_examples{2}=filenames_examples{1};
aux_ins{2}=aux_ins{1};
auxs{2}=struct;
auxs{2}.opts_xform.mode='translate';
auxs{2}.opts_xform.source='global';
auxs{2}.opts_xform.centering_specifier='typename';
auxs{2}.opts_xform.centering_typename='bp0600';
%
test_descs{3}='four animal-domain files, centering by typename, local';
filenames_examples{3}={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S4','./samples/animals/image_coords_S5','./samples/animals/image_coords_S6'};
aux_ins{3}=struct;
aux_ins{3}.opts_read=setfields(struct(),{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{3}.nsets=4;
auxs{3}=struct;
auxs{3}.opts_xform.mode='translate';
auxs{3}.opts_xform.source='local';
auxs{3}.opts_xform.centering_specifier='typename';
auxs{3}.opts_xform.centering_typename='ant';
%
test_descs{4}='four animal-domain files, centering by centroid, source = set 2';
filenames_examples{4}=filenames_examples{3};
aux_ins{4}=aux_ins{3};
auxs{4}=struct;
auxs{4}.opts_xform.mode='translate';
auxs{4}.opts_xform.source=2;
auxs{4}.opts_xform.centering_specifier='centroid';
%
test_descs{5}='four animal-domain files, centering by fixed value';
filenames_examples{5}=filenames_examples{3};
aux_ins{5}=aux_ins{3};
auxs{5}=struct;
auxs{5}.opts_xform.mode='translate';
auxs{5}.opts_xform.source='global';
auxs{5}.opts_xform.centering_specifier='value';
auxs{5}.opts_xform.centering_value=0.1*[1:10];
%
test_descs{6}='four animal-domain files, centering by index, global, offset_pca';
filenames_examples{6}=filenames_examples{3};
aux_ins{6}=aux_ins{3};
auxs{6}=struct;
auxs{6}.opts_xform.mode='offset_pca';
auxs{6}.opts_xform.source='global';
auxs{6}.opts_xform.centering_specifier='index';
auxs{6}.opts_xform.centering_index=17;
%
test_descs{7}='four animal-domain files, centering by index, global, translate then pca';
filenames_examples{7}=filenames_examples{3};
aux_ins{7}=aux_ins{3};
auxs{7}=struct;
auxs{7}.opts_xform.mode='translate_then_pca';
auxs{7}.opts_xform.source='local';
auxs{7}.opts_xform.centering_specifier='index';
auxs{7}.opts_xform.centering_index=17;
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    if ((aux_ins{itest}.opts_read.if_auto==1) | (if_auto_skip==0))
        aux_ins{itest}.opts_read.if_log=0;
        [data_reads{itest},aux_reads{itest}]=rs_get_coordsets(filenames_examples{itest},aux_ins{itest});
        %
        [xforms{itest},aux_outs{itest}]=rs_xform_specify(data_reads{itest},auxs{itest});
        %
        fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
        s=struct;
        s.data_read=data_reads{itest};
        s.aux_out=aux_outs{itest};
        s.xform_out=xforms{itest};
        rs_save_mat(cat(2,'tests',filesep,fns{itest}),s);
    end
end
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
for itest=1:ntests
    if ~isempty(data_reads{itest})
        disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
        [ifdif{itest},opts_used{itest}]=rs_benchmark_compare(fns{itest});
        if ~isempty(aux_outs{itest}.warnings)
            disp('warnings encountered during test:')
            disp(aux_outs{itest}.warnings)
        end
    end
end
