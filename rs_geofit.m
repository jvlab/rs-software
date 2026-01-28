function [rs,xs,aux_out]=rs_geofit(data_in,data_out,aux)
% [rs,xs,aux_out]=rs_geofit(data_in,data_out,aux) fits one or more geometrical transformations
% to coordinate sets
%
% data_in.ds{k},sas{k},sets{k}: dataset structures that are the starting points for the transformation
% data_out.ds{k},sas{k},sets{k}: dataset structures that are the targets of the transformation
%  They must have same number of stimuli, and a warning is given if the number matches but the names do not.
% aux:
%  aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
%
%  aux.opts_geof.model_list: a string, or a cell array of strings, consisting of one or more of the model types to be fitted.
%   These the strings in getfield(psg_geomodels_define,'model_types'), and currently are the following
%   If empty (default), the list is requested interactively.
%    'mean'                       : all input values mapped to mean of output                       }
%    'procrustes_noscale_nooffset': rotation (and possibly reflection) of input, no rescaling     , no translation
%    'procrustes_scale_nooffset   : rotation (and possibly reflection) of input, rescaling allowed, no translation
%    'procrustes_noscale_offset'  : rotation (and possibly reflection) of input, no rescaling     , translation allowed
%    'procrustes_scale_offset     : rotation (and possibly reflection) of input, rescaling allowed, translation allowed
%    'affine_nooffset'            : linear transformation of input, no translation
%    'affine_offset'              : linear transformation of input, translation allowed
%    'projective'                 : projective transformation of input
%    'pwaffine'                   : piecwise affine with one cutplane; two linear transformations with agreement on the cut
%    'pwaffine_2'                 : piecwise affine with two cutplanes: four linear transformations, with agreement on the cuts
%     Note: if empty, this is requested interactively.
%
%  aux.opts_geof.dimpairs_method: pairs of dimensions considered between input and ouptut datasets
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
%   Note: mdef=rs_geofit() returns a model definition structure;
%     mdef.model_types contains the names of available models
%     mdef.(model_name) defines each model 
%     mdef.(model_name).nested lists the nested models
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, PSG_GEOMODELS_FIT, PSG_GEOMODELS_DEFINE, PSG_GEOMODELS_NESTORDER.
%
%special case: display available models
if nargin==0
    [nr,order_ptrs,model_types_nested,ou]=psg_geomodels_nestorder(psg_geomodels_define);
    rs=model_types_nested';
    disp(model_types_nested');
    xs=struct;
    aux_out=struct;
    return
end
if (nargin<=1)
    aux=struct;
end
%set up sub-structure options
%
aux=filldefault(aux,'opts_check',struct); %options for other modules called
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=filldefault(aux,'opts_geof',struct); %options for this module
aux.opts_geof=filldefault(aux.opts_geof,'model_list',[]);
aux.opts_geof=filldefault(aux.opts_geof,'if_warn',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_log',1);
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
%
%parse model names
%
[nest_rank,order_ptrs,model_types_nested,ou]=psg_geomodels_nestorder(psg_geomodels_define);
model_names_avail=model_types_nested'; %model names, in nesting order
if isempty(aux.opts_geof.model_list)
    for k=1:length(model_names_avail)
        disp(sprintf(' model %2.0f: %s',k,model_names_avail{k}));
    end
    model_ptrs=getinp('choice(s)','d',[1 length(model_names_avail)]);
    models_used=cell(1,length(model_ptrs)); %models used, but not necessarily in nesting order
    for k=1:length(model_ptrs)
        models_used{k}=model_names_avail{model_ptrs(k)};
    end
else %models provided in input, but check that all are recognized
    if ~iscell(aux.opts_geof.model_list)
        aux.opts_geof.model_list{1}=aux.opts_geof.model_list;
    end
    models_used=cell(0);
    model_ptrs=[];
    for k=1:length(aux.opts_geof.model_list)
        model_ptr=strmatch(aux.opts_geof.model_list{k},model_names_avail,'exact');
        if isempty(model_ptr)
            wmsg=sprintf('model type %s not recognized, will be ignored',aux.opts_geof.model_list{k});
            aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_geof.if_warn));
        else
            models_used{1,end+1}=model_names_avail{model_ptr};
            model_ptrs(1,end+1)=model_ptr;
        end
    end
end
%evaluate models so that the "inside" of a nested model is always evaulated first
nest_ranks=nest_rank(model_ptrs);
if aux.opts_geof.if_log
    %display models in order to be used
end
%will also have to adjust psg_model_types output to remove unused models
%from nesting

%aux.opts_geof.model_list=***model lsit in order to be evaluated

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

%%%%determine order of models to compute

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
aux_out.opts_check=aux.opts_check;
aux_out.opts_geof=aux.opts_geof;
% %
% if aux_out.warn_bad==0
% %process
%     disp('cannot proceed');
% end

return
end
