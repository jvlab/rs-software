function [check,opts_used]=rs_check_coordsets(data_in,opts)
% [check,opts_used]=rs_check_coordsets(data_in,opts) checks the consistency of `dataset structures` between and within records,
% and tallies the available dimensions and stimuli
%
% Args:
%   data_in (struct): `dataset structure`, with fields
%
%     - ds (cell array): `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas (cell array): `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets (cell array): `set metadata structure`, sets{k} is the response metadata for the kth record
%
%   opts (struct): auxiliary options, may be omitted, with fields
%
%     - if_warn (int): 1 to display warnings, 0 to omit; default is 0
%     - if_checkorder (int): 1 to check that the order of the stimuli, as listed in ds.sas{k}.typenames, is the same, 0 to compare independent of odrer; default is 0
%     - record_num_offset (int): value to add to the record number in displaying aarnings; default is 0
%
% Returns:
%   check (struct): summary of the consistency check, with fields
% 
%     - warnings (char): warning messages
%     - warn_bad (int): count of severe warnings that likely prevent processing
%     - nsets (int): number of records
%     - nstims_each (int 1-D array): nstims_each(k) is the number of stimuli in record k
%     - dim_list_each (cell array): dim_list_each{k} is the list of dimensions available in record k
%     - dim_list_union (int 1-D array): union of dim_list_each{:}
%     - dim_list_inter (int 1-D array): intersection of dim_list_each{:}
%     - typenames_each (cell array): typenames_each{k} is data_in.sas{k}.typenames, in original order
%     - typenames_union (cell array): union of typenames_each{:}, alphabetized
%     - typenames_inter (cell array): intersection of typenames_each{:}, alphabetized
%
%   opts_used (struct): opts, with defaults filled in
%
%  See also:  RS_KNIT_COORDSETS, RS_ALIGN_COORDSETS.
%
if (nargin<=1)
    opts=struct;
end
opts=filldefault(opts,'if_warn',0);
opts=filldefault(opts,'if_checkorder',1);
opts=filldefault(opts,'record_num_offset',0);
opts_used=opts;
check=struct;
check.warn_bad=0;
check.warnings=[];
%
nsets_ds=length(data_in.ds);
nsets_sas=length(data_in.sas);
nsets_sets=length(data_in.sets);
nsets=min([nsets_ds nsets_sas nsets_sets]);
%
nstims_each=zeros(1,nsets);
dim_list_each=cell(1,nsets);
dim_list_union=[];
typenames_each=cell(1,nsets);
typenames_union=[];
%check that ds, sas, sets is consistent
if nsets_sas~=nsets_ds
    wmsg=sprintf('number of records in metadata structure sas (%3.0f) and data structure ds (%3.0f) are inconsistent',nsets_sas,nsets_ds);
    check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
end
if nsets_sets~=nsets
    wmsg=sprintf('number of records in metadata structure sets (%3.0f) and data structure ds (%3.0f) are inconsistent',nsets_sets,nsets_ds);
    check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
