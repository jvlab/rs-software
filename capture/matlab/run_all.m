function run_all(spec_dir, repo_root)
% run_all  Run capture for every spec in spec_dir.
%
%   run_all('build/capture')            % repo root is the current directory
%   run_all('build/capture', '/path')   % explicit repo root
%
% Sets up the MATLAB path so demos and their dependencies resolve, with the
% scripted input() shadow taking precedence over the builtin, runs each demo,
% then restores the original path. Intended to be called through the
% matlab-actions/run-command action in CI:
%
%   run_all('build/capture')
%
% Specs are matched by the pattern *.spec.json. Each demo's figure and
% manifest paths are absolute (written by the Python spec builder), so the
% working-directory change each demo makes does not affect where output lands.
%
% A marker file, run_all.done, is deleted at the start and written in spec_dir
% at the end. It is how the Python driver knows the capture really finished,
% rather than trusting that the process it started waited for MATLAB. On
% Windows the matlab command returns to the caller while MATLAB is still
% running, and without this marker the pages would be rendered from manifests
% that are not there yet, leaving demo pages with code and no output.

    if nargin < 2 || isempty(repo_root)
        repo_root = pwd;
    end

    % Source subfolders that must NOT go on the MATLAB path. octave_compat
    % holds Octave shims (contains.m, procrustes.m, ...) that would wrongly
    % shadow MATLAB's own functions.
    EXCLUDE_DIRS = {'octave_compat'};

    here = fileparts(mfilename('fullpath'));   % folder holding the input() shadow
    src = fullfile(repo_root, 'src');

    orig_path = path();
    restore_path = onCleanup(@() path(orig_path)); %#ok<NASGU>

    % The rs_* modules delegate to psg_* functions from perceptual_space_geometry.
    % It is added before src so that the prepend below leaves every rs-software
    % folder ahead of it, which is the precedence the installation notes require.
    psg_root = local_psg_root(repo_root);
    if ~isempty(psg_root)
        fprintf('run_all: perceptual_space_geometry at %s\n', psg_root);
        addpath(local_genpath(psg_root));
    end

    addpath(local_src_path(src, EXCLUDE_DIRS));   % source minus excluded folders
    addpath(here, '-begin');    % the input() shadow must win over the builtin

    % Resolve spec files to absolute paths before any demo changes directory.
    listing = dir(fullfile(spec_dir, '*.spec.json'));
    spec_paths = fullfile({listing.folder}, {listing.name});

    % Clear the marker of a previous run, so that its presence at the end can
    % only mean that this run reached the end.
    done_file = local_done_file(spec_dir);
    if isfile(done_file)
        delete(done_file);
    end

    local_check_dependencies();   % ... and rather than capture nothing but errors
    local_check_graphics();       % fail fast rather than capture black images

    fprintf('run_all: %d demo(s) to capture\n', numel(spec_paths));
    all_timer = tic;
    for i = 1:numel(spec_paths)
        [~, base] = fileparts(spec_paths{i});
        fprintf('  capturing %s\n', base);
        demo_timer = tic;
        try
            run_capture(spec_paths{i});
            fprintf('  captured %s in %.1f s\n', base, toc(demo_timer));
        catch e
            fprintf(2, '  FAILED %s after %.1f s: %s\n', base, ...
                toc(demo_timer), e.message);
        end
    end
    fprintf('run_all: finished %d demo(s) in %.1f s\n', ...
        numel(spec_paths), toc(all_timer));

    local_write_done(done_file, numel(spec_paths));
end


function done_file = local_done_file(spec_dir)
% Absolute path of the completion marker, resolved before any demo changes
% directory, so writing it at the end lands in spec_dir whatever the demos did.
    listing = dir(spec_dir);
    if isempty(listing)
        error('run_all:noSpecDir', 'spec directory not found: %s', spec_dir);
    end
    done_file = fullfile(listing(1).folder, 'run_all.done');
end


function local_write_done(done_file, ndemos)
% Write the completion marker. Its contents are for a human reading the folder;
% the Python driver only checks that the file is there.
    fid = fopen(done_file, 'w');
    if fid < 0
        fprintf(2, 'run_all: cannot write the completion marker %s\n', done_file);
        return
    end
    fprintf(fid, 'run_all finished %d demo(s) at %s\n', ndemos, ...
        datestr(now, 'yyyy-mm-ddTHH:MM:SS')); %#ok<TNOW1,DATST>
    fclose(fid);
