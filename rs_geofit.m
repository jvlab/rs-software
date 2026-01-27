function [xforms,aux_out]=rs_geofit(data_in,data_out,aux)
% [xforms,aux_out]=rs_geofit(data_in,data_out,aux) is a template for rs modules
% that accept one or more input datasets, process it, and produce one or more output datasets
%
% data_in.ds{k},sas{k},sets{k}: dataset structures that are the starting points for the transformation
% data_out.ds{k},sas{k},sets{k}: dataset structures that are the targets of the transformation
%
% aux:
%  aux.opts_geof.if_log: 1 to log progress
%  aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
%  *may also have some bare options
% 
% xforms:
%   xforms.ts are the transformations
%   xforms.pipeline is a structure that can serve as a subfield for sets, when the transformations are applied
%
% aux_out: auxiliary outputs and parameter values used
%    opts_geofit: overall options used
%    *may have additional fields, typically
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, PSG_GEOMODELS_FIT, PSG_GEOMODELS_DEFINE.
%
if (nargin<=1)
    aux=struct;
end
%set up sub-structure options
aux=filldefault(aux,'opts_geof',struct); %options for this module (psg_template)
aux.opts_knit=filldefault(aux.opts_geof,'if_log',1);
%
aux=filldefault(aux,'opts_check',struct); %options for other modules called
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_geofit');
%
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
xforms=struct;
%
%invoke rs_check_coordsets to check input data, either file by file
% (as in rs_align_coordsets), or across files (as in rs_knit_coordsets)
% %
% %check internal consistency
% %
% for iset=1:nsets
%     data_check=struct;
%     data_check.ds{1}=data_in.ds{iset};
%     data_check.sas{1}=data_in.sas{iset};
%     data_check.sets{1}=data_in.sets{iset};
%     check=rs_check_coordsets(data_check,setfield(aux.opts_check,'set_num_offset',iset-1));
%     if ~isempty(check.warnings) %since strvcat([],[])~=[]
%         aux_out.warnings=strvcat(aux_out.warnings,check.warnings);
%         disp(check.warnings);
%     end
%     aux_out.warn_bad=aux_out.warn_bad+check.warn_bad;
% end
% %
% %check consistency and get available stimuli, dimensions, typenames
% %
% check=rs_check_coordsets(data_in,aux.opts_check);
% %
% 
% %
% %validate input parameters for consistency, etc.
% %
% % for matlab style warnings
% if (condition)
%     wmsg=sprintf('xxx');
%     warning(wmsg);
%     aux_out.warnings=strvcat(aux_out.warnings,wmsg);
%     aux_out.warn_bad=aux_out.warn_bad+1;
% end
% %for custom warnings with rs leadin
% if (condition)
%     wmsg=sprintf('dim_list_in and dim_list_out have different lengths');
%     aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1)); %to force a warning output; second argument is a 1 if a bad warning
%     %or%
%     aux_out=rs_warning(wmsg,0,aux_out); %to accumulage warnings and log based on aux_out, first force a warning output
% 
% end
% 
% % return options as used
% aux_out.opts_temp=aux.opts_temp;
% aux_out.opts_othr=aux.opts_othr;
% %
% if aux_out.warn_bad==0
% %process
%     data_out.ds{*}=;
%     data_out.sas{*}=sas_knitted;
%     data_out.sets{*}=sets_knitted;
%     %
%     aux_out.opts_knit=aux.opts_temp; %the main options for this module
%     aux_out.opts_othr=opts_othr_used; %options for other routines called
%     aux_out.opts_oth2=opts_oth2_used;
% else
%     disp('cannot proceed');
% end

return
end