end
for iset=1:nsets
    %check that number of stimuli is internally consistent
    nstims_each(iset)=data_in.sets{iset}.nstims;
    typenames_each{iset}=data_in.sas{iset}.typenames;
    if nstims_each(iset)~=data_in.sas{iset}.nstims
        wmsg=sprintf('number of stimuli in set %1.0f in sets (%3.0f) and sas (%3.0f) are inconsistent',iset+opts.record_num_offset,nstims_each(iset),data_in.sas{iset}.nstims);
        check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
    end
    if nstims_each(iset)~=length(typenames_each{iset})
        wmsg=sprintf('number of stimuli in set %1.0f in sets (%3.0f) and typenames (%3.0f) are inconsistent',iset+opts.record_num_offset,nstims_each(iset),length(typenames_each{iset}));
        check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
    end
    %dimension list must be unique and ascending and integer
    dim_list_each{iset}=data_in.sets{iset}.dim_list;
    if (any(dim_list_each{iset}~=round(dim_list_each{iset})) | (any(dim_list_each{iset}<=0)))
        wmsg=sprintf('dimension list record %3.0f must be positive integers',iset);
        check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
    end
    dim_list_each{iset}=max(1,round(dim_list_each{iset}));
    if any(diff(dim_list_each{iset})<=0)
        wmsg=sprintf('dimension list for record %3.0f has non-unique values',iset);
        check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
    end
    dim_list_each{iset}=unique(dim_list_each{iset});
    %
    if iset==1
        typenames_inter=typenames_each{iset};
        dim_list_inter=dim_list_each{iset};
    end
    typenames_union=union(typenames_union,typenames_each{iset});
    typenames_inter=intersect(typenames_inter,typenames_each{iset});
    %check that each array of coordinates is consistent with number of stimuli and dimension
    dim_remove=[];
    for idim_ptr=1:length(dim_list_each{iset})
        idim=dim_list_each{iset}(idim_ptr);
        if length(data_in.ds{iset})>=idim
            coords=data_in.ds{iset}{idim};
            if size(coords,1)~=nstims_each(iset)
                wmsg=sprintf('number of stimuli in coordinate array for record %3.0f and dimension %3.0f (%3.0f) is inconsistent with number of stimuli (%3.0f)',iset+opts.record_num_offset,idim,size(coords,1),nstims_each(iset));
                check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
            end
            if size(coords,2)~=idim
                wmsg=sprintf('number of dimensions in coordinate array for record %3.0f and dimension %3.0f (%3.0f) is inconsistent with expected dimension (%3.0f)',iset+opts.record_num_offset,idim,size(coords,2),idim);
                check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
            end
        else
            wmsg=sprintf('coordinate array for record %3.0f, dimension %3.0f is missing',iset+opts.record_num_offset,idim);
            check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
            dim_remove=[dim_remove,idim];
        end
    end
    dim_list_each{iset}=setdiff(dim_list_each{iset},dim_remove);
    dim_list_union=union(dim_list_union(:)',dim_list_each{iset});
    dim_list_inter=intersect(dim_list_inter,dim_list_each{iset});
    %check if there are extra coordinate sets
    for idim=1:length(data_in.ds{iset})
        coords=data_in.ds{iset}{idim};
        if (size(coords,1)==nstims_each(iset) & size(coords,2)==idim)
            if ~ismember(idim,data_in.sets{iset}.dim_list)
                wmsg=sprintf('coordinate array for set %3.0f and dimension %3.0f is not listed in sets metadata; others may be processed',iset+opts.record_num_offset,idim);
                check=rs_warning(wmsg,0,setfield(check,'if_warn',opts.if_warn));
            end
        end
    end
end
%check that number of stimuli are consistent across datasets
if min(nstims_each)~=max(nstims_each)
    wmsg=sprintf('number of stimuli do not agree across datasets (min: %3.0f, max: %3.0f)',min(nstims_each),max(nstims_each));
    check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
end
%check that stimulus names are consistent across datasets
if length(typenames_inter)~=length(typenames_union)
    wmsg=sprintf('stimulus names do not agree across datasets');
    check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
else %only check order of typenames if they have same length and match in some order
    if opts.if_checkorder
        if_order=1;
        for iset=1:nsets-1
            if any(~strcmp(typenames_each{iset},typenames_each{iset+1}))
                if_order=0;
            end
        end
        if if_order==0
            wmsg=sprintf('stimulus orders do not agree across datasets');
            check=rs_warning(wmsg,1,setfield(check,'if_warn',opts.if_warn));
        end
    end
end %same stimulus names,independent of order?
if length(dim_list_union)~=length(dim_list_inter)
    wmsg=sprintf('dimension lists do not agree across datasets; intersection is available for processing'); %this is not severe, process the intersection
    if opts.if_warn
        check=rs_warning(wmsg,0,setfield(check,'if_warn',opts.if_warn));
        disp('discrepancies')
        disp(setdiff(dim_list_union,dim_list_inter));
    end
end
check.nsets=nsets;
check.nstims_each=nstims_each;
check.dim_list_each=dim_list_each;
check.dim_list_union=dim_list_union;
check.dim_list_inter=dim_list_inter;
check.typenames_each=typenames_each;
check.typenames_union=typenames_union;
check.typenames_inter=typenames_inter;
return
end

