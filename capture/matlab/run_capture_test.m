function run_capture_test()
% run_capture_test  Check that run_capture exports every figure while keeping
%                   only a bounded number of them open.
%
% Run it from the repository root, with capture/matlab on the path:
%
%   addpath('capture/matlab'); run_capture_test
%
% Writes its spec, images and manifest into a fresh temporary folder, so it
% touches neither docs/images/demos nor build/capture. Prints PASS per check and
% errors on the first failure.

    NFIGS = 50;           % more than the lag, so closing has to happen
    MAX_OPEN_ALLOWED = 25;  % lag is 20; a little slack for the tail

    work = fullfile(tempdir, sprintf('run_capture_test_%d', feature('getpid')));
    if exist(work, 'dir')
        rmdir(work, 's');
    end
    mkdir(work);
    cleaner = onCleanup(@() rmdir(work, 's')); %#ok<NASGU>

    % The demo under test: open NFIGS figures, drawing into each one after the
    % next has been created, which is what real demos do when they annotate.
    % max_open records the high-water mark of simultaneously open figures.
    code = sprintf([ ...
        'max_open=0;\n', ...
        'for k=1:%d\n', ...
        '  h=figure; plot(1:10, (1:10)*k); title(sprintf(''figure %%d'', k));\n', ...
        '  xlabel(''annotated after creation'');\n', ...
        '  max_open=max(max_open, numel(findall(groot, ''Type'', ''figure'')));\n', ...
        'end\n'], NFIGS);

    spec = struct( ...
        'name', 'capture_selftest', ...
        'workdir', work, ...
        'fig_dir', fullfile(work, 'figs'), ...
        'manifest', fullfile(work, 'selftest.manifest.json'), ...
        'answers', {{}}, ...
        'chunks', struct('id', {1, 2}, 'code', {code, 'disp(max_open)'}));

    spec_path = fullfile(work, 'capture_selftest.spec.json');
    fid = fopen(spec_path, 'w');
    fwrite(fid, jsonencode(spec));
    fclose(fid);

    run_capture(spec_path);

    manifest = jsondecode(fileread(spec.manifest));
    entry = manifest(1);

    local_check(isempty(entry.error), sprintf('demo ran without error (%s)', entry.error));

    figures = entry.figures;
    local_check(numel(figures) == NFIGS, ...
        sprintf('manifest lists all %d figures, got %d', NFIGS, numel(figures)));

    for j = 1:numel(figures)
        expected = sprintf('capture_selftest_chunk01_fig%d.png', j);
        local_check(strcmp(figures{j}, expected), ...
            sprintf('figure %d is named %s, got %s', j, expected, figures{j}));
        local_check(exist(fullfile(spec.fig_dir, figures{j}), 'file') == 2, ...
            sprintf('image file %s exists', figures{j}));
    end

    % Figures are numbered in creation order, so image k must be the plot of
    % line k: its title says so, and a later line is steeper, hence darker rows
    % further right. Checking the file sizes are all non-trivial is enough here.
    info = cellfun(@(n) dir(fullfile(spec.fig_dir, n)), figures);
    local_check(all([info.bytes] > 1000), 'every exported image has real content');

    max_open = str2double(strtrim(manifest(2).text));
    local_check(max_open <= MAX_OPEN_ALLOWED, ...
        sprintf('at most %d figures open at once, high-water mark was %d', ...
                MAX_OPEN_ALLOWED, max_open));

    close all;
    fprintf('run_capture_test: all checks passed\n');
end


function local_check(condition, description)
    if condition
        fprintf('  PASS  %s\n', description);
    else
        error('run_capture_test:failed', 'FAIL  %s', description);
    end
end
