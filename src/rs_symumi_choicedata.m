function [su,aux_out]=rs_symumi_choicedata(data_comp,aux)
% [su,aux_out]=rs_symumifit_choicedata(data_comp,aux) analyzes a set of triadic choices for consistency with symmetry and the ultrametric inequality
% 
% Args:
%   data_comp (int 2-D array): Triadic choice data, with each row containing the data from a single kind of comparison
%
%      - col 1 is reference, col 2 is s1, col 3 is s2
%      - col 4: number of times the first difference was judged __more similar than__ the second difference
%      - col 5: number of times the comparison was made
%
%   aux (struct): a structure, can be omitted, with fields 
%
%     - opts_symumi (struct): options for analysis, with fields
%
%         - if_log (int): 1 to log progress, 0 to omit; default is 1; see note below regarding customization
% 
%         - **Options for statistics and shuffles**
%         - if_frozen (int): random number control; 1 for same numbers every run, 0 for different random numbers each run, negative integer for a fixed seed each run, default is 1
%
%     - opts_check (struct): options for consistency checking, with field
%
%         - if_warn (int): 1 to show warnings, 0 to suppress; default is 1
%
% Returns:
%   su (struct): analysis results, a structure with fields
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_symumi (struct): aux,opts_symumi with defaults and values used
%     - opts_check (struct): aux.opts_check, with defaults filled in
%
% See also: RS_DIRFIT_CHOICEDATA, LOGLIK_BETA_DISCRETE.
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_symumi',struct);
aux.opts_symumi=filldefault(aux.opts_symumi,'if_log',1);
aux.opts_symumi=filldefault(aux.opts_symumi,'if_frozen',1);
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_symumi_choicedata');
%
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
%set up random number generator
%
if_frozen=aux.opts_symumi.if_frozen;
if (if_frozen~=0) 
    rng('default');
    if (if_frozen<0)
        rand(1,abs(if_frozen));
    end
else
    rng('shuffle');
end
%
su=struct;
%
% triadic? at least two choices neded to fit a, three choices for a and h, and one extra if doing jackknifes
%
if size(data_comp,2)~=5
    wmsg=sprintf('choice data must be triadic');
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
%
choices=data_comp(:,end-1:end);
choices_nz=find(choices(:,2)>0);
choices_used=choices(choices_nz,:);
probs=choices_used(:,1)./choices_used(:,2);
choices_used=choices(choices_nz,:);
%
% enough data? at least two choices needed to fit a, three choices for a and h
%
nchoices=length(choices_nz);
choices_needed=3; %minimal choices needed
if nchoices<choices_needed
    wmsg=sprintf('insufficient choices available for fitting; at least %2.0f needed',choices_needed);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
if all(or(probs==0,probs==1))
   wmsg=sprintf('all probabilities are 0 or 1; fitted parameter values are unreliable');
   aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
%
aux_out.opts_symumi=aux.opts_symumi;
%
if aux_out.warn_bad>0
    disp('cannot proceed');
    disp(aux_out.warnings);
    return
end
%
return
end
