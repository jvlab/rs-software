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
% If a dimension is present in data_in{k}{ip} but not xforms.ts{k}{ip} is empty, then the
%   data_out{k}{ip} will be empty, and a warning is generated.
% If length(xforms.ts) = 1, then it is applied to all datasets.  If length
% is not 1, then it should match length(data_in.ds)
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, RS_XFORM_SPECIFY.
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
%validate input parameters for consistency, etc.
%
if_ok=1;
x=aux.opts_xform; %for convenience
%
nsets_xform=length(xforms.ts);
if (nsets_xform~=nsets) & (nsets_xform~=1)
    wmsg=sprintf('number of transform sets specified (%2.0f) differs from number of datasets (%2.0f)',nsets_xform,nsets);
    if aux.opts_xform.if_warn
        warning(wmsg);
    end
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
end
%%%%%%%%%%%
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
