% rs_align_coordsets_test: test rs_align_coordsets
%
%  See also:  RS_ALIGN_COORDSETS, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='align_coordsets';
if ~exist('if_auto_skip') %set to 1 to skip non-interactive tests
    if_auto_skip=0;
end
%section to force btc defaults, even if rs_aux_defaults.mat has been created or modified
if ~exist('aux_force_filename') aux_force_filename='rs_aux_defaults_btc.mat'; end
auxs_force=struct;
opts_needed={'opts_read','opts_rays','opts_check','opts_align','opts_import','opts_qpred'};
for k=1:length(opts_needed)
    auxs_force.(opts_needed{k})=rs_aux_force(opts_needed{k},[],aux_force_filename);
end
%
ntests=6;
%
test_descs=cell(1,ntests);
filenames_examples=cell(1,ntests);
auxs=cell(1,ntests);
signflips=cell(1,ntests);
aux_ins=cell(1,ntests);
data_reads=cell(1,ntests);
aux_reads=cell(1,ntests);
opts_used=cell(1,ntests);
%
data_outs=cell(1,ntests);
aux_outs=cell(1,ntests);
%
test_descs{1}='non-interactive reading of three binary texture coordinate files, no logging';
filenames_examples{1}={'./samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_NF_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_SN_sess01_10.mat'};
auxs{1}=auxs_force;
aux_ins{1}=auxs_force;
aux_ins{1}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,0});
aux_ins{1}.nsets=3;
%
test_descs{2}='non-interactive reading of three binary texture coordinate files, second file is a model, logging';
filenames_examples{2}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_NF-br_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_SN-br_sess01_10.mat'};
auxs{2}=auxs_force;
aux_ins{2}=auxs_force;
aux_ins{2}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{[1 2],1,1});
aux_ins{2}.nsets=3;
signflips{2}={{'data_out','ds'}};
%
test_descs{3}='non-interactive reading of two binary texture coordinate files, stimuli disagree, logging, keep only if stimuli present in both';
filenames_examples{3}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat'};
auxs{3}=auxs_force;
aux_ins{3}=auxs_force;
auxs{3}.opts_align.min=2;
aux_ins{3}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{3}.nsets=2;
%
test_descs{4}='non-interactive reading of four animal-domain files';
filenames_examples{4}={'./samples/animals/image_coords_S3','./samples/animals/image_coords_S4','./samples/animals/image_coords_S5','./samples/animals/image_coords_S6'};
auxs{4}=auxs_force;
aux_ins{4}=auxs_force;
aux_ins{4}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{4}.nsets=4;
%
test_descs{5}='interactive reading of one coordinate file';
filenames_examples{5}={};
auxs{5}=auxs_force;
aux_ins{5}=auxs_force;
aux_ins{5}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log','if_gui'},{1,0,1,0});
aux_ins{5}.nsets=1;
%
test_descs{6}='non-interactive reading of two binary texture coordinate files, stimuli disagree, logging, keep only if stimuli present in either';
filenames_examples{6}={'./samples/bwtextures/bgca3pt_coords_MC-br_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat'};
auxs{6}=auxs_force;
aux_ins{6}=auxs_force;
auxs{6}=struct;
auxs{6}.opts_align.min=1;
aux_ins{6}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{6}.nsets=2;
%
if if_auto_skip==0
    disp('Suggest ''enter'' to accept the default for interactive responses.');
    if_ok=0;
    while (if_ok==0)
        if_ok=getinp('1 if OK to proceed','d',[0 1],1);
    end
end
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    if ((aux_ins{itest}.opts_read.if_auto==1) | (if_auto_skip==0))
        disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
        aux_ins{itest}.opts_read.if_log=0;
        [data_reads{itest},aux_reads{itest}]=rs_get_coordsets(filenames_examples{itest},aux_ins{itest});
        %
        auxs{itest}.opts_align.if_log=1;
        [data_outs{itest},aux_outs{itest}]=rs_align_coordsets(data_reads{itest},auxs{itest});
        %
        fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
        s=struct;
        s.data_out=data_outs{itest};
        s.aux_out=aux_outs{itest};
        rs_save_mat(cat(2,'tests',filesep,fns{itest}),s);
    end
end
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
for itest=1:ntests
    if ~isempty(data_outs{itest})
        disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
        [ifdif{itest},opts_used{itest}]=rs_benchmark_compare(fns{itest},setfield(struct,'signflips',signflips{itest}));
        if ~isempty(aux_outs{itest}.warnings)
            disp('warnings encountered during test:')
            disp(aux_outs{itest}.warnings)
        end
    end
end
