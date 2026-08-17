function [data_comp,aux_out]=rs_read_choicedata(fullname,aux)
% [data_comp,aux_out]=rs_read_choicedata(fullname,aux) reads a single `choice file`
%
% The `choice file` may be triadic or tetradic, as determined by the number of columns in the choices variable of the data file:  5 columns if triadic, 6 columns if tetradic
% Each row of the variable 'responses' holds responses from one or more presentations of a single comparison.  Comparisons may be repeated in other rows, and a comparison may also be repeated with a separate indexing (e.g., s1 and s2 may be reversed).
%
% __Important note__: The standard convention in the `choice file` is to count the number of times the first comparison is judged to be more different than the second; in 'data_comp', the __opposite__ convention is used.
% This conversion is made automatically and logged.
%
% Args:
%   fullname (char or singleton char array): full file name with path; if empty, it will be requested interactively. File names must contain the string '_coords'. See note below regarding setup files.
%
%   aux (struct): a structure, can be omitted, with fields 
%
%     - opts_read (struct): options for reading, can be omitted, with fields
%
%         - if_gui (int): 1 to use graphical interface to request data file name if 'fullname' is empty, 0 to use console; default is 1; see note below regarding customization
%         - if_log (int): 1 to log progress, 0 to omit; default is 1; see note below regarding customization
%         - data_fullname_def (char): prompt for data file if 'data_fullname' is empty; see note below regarding customization
%         - ui_filter (char): file name filter that appears in graphical user interface when if_gui=1; defaults to '*_choices*'; see note below regarding customization
%
%         - **Options for internal use and maintenance**
%         - if_uselocal (int): typically omitted; 0 to use options in rs_aux_defaults, 1 is reserved for maintenance; default is 0
%
%     - opts_check (struct): options for consistency checking, with field
%
%         - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
%
% Returns:
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
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - typenames (cell array):  stimulus labels, corresponding to the indices used in the first 3 or 4 columns of choices.  The order is unchanged from the order in the data file.
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_read (cell array of struct): opts_read{1} is aux.opts_read, with defaults filled in
%     - opts_check (struct): aux.opts_check, with defaults filled in
%
% Note: Note regarding customization
%     - The defaults for the following parameters can be set by editing the line containing generic.opts_read.[param_name] in  `rs_aux_defaults_define`, running it once, and saving the workspace as rs_aux_defaults.mat.
%
%         - if_gui
%         - if_log
%         - data_fullname_def ('_coords' will be replaced by '_choices' at run time)
%         - coord_string
%         - type_class_aux
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, PSG_READ_COORDDATA.
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_read',struct);
%
aux=filldefault(aux,'opts_rays',struct);
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux.opts_read.ui_filter='*_choices*';
aux=rs_aux_customize(aux,'rs_read_choicedata');
%
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
if iscell(fullname)
    fullname=fullname{1};
end
%
if isempty(fullname)
    if aux.opts_read.if_gui
        if_manual=0;
        ui_prompt='Select a choice file';
        ui_filter=aux.opts_read.ui_filter;       
        while (if_manual==0 & isempty(fullname))
            [filename_short,pathname]=uigetfile(ui_filter,ui_prompt,'Multiselect','off');
            if  (isequal(filename_short,0) | isequal(pathname,0)) %use Matlab's suggested way to detect cancel
                if_manual=getinp('1 to return to selection from console','d',[0 1]);
            else
                fullname=cat(2,pathname,filename_short);
            end
        end
    end
end
aux.opts_read.nometa=1;
aux.opts_read.sign_check_mode=0; %look for sign (< or >) in responses_colnames, and ask if it is not found
aux.opts_read.data_fullname_def=strrep(aux.opts_read.data_fullname_def,'_coords','_choices');
aux.opts_read.permutes=[]; %so that psg_read_coorddata will not attempt to permute rays
[data_comp,opts_read_used]=psg_read_choicedata(fullname,[],aux.opts_read);

% %
% data_out.ds{1}=d;
% data_out.sas{1}=sa;
% data_out.sets{1}=sets;
% aux_out.opts_check=aux.opts_check;
% aux_out.opts_read{1}=opts_read_used;
% aux_out.opts_rays{1}=opts_rays_used;
% aux_out.rayss{1}=rays;
% %for compatibility with rs_get_coordsets;
% aux_out.opts_qpred{1}=struct;
% aux_out.syms_list=struct();
% %
% %check consistency
% %
% check=rs_check_coordsets(data_out,aux.opts_check);
% if ~isempty(check.warnings) %since strvcat([],[])~=[]
%     aux_out.warnings=strvcat(aux_out.warnings,check.warnings);
%     warn_leadin=getfield(getfield(rs_aux_customize(struct()),'overall'),'warn_leadin');
%     for k=1:size(aux_out.warnings,1)
%         disp(cat(2,warn_leadin,aux_out.warnings(k,:)));
%     end
% end
% aux_out.warn_bad=aux_out.warn_bad+check.warn_bad;
% return
