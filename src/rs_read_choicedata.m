function [data_comp,aux_out]=rs_read_choicedata(fullname,aux)
% [data_comp,aux_out]=rs_read_choicedata(fullname,aux) reads a single `choice file` and validates entries
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
%         - data_fullname_def (char): prompt for data file if 'fullname' is empty; see note below regarding customization
%         - ui_filter (char): file name filter that appears in graphical user interface when if_gui=1; defaults to '*_choices*'; see note below regarding customization
%         - if_consolidate (int): 1 to consolidate equivalent triadic and tetradic judgments into a single line, 0 does not; default is 1
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
%      - next column: number of times the first difference was judged __more similar than__ the second difference
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
valid_choice_types={'triadic','tetradic'};
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_read',struct);
aux.opts_read=filldefault(aux.opts_read,'if_consolidate',1);
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
[data_comp,sa,opts_read_used]=psg_read_choicedata(fullname,[],aux.opts_read);
%
aux_out.typenames=sa.typenames;
aux_out.opts_read=opts_read_used;
aux_out.opts_check=aux.opts_check;
%
ncols=size(data_comp,2);
%
%validate response values: integer and in range, otherwise can't proceed
%
resps=data_comp(:,ncols-1);
trials=data_comp(:,ncols);
if any(resps~=round(resps)) | any(trials~=round(trials)) | any(resps<0) | any(resps>trials) | any(trials<0)
    wmsg=sprintf('response counts or trial counts is non-integer or out of range');
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
%
%validate indices for choices: integer and in range, otherwise can't proceed
%
all_stim_indices=unique(data_comp(:,1:ncols-2));
if any(all_stim_indices~=round(all_stim_indices)) | any(all_stim_indices<1) | any(all_stim_indices>length(aux_out.typenames))
    wmsg=sprintf('stimulus indices are non-integer or out of range, should be in [1:%1.0f]',length(aux_out.typenames));
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
%
% stimuli that never appear as indices: warning but can proceed
%
missing_stims=setdiff(1:length(aux_out.typenames),all_stim_indices);
if ~isempty(missing_stims) 
    wmsg=sprintf('some stimulus indices never appear in choices');
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
    disp('missing indices:')
    disp(sprintf(' %1.0f',missing_stims))
end   
%
%validate choice type: if not recognized, cannot proceed
%
if_valid_choice_type=strmatch(aux_out.opts_read.choice_type,valid_choice_types,'exact');
if isempty(if_valid_choice_type)
    wmsg=sprintf('choice type (%s) not recognized',aux_out.opts_read.choice_type);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
%
if aux_out.warn_bad>0
    disp('cannot proceed');
    disp(aux_out.warnings);
    return
end
%
%consolidate if requested
%
if aux.opts_read.if_consolidate
    data_comp_orig=data_comp;
    switch aux_out.opts_read.choice_type
        case 'triadic'
            flip=find(data_comp(:,2)>data_comp(:,3));
            data_comp(flip,[2 3])=data_comp(flip,[3 2]); %change the indices
        case 'tetradic'
            %first put comparisons in lexicographic order
            rev12=find(data_comp(:,1)>data_comp(:,2));
            data_comp(rev12,[1 2])=data_comp(rev12,[2 1]);
            rev34=find(data_comp(:,3)>data_comp(:,4));
            data_comp(rev34,[3 4])=data_comp(rev34,[4 3]);
            %
            flip_first=find(data_comp(:,1)>data_comp(:,3));
            flip_tie=intersect(find(data_comp(:,1)==data_comp(:,3)),find(data_comp(:,2)>data_comp(:,4)));
            flip=union(flip_first,flip_tie);
            data_comp(flip,[1 2 3 4])=data_comp(flip,[3 4 1 2]); %change the indices
    end
    nflipped=length(flip);
    data_comp(flip,ncols-1)=data_comp(flip,ncols)-data_comp(flip,ncols-1);
    [urows,ia,ic]=unique(data_comp(:,1:ncols-2),'rows','stable');
    data_comp_dups=data_comp;
    data_comp=zeros(length(ia),ncols);
    for k=1:length(ia)
        rows=find(ic==k);
        data_comp(k,1:ncols-2)=data_comp_dups(rows(1),1:ncols-2);
        data_comp(k,ncols-1:ncols)=sum(data_comp_dups(rows,ncols-1:ncols),1);
    end
    if aux.opts_read.if_log
        disp(sprintf('consolidation: %4.0f sets of judgments consolidated to %4.0f; %4.0f sets flipped',size(data_comp_orig,1),size(data_comp,1),nflipped));
    end      
end
return
end
