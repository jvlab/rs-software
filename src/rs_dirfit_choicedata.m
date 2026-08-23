function [dirfit,aux_out]=rs_dirfit_choicedata(data_comp,aux)
% [dirfit,aux_out]=rs_dirfit_choicedata(data_comp,aux) fits Dirichlet parameters to choice probability distribution
% 
% Args:
%   data_comp (int 2-D array): Each row contains the data from a single kind of comparison
%
%      - first 3 or 4 columns: indexes into the stimuli used for the comparison
% 
%          - triadic: col 1 is reference, col 2 is s1, col 3 is s2, comparisons are (ref,s1) and (ref,s2)
%          - tetradic: cols 1-4 are s1-s4, comparisons are (s1,s2) and (s3,s4)
%
%      - next column: number of times the first comparison was judged __more similar than__ the second comparison.
%      - final column: number of times the comparison was made
%
%   aux (struct): a structure, can be omitted, with fields 
%
%     - opts_dirfit (struct): options for fitting Dirichlet parameters, can be omitted, with fields
%
%         - if_log (int): 1 to log progress, 0 to omit; default is 1; see note below regarding customization
%
%     - opts_check (struct): options for consistency checking, with field
%
%         - if_warn (int): 1 to show warnings, 0 to suppress; default is 1
%
% Returns:
%
%   dirfit (struct): the fitted Dirichlet parameter values
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_read (cell array of struct): opts_read{1} is aux.opts_read, with defaults filled in
%     - opts_check (struct): aux.opts_check, with defaults filled in
%
%
%  See also: RS_READ_CHOICEDATA
%
valid_choice_types={'triadic','tetradic'};
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_dirfit',struct);
aux.opts_dirfit=filldefault(aux.opts_dirfit,'if_log',1);
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_dirfit_choicedata');
%
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
dirfit=struct;
return
