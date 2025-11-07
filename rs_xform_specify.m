function [xforms,aux_out]=rs_xform_specify(data_in,aux)
% [xforms,aux_out]=rs_xform_specify(data_in,aux) specifies transformation(s) of datasets
%
% data_in.ds{k},sas{k},sets{k}: the structures of coordinates (ds) and metadata (sas,sets)
%   Stimuli should be identical across datasets
%
% aux: auxiliary inputs
%  aux.opts_xform: a structure to specify the transformation, consisting of a rotation (possibly with reflection) and a translation
%  The translation is specified the point that should be translated to the origin.
%  The rotation is specified by principal components, either separately for each dataset, or, the average across datasets,
%  and can be carried out with respect to zero or the centroid, after the
%  above (optinal) centering.
%  
%  
% 
% The transformation is [output]=ts.scaling*[input]*ts.orthog+ts.translation,
%  where ts=xforms.ts{k}{idim}, for dataset k and dimension idim
%  (data_in.da{k} should be nstims x idim)
% Note that the output dimension is always equal to the input dimension.
% The transformation is the same as Matlab's procrustes.m, but with other field names
%  (see procrustes_compat), and with the translation replicated for each data point
%
% xforms:
%   xforms.ts are the transformations
%   xforms.pipeline is a structure that can serve as a subfield for sets, when the transformations are applied
% aux_out: auxiliary outputs and parameter values used
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, PSG_PCAOFFSET.
%
if (nargin<=1)
    aux=struct;
end
%
aux=filldefault(aux,'opts_xform',struct); 
%
%
aux.opts_xform=filldefault(aux.opts_xform,'mode','none'); %'none', 'translate', 'offset_pca', 'translate_then_pca'; 
aux.opts_xform=filldefault(aux.opts_xform,'source','global'); %options: global: calculation based on mean across datasets, 'local', use each dataset's value, or a number (specify the dataset to use)
aux.opts_xform=filldefault(aux.opts_xform,'centering_specifier','none'); %'none','centroid','index','typename','value'
aux.opts_xform=filldefault(aux.opts_xform,'centering_typename','rand'); %specify the typename to move to the origin
aux.opts_xform=filldefault(aux.opts_xform,'centering_index',1); %specify the stimulus index to move to the origin
aux.opts_xform=filldefault(aux.opts_xform,'centering_value',[]); %specify coordinate value to move to the origin
% 'offset_pca': do the pca around the centering point
% 'translate_then_pca: translate the centering point to the origin and then do pca, equivalent to doing the pca around centering point and then translating it to the origin
%
aux=rs_aux_customize(aux,'rs_xform_specify');
%
%
xforms=struct;
xforms.ts=cell(0);
xforms.pipeline=struct;
%
aux_out=struct;
%
%specify what to subtract from coords, before applying PCA -- this can be
%
%check datasets for consistency and get available stimuli, dimensions, typenames
%
check=rs_check_coordsets(data_in,setfield(struct(),'if_warn',1));
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
%validate input parameters for consistency, etc.
%
if_ok=1;
x=aux.opts_xform; %for convenience
switch x.centering_specifier
    case {'none','centroid'} %nothing to check
    case 'index'
        if ((x.centering_index~=round(x.centering_index)) | (x.centering_index>min(nstims_each)) | (x.centering_index<=0))
            wmsg=sprintf('centering index (%8.3f) not valid (non-integer or out of range); no centering used',x.centering_index);
            if_ok=0;
        else
            idx=x.centering_index;
        end
    case 'value'
        if length(x.centering_value)<max(dim_list_union)
            wmsg=sprintf('centering value vector length (%3.0f) less than max dimension needed (%3.0f); no centering used',length(x.centering_value),max(dim_list_union));
            if_ok=0;
        else
            x.centering_value=x.centering_value(:)';
        end
    case 'typename'
         idx_check=strmatch(x.centering_typename,typenames_inter,'exact');
         if length(idx_check)~=1
             wmsg=sprintf('centering typename (%s) not found or not unique in all datasets; no centering used',x.centering_typename);
             if_ok=0;
         end
    otherwise
        wmsg=sprintf('centering specifier (%s) not recognized; no centering used',x.centering_specifier);
        if_ok=0;
end
switch x.source
    case {'global','local'}
    otherwise
        if isnumeric(x.source)
            if ((x.source~=round(x.source)) | (x.source>nsets) | (x.source<=0))
                wmsg=sprintf('source (%8.3f) not valid (non-integer or out of range); no centering used',x.source);
                if_ok=0;
            end
        else
            wmsg=sprintf('centering source (%s) not recognized; no centering used',x.source);
            if_ok=0;
        end
end
if (if_ok==0)
    warning(wmsg);
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    x.centering_specifier='none';
end
aux.opts_xform=x;
%
% if centering_specifier='value', then value must be a vector or a cell array of vectors, one for each dataset
%if it is typename, then check that the typename exists, otherwise warn

% if (condition)
%     wmsg=sprintf('xxx');
%     warning(wmsg);
%     aux_out.warnings=strvcat(aux_out.warnings,wmsg);
%     aux_out.warn_bad=aux_out.warn_bad+1;
% end'
xforms.pipeline.type='xform';
xforms.pipeline.opts.opts_xform=aux.opts_xform;
xforms.pipeline.sets_combined=cell(1,nsets);
for iset=1:nsets
    xforms.pipeline.sets_combined{iset}=data_in.sets{iset};
end
%
if aux_out.warn_bad==0
    %process
    xforms.ts=cell(nsets,1);
    nstims=min(nstims_each);
    for iset=1:nsets
        xforms.ts{iset}=cell(1,max(dim_list_each{iset}));
        for dim_ptr=1:length(dim_list_each{iset});
            idim=dim_list_each{iset}(dim_ptr);
            %
            ts=struct;
            ts.scaling=1;
            ts.orthog=eye(idim);
            ts.translation=zeros(1,idim);
            if ~strcmp(x.mode,'none')
                switch x.source
                    case 'local'
                        source=iset;
                        have_data=ismember(idim,dim_list_each{iset});
                    case 'global'
                        source=[1:nsets];
                        have_data=ismember(idim,dim_list_inter);
                    otherwise
                        source=x.source;
                        have_data=1;
                end
                if have_data
                    %determine centering
                    coords_each=zeros(nstims,idim,length(source));
                    for is=1:length(source)
                        coords_each(:,:,is)=data_in.ds{source(is)}{idim};
                    end
                    coords=mean(coords_each,3,'omitnan');
                    switch x.centering_specifier
                        case 'none'
                            cvec=zeros(1,idim);
                        case 'centroid'
                            cvec=mean(coords,1,'omitnan');
                        case 'index'
                            cvec=coords(idx,:);
                        case 'typename'
                            cvec_each=zeros(1,idim,length(source));
                            for is=1:length(source)
                                cvec_each(1,:,is)=coords_each(strmatch(x.centering_typename,typenames_each{source(is)},'exact'),:,is);
                            end
                            cvec=mean(cvec_each,3,'omitnan');
                        case 'value'
                            cvec=x.centering_value(1:idim);
                    end
                    %aux.opts_xform=filldefault(aux.opts_xform,'mode','none'); %'none', 'translate', 'offset_pca', 'translate_then_pca';
                    switch x.mode
                        case 'translate'
                            ts.translation=-cvec;
                    end
                else
                    ts=struct;
                end
            end %mode
            xforms.ts{iset}{idim}=ts;
        end %dim_ptr
    end %each set
else
    disp('cannot proceed');
end
return
end
