function answer = input(prompt, mode)
% input  Scripted stand-in for the builtin input(), used only during
%        documentation capture. This file deliberately shadows the builtin
%        so that demos containing interactive prompts can run unattended in
%        batch. It must be on the path only while capture runs, and removed
%        afterwards, so it never affects normal use of the code.
%
% Answers are supplied by the capture driver through two globals:
%   DEMO_ANSWERS  cell array of raw answer strings, in call order
%   DEMO_IDX      index of the last answer consumed (starts at 0)
%
% An empty answer string means "the user pressed enter", matching the real
% input(), which returns [] (numeric mode) or '' (in 's' mode) in that case.

    global DEMO_ANSWERS DEMO_IDX

    DEMO_IDX = DEMO_IDX + 1;
    if DEMO_IDX > numel(DEMO_ANSWERS)
        error('democapture:tooFewAnswers', ...
            ['input() was called more times than there are demo-input ', ...
             'directives in this demo. Add another directive comment.']);
    end
    raw = DEMO_ANSWERS{DEMO_IDX};

    % Echo the prompt and the answer into the captured console text. In a
    % real terminal the typed characters are echoed by the terminal, not by
    % MATLAB, so without this the answer would be missing from the docs.
    fprintf('%s%s\n', prompt, raw);

    if nargin > 1 && strcmp(mode, 's')
        answer = raw;              % 's' mode: return the text verbatim
    elseif isempty(raw)
        answer = [];               % plain enter --> [] like the real input()
    else
        answer = str2num(raw);     %#ok<ST2NM> evaluate, as the real input() does
    end
end
