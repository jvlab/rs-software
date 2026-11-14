function rs_subset_choicesets_test()
% rs_subset_choicesets_test()
% tests rs_subset_choicesets on four sample choice files, as loaded by load():
%   triadic (bwtextures), tetradic (bwtextures), triadic (animals), and odd-one-out (brightness).
% The trials that remain, their renumbering, and the stimulus names must follow the stimuli that are kept,
% and everything else must come back untouched.  The expected results are worked out here, in MATLAB,
% independently of Python.
%
% Run from any folder:  rs_subset_choicesets_test
% In MATLAB this uses the Python interface (pyenv); in Octave it uses the command line.
% Needs Python with numpy and scipy, and the lab's perceptual_space_geometry folders on the path
% (rs_subset_choicesets itself puts the rs-software folder with rs_tools on Python's path).
%
%  See also: RS_SUBSET_CHOICESETS, RS_SUBSET_COORDSETS_TEST.
%
here=fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..'));
if isempty(which('filldefault'))
    error('rs_subset_choicesets_test: the lab''s perceptual_space_geometry folders must be on the path (filldefault not found).');
end
samples=fullfile(here,'..','samples');
%                  file                                                          label         stimulus columns  regex
cases={ fullfile(samples,'bwtextures','bc6pt_choices_SAW_sess01_10.mat'),        'triadic',    3,  '^[bc]';...
        fullfile(samples,'bwtextures','bgca3pt_choices_MC-gm_sess01_10.mat'),    'tetradic',   4,  '^[abc]';...
        fullfile(samples,'animals','texture_choices_S3.mat'),                    'triadic',    3,  '^[a-m]';...
        fullfile(samples,'brightness','brightness_choices-ooo_GA2.mat'),         'odd-one-out',3,  '^s0[1-5]'};
nfail=0;
quiet=struct('opts_subset',struct('if_log',0),'opts_check',struct('if_warn',0));
%
for icase=1:size(cases,1)
    file=cases{icase,1};
    [~,fname]=fileparts(file);
    label=cases{icase,2};
    n_idx=cases{icase,3};
    pattern=cases{icase,4};
    d=load(file);
    d.note='this field must come back untouched';
    names=strtrim(cellstr(d.stim_list));
    n=length(names);
    ntrials=size(d.responses,1);
    tag0=sprintf('%s (%s, %d trials, %d stimuli)',fname,label,ntrials,n);
    %
    % keep_all (the default) returns the input unchanged
    [data_out,aux_out]=rs_subset_choicesets(d,quiet);
    if aux_out.warn_bad>0 && icase==1
        % the first call is the simplest one; if it fails, nothing else can work, so stop with a clear message
        disp(aux_out.warnings);
        error('rs_subset_choicesets_test: the first call failed, so the other checks cannot run. The message above is what Python reported; see README.txt for Python setup.');
    end
    nfail=nfail+check(aux_out.warn_bad==0 && isequal(data_out,d),[tag0 ': keep_all returns every variable identical']);
    nfail=nfail+check(isequal(aux_out.kept_indices,1:n) && isequal(aux_out.ntrials,[ntrials ntrials]),[tag0 ': keep_all kept_indices and ntrials']);
    %
    % regex
    keep=find(~cellfun(@isempty,regexp(names,pattern,'once')))';
    expected=expected_subset(d.responses,n_idx,keep);
    aux=quiet;
    aux.opts_subset.filter_type='regex';
    aux.opts_subset.filter_pattern=pattern;
    [data_out,aux_out]=rs_subset_choicesets(d,aux);
    tag=sprintf('%s, regex %s (%d of %d stimuli, %d of %d trials)',fname,pattern,length(keep),n,size(expected,1),ntrials);
    nfail=nfail+check(aux_out.warn_bad==0,[tag ': no warnings']);
    nfail=nfail+check(isequal(data_out.responses,expected),[tag ': remaining trials are renumbered correctly']);
    nfail=nfail+check(isequal(data_out.stim_list,d.stim_list(keep,:)),[tag ': stimulus names are the kept rows, with the same padding']);
    nfail=nfail+check(isequal(data_out.responses_colnames,d.responses_colnames) && isequal(data_out.note,d.note),[tag ': column names and other fields untouched']);
    nfail=nfail+check(isequal(aux_out.kept_indices,keep) && isequal(aux_out.ntrials,[ntrials size(expected,1)]),[tag ': kept_indices and ntrials']);
    keep_rows=all(ismember(d.responses(:,1:n_idx),keep),2);
    nfail=nfail+check(isequal(data_out.responses(:,n_idx+1:end),d.responses(keep_rows,n_idx+1:end)),[tag ': count columns are not changed']);
end
%
% include in a different order, alphabetize, exclude, and a cell array of names (triadic animals)
d=load(cases{3,1});
names=strtrim(cellstr(d.stim_list));
n=length(names);
pick=names([30 4 12 25 2 18 9 33 21 7 15 27 1 36 11 20 5 24]);
aux=quiet;
aux.opts_subset.filter_type='include';
aux.opts_subset.filter_pattern=pick;
keep=find(ismember(names,pick))';
[data_out,aux_out]=rs_subset_choicesets(d,aux);
nfail=nfail+check(aux_out.warn_bad==0 && isequal(data_out.stim_list,d.stim_list(keep,:)) && isequal(data_out.responses,expected_subset(d.responses,3,keep)),...
    'include: keeps the named stimuli, in their original order');
aux.opts_subset.alphabetize=1;
[~,o]=sort(names(keep));
order=keep(o);
[data_out,aux_out]=rs_subset_choicesets(d,aux);
nfail=nfail+check(aux_out.warn_bad==0 && isequal(data_out.stim_list,d.stim_list(order,:)) && isequal(data_out.responses,expected_subset(d.responses,3,order)) && isequal(aux_out.kept_indices,order),...
    'include + alphabetize: stimuli are in alphabetical order and the trials are renumbered to match');
aux=quiet;
aux.opts_subset.filter_type='exclude';
aux.opts_subset.filter_pattern=names([3 14 22]);
keep=setdiff(1:n,[3 14 22]);
[data_out,aux_out]=rs_subset_choicesets(d,aux);
nfail=nfail+check(aux_out.warn_bad==0 && isequal(data_out.stim_list,d.stim_list(keep,:)) && isequal(data_out.responses,expected_subset(d.responses,3,keep)),'exclude: drops the named stimuli');
dc=d;
dc.stim_list=names;                                       % a cell array of names instead of a character array
aux=quiet;
aux.opts_subset.filter_type='regex';
aux.opts_subset.filter_pattern='^[a-m]';
keep=find(~cellfun(@isempty,regexp(names,'^[a-m]','once')))';
[data_out,aux_out]=rs_subset_choicesets(dc,aux);
nfail=nfail+check(aux_out.warn_bad==0 && iscell(data_out.stim_list) && isequal(data_out.stim_list,names(keep)) && isequal(data_out.responses,expected_subset(d.responses,3,keep)),...
    'stim_list given as a cell array: comes back as a cell array, same result');
%
% no trials left: a trial needs 3 (or 4) kept stimuli, so two kept stimuli leave none
aux=quiet;
aux.opts_subset.filter_type='include';
aux.opts_subset.filter_pattern=names([1 2]);
[data_out,aux_out]=rs_subset_choicesets(d,aux);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'No trials left after filtering')) && isempty(fieldnames(data_out)),'two stimuli kept, no trial uses only them: warn_bad=1 and says No trials left after filtering');
%
% problems are reported by Python and shown in aux_out, with a readable message
aux=quiet;
aux.opts_subset.filter_type='regex';
aux.opts_subset.filter_pattern='*B';
[data_out,aux_out]=rs_subset_choicesets(d,aux);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'valid pattern')) && isempty(fieldnames(data_out)),'invalid regex *B: warn_bad=1, clear message, empty data_out');
aux.opts_subset.filter_pattern='^QQQ';
[data_out,aux_out]=rs_subset_choicesets(d,aux);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'No stimuli left after filtering')),'no-match pattern: warn_bad=1 and says No stimuli left after filtering');
bad=d;
bad.responses=[d.responses zeros(size(d.responses,1),2)];
[data_out,aux_out]=rs_subset_choicesets(bad,quiet);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'7 columns')),'7 columns: warn_bad=1 and the message says how many columns there are');
bad=d;
bad.stim_list=d.stim_list(1:30,:);
[data_out,aux_out]=rs_subset_choicesets(bad,quiet);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'but there are 30 stimulus names')),'stimulus numbers beyond the list of names: warn_bad=1 and a clear message');
bad=load(cases{2,1});
bad=rmfield(bad,'responses_colnames');
[data_out,aux_out]=rs_subset_choicesets(bad,quiet);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'tetradic or odd-one-out')),'6 columns without responses_colnames: warn_bad=1, says it cannot tell tetradic from odd-one-out');
bad=rmfield(d,'responses');
[data_out,aux_out]=rs_subset_choicesets(bad,quiet);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'responses')),'missing responses: warn_bad=1 and the message names the variable');
[data_out,aux_out]=rs_subset_choicesets('not a structure',quiet);
nfail=nfail+check(aux_out.warn_bad==1,'input that is not a structure: warn_bad=1');
%
if nfail==0
    disp('rs_subset_choicesets_test: ALL PASSED');
else
    error('rs_subset_choicesets_test: %d check(s) FAILED',nfail);
end
end

function expected=expected_subset(responses,n_idx,order)
% the trials that use only the stimuli in order, with the stimuli renumbered by their position in order
newnum=zeros(1,max([max(max(responses(:,1:n_idx))) max(order)]));
newnum(order)=1:length(order);
mapped=newnum(responses(:,1:n_idx));
rows=all(mapped>0,2);
expected=responses(rows,:);
expected(:,1:n_idx)=mapped(rows,:);
end

function nfail=check(ok,description)
if ok
    fprintf('  pass: %s\n',description);
    nfail=0;
else
    fprintf('  FAIL: %s\n',description);
    nfail=1;
end
end
