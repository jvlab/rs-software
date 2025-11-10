function [xforms,aux_out]=rs_xform_specify(data_in,aux)
% [xforms,aux_out]=rs_xform_specify(data_in,aux) specifies transformation(s) of datasets
%
% data_in.ds{k},sas{k},sets{k}: the structures of coordinates (ds) and metadata (sas,sets)
%   Stimuli should be identical across datasets
%
% aux: auxiliary inputs
%  aux.opts_xform: a structure to specify the transformation, consisting of a rotation (possibly with reflection) and a translation
%      The translation is specified the point that should be translated to the origin.
%      The rotation is specified by principal components, either separately for each dataset, or, the average across datasets,
%      and can be carried out with respect to zero or the centroid, after the above (optinal) centering.
%   aux.opts_xform.mode: 'none', 'translate','offset_pca','translate_then_pca'
%      none (default): no transformation is carried out
%      translate: the specified point (see 'centering specifier') is translated to the origin, no rotation is done
%      offset_pca: a pca rotation is performed around the point specified by the centering specifier, so that
%          the first coordinate explains the most variance around that point, the second coordinate explains the next-most-variance, etc.
%          the point specified by the centerind specifier is not moved
%      translate_then_pca: the specified point (see 'centering specifier') is translated to the origin, and then standard pca is done
%   aux.opts_xform.source: 'global','local', or an integer in [1:length(data_in.ds)]
%      global (default): the centering specifier is determined from the mean all datasets; pca is computed after pooling across datasets;
%          the transformations specified for all datasets are identical
%      local: the centering specifieer and pca is computed separately for each dataset; tranformations for each dataset typically differ
%      an integer: the specified datast is used for the centering specifieer and pca;  transformations specfied for all datasets are identical
%   aux.opts_xform.centering_specifier: 'none','centroid','index','typename','value'
%      none (default): no centering id done
%      centroid: the centroid of the dataset is used
%      index: the value in aux.opts_xform.centering_index, is the index number of the stimulus whose coordinates are to be used for centering
%      typename: the string in aux.opts_xform.centering_typename is the label of the stimulus whose coordinates are to be used for centering
%      value: the coordinates in aux.opts_xform.centering_value are to be used for centering; for coordinate sets of dimension k, only the first k are used
%   aux.opts_xform.centering_[index|typename|value]: see above in aux.opts_xform.centering_specifier
%   aux.opts_xform.if_warn: 1 (default) to show warnings
%   If inconsistent or unrecognized options are used, opts_xform.mode is set to 'none' and warnings are generated.
%  aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
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
%   aux_out.opts_xforms: values of aux.opts_xforms as used
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, PSG_PCAOFFSET, RS_XFORM_SPECIFY_TEST.
%
if (nargin<=1)
    aux=struct;
