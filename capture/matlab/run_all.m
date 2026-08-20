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

    fprintf('run_all: %d demo(s) to capture\n', numel(spec_paths));
    for i = 1:numel(spec_paths)
        [~, base] = fileparts(spec_paths{i});
        fprintf('  capturing %s\n', base);
        try
            run_capture(spec_paths{i});
        catch e
            fprintf(2, '  FAILED %s: %s\n', base, e.message);
        end
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
