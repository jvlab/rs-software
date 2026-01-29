function [rs,xs,aux_out]=rs_geofit(data_in,data_out,aux)
% [rs,xs,aux_out]=rs_geofit(data_in,data_out,aux) fits one or more geometrical transformations
% to coordinate sets
%
% data_in.ds{k},sas{k},sets{k}: dataset structures that are the starting points for the transformation
% data_out.ds{k},sas{k},sets{k}: dataset structures that are the targets of the transformation
%  They must have same number of stimuli, and a warning is given if the number matches but the names do not.
% aux:
%  aux.opts_check
%    if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
%  aux.opts_geof
%   model_list: a string, or a cell array of strings, consisting of one or more of the model types to be fitted.
%     These the strings in getfield(psg_geomodels_define,'model_types'), and currently are the following
%     If empty, the list is requested interactively; if omitted is given by model_list_default
%    'mean'                       : all input values mapped to mean of output
%    'procrustes_noscale_nooffset': rotation (and possibly reflection), no rescaling     , no translation
%    'procrustes_scale_nooffset   : rotation (and possibly reflection), rescaling allowed, no translation
%    'procrustes_noscale_offset'  : rotation (and possibly reflection), no rescaling     , translation allowed
%    'procrustes_scale_offset     : rotation (and possibly reflection), rescaling allowed, translation allowed
%    'affine_nooffset'            : linear transformation, no translation
%    'affine_offset'              : linear transformation, translation allowed
%    'projective'                 : projective transformation
%    'pwaffine'                   : piecwise affine with one cutplane; two linear transformations with agreement on the cut
%    'pwaffine_2'                 : piecwise affine with two cutplanes: four linear transformations, with agreement on the cuts
%     Note: if empty, this is requested interactively.
%  model_list_default: models when model_list is not specified, can modify in rs_aux_defaults_define
%  dimpairs_method: pairs of dimensions considered between input and ouptut datasets
%    'all': all pairings
%    'equal': input dimension= output dimension (default)
%    'din_lteq_dout': input dimension less than or equal to output dimension
%    'din_gteq_dout': input dimension greater than or equal to output dimension
%    'list': a two-column list of pairs (in, out)
%  dimpairs_list:  two-column array of pairs of dimensions to consider
%  dim_max_in:  maximum dimension of input dataset to use, defaults to 10
%  dim_max_out: maximum dimension of output dataset to use, defaults to dim_max_in
%
%  if_nestbydim:    1 to do statistics on nesting by dimension, 0 (default) to omit
%  if_nestbymodel:  1 (default) to do statistics on nesting by model, 0 to omit, -1 to only do statistics for maximally nested model
%  nshuffs:         number of shuffles, defaults to 100
%  if_warn: 1 (default) to show warnings
%  if_log: 1 (default) to log progress
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
psg_geomodels_def=psg_geomodels_define();
%special case: display available models
if nargin==0
    [nr,order_ptrs,model_types_nested]=psg_geomodels_nestorder(psg_geomodels_def);
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
aux.opts_geof=filldefault(aux.opts_geof,'dimpairs_method','equal');
aux.opts_geof=filldefault(aux.opts_geof,'dimpairs_list',[]);
aux.opts_geof=filldefault(aux.opts_geof,'dim_max_in',10);
aux.opts_geof=filldefault(aux.opts_geof,'dim_max_out',aux.opts_geof.dim_max_in);
aux.opts_geof=filldefault(aux.opts_geof,'if_nestbydim',0);
aux.opts_geof=filldefault(aux.opts_geof,'if_nestbymodel',1);
aux.opts_geof=filldefault(aux.opts_geof,'nshuffs',100);
aux.opts_geof=filldefault(aux.opts_geof,'if_warn',1);
aux.opts_geof=filldefault(aux.opts_geof,'if_log',1);
%
aux=rs_aux_customize(aux,'rs_geofit');
%
aux.opts_geof=filldefault(aux.opts_geof,'model_list',aux.opts_geof.model_list_default);
%
%************need to set up defaults***********
%
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
xs=struct;
rs=struct;
%
%parse model names and determine order of models to compute
%
[aux,aux_out]=rs_geofit_getmodels(aux,psg_geomodels_def,aux_out);
%aux.opts_geof.model_list is model models in order to be evaluated
%aux_opts_geof.model_definitions is the model definition structure
nmodels=length(aux.opts_geof.model_list);
%
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

