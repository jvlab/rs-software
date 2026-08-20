function run_capture(spec_path)
% run_capture  Execute one demo, capturing console output and figures, and
%              write a manifest describing the results.
%
% Python owns the display segmentation; MATLAB is a generic executor. The
% spec is a JSON file with these fields:
%   name      demo name, used to name figure image files
%   workdir   working directory the demo runs in (demos load data by paths
%             relative to the src folder, so this is normally "src")
%   fig_dir   directory to write figure images into (absolute path)
%   manifest  path of the JSON manifest to write (absolute path)
%   answers   scripted input() answers, in call order (cell / string array)
%   seed      optional rng seed for reproducible runs; omit to skip seeding
%   chunks    array of structs, each with:
%               id    identifier echoed back in the manifest (the chunk index)
%               code  MATLAB source of the display chunk
%
% Two things make this robust:
%
%   Isolation. Demo code runs in the base workspace via evalin, not in this
%   function's workspace, so a demo that uses names like k, i, text or results
%   cannot corrupt the capture loop.
%
%   Grouping. A comment inside a control block splits the display chunks so
%   that a fragment like "for idim=..." has no matching "end". Chunks are
%   accumulated until the accumulated code parses as a complete unit, then run
%   as one group. A group's output and figures are attached to the id of its
%   last chunk, so the renderer places them after that code block.
%
% The manifest is a JSON array, one entry per completed group:
%   id       the id of the group's last chunk
%   text     captured console output for the group
%   figures  filenames of images the group produced (bare names)
%   error    empty if the group ran cleanly, otherwise the error message

    spec = jsondecode(fileread(spec_path));

    if ~exist(spec.fig_dir, 'dir')
        mkdir(spec.fig_dir);
    end

    % Hand the scripted answers to the shadowed input().
    global DEMO_ANSWERS DEMO_IDX
    DEMO_IDX = 0;
    DEMO_ANSWERS = local_to_cellstr(spec.answers);

    if isfield(spec, 'seed') && ~isempty(spec.seed)
        rng(spec.seed);   % reproducible output and figures across runs
    end

    pause('off');   % never block on pause() during capture
    close all;

    % Run the demo in a clean base workspace, isolated from this function.
    evalin('base', 'clearvars');

    % Demos reference data by paths relative to the src folder, so run there.
    % onCleanup restores the original directory even if a chunk errors.
    if isfield(spec, 'workdir') && ~isempty(spec.workdir)
        start_dir = pwd;
        restore_dir = onCleanup(@() cd(start_dir)); %#ok<NASGU>
        cd(spec.workdir);
    end

    chunks = spec.chunks;
    results = struct('id', {}, 'text', {}, 'figures', {}, 'error', {});

    acc = '';                                       % code of the current group
    group_start_figs = findall(groot, 'Type', 'figure');

    for c = 1:numel(chunks)
        if isempty(acc)
            group_start_figs = findall(groot, 'Type', 'figure');
            acc = chunks(c).code;
        else
            acc = sprintf('%s\n%s', acc, chunks(c).code);
        end

        captured = '';
        err_msg = '';
        incomplete = false;
        try
            captured = evalc('evalin(''base'', acc)');
        catch e
            if local_is_incomplete(e)
                incomplete = true;   % a control block is still open
            else
                err_msg = e.message;
            end
        end

        if incomplete
            continue;   % accumulate the next chunk before running again
        end

        drawnow;        % force pending draws so figures are complete
        after = findall(groot, 'Type', 'figure');
        new_figs = local_new_figures(group_start_figs, after);
        fig_names = local_export_figures(new_figs, spec.name, spec.fig_dir, c);

        results(end + 1).id = chunks(c).id;   %#ok<AGROW>
        results(end).text = captured;
        results(end).figures = fig_names;
        results(end).error = err_msg;

        acc = '';   % group closed; start a fresh group at the next chunk

        if ~isempty(err_msg)
            break;   % a real error stops the demo; the manifest records why
        end
    end

    % Code left accumulated at the end never closed its control block.
    if ~isempty(acc)
        results(end + 1).id = chunks(end).id;   %#ok<AGROW>
        results(end).text = '';
        results(end).figures = {};
        results(end).error = ['Incomplete code block: a control statement ', ...
                              'was not closed by the end of the demo.'];
    end

    local_write_json(spec.manifest, results);
    pause('on');
end


function tf = local_is_incomplete(e)
% True if the error is MATLAB reporting that the code is not yet a complete
% statement (an open control block), as opposed to a real runtime error.
    msg = lower(e.message);
    tf = contains(msg, 'end is missing') ...
      || contains(msg, 'is incomplete') ...
      || contains(msg, 'unexpected end of');
    if ~tf && ~isempty(e.identifier)
        idl = lower(e.identifier);
        tf = contains(idl, 'endmissing') || contains(idl, 'incomplete');
    end
end


function new_figs = local_new_figures(before, after)
% Figures present in after but not in before, compared by handle identity.
    new_figs = gobjects(0);
    for f = reshape(after, 1, [])
        if ~any(before == f)
            new_figs(end + 1) = f; %#ok<AGROW>
        end
    end
end


function names = local_export_figures(figs, demo_name, fig_dir, chunk_idx)
% Export each figure to a deterministic PNG and return the bare filenames.
    names = {};
    for j = 1:numel(figs)
        fname = sprintf('%s_chunk%02d_fig%d.png', demo_name, chunk_idx, j);
        exportgraphics(figs(j), fullfile(fig_dir, fname), 'Resolution', 150);
        names{end + 1} = fname; %#ok<AGROW>
    end
end


function out = local_to_cellstr(answers)
% Normalize the spec's answers field to a cell array of char.
% jsondecode maps an empty JSON array ("answers": []) to an empty double, a
% list of strings to a cellstr, and a single string to a char, so handle each.
    if iscell(answers)
        out = answers;
    elseif ischar(answers)
        out = {answers};              % single answer, possibly '' (blank enter)
    elseif isstring(answers)
        out = cellstr(answers);
    else
        out = {};                     % empty double: the demo has no answers
    end
end


function local_write_json(path, data)
    fid = fopen(path, 'w');
    fwrite(fid, jsonencode(data));
    fclose(fid);
end
