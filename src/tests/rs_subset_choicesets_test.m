function rs_subset_choicesets_test()
% rs_subset_choicesets_test()
% tests rs_subset_choicesets on triadic choice data from a sample choice file, and on a small tetradic table:
% the trials that remain, their renumbering, and the stimulus names must follow the stimuli that are kept,
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
nfail=0;
quiet=struct('opts_subset',struct('if_log',0),'opts_check',struct('if_warn',0));
%
% triadic choice data from a sample choice file
d=load(fullfile(here,'..','samples','animals','image_choices_S1.mat'));
tri=struct;
tri.data_comp=d.responses;
tri.typenames=strtrim(cellstr(d.stim_list));
tri.note='this field must come back untouched';
n=length(tri.typenames);
nfail=nfail+check(size(tri.data_comp,2)==5 && n==37,sprintf('triadic sample: %d trials, %d stimuli',size(tri.data_comp,1),n));
%
% keep_all (the default) returns the input unchanged
[data_out,aux_out]=rs_subset_choicesets(tri,quiet);
nfail=nfail+check(aux_out.warn_bad==0,'keep_all: no warnings');
nfail=nfail+check(isequal(data_out.data_comp,tri.data_comp) && isequal(data_out.typenames,tri.typenames),'keep_all: data_comp and typenames are identical to the input');
nfail=nfail+check(isequal(aux_out.kept_indices,1:n) && isequal(aux_out.ntrials,[1 1]*size(tri.data_comp,1)),'keep_all: kept_indices lists every stimulus; no trials lost');
%
% regex
pattern='^[a-m]';
aux=quiet;
aux.opts_subset.filter_type='regex';
aux.opts_subset.filter_pattern=pattern;
keep=find(~cellfun(@isempty,regexp(tri.typenames,pattern,'once')))';
expected=expected_subset(tri.data_comp,keep);
[data_out,aux_out]=rs_subset_choicesets(tri,aux);
tag=sprintf('regex %s (%d of %d stimuli, %d of %d trials)',pattern,length(keep),n,size(expected,1),size(tri.data_comp,1));
nfail=nfail+check(aux_out.warn_bad==0,[tag ': no warnings']);
nfail=nfail+check(isequal(data_out.data_comp,expected),[tag ': remaining trials are renumbered correctly']);
nfail=nfail+check(isequal(data_out.typenames,tri.typenames(keep)),[tag ': stimulus names match']);
nfail=nfail+check(isequal(aux_out.kept_indices,keep) && isequal(aux_out.ntrials,[size(tri.data_comp,1) size(expected,1)]),[tag ': kept_indices and ntrials']);
nfail=nfail+check(isequal(data_out.note,tri.note),[tag ': other fields untouched']);
nfail=nfail+check(isequal(data_out.data_comp(:,4:5),tri.data_comp(all(ismember(tri.data_comp(:,1:3),keep),2),4:5)),[tag ': counts are not changed']);
%
% include, in a different order from the original; alphabetize puts the kept stimuli in alphabetical order
names=tri.typenames([30 4 12 25 2 18 9 33 21 7 15 27 1 36 11 20]);
aux=quiet;
aux.opts_subset.filter_type='include';
aux.opts_subset.filter_pattern=names;
keep=find(ismember(tri.typenames,names))';
[data_out,aux_out]=rs_subset_choicesets(tri,aux);
nfail=nfail+check(aux_out.warn_bad==0 && isequal(data_out.typenames,tri.typenames(keep)) && isequal(data_out.data_comp,expected_subset(tri.data_comp,keep)),...
    'include: keeps the named stimuli, in their original order');
aux.opts_subset.alphabetize=1;
[~,o]=sort(tri.typenames(keep));
order=keep(o);
[data_out,aux_out]=rs_subset_choicesets(tri,aux);
nfail=nfail+check(aux_out.warn_bad==0 && isequal(data_out.typenames,tri.typenames(order)) && isequal(data_out.data_comp,expected_subset(tri.data_comp,order)),...
    'include + alphabetize: stimuli are in alphabetical order and the trials are renumbered to match');