end


function p = local_genpath(root)
% genpath(root), minus any folder at or below a dot-directory.
%
% genpath skips 'private', '@' and '+' folders but descends into .git, so
% running it on a checkout adds a couple of hundred useless entries to the path.
% Only components below root are inspected, so a checkout that itself lives
% under a dot-directory still works.
    folders = strsplit(genpath(root), pathsep);
    folders = folders(~cellfun(@isempty, folders));

    keep = true(size(folders));
    for k = 1:numel(folders)
        rel = folders{k}(min(numel(folders{k}), numel(root)) + 1:end);
        parts = strsplit(rel, filesep);
        for j = 1:numel(parts)
            if ~isempty(parts{j}) && parts{j}(1) == '.'
                keep(k) = false;
                break;
            end
        end
    end

    p = strjoin(folders(keep), pathsep);
end


function root = local_psg_root(repo_root)
% Locate a perceptual_space_geometry checkout to put on the path.
%
% Looked for in the RS_PSG_PATH environment variable, then inside the repository
% (where the CI workflows check it out), then beside it. Returns '' when none is
% found, which is the normal case on a machine where the repository is already on
% the saved MATLAB path; local_check_dependencies then decides whether that is a
% problem.
    candidates = { ...
        getenv('RS_PSG_PATH'), ...
        fullfile(repo_root, 'perceptual_space_geometry'), ...
        fullfile(fileparts(repo_root), 'perceptual_space_geometry')};

    root = '';
    for k = 1:numel(candidates)
        if ~isempty(candidates{k}) && isfolder(candidates{k})
            root = candidates{k};
            return;
        end
    end
end


function local_check_dependencies()
% Verify that perceptual_space_geometry is reachable before capturing anything.
%
% Nearly every rs_* module calls a psg_* function, so without that repository on
% the path each demo dies at its first call. run_capture catches that error and
% records it in the manifest, which means the run still reports success and the
% documentation quietly fills with error blocks instead of output. Check up front
% instead.
    needed = {'psg_read_coorddata', 'psg_geomodels_define', 'psg_defopts'};
    missing = needed(cellfun(@(f) isempty(which(f)), needed));
    if ~isempty(missing)
        error('run_all:missingPsg', ...
            ['perceptual_space_geometry is not on the MATLAB path, so %s ' ...
             'cannot be resolved. Clone ' ...
             'https://github.com/jvlab/perceptual_space_geometry beside or inside ' ...
             'this repository, or point RS_PSG_PATH at an existing checkout.'], ...
            strjoin(missing, ', '));
    end
    fprintf('run_all: psg_* functions resolve to %s\n', ...
        fileparts(which('psg_read_coorddata')));
end


function local_check_graphics()
% Verify that figures actually render before spending minutes capturing demos.
%
% A MATLAB started in batch mode while an X display is present tries to use
% hardware OpenGL, fails to create a GL context, and then exports every figure
% as a solid black image without raising an error. That failure is silent and
% costs a whole capture run, so check it once, up front, on a figure we draw
% ourselves and know cannot be blank.
    f = figure('Visible', 'off');
    closer = onCleanup(@() close(f)); %#ok<NASGU>
    plot(1:10);
    probe = [tempname '.png'];
    exportgraphics(f, probe, 'Resolution', 50);
    img = imread(probe);
    delete(probe);
    if numel(unique(img(:))) <= 1
        error('run_all:blankFigures', ...
            ['figures render blank: this MATLAB has no usable graphics context. ' ...
             'On Linux and macOS, start it with -nodisplay, as in ' ...
             'matlab -nodisplay -batch "addpath(''capture/matlab''); ' ...
             'run_all(''build/capture'')". docs/update_demo_docs.py does this.']);
    end
end


function p = local_src_path(src, exclude_dirs)
% Build a path string for src (recursive), dropping any folder that is, or is
% inside, one of exclude_dirs. Matching is on full path components, so a name
% like "octave_compat_extra" is not excluded by "octave_compat".
    folders = strsplit(local_genpath(src), pathsep);
    folders = folders(~cellfun(@isempty, folders));

    excluded = false(size(folders));
    for k = 1:numel(exclude_dirs)
        root = fullfile(src, exclude_dirs{k});
        excluded = excluded | strcmp(folders, root) ...
                            | startsWith(folders, [root filesep]);
    end

    p = strjoin(folders(~excluded), pathsep);
end
