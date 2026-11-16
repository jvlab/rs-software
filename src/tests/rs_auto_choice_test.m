%rs_auto_choice_test: run all tests for the choice analyses in automati mode 
% (rs_dirfit_choicedata is called by rs_symumi_choicedata and rs_addtree_choicedata, and not tested explicitly)
%
if ~exist('if_auto_skip')  if_auto_skip=1; end %by default, skip modules that require keyboard input
if ~exist('if_ignore_svdambig') if_ignore_svdambig=0; end
if ~exist('diff_maxchars') diff_maxchars=70; end 
if ~exist('diff_maxlines') diff_maxlines=3; end
if ~exist('if_save_and_close') if_save_and_close=1; end %for graphics tests
if ~exist('aux_force_filename') aux_force_filename='rs_aux_defaults_btc.mat'; end %so that tests run with btc defaults
%
r=struct;
%
%input modules
%
clear ifdif
rs_read_choicedata_test;
r.(rs_module).ifdif=ifdif;
r.(rs_module).data_outs=data_comps;
r.(rs_module).aux_outs=aux_reads;
%
%analysis modules
%
clear ifdif
rs_symumi_choicedata_test;
r.(rs_module).ifdif=ifdif;
r.(rs_module).data_outs=sus;
r.(rs_module).aux_outs=aux_symumi_outs;
%
clear ifdif
rs_addtree_choicedata_test;
r.(rs_module).ifdif=ifdif;
r.(rs_module).data_outs=ads;
r.(rs_module).aux_outs=aux_addtree_outs;
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
disp('results of comparisons with benchmarks: choice analyses')
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
disp(sprintf('date: %s',date))
disp(sprintf('working directory: %s',pwd))
disp(pwd);
ver
rs_modules=fieldnames(r);
alldiffs=0;
summ_strings=cell(1,length(rs_modules));
for irs=1:length(rs_modules)
    rs_module=rs_modules{irs};
    diff_list=zeros(1,length(r.(rs_module).ifdif(:)));
    run_list=zeros(1,length(r.(rs_module).ifdif(:)));
    for id=1:length(r.(rs_module).ifdif(:)) %r.(rs_module).ifdif is [submodules x tests/submodules]
        diff_list(id)=~isempty(r.(rs_module).ifdif{id});
        run_list(id)=~isempty(r.(rs_module).aux_outs{id});
    end
    r.(rs_module).diff_list=reshape(diff_list,size(r.(rs_module).ifdif));
    summ_strings{irs}=...
        sprintf('%20s: %3.0f tests of %3.0f show differences (%3.0f skipped in auto mode)',rs_module,sum(diff_list),sum(run_list),length(run_list)-sum(run_list));
    disp(summ_strings{irs});
    if sum(diff_list)>0
        nsubmodules=size(r.(rs_module).ifdif,1);
        for idiff=find(diff_list>0)
            disp(sprintf(' test %2.0f (sequential test %3.0f, sub-module %3.0f):',idiff,...
                ceil(idiff/nsubmodules),mod(idiff-1,nsubmodules)+1));
            diff_show=r.(rs_module).ifdif{idiff};
            if size(diff_show,2)>diff_maxchars
                diff_show=diff_show(:,1:diff_maxchars);
            end
            if size(diff_show,1)>diff_maxlines
                diff_show=strvcat(diff_show(1:diff_maxlines-1,:),'  ...',diff_show(end,:));
            end
            disp(diff_show);
        end
        alldiffs=alldiffs+sum(diff_list);
    end
end
disp(sprintf('run with if_auto_skip=%1.0f, if_ignore_svdambig=%1.0f, if_save_and_close=%1.0f',...
    if_auto_skip,if_ignore_svdambig,if_save_and_close));
disp(sprintf('total number of tests with differences: %4.0f',alldiffs));
r_diffs=struct;
if alldiffs>0
    disp('%%%%%%%%%%%%%%%%%%%%%%')
    disp('summary of differences')
    disp('%%%%%%%%%%%%%%%%%%%%%%')
    for irs=1:length(rs_modules)
        rs_module=rs_modules{irs};
        if sum(r.(rs_module).diff_list(:))>0
            disp(summ_strings{irs});
            r_diffs.(rs_module)=r.(rs_module);
        end
    end
    disp('Consider re-running with if_ignore_svdambig=1 to ignore differences related to implementations of singular value decomposition');
    disp(sprintf('Consider re-running with diff_maxchars or diff_maxlines set to larger values (currently: %4.0f and %4.0f ) to show more differences',diff_maxchars,diff_maxlines));
    disp('Look in r_diffs for details of differences');
    disp(r_diffs);
end
