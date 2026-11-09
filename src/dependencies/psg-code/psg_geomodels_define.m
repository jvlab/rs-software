function model_types_def=psg_geomodels_define(if_select)
%model_types_def=psg_geomodels_define(if_select) sets up the definitions of geometric model types
%
% if_select: if present and nonzero, can select model types
% model_types_def: a structure that defines the models and their hierarchical relationships
%
% 05Dec23: add piecewise affine
% 21Dec23: add dof 
%    dof is an array whose entry in row (i+1) and column (j+1) is the
%    coefficient of (nx)^i*(ny)^j in a polynomial that gives the number of degrees of
%    freedom in a model, where nx is the number of dimensions in input space for the transformation
%    and ny is the number of dimensions in the output space
%    Note that the count for degrees of freedom does not include translation.
% 28May24: add if_select; add min_inputdims, minimum number of dimensions in input space required to fit
% 24Jan26: remove restriction that ny>=nx by adding a slice on dim 3 for dof, to use if nx>ny
%   (see psg_geomodels_ndof_notes.docx)
% 24Jan26: remove restriction that ny>=nx by adding a slice on dim 3 for dof, to use if nx>ny
%   Add procrustes_*_nooffset, and only the procrustes_*_nooffset are nested in affine_nooffset
% 25Jan26: allow for selection of models by removal or retention, fix nesting and dof
% 27Jan26: fill opts with if_scale=1,if_offset=1 unless othewise specified; procrustes->procrustes_offset, 
% 16Feb26: remove 'mean' as nested under 'procrustes_noscale_offset'
% 
%   See also: PSG_GEOMODELS_TEST, PSG_GEO_GENERAL, PSG_GEOMODELS_ILLUS, PSG_GEO_PWAFFINE_TEST,
%     PSG_GEOMODELS_NDOF, PSG_GEOMODELS_NESTORDER.
%

if nargin==0
    if_select=0;
end
model_types_def=struct;
model_types_def.model_types={'mean','procrustes_noscale_offset','procrustes_scale_offset','affine_nooffset',...
    'affine_offset','projective','pwaffine','pwaffine_2','procrustes_noscale_nooffset','procrustes_scale_nooffset'};