function [aux_new,aux_out_new]=rs_geofit_getmodels(aux,psg_geomodels_def,aux_out)
%parse the model names, request if none are supplied, check that they are
%recognized, determine nesting and maximal nesting, and log if requested
[nest_rank,order_ptrs,model_types_nested]=psg_geomodels_nestorder(psg_geomodels_def); %determine model types in nesting order
if_interactive=double(isempty(aux.opts_geof.model_list));
if_ok=0;
if if_interactive
    model_ptrs=[];
    for k=1:length(aux.opts_geof.model_list_default)
        model_ptrs(1,end+1)=strmatch(aux.opts_geof.model_list_default{k},model_types_nested,'exact'); %starting point for interactive
    end
end
while(if_ok==0)
    if ~if_interactive
        if ~iscell(aux.opts_geof.model_list)
            aux.opts_geof.model_list{1}=aux.opts_geof.model_list;
        end
        models_used=cell(0);
        model_ptrs=[];
        for k=1:length(aux.opts_geof.model_list) %check that model names are recognized
            model_ptr=strmatch(aux.opts_geof.model_list{k},model_types_nested,'exact');
            if isempty(model_ptr)
                wmsg=sprintf('model type %s not recognized, will be ignored',aux.opts_geof.model_list{k});
                aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_geof.if_warn));
            else
                models_used{1,end+1}=model_types_nested{model_ptr};
                model_ptrs(1,end+1)=model_ptr;
            end
        end
    else %get model list interactively
        for k=1:length(model_types_nested)
            disp(sprintf('model %2.0f: %s',k,model_types_nested{k}));
        end
        model_ptrs=getinp('choice(s)','d',[1 length(model_types_nested)],model_ptrs);
        models_used=cell(1,length(model_ptrs)); %models used, but not necessarily in nesting order
        for k=1:length(model_ptrs)
            models_used{k}=model_types_nested{model_ptrs(k)};
        end
    end
    %
    %create a model definition structure based only on the models used
    %
    nmodels=length(models_used);
    mdef=struct;
    models_ordered=cell(1,nmodels);
    ko=0;
    for k=1:length(model_types_nested) %now work in nesting order
        if strmatch(model_types_nested{k},models_used,'exact')
            model_type=model_types_nested{k};
            ko=ko+1;
            models_ordered{ko}=model_type;
            mdef.(model_type)=rmfield(psg_geomodels_def.(model_type),'nested');
            nested_all=psg_geomodels_def.(model_type).nested;
            nested_used=cell(0);
            for kn=1:nmodels
                if ~isempty(strmatch(models_used{kn},nested_all,'exact'))
                    nested_used{1,end+1}=models_used{kn};
                end
            end
            mdef.(model_type).nested=nested_used;
        end
    end
    mdef.model_types=models_ordered; %complete the model definition structure
    aux.opts_geof.model_list=models_ordered; %models in order of evaluation
    aux.opts_geof.model_definitions=mdef; %model definition structure
    [nest_rank,order_ptrs,models_ordered,opts_nestorder_used]=psg_geomodels_nestorder(mdef); %recreate the ordered list and obtain maximally nested models
    mdef_max=opts_nestorder_used.mdef0; %model definitions with maximally nested model
    if aux.opts_geof.if_log | if_interactive
        disp('models, in order of evaluation')
        for k=1:nmodels
            disp(sprintf(' model: %s',models_ordered{k}))
            if aux.opts_geof.if_nestbymodel~=0
                switch aux.opts_geof.if_nestbymodel
                    case 1
                        nesteds=mdef.(models_ordered{k}).nested;
                        nest_string='nested';
                    case -1
                        nesteds=mdef_max.(models_ordered{k}).nested;
                        nest_string='maximally nested';
                end
                if length(nesteds)>0
                    disp(sprintf('  %s models:',nest_string))
                    disp(nesteds);
                else
                    disp('  no nested models');
                end
            end
        end
    end
    if (if_interactive)
        if_ok=getinp('1 if ok','d',[0 1]);
    else
        if_ok=1;
    end
end
aux_new=aux;
aux_out_new=aux_out;
return
end
