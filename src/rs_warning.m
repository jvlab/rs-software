function opts_used=rs_warning(msg,if_bad,opts_warn)
%opts_used=rs_warning(msg,if_bad,opts_warn) displays a warning message and updates a structure of warning tallies and messages
% 
% Args:
%   msg (char or vertical concatenation of char): one or more warning messages
%   if_bad (int): severity, can =be omitted; 1 indicates that furhter processing cannot proceed, 0 is less serious; default is 1
%   opts_warn (struct): options, can be omitted, with fields
%
%      - if_warn (int): 1 to display warning, 0 to omit; default is 1
%      - warnings (char or vertical concatenaton of char): previous warnings; default is []
%      - warn_bad (int): current tally of serious warnings; default is 0
%      - warn_leadin (char) a prefix for warnings echoed at console;
%      default is '##### rs_warning: '; can be modified by editing `rs_aux_defaults_define` [??how to hyperlink]
%      - if_warn_traceback (int): 1 to show a traceback with each warning, 0 to omit; default is 0 defaults to 0; if 1, forces if_warn to 1
%
%  Returns:
%    opts_used (struct): updated opts_warn structure
%
% Note: 
%    Typical usage is
%    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux_out.if_warn)) [?how to show code?]
%    which appends the warning message 'wmsg' to aux_out.warnings, and increments tally of aux_out.warn_bad
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

