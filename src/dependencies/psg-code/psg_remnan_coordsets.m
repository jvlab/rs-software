function [sets_nonan,ds_nonan,sas_nonan,opts_used]=psg_remnan_coordsets(sets_align,ds_align,sas_align,ovlp_array,opts)
% [sets_nonan,ds_nonan,sas_nonan,opts_used]=psg_remnan_coordsets(sets_align,ds_align,sas_align,ovlp_array,opts)
% removes entries that have been inserted to align datasets and metadata with partially overlapping stimuli
% (typically by psg_align_coordsets).
% Here, "alignment" refers to matching up the stimuli at the level of the metadata, not a coordinate rotation
%
% sas_align{k}.typenames is used to establish stimulus identity, and
%  typenames that correspond to 0 in ovlp_array are deleted, along with other fields
%  of sas_align{k} that correspond to individual stimuli
% coordinates of ds_align correseponding to 0 in ovlp_array are deleted, should just be NaN's
% all sets should have same number of stimuli, determined from ds, and same type names
% sets_align: cell array (one cell for each dataset) dataset descriptors (typically from psg_align_coordsets) after alignment
% ds_align: cell array (one cell for each dataset) of coordinate data after alignment
%  all datasets must have dimension lists beginning at 1 and without gaps
% sas_align: cell array (one cell for each dataset) of metadata after alignment
% ovlp_array: [nstims_all nsets]: array of 1's for points in overlaps, 0 otherwise
%    If empty, then the first set of coordinates if ds_align is used, and NaN is used to indicate a 0
% opts: options
%   opts.if_log: 1 to log progress
%
% sets_nan: cell array (one cell for each dataset) dataset descriptors after removal of NaN's
% ds_nan: cell array (one cell for each dataset) of coordinate data after removal of NaN's
% sas_nan: cell array (one cell for each dataset) of metadata after removal of NaN's
% opts_used: options used
%    opts_used.ovlp_array: ovlp_array as furnished, or as computed from NaN's in ds_align
%
% 02Feb26: allow for empty variables
%
%  See also: PSG_ALIGN_KNIT_DEMO, PSG_GET_COORDSETS, PSG_READ_COORDDATA, PSG_ALIGN_COORDSETS, PSG_DEFOPTS.
%
opts_fields=psg_defopts();
fields_align=opts_fields.fields_align;
fields_pool=opts_fields.fields_pool;
%
if (nargin<=4) opts=struct; end
opts=filldefault(opts,'if_log',0);
opts_used=opts;
%
nsets=length(ds_align);
%
if (opts.if_log)
    disp(sprintf('NaN removal attempted with %2.0f datasets',nsets));
end
opts_used.warnings=[];
if isempty(ovlp_array)
    nstims_all=size(ds_align{1}{1},1);
else
    nstims_all=size(ovlp_array,1);
end
%
%build ovlp_array from NaN's or, if ovlp_array is given, check for consistency with NaN's
%
ovlp_array_check=zeros(nstims_all,nsets);
for iset=1:nsets
    nstims_this=size(ds_align{iset}{1},1);
    if nstims_all~=nstims_this
        wmsg=sprintf('dataset %1.0f (%s) has incorrect number of stimuli: %2.0f found, %2.0f expected',...
            iset,sets_align{iset}.label,nstims_this,nstims_all);
        opts_used.warnings=strvcat(opts_used.warnings,wmsg);
        warning(wmsg);
    end
    ovlp_array_check(:,iset)=double(~any(isnan(ds_align{iset}{1}),2));
end
if isempty(ovlp_array)
    ovlp_array=ovlp_array_check;
else
    if any(ovlp_array(:)~=ovlp_array_check(:))
        wmsg=sprintf('overlap array does not match pattern of NaN''s in data');
        opts_used.warnings=strvcat(opts_used.warnings,wmsg);
        warning(wmsg);       
    end
end
opts_used.ovlp_array=ovlp_array;
%
sets_nonan=sets_align;
ds_nonan=ds_align;
sas_nonan=sas_align;
typenames_all=cell(0);
nstims_each=zeros(nsets,1);
for iset=1:nsets
    nstims_each(iset)=sets_align{iset}.nstims;
    typenames_all=[typenames_all;sas_align{iset}.typenames];
end
typenames_all=unique(typenames_all);
nstims_all_found=length(typenames_all);
if (opts.if_log)
    for iset=1:nsets
        disp(sprintf(' set %3.0f: stimuli: %3.0f, type %10s, label %s',iset,sets_align{iset}.nstims,sets_align{iset}.type,sets_align{iset}.label));
    end
    disp(sprintf(' unique typenames: %3.0f',nstims_all_found));
end
if (nstims_all_found~=nstims_all)
    wmsg=sprintf('incorrect number of unique typenames: %4.0f found, %4.0f expected');
    opts_used.warnings=strvcat(opts_used.warnings,wmsg);
    warning(wmsg);
end
for iset=1:nsets
%modify overall set descriptors
    sets_nonan{iset}.nstims=sum(ovlp_array(:,iset));
%modify metadata
     fns=fieldnames(sas_align{iset});
     for ifn=1:length(fns)
         fn=fns{ifn};
         if strmatch(fn,'nstims','exact') %special case for nstims
             sas_nonan{iset}.(fn)=sum(ovlp_array(:,iset)==1);
         elseif ~isempty(strmatch(fn,fields_align,'exact')) | ~isempty(strmatch(fn,fields_pool,'exact')) %remove nans from this field
            if iscell(sas_align{iset}.(fn)) %1d cell
                sas_nonan{iset}.(fn)=sas_align{iset}.(fn)(ovlp_array(:,iset)==1);
            else %multi-dim array, first index is stimulus id
                sas_nonan{iset}.(fn)=psg_nonan_coordsets_do(sas_align{iset}.(fn),ovlp_array(:,iset));
            end
         else %other fields, just copy
             sas_nonan{iset}.(fn)=sas_align{iset}.(fn);
         end
     end  
%modify coordinates
    for idim=1:length(ds_align{iset})
        ds_nonan{iset}{idim}=ds_align{iset}{idim}(ovlp_array(:,iset)==1,:);
    end
end
return

function nonaned=psg_nonan_coordsets_do(to_nonan,keep) %remove nonans from a multidimensional variable based on first dimension
dims_all=size(to_nonan);
dims_last=dims_all(2:end);
var_tononan=reshape(to_nonan,[size(to_nonan,1) prod(dims_last)]); %make .(fn) 2-dimensional
if ~isempty(var_tononan)
    var_nonaned=var_tononan(keep==1,:);
    nonaned=reshape(var_nonaned,[sum(keep==1) dims_last]);
else
    nonaned=[];
end
return