%
model_types_def.mean.opts=struct;
model_types_def.mean.nested={};
model_types_def.mean.dof=[0];
%
model_types_def.procrustes_noscale_offset.opts.if_scale=0;
model_types_def.procrustes_noscale_offset.opts.if_offset=1;
model_types_def.procrustes_noscale_offset.nested={'procrustes_noscale_nooffset'};
proc_dof=[0 0 0;-1 2 0;-1 0 0]/2; %nx*ny-0.5*nx*nx-0.5*nx if ny>=nx
model_types_def.procrustes_noscale_offset.dof=cat(3,proc_dof,proc_dof'); %exchange roles of x and y if ny<nx
%
model_types_def.procrustes_scale_offset.opts.if_scale=1;
model_types_def.procrustes_scale_offset.opts.if_offset=1;
model_types_def.procrustes_scale_offset.nested={'mean','procrustes_noscale_offset','procrustes_noscale_nooffset','procrustes_scale_nooffset'};
model_types_def.procrustes_scale_offset.dof=model_types_def.procrustes_noscale_offset.dof+repmat([1 0 0;0 0 0;0 0 0],[1 1 2]); %add 1
%
model_types_def.affine_nooffset.opts.if_offset=0;
model_types_def.affine_nooffset.nested={'procrustes_noscale_nooffset','procrustes_scale_nooffset'};
model_types_def.affine_nooffset.dof=[0 0;0 1];%  ny*nx (a general matrix)
%
model_types_def.affine_offset.opts.if_offset=1;
model_types_def.affine_offset.nested={'mean','procrustes_noscale_offset','procrustes_scale_offset','procrustes_noscale_nooffset','procrustes_scale_nooffset','affine_nooffset'};
model_types_def.affine_offset.dof=[0 0;0 1];%  same as affine_nooffset since we don't include translational degrees of freedom
%
model_types_def.projective.opts.method='fmin'; %minimization method
model_types_def.projective.opts.if_display=1; %display during minimization
model_types_def.projective.nested={'mean','procrustes_noscale_offset','procrustes_scale_offset','affine_nooffset','affine_offset','procrustes_noscale_nooffset','procrustes_scale_nooffset'};
model_types_def.projective.dof=[0 0;1 1];% ny*nx+nx, a general projective matrix, but excluding offset ny
%
model_types_def.pwaffine.opts.method='fmin';
model_types_def.pwaffine.opts.if_display=1;
model_types_def.pwaffine.opts.n_cuts_model=1;
model_types_def.pwaffine.nested={'mean','procrustes_noscale_offset','procrustes_scale_offset','affine_nooffset','affine_offset','procrustes_noscale_nooffset','procrustes_scale_nooffset'};
model_types_def.pwaffine.dof=model_types_def.affine_offset.dof+[0 1;1 0];% affine dof+nx+ny
%
model_types_def.pwaffine_2.opts.method='fmin';
model_types_def.pwaffine_2.opts.if_display=1;
model_types_def.pwaffine_2.opts.n_cuts_model=2;
model_types_def.pwaffine_2.nested={'mean','procrustes_noscale_offset','procrustes_scale_offset','affine_nooffset','affine_offset','pwaffine','procrustes_noscale_nooffset','procrustes_scale_nooffset'};
model_types_def.pwaffine_2.dof=model_types_def.affine_offset.dof+[0 2;2 0];% affine dof+2(nx+ny)
model_types_def.pwaffine_2.min_inputdims=2;
%
model_types_def.procrustes_noscale_nooffset.opts.if_scale=0;
model_types_def.procrustes_noscale_nooffset.opts.if_offset=0;
model_types_def.procrustes_noscale_nooffset.nested={};
model_types_def.procrustes_noscale_nooffset.dof=model_types_def.procrustes_noscale_offset.dof;
%
model_types_def.procrustes_scale_nooffset.opts.if_scale=1;
model_types_def.procrustes_scale_nooffset.opts.if_offset=0;
model_types_def.procrustes_scale_nooffset.nested={'procrustes_noscale_nooffset'};
model_types_def.procrustes_scale_nooffset.dof=model_types_def.procrustes_scale_offset.dof;
%
mnames=model_types_def.model_types;
for im=1:length(mnames)
    mname=mnames{im};
    mclass=mname(1:-1+min(find(cat(2,mname,'_')=='_')));
    model_types_def.(mname).class=mclass;
    model_types_def.(mname)=filldefault(model_types_def.(mname),'min_inputdims',1);
    model_types_def.(mname).opts=filldefault(model_types_def.(mname).opts,'if_scale',1); %assume a scale is included
    model_types_def.(mname).opts=filldefault(model_types_def.(mname).opts,'if_offset',1); %assume an offset is included
end
mnames_orig=mnames;
if (if_select)
    for im=1:length(mnames)
        disp(sprintf('%2.0f->%s',im,mnames{im}))
    end
    if_ok=0;
    while (if_ok==0)
        model_list=getinp('list of models to remove, negative values to list models to retain, or 0 to keep all','d',[-length(mnames) length(mnames)],0);
        if all(model_list>0)
            remove_list=model_list;
            if_ok=1;
        elseif all(model_list<0)
            remove_list=setdiff([1:length(mnames)],abs(model_list));
            if_ok=1;
        elseif length(model_list)==1 %model list is zero
            remove_list=[];
            if_ok=1;
        end
    end
    for irem=1:length(remove_list)
        im=remove_list(irem);
        remove_name=mnames_orig{im};
        model_types_def=rmfield(model_types_def,remove_name);
        %remove model from list of model types
        ir=strmatch(remove_name,model_types_def.model_types,'exact');
        model_types_def.model_types={model_types_def.model_types{1,setdiff(1:length(model_types_def.model_types),ir)}};
        %remove from nesteds
        mnames=model_types_def.model_types;
        for im=1:length(mnames)
            mname=mnames{im};
            ir=strmatch(remove_name,model_types_def.(mname).nested,'exact');
            if ir>0
               model_types_def.(mname).nested={model_types_def.(mname).nested{1,setdiff(1:length(model_types_def.(mname).nested),ir)}};
            end
        end
    end
end
return
end
