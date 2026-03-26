function [xforms,aux_out]=rs_xform_specify(data_in,aux)
% Creates a `transformation structure` based on a 'dataset structure`
%
% A `transformation structure` is a cell array of geometric transformations.
% The `transformation structures` created by this module are all combinations of linear transformations and translations.
% These transformations center the coordinates in data_in (i.e., move the centroid to the origin), 
% and/or or rotate them into their principal components.
% 
% Args:
%   data_in (struct): `dataset structure` to be aligned containing n records, with fields
%
%     - ds (cell array): `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas (cell array): `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets (cell array): `set metadata structure`, sets{k} is the response metadata for the kth record
%
%   aux (struct): auxiliary options, may be omitted, with fields
%
%     - opts_xform (struct): specification of the transformation, with fields
%
%         - mode (char): One of 'none', 'translate','offset_pca','translate_then_pca'; default is 'none'
%
%             - 'none': the identity transformation
%             - 'translate': a point specified by 'centering_specifier' (see below) is translated to the origin
%             - 'offset_pca': the data are rotated into the principal components around the point specified by 'centering_specifier' (see below). 
%             The first coordinate explains the most variance around that point, the second coordinate explains the next-most-variance, etc.
%             The point specified by the 'centering_specifier' is not moved.
%             - 'translate_then_pca': the point specified by 'centering_specifier') is translated to the origin, and then standard pca is done.
%
%         - source (char): 'global','local', or an integer in [1:n], where n is the number of records, equal to length(data_in.ds); default is 'global'
%
%             - 'global' (default): the centering specifier is determined from the mean across records; pca is computed across all records;
%             the transformations specified for all records are identical
%             - 'local': the centering specifier and pca is computed separately for each record; tranformations for each record typically differ
%             - an integer: the specified record is used for the centering specifier and pca; transformations foe all records are identical
%
%         - centering_specifier (char): 'none','centroid','index','typename','value'; default is 'none'
%
%             - 'none': no centering is done
%             - 'centroid': centroid is the centering point
%             - 'typename': use the stimulus corresponding to aux.opts_xform.centering_typename in data_in.sas{k}.typenames for centering
%             - 'index': use the value in aux.opts_xform.centering_index, as the
%             index number of the stimulus whose coordinates are to be used for centering.
%             Caution: the index refers to the position of the stimulus in data_in.ds{k}, and stimulus order may differ across datasets. 
%             To avoid mis-refrencing stimuli, specify by typename.
%             - 'value': use the coordinates in aux.opts_xform.,centering_value for centering
%
%         - centering_typename (char): the label of the stimulus in data_in.sas{k} to be used for centering
%         - centering_index (int): the index in data_in.ds{k} to be used for centering
%         - centering_value (float 1-D array): the coordinates to be used for centering; for coordinate sets of dimension k, only the first k are used
%         aux.opts_xform.centering_[index|typename|value]: see above in aux.opts_xform.centering_specifier
%         - if_warn (int): 1 (default) to show warnings
%
%     - opts_check (struct): options for consistency checking, with field
%
%          - if_warn (int): 1 to show warnings when datasets are checked for consistency, 0 to suppress; default is 1
% 
% Returns:
%   xforms (struct):  the transformations, with fields
%
%      - ts (cell array): ts{k}{idim} is the transformation to be applied to the coordinates of dimension idim in record k; see note below regarding transformations
%      - pipeline (structure): a structure that indicates how the transformation is specified, and can serve as the 'pipeline' field of a `set metadata structure` when the transformations are applied
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_xform (struct): aux.opts_xform, with defaults filled in
%     - opts_check (struct): aux.opts_check, with defaults filled in
%
% Note regarding transformations:
%     - The transformations specified by rs_xform_specify are combinations of translations
%     and linear transformations.  With ts=xforms.ts{k}{idim}, and each
%     input a row vector the transformation is
%     [output]=ts.b*[input]*ts.T+ts.c, where ts.b is a scalar, ts.T is an
%     array of size [idim,idim], [input] is an array of size [nstims,idim], and c is a row vector of length idim.
%     - This structure is identical to the output of Matlab's procrustes.m,
%     [??how to hyperlink], except that the translation ts.c in procrustes.m
%     is an array of identical rows; here it is just one row.
%     - This structure is also identical to that of
%     aux_out.knit_stats.ts{idim}{k}, where the roles of ts.b, ts.T, and ts.c are
%     replaced by ts.scaling, ts.orthog, and ts.translation.
%     ts_specify{k}{idim}=procrustes_compat(ts_knit{idim}{k}) can be used to convert the transformations produced by ts_knit_coordsets
%     to the transformations produced by rs_xform_specify.
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, PSG_PCAOFFSET, RS_XFORM_SPECIFY_TEST, RS_XFORM_APPLY.
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
aux_out.opts_check=aux.opts_check;
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
%
switch x.centering_specifier
    case {'none','centroid'} 
        x.centering_index=[];
        x.centering_value=[];
        x.centering_typename=[];
    case 'index'
        if ((x.centering_index~=round(x.centering_index)) | (x.centering_index>min(nstims_each)) | (x.centering_index<=0))
            wmsg=sprintf('centering index (%8.3f) not valid (non-integer or out of range); no centering applied',x.centering_index);
            aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_xform.if_warn));
            if_ok_centering=0;
        else
            idx=x.centering_index;
        end
        x.centering_value=[];
        x.centering_typename=[];
    case 'value'
        if length(x.centering_value)<max(dim_list_union)
            wmsg=sprintf('centering value vector length (%3.0f) less than max dimension needed (%3.0f); no centering applied',length(x.centering_value),max(dim_list_union));
            aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_xform.if_warn));
            if_ok_centering=0;
        else
            x.centering_value=x.centering_value(:)';
        end
        x.centering_index=[];
        x.centering_typename=[];
    case 'typename'
         idx_check=strmatch(x.centering_typename,typenames_inter,'exact');
         if length(idx_check)~=1
            wmsg=sprintf('centering typename (%s) not found or not unique in all datasets; no centering applied',x.centering_typename);
            aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_xform.if_warn));
            if_ok_centering=0;
         end
        x.centering_index=[];
        x.centering_value=[];
    otherwise
        wmsg=sprintf('centering specifier (%s) not recognized; no centering applied',x.centering_specifier);
        if_ok_centering=0;
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_xform.if_warn));
        x.centering_index=[];
        x.centering_value=[];
        x.centering_typename=[];
