% rs_geofit_pw_test: test rs_geofit, piecewise model options
%
%  See also:  RS_GEOFIT, RS_BENCHMARK_COMPARE, RS_SAVE_MAT.
%
rs_module='geofit_pw';
if ~exist('if_auto_skip') %set to 1 to skip non-interactive tests
    if_auto_skip=0;
end
%
%section to force btc defaults, even if rs_aux_defaults.mat has been created or modified
if ~exist('aux_force_filename') aux_force_filename='rs_aux_defaults_btc.mat'; end
auxs_force=struct;
opts_needed={'opts_read','opts_rays','opts_check','opts_geof','opts_qpred'};
for k=1:length(opts_needed)
    auxs_force.(opts_needed{k})=rs_aux_force(opts_needed{k},[],aux_force_filename);
end
%
ntests=2;
%
test_descs=cell(1,ntests);
filenames_in=cell(1,ntests);
filenames_out=cell(1,ntests);
aux_ins=cell(1,ntests);
aux_outs=cell(1,ntests);
data_ins=cell(1,ntests);
data_outs=cell(1,ntests);
%
auxs=cell(1,ntests);
gfs=cell(1,ntests);
xs=cell(1,ntests);
aux_geofits=cell(1,ntests);
%
opts_used=cell(1,ntests);
signflips=cell(1,ntests);
%
test_descs{1}='transforming a binary texture coordinate files to another, selected standard nesting, leteq dims up to 4';
filenames_in{1}={'./samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat'};
auxs{1}=auxs_force;
aux_ins{1}=auxs_force;
aux_ins{1}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{1}.nsets=1;
filenames_out{1}={'./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat'};
aux_outs{1}=aux_ins{1};
auxs{1}.opts_geof.model_list={'procrustes_scale_offset','affine_offset','pwaffine'};
auxs{1}.opts_geof.dimpairs_method='din_lteq_dout';
auxs{1}.opts_geof.if_stats=1;
auxs{1}.opts_geof.nshuffs=3;
auxs{1}.opts_geof.dim_max_in=4;
auxs{1}.opts_geof.dim_max_out=4;
%
%
test_descs{2}='transforming a binary texture coordinate files to another, selected models but fixed choice for piecewise affine cuts, standard nesting, leteq dims up to 4';
filenames_in{2}={'./samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat'};
auxs{2}=auxs_force;
aux_ins{2}=auxs_force;
aux_ins{2}.opts_read=setfields(auxs_force.opts_read,{'input_type','if_auto','if_log'},{1,1,1});
aux_ins{2}.nsets=1;
filenames_out{2}={'./samples/bwtextures/bgca3pt_coords_BL-br_sess01_10.mat'};
aux_outs{2}=aux_ins{2};
auxs{2}.opts_geof.model_list={'procrustes_scale_offset','affine_offset','pwaffine'};
auxs{2}.opts_geof.dimpairs_method='din_lteq_dout';
auxs{2}.opts_geof.if_stats=1;
auxs{2}.opts_geof.nshuffs=3;
auxs{2}.opts_geof.dim_max_in=4;
auxs{2}.opts_geof.dim_max_out=4;
%
fns=cell(1,ntests);
ifdif=cell(1,ntests);
for itest=1:ntests
    if ((aux_ins{itest}.opts_read.if_auto==1) | (if_auto_skip==0))
        disp(sprintf('testing rs_%s: %s',rs_module,test_descs{itest}));
        %read the input and output data structures
        aux_ins{itest}.opts_read.if_log=0;
        [data_ins{itest},aux_read_ins{itest}]=rs_get_coordsets(filenames_in{itest},aux_ins{itest});
        %
        aux_outs{itest}.opts_read.if_log=0;
        [data_outs{itest},aux_read_outs{itest}]=rs_get_coordsets(filenames_out{itest},aux_outs{itest});
        %
        [gfs{itest},xs{itest},aux_geofits{itest}]=rs_geofit(data_ins{itest},data_outs{itest},auxs{itest});
        %
        fns{itest}=sprintf('rs_%s_test_%1.0f',rs_module,itest);
        s=struct;
        s.data_in=data_outs{itest};
        s.data_out=data_outs{itest};
        s.aux_ins=aux_ins{itest};
        s.aux_outs=aux_ins{itest};
        s.gfs=gfs{itest};
        s.xs=xs{itest};
        s.aux_geofits=aux_geofits{itest};
        %
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
        if ~isempty(aux_read_ins{itest}.warnings)
            disp('warnings encountered during reading of input data:')
            disp(aux_read_ins{itest}.warnings)
        end
        if ~isempty(aux_read_outs{itest}.warnings)
            disp('warnings encountered during reading of output data:')
            disp(aux_read_outs{itest}.warnings)
        end
        if ~isempty(aux_geofits{itest}.warnings)
            disp('warnings encountered during geofit:')
            disp(aux_geofits{itest}.warnings)
        end
        
    end
end
