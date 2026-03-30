function [data_out,aux_out]=rs_xform_apply(data_in,xforms,aux)
% [data_out,aux_out]=rs_xform_apply(data_in,xforms,aux)
% applies a `transformation structure` to the coordinates in a `dataset structure`
%
% A `transformation structure` is a cell array of geometric transformations.
% This module can apply several types of transformations: linear, linear with offset (affine), projective, piecewise affine, and piecewise projective.
%
% Args:
%   data_in (struct): `dataset structure` to be aligned containing n records, with fields
%
%     - ds (cell array): `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas (cell array): `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets (cell array): `set metadata structure`, sets{k} is the response metadata for the kth record
%
%   xforms (struct): specification of the transformations, typically an output structure from rs_xform_specify [??how to hyperlink] or rs_geofit [??how to hyperlink], with fields
%
%      - ts (cell array): ts{k}{idim} is the transformation to be applied to the coordinates of dimension idim in record k; see note below regarding transformations
%      - pipeline (structure): a structure that becomes the 'pipeline' field of a `set metadata structure` when the transformations are applied
%
%   aux (struct): auxiliary options, may be omitted, with fields
%
%     - opts_xform (struct): specification of the transformation, with fields
%
%         - class (char): 'affine','mean','procrustes','projective','pwaffine','pwprojective'; default is affine; see note below regarding transformations
%         - if_warn (int): 1 (default) to show warnings
%
%     - opts_check (struct): options for consistency checking, with field
%
%          - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
%
% Returns:
%   data_out (struct): a `dataset structure` with the transformations applied, same format as  as `data_in`
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_xform (struct): aux.opts_xform, with defaults filled in
%     - opts_check (struct): aux.opts_check, with defaults filled in
%
% Note regarding transformations:
%   - xforms.ts{k}{idim} are the transformations to be applied to record k in `data_in`, i.e., to the coordinates data_in.ds{k}{idim}.
%
%       - If length(xforms.ts{k})<length(data_in), transformations are used in cyclic order.
%       - If any of xforms.ts{k}{idim} are missing, then the coordinates in data_in.ds{k}{idim} are passed to `data_out` unchanged.
%
%    - Several classes of transformations, specified by aux.opts_xforms.class, are supported.  The parameters in
%    xforms.ts{k}{idim} have the following meaning, where output and input both have size [nstims idim], and ts=ts{k}{idim}:
%
%       - affine: [output(istim,:)]=ts.b * [input(istim,:)] * ts.T + ts.c;
%       where size(b)=1, size(T)=[idim,idim], and size(c)=[1 idim]. If these fields are not present and xform.class='affine', then
%       alternative parameter names are allowed: 'scaling' for b, 'orthog' for T, and 'translation' for c.
%       This allows for compatibility with the transformations produced by `procrustes_consensus`.
%       - procrustes: same as affine, but ts.b=1 and abs(det(T))=1.  *These are not checked.*
%       - mean: same as affine, but ts.b=1, T=0. *These are not checked.*
%       - projective: affine parameters and also p, size [isim 1]. p=0
%       reduces to affine.  See `transformation structures` for further details.
%       - pwaffine (piecewise affine): b as in affine.  T has size [idim idim 2^ncuts] and c
%       has size [2^nchuts idim], specifying the affine transformation on
%       each cut. vcut has size [ncuts idim], each row is a unit vector,
%       orthogonal to the cutplanes. acut has size [1 2^ncuts], specifying the cutpoints.
%       See `transformation structures` for further details.
%       - pwprojective (piecewise projective): parameters as in pwaffine, and also p, of size [idim, 2^ncuts], used as in projective for each component
%       See `transformation structures` for further details. 
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, RS_XFORM_SPECIFY, RS_FORM_SPECIFY_APPLY_TEST,
%  PSG_GEOMODELS_APPLY, PROCRUSTES_COMPAT.
%
if (nargin<=2)
    aux=struct;
