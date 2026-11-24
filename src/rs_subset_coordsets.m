function [data_out,aux_out]=rs_subset_coordsets(data_in,aux)
% [data_out,aux_out]=rs_subset_coordsets(data_in,aux)
% keeps or drops stimuli in every record of a `dataset structure`, using the Python package rs_tools
%
% The choice of stimuli is made by Python (rs_tools.subset_stimuli), from the stimulus names in data_in.sas{k}.typenames.
% The same selection rule is applied to each record.  In each record, the rows of the coordinates
% and of the stimulus metadata that belong to stimuli that are dropped are removed, and the metadata
% for the response set is otherwise unchanged.
%
% Args:
%   data_in (struct): `dataset structure` containing n records, with fields
%
%     - ds (cell array): `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas (cell array): `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets (cell array): `set metadata structure`, sets{k} is the response metadata for the kth record
%
%   aux (struct): auxiliary options, may be omitted, with fields
%
%     - opts_subset (struct): options for subsetting, with fields
%
%       - filter_type (char): 'keep_all' (default), 'regex', 'include', or 'exclude'
%       - filter_pattern (char or cell array): for 'regex', a regular expression, as a single char array (a cell array gives an error), such as '^b' for names that start with b;
%       for 'include' or 'exclude', a cell array of stimulus names
%       - regex_mode (char): for 'regex', 'include' (default) to keep the stimuli that match, 'exclude' to drop them
%       - alphabetize (int): 1 to put the kept stimuli in alphabetical order, 0 (default) to keep their original order
%       - backend (char): 'auto' (default), 'py' (MATLAB's built-in Python interface, set up with pyenv), or 'cli' (command line);
%       'auto' selects 'py' in MATLAB and 'cli' in Octave
%       - python_executable (char): Python to use for 'cli'; default is 'python3'
%       - if_log (int): 1 to log progress, 0 to suppress; default is 1
%
%     - opts_check (struct): options for consistency checking, with field
%
%       - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
%
% Returns:
%   data_out (struct): `dataset structure` with n records, same format as `data_in`, containing the kept stimuli only
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check, or by Python
%     - warn_bad (int): number of warnings that prevent further processing
%     - kept_indices (cell array): kept_indices{k} is a row vector of the positions in data_in.sas{k}.typenames of the stimuli kept in
%     record k, in the order in which they appear in data_out
%     - opts_subset (struct): aux.opts_subset, with defaults filled in
%     - opts_check (struct): aux.opts_check, with defaults filled in
%
% Note: Notes
%   -  aux may be omitted; defaults are filled in.  The default, filter_type='keep_all', returns data_in unchanged.
%   -  Python (numpy and scipy) is required, and the folder that contains this file's folder must contain rs_tools.
%   -  In each record, the fields of sas{k} that have one row per stimulus (typenames; optionally, type_coords, btc_specoords, btc_augcoords, spec_labels, specs) are subsetted by rows, and sas{k}.nstims and sets{k}.nstims are updated.
%   -  data_out.sets{k}.pipeline records the subsetting: type 'subset', opts (opts_subset and kept_indices), and sets{1},
%   the set metadata of the kth record of data_in (which contains its earlier pipeline).  With filter_type='keep_all', nothing is
%   changed, and the pipeline is not updated.
%   -  If no stimuli remain in a record, or the pattern is not valid, or does not match any of typenames, warn_bad is set to 1 and data_out is empty.
%
% Example:
%   [data_b,aux_out]=rs_subset_coordsets(data_in,struct('opts_subset',struct('filter_type','regex','filter_pattern','^b')));
%
% See also:
%   RS_ALIGN_COORDSETS, RS_CONCAT_COORDSETS, RS_EXTRACT_COORDSETS, RS_IMPORT_COORDSETS, RS_CHECK_COORDSETS.
%
if (nargin<=1)
    aux=struct;
end
%set up sub-structure options
%
aux=filldefault(aux,'opts_subset',struct);
aux.opts_subset=filldefault(aux.opts_subset,'filter_type','keep_all');
aux.opts_subset=filldefault(aux.opts_subset,'filter_pattern',[]);
aux.opts_subset=filldefault(aux.opts_subset,'regex_mode','include');
aux.opts_subset=filldefault(aux.opts_subset,'alphabetize',0);
aux.opts_subset=filldefault(aux.opts_subset,'backend','auto');
aux.opts_subset=filldefault(aux.opts_subset,'python_executable','python3');
aux.opts_subset=filldefault(aux.opts_subset,'if_log',1);
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
data_out=struct;
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
% rs_tools is in the folder above the one containing the m-files
repo_root=fileparts(fileparts(mfilename('fullpath')));
%
%check internal consistency of the input
%
check=rs_check_coordsets(data_in,aux.opts_check);
aux_out.warnings=check.warnings;
aux_out.warn_bad=check.warn_bad;
%
if aux_out.warn_bad==0
    nsets=length(data_in.sets);
    fns={'ds','sas','sets'}; %fields to subset
    for ifn=1:length(fns)
        data_out.(fns{ifn})=cell(1,nsets);
    end
    aux_out.kept_indices=cell(1,nsets);
    for iset=1:nsets
        [ds_new,sas_new,sets_new,kept,wmsg]=subset_one_record(data_in.ds{iset},data_in.sas{iset},data_in.sets{iset},aux.opts_subset,repo_root);
        if ~isempty(wmsg)
            wmsg=sprintf('record %1.0f: %s',iset,wmsg);
            aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
            break
        end
        data_out.ds{iset}=ds_new;
        data_out.sas{iset}=sas_new;
        data_out.sets{iset}=sets_new;
        if ~strcmp(aux.opts_subset.filter_type,'keep_all')
            pipeline_opts=struct;
            pipeline_opts.opts_subset=aux.opts_subset;
            pipeline_opts.kept_indices=kept;
            data_out.sets{iset}.pipeline=psg_coord_pipe_util('subset',pipeline_opts,data_in.sets{iset});
        end
        aux_out.kept_indices{iset}=kept;
        if aux.opts_subset.if_log
            disp(sprintf('record %3.0f: kept %3.0f of %3.0f stimuli',iset,length(kept),length(data_in.sas{iset}.typenames)));
        end
    end
end
%
if aux_out.warn_bad==0
    [check,opts_used]=rs_check_coordsets(data_out,aux.opts_check);
    aux_out.warnings=check.warnings;
    aux_out.warn_bad=check.warn_bad;
else
    data_out=struct;
    disp('cannot proceed');
    disp(aux_out.warnings);
end
%
aux_out.opts_subset=aux.opts_subset;
aux_out.opts_check=aux.opts_check;
return
end

function [ds_new,sas_new,sets_new,kept,wmsg]=subset_one_record(ds,sas,sets,opts_subset,repo_root)
% subsets one record: asks Python which stimuli to keep, then cuts every per-stimulus array the same way
%
ds_new=ds;
sas_new=sas;
sets_new=sets;
kept=[];
wmsg='';
nstims=length(sas.typenames);
%
% Python gets the coordinates and the stimulus names in the form of a coordinate file (dim1, dim2, ..., stim_labels)
flat=struct;
for idim=1:length(ds)
    if ~isempty(ds{idim})
        flat.(sprintf('dim%1.0f',idim))=ds{idim};
    end
end
if isempty(fieldnames(flat))
    wmsg='there are no coordinates to subset';
    return
end
flat.stim_labels=sas.typenames(:);
%
pyaux=struct;
pyaux.operation='subset';
pyaux.filter_type=opts_subset.filter_type;
pyaux.filter_pattern=opts_subset.filter_pattern;
pyaux.regex_mode=opts_subset.regex_mode;
pyaux.alphabetize=opts_subset.alphabetize;
pyaux.return_indices=1;
%
[flat_out,wmsg]=call_python(flat,pyaux,opts_subset,repo_root);
if ~isempty(wmsg)
    return
end
kept=double(flat_out.kept_indices(:))';
%
% cut the rows that belong to stimuli that are dropped
for idim=1:length(ds)
    if ~isempty(ds{idim})
        ds_new{idim}=ds{idim}(kept,:);
    end
end
sas_fields={'typenames','type_coords','btc_specoords','btc_augcoords','spec_labels','specs'};
for ifield=1:length(sas_fields)
    fn=sas_fields{ifield};
    if isfield(sas,fn)
        v=sas.(fn);
        if ~isempty(v) && size(v,1)==nstims
            sas_new.(fn)=v(kept,:); %only the rows are subsetted, even if the array happens to be square
        end
    end
end
sas_new.nstims=length(kept);
sets_new.nstims=length(kept);
return
end

function [data_py,wmsg]=call_python(data_flat,pyaux,opts_subset,repo_root)
% passes a coordinate file through rs_tools.transform, in Python, via temporary files
% wmsg is empty if all went well, and otherwise the message from Python
%
data_py=struct;
wmsg='';
backend=opts_subset.backend;
if strcmp(backend,'auto')
    if exist('OCTAVE_VERSION','builtin')
        backend='cli';
    else
        backend='py';
    end
end
tmp_in=[tempname() '.mat'];
tmp_out=[tempname() '.mat'];
tmp_aux=[tempname() '.json'];
cleanup=onCleanup(@() delete_files({tmp_in,tmp_out,tmp_aux}));
save(tmp_in,'-struct','data_flat','-v7'); %-v7 so that scipy can read the file
aux_json=jsonencode(pyaux);
%
switch backend
    case 'py'
        pe=pyenv;
        if strlength(string(pe.Version))==0
            wmsg='MATLAB has no Python configured. Set one with pyenv(''Version'',''/path/to/python''), or use opts_subset.backend=''cli''.';
            return
        end
        if count(py.sys.path,repo_root)==0
            insert(py.sys.path,int32(0),repo_root);
        end
        try
            % import the module by name: if Python cannot load it (for example, numpy or scipy is not installed in this
            % Python), the message is Python's own, not just "Unable to resolve the name py.rs_tools.transform.run_files"
            py.importlib.invalidate_caches();
            tools=py.importlib.import_module('rs_tools.transform');
            tools.run_files(tmp_in,tmp_out,aux_json);
        catch err
            wmsg=sprintf('Python reported: %s (rs_tools is looked for in %s; Python needs numpy and scipy)',err.message,repo_root);
            return
        end
    case 'cli'
        fid=fopen(tmp_aux,'w');
        fwrite(fid,aux_json);
        fclose(fid);
        old_pp=getenv('PYTHONPATH');
        setenv('PYTHONPATH',repo_root);
        cmd=sprintf('"%s" -m rs_tools.transform --input "%s" --output "%s" --aux-file "%s" 2>&1',...
            opts_subset.python_executable,tmp_in,tmp_out,tmp_aux);
        [status,msg]=system(cmd);
        setenv('PYTHONPATH',old_pp);
        if status~=0
            wmsg=sprintf('Python reported: %s',strtrim(msg));
            return
        end
    otherwise
        wmsg=sprintf('unknown backend ''%s'' (use ''auto'', ''py'' or ''cli'').',backend);
        return
end
data_py=load(tmp_out);
return
end

function delete_files(files)
for k=1:length(files)
    if exist(files{k},'file')
        delete(files{k});
    end
end
end
