function check_new=rs_warning(msg,if_bad,opts_check)
% check_new=rs_warning(msg,if_bad,opts_check) produces a warning message and updates a strructure of warning tallies and messages
% 
% msg: a string or a strvcat of strings
% if_bad: 1 if the warning is severe, and should hald further processing
% opts_check: a structure
%   opts_check.if_warn: whether to echo warnings (defaults to 1)
%   opts_check.warnings: warnings so far, as a strvcat (defaults to []) 
%   opts_check.warn_bad: a tally of serious warnings (defaults to 0)
%   opts_check.warn_leadin: a prefix for warnings echoed at console
%
% check_new: updated opts_check structure
%
if (nargin<=2)
    opts_check=struct();
end
opts_check=filldefault(opts_check,'if_warn',1);
opts_check=filldefault(opts_check,'warnings',[]);
opts_check=filldefault(opts_check,'warn_bad',0);
opts_check=filldefault(opts_check,'warn_leadin',getfield(getfield(rs_aux_customize(struct()),'overall'),'warn_leadin'));
%
if opts_check.if_warn
    for k=1:size(msg,1)
        disp(cat(2,opts_check.warn_leadin,msg(k,:)));
    end
end
opts_check.warnings=strvcat(opts_check.warnings,msg);
opts_check.warn_bad=opts_check.warn_bad+if_bad;
%
check_new=opts_check;
return
end

