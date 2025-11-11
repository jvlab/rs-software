function [data_out,aux_out]=rs_xform_apply(data_in,xforms,aux)
% [data_out,aux_out]=rs_xform_apply(data_in,xforms,aux) applies transformation(s) to datasets
%
% These transformations all preserve the number of dimensions, and consist of a translation and rotation, typically specified by rs_xform_specify.
%
% data_in.ds{k},sas{k},sets{k}: the structures of coordinates (ds) and metadata (sas,sets)
%   Stimuli should be identical across datasets
% xforms: typically an output structure from rs_xform_specify
%   xforms.ts are the transformations
%   xforms.pipeline is a structure that can serve as a subfield for sets, when the transformations are applied
% aux: auxiliary inputs
%  aux.opts_xform.if_warn: 1 (default) to show warnings
%  aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
%
% data_in.ds{k},sas{k},sets{k}: the structures of coordinates (ds) and metadata (sas,sets) after the transformation
% aux_out: auxiliary outputs and parameter values used
%   aux_out.opts_xforms: values of aux.opts_xforms as used
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%
% The transformation is [output]=ts.scaling*[input]*ts.orthog+ts.translation,
%  where ts=xforms.ts{k}{idim}, for dataset k and dimension idim
%  (data_in.da{k} should be nstims x idim)
% Note that the output dimension is always equal to the input dimension.
% The transformation is the same as Matlab's procrustes.m, but with other field names
%  (see procrustes_compat), and with the translation replicated for each data point
%
% If a dimension is present in data_in.ds{k}{ip} but not xforms.ts{k}{ip} is empty, then the
%   data_out.ds{k}{ip} will be empty, and a warning is generated.
% Entries in length(xforms.ts) are cycled through (so if length is 1, xforms.ts{1} is applied to all datasets).
%   If length is not 1, then it should match length(data_in.ds); otherwise warning is issued. 
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, RS_XFORM_SPECIFY, PSG_GEOMODELS_APPLY, PROCRUSTES_COMPAT.
%
if (nargin<=1)
    aux=struct;
end
%
aux=filldefault(aux,'opts_xform',struct); 
aux.opts_xform=filldefault(aux.opts_xform,'if_warn',1);
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_xform_apply');
%
aux_out=struct;
data_out=struct;
%
%check consistency and get available stimuli, dimensions, typenames
%
check=rs_check_coordsets(data_in,aux.opts_check);
%
aux_out.warnings=check.warnings;
aux_out.warn_bad=check.warn_bad;
nsets=check.nsets;
nstims_each=check.nstims_each;
dim_list_each=check.dim_list_each;
dim_list_union=check.dim_list_union;
dim_list_inter=check.dim_list_inter;
typenames_each=check.typenames_each;
typenames_union=check.typenames_union;
typenames_inter=check.typenames_inter;
%
%check number of transform sets
%
nsets_xform=length(xforms.ts);
if (nsets_xform~=nsets) & (nsets_xform~=1)
    wmsg=sprintf('number of transform sets specified (%2.0f) differs from number of datasets (%2.0f)',nsets_xform,nsets);
    if aux.opts_xform.if_warn
        warning(wmsg);
    end
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
end
data_out.ds=cell(1,nsets);
data_out.sas=cell(1,nsets);
data_out.sets=cell(1,nsets);
%create pipeline -- need to add the dimension list
%
for k=1:nsets
    k_xform=mod(k-1,nsets_xform)+1;
    dim_list_out=[];
    data_out.ds{k}=cell(1,0);
    for ip=1:length(data_in.da{k})
        coords=data_in.da{k}{ip};
        ts=xforms.ts{k_xform};
        if ~isempty(coords) & ~isempty(ts)
            coords_new=psg_geomodels_apply('procrustes',coords,procrustes_compat(ts));
            data_out.ds{k}.ip=coords_new;
            dim_list_out=[dim_list_out,ip];
        end
    end
    data_out.sas{k}=data_in.sas{k};
    %sets is taken from input, other than pipeline and dimensions present   
    data_out.sets{k}=data_in.sets{k};
    if isfield(xforms,'pipeline')
        data_out.sets{k}.pipeline=xforms.pipeline;
    end
    data_out.sets{k}.pipeline.sets=data_in.sets{k};
    data_out.sets{k}.dim_list=dim_list_out;
end
return
end
