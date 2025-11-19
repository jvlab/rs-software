function [ifdif,opts_used]=rs_benchmark_compare(rs_outfile,opts)
% [ifdif,t,b,opts_used]=rs_benchmark_compare(rs_outfile,opts) compares the contents of a test file with a benchmark
%
% rs_outfile: name of file to compare, e.g., rs_aux_customize_test
% opts: options
%  opts.signflips{k}: a cell array of nested fieldnames pointing to variables that may have a dimension sign-flipped, defaults to empty
%  opts.ignore{k}: a cell array of fieldnames that should not be compared
%  opts.flipdims: array, of same length as signflips, indicating the dimensions for flips
%
% ifdif: empty if contents are identical, otherwise a string describing the differences
% opts_used:
%  opts_used.t|b]: test or benchmark structure read from file, with all fields
%  opts_used.[t|b]_comp: test or benchmark structure, with fields with column sign-flip ambiguities removed
%  opts_used.signflips{k}.[t|b]: fields that need to be compared recognizing sign-flip ambiguities
%  opts_used.flipdims: dimensions for possible slgn flips
%
%   See also:  FILLDEFAULT, RMSUBFIELD, GETSUBFIELD, COMPARE_SIGNFLIP, RS_WARNING.
%
if (nargin<=1)
    opts=struct;
end
opts=filldefault(opts,'dir_test','tests');
opts=filldefault(opts,'dir_benchmark','benchmarks');
opts=filldefault(opts,'if_log',1);
opts=filldefault(opts,'signflips',cell(0));
opts=filldefault(opts,'ignore',cell(0));
opts=filldefault(opts,'flipdims',ones(1,length(opts.signflips)));
%
tf=cat(2,opts.dir_test,filesep,rs_outfile,'.mat');
tf=strrep(tf,'.mat.mat','.mat');
bf=cat(2,opts.dir_benchmark,filesep,rs_outfile,'.mat');
bf=strrep(bf,'.mat.mat','.mat');
if exist(tf,'file')
    t=load(tf);
else
    rs_warning(sprintf('%s not found',tf));
    t=struct;
end
if exist(bf,'file')
    b=load(bf);
else
    rs_warning(sprintf('%s not found',bf));
    b=struct;
end
t_comp=t;
b_comp=b;
%remove fields to be ignored
for k=1:length(opts.ignore)
    if opts.if_log
        disp(sprintf('field (and subfield) that are ignored'));
        disp(opts.ignore{k});
    end
    if ~isempty(t_comp)
        t_comp=rmsubfield(t_comp,opts.ignore{k});
    end
    if ~isempty(b_comp)
        b_comp=rmsubfield(b_comp,opts.ignore{k});
    end
end
%extract signflips
signflips=cell(0,length(opts.signflips));
for k=1:length(opts.signflips)
    if opts.if_log
        disp(sprintf('field (and subfield) that may have sign-flips along dimension %2.0f',opts.flipdims(k)));
        disp(opts.signflips{k});
    end
    signflips{k}=struct;
    if ~isempty(t_comp)
        t_comp=rmsubfield(t_comp,opts.signflips{k});
        signflips{k}.t=getsubfield(t,opts.signflips{k});
    end
    if ~isempty(b_comp)
        b_comp=rmsubfield(b_comp,opts.signflips{k});
        signflips{k}.b=getsubfield(b,opts.signflips{k});
    end
    %process signflips: compare columns of signflips{k}.t{m}{d} with signflips{k}.b{m}{d}
    [signflips{k}.ifdif,signflips{k}.maxdiff,signflips{k}.maxdiff_noflip]=...
        compare_signflip(signflips{k}.b,signflips{k}.t,opts.flipdims(k));
    if opts.if_log
        if ~isempty(signflips{k}.ifdif)
            disp(signflips{k}.ifdif);
            if ~isempty(signflips{k}.maxdiff)
                disp(sprintf('max difference: %0.5g (without sign flip: %0.5g)',signflips{k}.maxdiff,signflips{k}.maxdiff_noflip));
            end
        end
    end
end
%
opts.t=t;
opts.b=b;
opts.b_comp=b_comp;
opts.t_comp=t_comp;
opts.signflips=signflips;
%
%
ifdif=compstruct('benchmark',b_comp,'test',t_comp);
if ~isempty(ifdif)
    rs_warning(sprintf('%s: benchmark comparison fails',rs_outfile));
else
    if (opts.if_log)
        disp(sprintf('%s: benchmark comparison ok',rs_outfile));
    end
end
opts_used=opts;
return

