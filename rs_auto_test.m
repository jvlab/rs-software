%rs_auto_test: run all tests in automatic mode
if ~exist('if_auto_skip')
    if_auto_skip=1;
end
if ~exist('if_ignore_svdambig')
    if_ignore_svdambig=0; 
end
if ~exist('diff_maxchars')
    diff_maxchars=70;   
end
if ~exist('diff_maxlines')
    diff_maxlines=3;
end
%
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
alldiffs=0;
for irs=1:length(rs_modules)
    rs_module=rs_modules{irs};
    diff_list=zeros(1,length(r.(rs_module).ifdif(:)));
    run_list=zeros(1,length(r.(rs_module).ifdif(:)));
    for id=1:length(r.(rs_module).ifdif(:)) %r.(rs_module).ifdif is [submodules x tests/submodules]
        diff_list(id)=~isempty(r.(rs_module).ifdif{id});
        run_list(id)=~isempty(r.(rs_module).aux_outs{id});
    end
    r.(rs_module).diff_list=reshape(diff_list,size(r.(rs_module).ifdif));
    disp(sprintf('%20s: %3.0f tests of %3.0f show differences (%3.0f skipped in auto mode)',rs_module,sum(diff_list),sum(run_list),length(run_list)-sum(run_list)));
    if sum(diff_list)>0
        nsubmodules=size(r.(rs_module).ifdif,1);
        for idiff=find(diff_list>0)
            disp(sprintf(' test %2.0f (sequential test %3.0f, sub-module %3.0f):',idiff,...
                ceil(idiff/nsubmodules),mod(idiff-1,nsubmodules)+1));
            diff_show=r.(rs_module).ifdif{idiff};
            if diff_maxchars<Inf
                if size(diff_show,2)>diff_maxchars
                    diff_show=diff_show(:,1:diff_maxchars);
                end
            end
            if diff_maxlines<Inf
                if size(diff_maxlines,1)<diff_maxlines
                    diff_show=strvcat(diff_show(1:diff_maxlines-1,:),'  ...',diff_show(end,:));
                end
            end
            disp(diff_show);
        end
        alldiffs=alldiffs+sum(diff_list);
    end
end
disp(sprintf('run with if_auto_skip=%1.0f, if_ignore_svdambig=%1.0f',if_auto_skip,if_ignore_svdambig));
disp(sprintf('total number of tests with differences: %4.0f',alldiffs));
if alldiffs>0
    disp('Consider re-running with if_ignore_svdambig=1 to ignore differences related to implementations of singular value decomposition');
    disp(sprintf('Condider re-running with diff_maxchars or diff_maxlines set to larger values (currently: %4.0f and %4.0f ) to show more differences',diff_maxchars,diff_maxlines));
end
