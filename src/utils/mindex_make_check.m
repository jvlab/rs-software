function [opts_used,mindex,mults]=mindex_make_check(tags,opts)
% [opts_used,mindex,mults]=mindex_make_check(tags,opts) creates or checks a multi-index
%
% tags: a multidimensional aray (typically of integers), must have dimension >=2
% opts: options
%    opts.mindex:  multi-index array, from mindex_make (computed if not supplied)
%    opts.mults:   multiplier from mindex_make (computed if not supplied)
%
% opts_used: opts, with mindex, mults, and any defaults
%
%   See also:  MINDEX_MAKE, FILLDEFAULT
%
opts=filldefault(opts,'mindex',[]);
opts=filldefault(opts,'mults',[]);
dims=size(tags);
r=length(dims);
%create multi-index or check that supplied values are valid
if isempty(opts.mindex) | isempty(opts.mults)
    [mindex,mults]=mindex_make(dims);
    opts.mindex=mindex;
    opts.mults=mults;
else
    mindex=opts.mindex;
    mults=opts.mults;
    if ~all(size(mindex)==[prod(dims) r]);
        disp('size(supplied mindex)')
        disp(size(mindex));
        error(sprintf(' supplied mindex size should be %7.0f %3.0f',prod(dims),r));
    end
    if ~all(size(mults)==[r 1])
        disp('size(supplied mults')
        disp(size(mults))
        error(sprintf('supplied mults size should be %7.0f %3.0f',[r 1]))
    end
end
opts_used=opts;
return

