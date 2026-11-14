function rs_subset_coordsets_test()
% rs_subset_coordsets_test()
% tests rs_subset_coordsets on a `dataset structure` made from a sample coordinate file
% (two records, combined with rs_concat_coordsets): the coordinates, stimulus names, per-stimulus
% metadata and counts must follow the stimuli that are kept, and everything else must come back untouched.
%
% Run from any folder:  rs_subset_coordsets_test
% In MATLAB this uses the Python interface (pyenv); in Octave it uses the command line.
% Needs Python with numpy and scipy, and the lab's perceptual_space_geometry folders on the path
% (rs_subset_coordsets itself puts the rs-software folder with rs_tools on Python's path).
%
%  See also: RS_SUBSET_COORDSETS, RS_IMPORT_COORDSETS, RS_CONCAT_COORDSETS.
%
here=fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..'));
if isempty(which('filldefault'))
    error('rs_subset_coordsets_test: the lab''s perceptual_space_geometry folders must be on the path (filldefault not found).');
end
samples=fullfile(here,'..','samples');
file=fullfile(samples,'animals','image_coords_S1.mat');
nfail=0;
%
% make a two-record dataset structure.  The lab's consistency check requires that all records have the same stimuli,
% so both records use the stimuli of the same sample file; record 2 has scaled coordinates.
% Stimulus coordinates are added to record 1 so that they can be checked.
d=load(file);
labs=strtrim(cellstr(d.stim_labels));
for irec=1:2
    coords={};
    for k=1:length(fieldnames(d))
        if isfield(d,sprintf('dim%d',k)), coords{k}=irec*d.(sprintf('dim%d',k)); end
    end
    opts=struct('opts_import',struct('typenames',{labs}));
    if irec==1
        opts.opts_import.type_coords=[(1:length(labs))' 10*(1:length(labs))']; %non-square, one row per stimulus
    end
    [dat{irec},aux_imp]=rs_import_coordsets(coords,opts);
    dat{irec}.sets{1}.pipeline=struct('note',sprintf('pipeline of record %d',irec)); %must come back untouched
end
data_in=rs_concat_coordsets(dat{1},dat{2},struct('opts_check',struct('if_warn',0)));
nsets=length(data_in.sets);
nfail=nfail+check(nsets==2,'test dataset structure has 2 records');
quiet=struct('opts_subset',struct('if_log',0),'opts_check',struct('if_warn',0));
%
% keep_all (the default) returns the input unchanged
[data_out,aux_out]=rs_subset_coordsets(data_in,quiet);
if aux_out.warn_bad>0
    % the first call is the simplest one; if it fails, nothing else can work, so stop with a clear message
    disp(aux_out.warnings);
    error('rs_subset_coordsets_test: the first call failed, so the other checks cannot run. The message above is what Python reported; see README.txt for Python setup.');
end
nfail=nfail+check(aux_out.warn_bad==0,'keep_all: no warnings');
nfail=nfail+check(isequaln(data_out,data_in),'keep_all: the dataset structure is identical to the input');
nfail=nfail+check(isequal(aux_out.kept_indices{1},1:length(data_in.sas{1}.typenames)),'keep_all: kept_indices lists every stimulus');
%
% regex: stimuli in every record that start with the first letter of record 1's first name
labs1=data_in.sas{1}.typenames;
pattern=['^' labs1{1}(1)];
aux=quiet;
aux.opts_subset.filter_type='regex';
aux.opts_subset.filter_pattern=pattern;
[data_out,aux_out]=rs_subset_coordsets(data_in,aux);
nfail=nfail+check(aux_out.warn_bad==0,['regex ' pattern ': no warnings']);
for k=1:nsets
    labs=data_in.sas{k}.typenames;
    keep=find(~cellfun(@isempty,regexp(labs,pattern,'once')))';
    tag=sprintf('regex %s, record %d (%d of %d kept)',pattern,k,length(keep),length(labs));
    nfail=nfail+check(isequal(aux_out.kept_indices{k},keep),[tag ': kept_indices are the matching names']);
    nfail=nfail+check(isequal(data_out.sas{k}.typenames,labs(keep)),[tag ': stimulus names match']);
    rows_ok=true;
    for idim=1:length(data_in.ds{k})
        if ~isempty(data_in.ds{k}{idim})
            rows_ok=rows_ok & isequal(data_out.ds{k}{idim},data_in.ds{k}{idim}(keep,:));
        else
            rows_ok=rows_ok & isempty(data_out.ds{k}{idim});
        end
    end
    nfail=nfail+check(rows_ok,[tag ': coordinate rows follow the kept stimuli']);
    nfail=nfail+check(data_out.sas{k}.nstims==length(keep) & data_out.sets{k}.nstims==length(keep),[tag ': sas.nstims and sets.nstims updated']);
    sets_same=true;
    sets_fns=setdiff(fieldnames(data_in.sets{k}),{'nstims'});
    for ifn=1:length(sets_fns)
        sets_same=sets_same & isequaln(data_out.sets{k}.(sets_fns{ifn}),data_in.sets{k}.(sets_fns{ifn}));
    end
    nfail=nfail+check(sets_same,[tag ': other set metadata (including pipeline) untouched']);
    nfail=nfail+check(strcmp(class(data_out.ds{k}{end}),class(data_in.ds{k}{end})),[tag ': coordinates keep their number type']);
end
nfail=nfail+check(isequal(data_out.sas{1}.type_coords,data_in.sas{1}.type_coords(aux_out.kept_indices{1},:)),'regex: stimulus coordinates (type_coords) of record 1 follow the kept stimuli');
%
% include / exclude by name; alphabetize sorts the kept names
names=labs1([3 1]);
aux=quiet;
aux.opts_subset.filter_type='include';
aux.opts_subset.filter_pattern=names;
% (a name that is not in a record is an error for that record, so use a single-record dataset here)
data_one=struct('ds',{data_in.ds(1)},'sas',{data_in.sas(1)},'sets',{data_in.sets(1)});
[data_out,aux_out]=rs_subset_coordsets(data_one,aux);
nfail=nfail+check(aux_out.warn_bad==0 && isequal(data_out.sas{1}.typenames,labs1([1 3])),'include: keeps the named stimuli, in their original order');
aux.opts_subset.alphabetize=1;
[data_out,aux_out]=rs_subset_coordsets(data_one,aux);
pair=labs1([1 3]);
[~,order]=sort(pair);
nfail=nfail+check(aux_out.warn_bad==0 && isequal(data_out.sas{1}.typenames,pair(order)),'include + alphabetize: kept stimuli are in alphabetical order');
aux=quiet;
aux.opts_subset.filter_type='exclude';
aux.opts_subset.filter_pattern=names;
[data_out,aux_out]=rs_subset_coordsets(data_one,aux);
nfail=nfail+check(aux_out.warn_bad==0 && data_out.sas{1}.nstims==length(labs1)-2,'exclude: drops the named stimuli');
%
% a square stimulus-coordinate array (columns also correspond to stimuli) is cut in both directions
data_sq=data_one;
n1=length(labs1);
data_sq.sas{1}.type_coords=eye(n1);
aux=quiet;
aux.opts_subset.filter_type='regex';
aux.opts_subset.filter_pattern=pattern;
[data_out,aux_out]=rs_subset_coordsets(data_sq,aux);
nk=length(aux_out.kept_indices{1});
nfail=nfail+check(isequal(data_out.sas{1}.type_coords,eye(nk)),'square type_coords: rows and columns both follow the kept stimuli');
%
% problems are reported in aux_out, as in the other rs_ modules, with a readable message
aux=quiet;
aux.opts_subset.filter_type='regex';
aux.opts_subset.filter_pattern='*B';
[data_out,aux_out]=rs_subset_coordsets(data_in,aux);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'valid pattern')),'invalid regex *B: warn_bad=1 and a clear message');
aux.opts_subset.filter_pattern='^QQQ';
[data_out,aux_out]=rs_subset_coordsets(data_in,aux);
nfail=nfail+check(aux_out.warn_bad==1 && ~isempty(strfind(aux_out.warnings,'No stimuli left after filtering')),'no-match pattern: warn_bad=1 and says No stimuli left after filtering');
%
if nfail==0
    disp('rs_subset_coordsets_test: ALL PASSED');
else
    error('rs_subset_coordsets_test: %d check(s) FAILED',nfail);
end
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
