function [rs,xs,aux_out]=rs_geofit(data_in,data_out,aux)
% [rs,xs,aux_out]=rs_geofit(data_in,data_out,aux) fits one or more geometrical transformations
% to coordinate sets
%
% data_in.ds{k},sas{k},sets{k}: dataset structures that are the starting points for the transformation
% data_out.ds{k},sas{k},sets{k}: dataset structures that are the targets of the transformation
%  These are checked for internal consistency, and warnings are given.
%  They must have same number of stimuli.
% aux:
%  aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
%
%   ****here need to specify how transforms are selected and nestings*****
%  aux.opts_geof.dimpairs_method: pairs of dimensoins considered between input and ouptut datasets
%   'all': all pairings
%   'equal': input dimension= output dimension (default)
%   'din_lteq_dout': input dimension less than or equal to output dimension
%   'din_gteq_dout': input dimension greater than or equal to output dimension
%   'list': a two-column list of pairs (in, out)
%  aux.opts_geof.dimpairs_list:  two-column array of pairs of dimensions to consider
%  aux.opts_geof.xform_select_method: transformations for xs are selected
%   'equal' (default): xforms.ts{k}{idim} is taken from input dim= output dim
%   'list': xform_select_list is a two-column array; first column is input dim, second column is to be used for the transform output dim, 
%  aux.opts_geof.if_log: 1 (default) to log progress
%    
% rs{k}.results{din,dout} is a structure containing the results of the analysis, including fitted transformations, residuals, statistics
%    from data_in.da{k} to data_out.da{k}, for dimensions din and dout
% xs: the transformations, in a format compatible with rs_xform_apply
%   xs.{iclass}.class: the transformation class ('affine', 'projective','pwaffine','pwprojective')
%   xs.{iclass}.xforms.ts{k}{idim}: the transformation to be applied to dataset k, coordinate set of dimension idim
%     (this will be empty if there is no transformation in rs{k}.results{idim,idim}
%
% aux_out: auxiliary outputs and parameter values used
%    opts_geofit: overall options used
%    *may have additional fields, typically
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, PSG_GEOMODELS_FIT, PSG_GEOMODELS_DEFINE.
%
if (nargin<=1)
    aux=struct;
end
%set up sub-structure options
aux=filldefault(aux,'opts_geof',struct); %options for this module (psg_template)
aux.opts_geof=filldefault(aux.opts_geof,'if_log',1);
%
aux=filldefault(aux,'opts_check',struct); %options for other modules called
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
%************need to set up defaults***********
aux=rs_aux_customize(aux,'rs_geofit');
%
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
xs=struct;
rs=struct;
%check consistency
check_in=rs_check_coordsets(data_in,aux.opts_check);
aux_out.warnings=strvcat(aux_out.warnings,check_in.warnings);
check_out=rs_check_coordsets(data_out,aux.opts_check);
aux_out.warnings=strvcat(aux_out.warnings,check_out.warnings);
%
%
% check.nsets=nsets;
% check.nstims_each=nstims_each;
% check.dim_list_each=dim_list_each;
% check.dim_list_union=dim_list_union;
% check.dim_list_inter=dim_list_inter;
% check.typenames_each=typenames_each;
% check.typenames_union=typenames_union;
% check.typenames_inter=typenames_inter;
%
if aux_out.warn_bad>0
    disp('cannot proceed');
    return
end
nstims_in=check_in.nstims_each;
nstims_out=check_out.nstims_each;
if nstims_in~=nstims_out
    wmsg=sprintf('mismatch in number of stimuli: input dataset has %3.0f stimuli, output dataset has %3.0f stimuli',nstims_in,nstims_out);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',1));
end
if length(union(check_in.typenames_union,check_out.typenames_union))~=length(intersect(check_in.typenames_inter,check_out.typenames_inter))
    wmsg=sprintf('data_in and data_out have different typenames');
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
if aux_out.warn_bad>0
    disp('cannot proceed');
    return
end
nsets=max(check_in.nsets,check_out.nsets);
rs=cell(1,nsets);
xs=cell(1,nsets);
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
%     disp('cannot proceed');
% end

return
end