end
%
class_default='affine';
aux=filldefault(aux,'opts_xform',struct); 
aux.opts_xform=filldefault(aux.opts_xform,'if_warn',1);
aux.opts_xform=filldefault(aux.opts_xform,'class',class_default);
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
params_needed=struct;
params_needed.mean={'b','T','c'};
params_needed.procrustes={'b','T','c'};
params_needed.affine={'b','T','c'};
params_needed.projective={'b','T','c','p'};
params_needed.pwaffine={'b','T','c','vcut','acut'};
params_needed.pwprojective={'b','T','c','vcut','acut','p'};
%
missing_params=[];
%
%check number of transform sets
%
nsets_xform=length(xforms.ts);
if (nsets_xform~=nsets) & (nsets_xform~=1)
    wmsg=sprintf('number of transform sets specified (%2.0f) differs from number of datasets (%2.0f)',nsets_xform,nsets);
    aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_xform.if_warn));
end
data_out.ds=cell(1,nsets);
data_out.sas=cell(1,nsets);
data_out.sets=cell(1,nsets);
%
class=aux.opts_xform.class;
if ~isfield(params_needed,class)
    wmsg=sprintf('transformation class %s not recognized, set to %s',class,class_default);
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_xform.if_warn));
    aux.opts_xform.class=class_default;
    class=class_default;
end
for k=1:nsets
    k_xform=mod(k-1,nsets_xform)+1;
    dim_list_out=[];
    data_out.ds{k}=cell(1,0);
    for idim=1:length(data_in.ds{k})
        coords=data_in.ds{k}{idim};
        have_xform=0;
        if idim<=length(xforms.ts{k_xform})
            if isstruct(xforms.ts{k_xform}{idim})
                have_xform=1;
            end
        end
        if have_xform %check that parameters are present and reformat if needed
            ts=xforms.ts{k_xform}{idim};
            if strcmp(aux.opts_xform.class,'affine') %check to see if alternate names are used
                if ~isempty(ts)
                    if ((~isfield(ts,'b') | ~isfield(ts,'T') | ~isfield(ts,'c')) & (isfield(ts,'scaling') & isfield(ts,'orthog') & isfield(ts,'translation')))
                        ts=procrustes_compat(ts);
                    end
                end
            end
            if isempty(ts)
                ts=struct;
            end
            for ifn=1:length(params_needed.(class))
                if ~isfield(ts,params_needed.(class){ifn})
                    missing_params=strvcat(missing_params,params_needed.(class){ifn});
                    have_xform=0;
                end
            end
        end 
        if have_xform==0 | isempty(coords)
            coords_new=coords;
        else
            coords_new=psg_geomodels_apply(aux.opts_xform.class,coords,ts);
        end
        data_out.ds{k}{1,idim}=coords_new;
        dim_list_out=[dim_list_out,idim];
    end
    data_out.sas{k}=data_in.sas{k};
    %sets is taken from input, other than pipeline and dimensions present   
    data_out.sets{k}=data_in.sets{k};
    if isfield(xforms,'pipeline')
        data_out.sets{k}.pipeline=xforms.pipeline;
    else
        data_out.sets{k}.pipeline=struct();
    end
    data_out.sets{k}.pipeline.opts.opts_xform.transforms=xforms.ts;
    data_out.sets{k}.pipeline.sets=data_in.sets{k};
    data_out.sets{k}.dim_list=dim_list_out;
end
if ~isempty(missing_params)
    missing_params=unique(missing_params,'rows');
    miss_string=[];
    for imiss=1:size(missing_params,1)
        miss_string=cat(2,miss_string,' ',missing_params(imiss,:));
    end
    wmsg=sprintf('transform specification is missing parameters: %s',deblank(miss_string));
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_xform.if_warn));
end
aux_out.opts_check=aux.opts_check;
aux_out.opts_xform=aux.opts_xform;
return
end
