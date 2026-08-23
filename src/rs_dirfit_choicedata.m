function [dirfit,aux_out]=rs_dirfit_choicedata(choices,aux)
% [dirfit,aux_out]=rs_dirfit_choicedata(choices,aux) fits Dirichlet parameters to choice probability distribution
% 
% Args:
%   choices (int 2-D array): Each row contains the data from a single kind of comparison, typically the last two columns of data_comp as returned by `rs_read_choicedata`
%
%      - choices(:,1): number of times the first difference was judged __more similar than__ the second difference
%      - choices(:,2): number of times the comparison was made
%
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
%   dirfit (struct): the fitted Dirichlet parameter values, a structure with fields
%
%      - nchoices: number of choices used
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_read (cell array of struct): opts_read{1} is aux.opts_read, with defaults filled in
%     - opts_check (struct): aux.opts_check, with defaults filled in
%
%  See also: RS_READ_CHOICEDATA
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
probs=choices(:,1)./choices(:,2);
nchoices=size(choices,1);
if aux.opts_dirfit.if_log
    disp(sprintf('fitting Dirichlet parameters: %5.0f choices, probability range: [%8.6f %8.6f]',nchoices,min(probs),max(probs)));
end
%
dirfit=struct;
dirfit.nchoices=nchoices;
return