aux=quiet;
aux.opts_subset.filter_type='exclude';
aux.opts_subset.filter_pattern=tri.typenames([3 14 22]);
keep=setdiff(1:n,[3 14 22]);
[data_out,aux_out]=rs_subset_choicesets(tri,aux);
nfail=nfail+check(aux_out.warn_bad==0 && isequal(data_out.typenames,tri.typenames(keep)) && isequal(data_out.data_comp,expected_subset(tri.data_comp,keep)),'exclude: drops the named stimuli');
%
% tetradic: 6 columns, a trial stays only if all four stimuli stay
tet=struct;
tet.typenames={'a';'b';'c';'d';'e';'f';'g';'h'};
tet.data_comp=[1 2 3 4 5 10; 1 2 5 6 3 6; 2 3 4 8 1 4; 5 6 7 8 2 5; 4 3 2 1 7 9];
aux=quiet;
aux.opts_subset.filter_type='regex';
aux.opts_subset.filter_pattern='^[a-d]';
[data_out,aux_out]=rs_subset_choicesets(tet,aux);
nfail=nfail+check(aux_out.warn_bad==0 && isequal(data_out.data_comp,[1 2 3 4 5 10; 4 3 2 1 7 9]) && isequal(data_out.typenames,{'a';'b';'c';'d'}),'tetradic: only the trials whose four stimuli are all kept remain');
aux.opts_subset.filter_pattern='^[aeg]';
[data_out,aux_out]=rs_subset_choicesets(tet,aux);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'No trials left after filtering')),'tetradic, kept stimuli never together: warn_bad=1 and says No trials left after filtering');
%
% problems are reported by Python and shown in aux_out, with a readable message
aux=quiet;
aux.opts_subset.filter_type='regex';
aux.opts_subset.filter_pattern='*B';
[data_out,aux_out]=rs_subset_choicesets(tri,aux);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'valid pattern')) && isempty(fieldnames(data_out)),'invalid regex *B: warn_bad=1, clear message, empty data_out');
aux.opts_subset.filter_pattern='^QQQ';
[data_out,aux_out]=rs_subset_choicesets(tri,aux);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'No stimuli left after filtering')),'no-match pattern: warn_bad=1 and says No stimuli left after filtering');
bad=tri;
bad.data_comp=[tri.data_comp zeros(size(tri.data_comp,1),2)]; %5+2=7 columns
[data_out,aux_out]=rs_subset_choicesets(bad,quiet);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'7 columns')),'7 columns: warn_bad=1 and the message says how many columns there are');
bad=tri;
bad.typenames=tri.typenames(1:30);
[data_out,aux_out]=rs_subset_choicesets(bad,quiet);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'but there are 30 stimulus names')),'stimulus numbers beyond the list of names: warn_bad=1 and a clear message');
bad=rmfield(tri,'data_comp');
[data_out,aux_out]=rs_subset_choicesets(bad,quiet);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'data_comp')),'missing data_comp: warn_bad=1 and the message names the variable');
[data_out,aux_out]=rs_subset_choicesets('not a structure',quiet);
nfail=nfail+check(aux_out.warn_bad==1,'input that is not a structure: warn_bad=1');
%
if nfail==0
    disp('rs_subset_choicesets_test: ALL PASSED');
else
    error('rs_subset_choicesets_test: %d check(s) FAILED',nfail);
end
end

function expected=expected_subset(data_comp,keep)
% the trials that use only the stimuli in keep, with the stimuli renumbered by their position in keep
ncol_idx=size(data_comp,2)-2;
newnum=zeros(1,max(max(data_comp(:,1:ncol_idx))));
newnum(keep)=1:length(keep);
mapped=newnum(data_comp(:,1:ncol_idx));
rows=all(mapped>0,2);
expected=data_comp(rows,:);
expected(:,1:ncol_idx)=mapped(rows,:);
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
