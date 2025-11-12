%rs_auto_test: run all tests in automatic mode
if ~exist('if_auto_skip')
    if_auto_skip=1;
end
r=struct;
%
rs_aux_customize_test;
r.(rs_module).ifdif=ifdif;
r.(rs_module).aux_outs=aux_outs;
%
rs_get_coordsets_test;
r.(rs_module).ifdif=ifdif;
r.(rs_module).data_outs=data_outs;
r.(rs_module).aux_outs=aux_outs;
%
rs_read_coorddata_test;
r.(rs_module).ifdif=ifdif;
r.(rs_module).data_outs=data_outs;
r.(rs_module).aux_outs=aux_outs;
r.(rs_module).ifdif2_data=ifdif2_data;
r.(rs_module).ifdif2_aux=ifdif2_aux;
%
rs_align_coordsets_test;
r.(rs_module).ifdif=ifdif;
r.(rs_module).data_outs=data_outs;
r.(rs_module).aux_outs=aux_outs;
%
rs_knit_coordsets_test;
r.(rs_module).ifdif=ifdif;
r.(rs_module).data_outs=data_outs;
r.(rs_module).aux_outs=aux_outs;
%
rs_xform_specify_test;
r.(rs_module).ifdif=ifdif;
r.(rs_module).data_reads=data_reads;
r.(rs_module).xforms=xforms;
r.(rs_module).aux_outs=aux_outs;
%
rs_xform_specify_apply_test;
r.(rs_module).ifdif=ifdif;
r.(rs_module).data_reads=data_reads;
r.(rs_module).xforms=xforms;
r.(rs_module).aux_outs=aux_outs;
r.(rs_module).data_outs=data_outs;
%
disp('%%%%%%%')
disp('summary')
disp('%%%%%%%')
disp(sprintf('date: %s',date))
disp(sprintf('working directory: %s',pwd))
disp(pwd);
ver
rs_modules=fieldnames(r);
for irs=1:length(rs_modules)
    rs_module=rs_modules{irs};
    diff_list=zeros(1,length(r.(rs_module).ifdif(:)));
    run_list=zeros(1,length(r.(rs_module).ifdif(:)));
    for id=1:length(r.(rs_module).ifdif(:))
        diff_list(id)=~isempty(r.(rs_module).ifdif{id});
        run_list(id)=~isempty(r.(rs_module).aux_outs{id});
    end
    r.(rs_module).diff_list=reshape(diff_list,size(r.(rs_module).ifdif));
    disp(sprintf('%20s: %3.0f tests of %3.0f show differences (%3.0f skipped in auto mode)',rs_module,sum(diff_list),sum(run_list),length(run_list)-sum(run_list)));
    if sum(diff_list)>0
        for idiff=find(diff_list>0)
            disp(sprintf(' test %2.0f:',idiff));
            disp(r.(rs_module).ifdif{idiff});
        end
    end
end