end
switch x.source
    case {'global','local'}
    otherwise
        if isnumeric(x.source)
            if ((x.source~=round(x.source)) | (x.source>nsets) | (x.source<=0))
               wmsg=sprintf('source (%8.3f) not valid (non-integer or out of range); no centering applied',x.source);
               aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_xform.if_warn));
               if_ok_centering=0;
            end
        else
           wmsg=sprintf('centering source (%s) not recognized; no centering applied',x.source);
           aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_xform.if_warn));
           if_ok_centering=0;
        end
end
switch x.mode
    case {'none','translate','offset_pca','translate_then_pca'}
    otherwise
        wmsg=sprintf('mode  (%s) not recognized; no transformation applied',x.mode);
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_xform.if_warn));
        if_ok_mode=0;
end
if (if_ok_centering==0)
    x.centering_specifier='none';
end
if (if_ok_mode==0)
    x.mode='none';
end
aux_out.opts_xform=x;
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
            ts.b=1;
            ts.T=eye(idim);
            ts.c=zeros(1,idim);
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
                            ts.c=-cvec;
                        case {'offset_pca','translate_then_pca'}
                            if (iset==1) | ~strcmp(x.source,'global')
                                %cvec+(coords-cvec)*qv is the reconstruction in the PC space.
                                [recon_pcaxes,recon_coords,var_ex,var_tot,coord_maxdiff,opts_offset_pca]=psg_pcaoffset(coords,cvec);
                                qv=opts_offset_pca.qv;
                                ts.T=qv;
                                if strcmp(x.mode,'offset_pca')
                                    ts.c=-cvec*qv+cvec;
                                else
                                    ts.c=-cvec*qv;
                                end
                            else
                                ts=xforms.ts{1}{idim}; %no need to redo PCA
                            end
                    end
                else
                    ts=[]; %better than struct(), which is not empty
                end
            end %mode
            xforms.ts{iset}{idim}=ts;
        end %dim_ptr
    end %each set
else
    disp('cannot proceed');
    disp(aux_out.warnings);
end
return
end
