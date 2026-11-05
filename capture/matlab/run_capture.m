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
%               id        identifier echoed back in the manifest (the chunk index)
%               code      MATLAB source of the display chunk
%               snapshot  optional: '' for none, 'current' or 'all', from a
%                         %#demo-snapshot directive in the chunk
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
%
% Figures are exported while the group runs, not only when it ends. A single
% chunk can open dozens of figures (rs_toygeom_scenarioA opens 72 in one), and
% holding all of them until the end exhausted the graphics resources of a CI
% runner, which killed the job. A figure is exported and closed once
% CLOSE_LAG_FIGURES newer figures exist, so at most that many are ever open,
% whatever the demo does. The lag is what keeps it safe: demos routinely come
% back to a figure they created a moment ago, as rs_toygeom_disp does when it
% annotates the figures of the fit it just displayed. Should a demo revisit a
% figure that is already closed, figure(h) errors and the manifest records it,
% so the failure is loud rather than a silently incomplete image.
%
% Figures are numbered in the order they were created, so <demo>_chunk03_fig1
% is the first figure that chunk opened.
%
% Snapshots. A figure is exported once, when the group that opened it ends, so
% drawing on it in a later chunk does not reach the page. A chunk with a
% %#demo-snapshot directive exports figures again when its group ends: the
% current figure for 'current', every figure left open by earlier groups for
% 'all'. Only figures that existed before the group started are re-exported,
% since the group's own figures have just been exported anyway. The new images
% are listed after the group's own, and numbered on from them.

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

    % Export figures as the demo creates them; see the note in the header.
    restore_createfcn = onCleanup(@() local_stop_tracking()); %#ok<NASGU>

    acc = '';                                       % code of the current group
    group_snapshot = '';                            % strongest snapshot asked
    group_start_figs = findall(groot, 'Type', 'figure');

    for c = 1:numel(chunks)
        if isempty(acc)
            group_start_figs = findall(groot, 'Type', 'figure');
            acc = chunks(c).code;
        else
            acc = sprintf('%s\n%s', acc, chunks(c).code);
        end
        group_snapshot = local_stronger_snapshot(group_snapshot, ...
                                                 local_chunk_snapshot(chunks(c)));

        captured = '';
        err_msg = '';
        incomplete = false;
        % Progress is echoed as the chunk starts, not after it returns, so a
        % long-running chunk is visibly in progress rather than looking dead.
        % A demo can take many minutes in a single chunk (rs_geofit with
        % statistics, for example), and everything the demo prints is
        % swallowed by evalc, so this is the only feedback the console gets.
        fprintf('    chunk %d/%d ... ', c, numel(chunks));
        chunk_timer = tic;
        local_start_tracking(spec.name, spec.fig_dir, c);
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
            fprintf('open block, accumulating\n');
            continue;   % accumulate the next chunk before running again
        end
        fprintf('%.1f s\n', toc(chunk_timer));

        drawnow;        % force pending draws so figures are complete
        fig_names = local_stop_tracking(group_start_figs);
        fig_names = [fig_names, local_snapshot(group_snapshot, spec.name, ...
            spec.fig_dir, c, numel(fig_names), group_start_figs)]; %#ok<AGROW>

        results(end + 1).id = chunks(c).id;   %#ok<AGROW>
        results(end).text = captured;
        results(end).figures = fig_names;
        results(end).error = err_msg;

        acc = '';   % group closed; start a fresh group at the next chunk
        group_snapshot = '';

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


function mode = local_chunk_snapshot(chunk)
% The snapshot mode a chunk asks for, '' when none. Specs written before the
% directive existed have no snapshot field at all.
    mode = '';
    if isfield(chunk, 'snapshot') && ischar(chunk.snapshot)
        mode = chunk.snapshot;
    end
end


function mode = local_stronger_snapshot(first, second)
% Combine the requests of the chunks in one group: 'all' > 'current' > ''.
    order = {'', 'current', 'all'};
    rank = @(m) find(strcmp(order, m), 1);
    if isempty(rank(second)) || rank(first) >= rank(second)
        mode = first;
    else
        mode = second;
    end
end


function names = local_snapshot(mode, demo_name, fig_dir, chunk_idx, nprior, before)
% Export figures again at the end of a group, as a %#demo-snapshot asked.
%
% before holds the figures open when the group started, as findall returned
% them (newest first). Only those are candidates: a figure the group opened
% itself was exported moments ago by local_stop_tracking. Images are numbered
% on from the nprior the group already produced.
    names = {};
    switch mode
        case 'current'
            figs = get(groot, 'CurrentFigure');
        case 'all'
            figs = flip(before);                    % oldest first
        otherwise
            return
    end

    for f = reshape(figs, 1, [])
        if ~isvalid(f) || ~any(before == f)
            continue    % closed since, or opened by this group
        end
        fname = sprintf('%s_chunk%02d_fig%d.png', demo_name, chunk_idx, ...
                        nprior + numel(names) + 1);
        try
            local_export_figure(f, fullfile(fig_dir, fname));
            names{end + 1} = fname; %#ok<AGROW>
        catch e
            fprintf(2, '\n    snapshot export failed (%s): %s\n', fname, e.message);
        end
    end
