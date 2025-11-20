function opts_used=rs_warning(msg,if_bad,opts_warn)
% opts_used=rs_warning(msg,if_bad,opts_warn) produces a warning message and updates a strructure of warning tallies and messages
% 
% msg: a string or a strvcat of strings
% if_bad: 1 (default) if the warning is severe, and should hald further processing; may be omitted
% opts_warn: a structure, may be omitted
%   opts_warn.if_warn: whether to echo warnings (defaults to 1)
%   opts_warn.warnings: warnings so far, as a strvcat (defaults to []) 
%   opts_warn.warn_bad: a tally of serious warnings (defaults to 0)
%   opts_warn.warn_leadin: a prefix for warnings echoed at console
%   opts_warn.if_warn_traceback: 1 to show a traceback with each warning, defaults to 0, if 1, forces if_warn to 1
%
% opts_used: updated opts_warn structure
%
if (nargin<=1)
    if_bad=1;
end
if (nargin<=2)
    opts_warn=struct();
end
opts_warn=filldefault(opts_warn,'if_warn',1);
opts_warn=filldefault(opts_warn,'warnings',[]);
opts_warn=filldefault(opts_warn,'warn_bad',0);
opts_warn=filldefault(opts_warn,'warn_leadin',getfield(getfield(rs_aux_customize(struct()),'overall'),'warn_leadin'));
opts_warn=filldefault(opts_warn,'if_warn_traceback',getfield(getfield(rs_aux_customize(struct()),'overall'),'if_warn_traceback'));
if opts_warn.if_warn_traceback
    opts_warn.if_warn=1;
end
%
if opts_warn.if_warn
    for k=1:size(msg,1)
        disp(cat(2,opts_warn.warn_leadin,msg(k,:)));
    end
end
if opts_warn.if_warn_traceback
    warning(opts_warn.warn_leadin);
end
opts_warn.warnings=strvcat(opts_warn.warnings,msg);
opts_warn.warn_bad=opts_warn.warn_bad+if_bad;
%
opts_used=opts_warn;
return
end