end
%
aux=filldefault(aux,'opts_xform',struct); 
%
aux.opts_xform=filldefault(aux.opts_xform,'mode','none'); %'none', 'translate', 'offset_pca', 'translate_then_pca'; 
aux.opts_xform=filldefault(aux.opts_xform,'source','global'); %options: global: calculation based on mean across datasets, 'local', use each dataset's value, or a number (specify the dataset to use)
aux.opts_xform=filldefault(aux.opts_xform,'centering_specifier','none'); %'none','centroid','index','typename','value'
aux.opts_xform=filldefault(aux.opts_xform,'centering_typename','rand'); %specify the typename to move to the origin
aux.opts_xform=filldefault(aux.opts_xform,'centering_index',1); %specify the stimulus index to move to the origin
aux.opts_xform=filldefault(aux.opts_xform,'centering_value',[]); %specify coordinate value to move to the origin
aux.opts_xform=filldefault(aux.opts_xform,'if_warn',1); %show warnings
%
aux=filldefault(aux,'opts_check',struct);
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_xform_specify');
%
xforms=struct;
xforms.ts=cell(0);
xforms.pipeline=struct;
%
aux_out=struct;
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
%validate input parameters for consistency, etc.
%
if_ok_centering=1;
if_ok_mode=1;
x=aux.opts_xform; %for convenience
wmsg_all=[];
switch x.centering_specifier
    case {'none','centroid'} %nothing to check
    case 'index'
        if ((x.centering_index~=round(x.centering_index)) | (x.centering_index>min(nstims_each)) | (x.centering_index<=0))
            wmsg=sprintf('centering index (%8.3f) not valid (non-integer or out of range); no centering applied',x.centering_index);
            if_ok_centering=0;
            wmsg_all=strvcat(wmsg_all,wmsg);
        else
            idx=x.centering_index;
        end
    case 'value'
        if length(x.centering_value)<max(dim_list_union)
            wmsg=sprintf('centering value vector length (%3.0f) less than max dimension needed (%3.0f); no centering applied',length(x.centering_value),max(dim_list_union));
            if_ok_centering=0;
            wmsg_all=strvcat(wmsg_all,wmsg);
        else
            x.centering_value=x.centering_value(:)';
        end
    case 'typename'
         idx_check=strmatch(x.centering_typename,typenames_inter,'exact');
         if length(idx_check)~=1
             wmsg=sprintf('centering typename (%s) not found or not unique in all datasets; no centering applied',x.centering_typename);
             if_ok_centering=0;
             wmsg_all=strvcat(wmsg_all,wmsg);
         end
    otherwise
        wmsg=sprintf('centering specifier (%s) not recognized; no centering applied',x.centering_specifier);
        if_ok_centering=0;
        wmsg_all=strvcat(wmsg_all,wmsg);
end
switch x.source
    case {'global','local'}
    otherwise
        if isnumeric(x.source)
            if ((x.source~=round(x.source)) | (x.source>nsets) | (x.source<=0))
               wmsg=sprintf('source (%8.3f) not valid (non-integer or out of range); no centering applied',x.source);
               if_ok_centering=0;
               wmsg_all=strvcat(wmsg_all,wmsg);
            end
        else
           wmsg=sprintf('centering source (%s) not recognized; no centering applied',x.source);
           if_ok_centering=0;
           wmsg_all=strvcat(wmsg_all,wmsg);
        end
end
switch x.mode
    case {'none','translate','offset_pca','translate_then_pca'}
    otherwise
        wmsg=sprintf('mode  (%s) not recognized; no transformation applied',x.mode);
        if_ok_mode=0;
        wmsg_all=strvcat(wmsg_all,wmsg);
end
if (if_ok_centering==0) | (if_ok_mode==0)
    if aux.opts_xform.if_warn
        for k=1:size(wmsg_all,1)
            warning(wmsg_all(k,:));
        end
    end
    aux_out.warnings=strvcat(aux_out.warnings,wmsg_all);
end
if (if_ok_centering==0)
    x.centering_specifier='none';
end
if (if_ok_mode==0)
    x.mode='none';
end
aux.opts_xform=x;
%
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
                    switch x.centering_specifier % none','centroid','index','typename','value'
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
                    %handle rotation
                    switch x.mode % 'none', 'translate', 'offset_pca', 'translate_then_pca';
                        case 'none'
                        case 'translate'
                            ts.translation=-cvec;
                        case {'offset_pca','translate_then_pca'}
                            if (iset==1) | ~strcmp(x.source,'global')
                                %cvec+(coords-cvec)*qv is the reconstruction in the PC space.
                                [recon_pcaxes,recon_coords,var_ex,var_tot,coord_maxdiff,opts_offset_pca]=psg_pcaoffset(coords,cvec);
                                qv=opts_offset_pca.qv;
                                ts.orthog=qv;
                                if strcmp(x.mode,'offset_pca')
                                    ts.translation=-cvec*qv+cvec;
                                else
                                    ts.translation=-cvec*qv;
                                end
                            else
                                ts=xforms.ts{1}{idim}; %no need to redo PCA
                            end
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