end


function local_start_tracking(demo_name, fig_dir, chunk_idx)
% Begin exporting figures as the current group creates them.
%
% State lives in groot's application data rather than in a variable, because the
% figure-creation callback runs outside this function's workspace. A group that
% is still accumulating an open control block never executes, so restarting the
% tracking on each attempt cannot lose figures: the successful attempt is the
% one that runs, and its chunk index is the one the images are named after.
    state = struct('demo', demo_name, 'fig_dir', fig_dir, 'chunk', chunk_idx, ...
                   'names', {{}}, 'tracked', gobjects(1, 0), 'busy', false);
    setappdata(groot, 'RS_CAPTURE_STATE', state);
    set(groot, 'DefaultFigureCreateFcn', @local_figure_created);
end


function names = local_stop_tracking(group_start_figs)
% Stop tracking, export whatever the group left open, and return every image
% name it produced, in creation order.
%
% Figures still open here are the newest ones, the ones the lag deliberately
% keeps available. They are exported but NOT closed, because a later chunk may
% still draw into them, which is how rs_toygeom_sim builds up one figure per
% paradigm across several chunks. Closing them is the next demo's "close all".
    set(groot, 'DefaultFigureCreateFcn', '');
    names = {};
    if ~isappdata(groot, 'RS_CAPTURE_STATE')
        return
    end
    state = getappdata(groot, 'RS_CAPTURE_STATE');
    rmappdata(groot, 'RS_CAPTURE_STATE');
    if nargin < 1
        return      % cleanup path: the group errored, names are not needed
    end

    open_figs = state.tracked(isvalid(state.tracked));

    % A demo that passes its own CreateFcn to figure() overrides the default and
    % is never tracked, so pick up anything else the group opened as well.
    extra = local_new_figures(group_start_figs, state.tracked, ...
                              findall(groot, 'Type', 'figure'));
    for f = [open_figs, extra]
        state = local_export_one(state, f);
    end
    names = state.names;
end


function local_figure_created(new_fig, ~)
% Default CreateFcn for every figure a tracked group opens: remember the new
% figure, then export and close any that are now more than CLOSE_LAG_FIGURES
% old. The lag is generous because demos revisit the figures of the display
% call they just made; it only has to bound how many stay open at once.
    CLOSE_LAG_FIGURES = 20;

    if ~isappdata(groot, 'RS_CAPTURE_STATE')
        return
    end
    state = getappdata(groot, 'RS_CAPTURE_STATE');
    if state.busy
        return      % a figure opened by exportgraphics itself; not the demo's
    end

    state.tracked = [state.tracked(isvalid(state.tracked)), new_fig];
    while numel(state.tracked) > CLOSE_LAG_FIGURES
        oldest = state.tracked(1);
        state.tracked = state.tracked(2:end);
        state = local_export_one(state, oldest);
        delete(oldest);     % delete, not close: CloseRequestFcn must not block
    end
    setappdata(groot, 'RS_CAPTURE_STATE', state);
end


function state = local_export_one(state, fig)
% Export one figure and record its name. Never lets an export failure reach the
% demo: an image that cannot be written is worth less than the rest of the run.
    if ~isvalid(fig)
        return
    end
    state.busy = true;      % suppress tracking of anything exportgraphics opens
    setappdata(groot, 'RS_CAPTURE_STATE', state);
    fname = sprintf('%s_chunk%02d_fig%d.png', state.demo, state.chunk, ...
                    numel(state.names) + 1);
    try
        local_export_figure(fig, fullfile(state.fig_dir, fname));
        state.names{end + 1} = fname;
    catch e
        fprintf(2, '\n    figure export failed (%s): %s\n', fname, e.message);
    end
    state.busy = false;
    setappdata(groot, 'RS_CAPTURE_STATE', state);
end


function new_figs = local_new_figures(before, tracked, after)
% Figures in after that are neither in before nor already tracked, oldest first.
% findall returns figures newest first, hence the flip.
    new_figs = gobjects(1, 0);
    for f = reshape(flip(after), 1, [])
        if ~any(before == f) && ~any(tracked == f)
            new_figs(end + 1) = f; %#ok<AGROW>
        end
    end
end


function local_export_figure(fig, path)
% Write one figure to a PNG.
%
% 96 dpi rather than 150: each render needs about 2.4 times fewer pixels, which
% matters on CI runners where software rendering of many figures ran out of
% graphics resources, and the PNGs come out about half the size. Figures stay
% legible, though dense stimulus-label clusters get tight.
    EXPORT_DPI = 96;
    exportgraphics(fig, path, 'Resolution', EXPORT_DPI);
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
