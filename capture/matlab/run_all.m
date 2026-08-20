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

    addpath(local_src_path(src, EXCLUDE_DIRS));   % source minus excluded folders
    addpath(here, '-begin');    % the input() shadow must win over the builtin

    % Resolve spec files to absolute paths before any demo changes directory.
    listing = dir(fullfile(spec_dir, '*.spec.json'));
    spec_paths = fullfile({listing.folder}, {listing.name});

    local_check_graphics();   % fail fast rather than capture black images

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
    folders = strsplit(genpath(src), pathsep);
    folders = folders(~cellfun(@isempty, folders));

    excluded = false(size(folders));
    for k = 1:numel(exclude_dirs)
        root = fullfile(src, exclude_dirs{k});
        excluded = excluded | strcmp(folders, root) ...
                            | startsWith(folders, [root filesep]);
    end

    p = strjoin(folders(~excluded), pathsep);
end
