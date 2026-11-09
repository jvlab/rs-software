function [nest_rank,order_ptrs,model_types_nested,opts_used]=psg_geomodels_nestorder(mdef,opts)
% [nest_rank,order_ptrs,model_types_nested,opts_used]=psg_geomodels_nestorder(mdef,opts)
% determines the order of models so that a model precedes a model that it is nested in
% also checks the nesting structure for consistency, and determines a set
% of "maximal" nests, i.e., models that are nested in another but with no intermediate nested model
%
% mdef: the model definition structure, from psg_geomodels_define;
%   mdef.model_types is a list of model types to be reordered
%   mdef is requested if empty
% opts:
%   opts.if_log: 1 to log activity (default: 0; 1 for standard log, 2 for details)
%   opts.if_select: 1 to allow interactive selection of model types if mdef is omitted, default: 0
%
% nest_rank: the integers [1:length(mdef.model_types)]
%     if nest_rank(i)<nest_rank(j), then mdef.model_types{i} may be nested in nest_rank{j}
% order_ptrs: the integers [1:length(mdef.model_types}],
%     the order in which the model types should be computed so that a model is computed
%     before a model that it is nested in
% model_types_nested: mdef.model_types, ordered in the order that they
%     should be computed
% opts_used: options used, and also
%     hierarchy(i,j) is 1 if model j is nested in model i, indices are models in original order
%     hierarchy_nest(i,j): same as hierarchy(i,j), but indices are models in nested order, 
%       this is is always lower triangular
%     hierarchy0(i,j) is 1 if model j is maximally nested in model i, i.e., there is no intermediate nested model; indices are models in original order
%     hierarchy0_nest(i,j): same as hierarchy0(i,j), but indices are models in nested order
%     mdef: model definition structure, as provided as input, or as determined from call to psg_geomodels_define
%     mdef0: model definition structure but with nested subfields modified to show only maximal nested models
%  If no ordering is possible (because nesting is not tree-like), then nest_rank, order_ptrs will be NaNs, and model_types_nested will be empty
%
%    See also: PSG_GEOMODELS_DEFINE, PSG_GEOMODELS_FIT, PSG_GEOMODELS_RUN.
%
if (nargin==0)
    mdef=[];
end
if (nargin<=1)
    opts=struct;
end
opts=filldefault(opts,'if_log',0);
opts=filldefault(opts,'if_select',0);
opts_used=opts;
%
if isempty(mdef)
    mdef=psg_geomodels_define(opts.if_select);
elseif isstruct(mdef)
    if isempty(fieldnames(mdef))
         mdef=psg_geomodels_define(opts.if_select);
    end
end
model_types=mdef.model_types;
nmodels=length(model_types);
%
nest_rank=NaN(1,nmodels);
order_ptrs=NaN(1,nmodels);
model_types_nested=cell(0);
%
%create a hierarchy matrix
%
h=zeros(nmodels,nmodels);
for imodel=1:nmodels
    nested=mdef.(model_types{imodel}).nested;
    for k=1:length(nested)
        hk=strmatch(nested{k},model_types,'exact');
        h(imodel,hk)=1;
    end
end
%
if opts.if_log>=1
    disp('hierarchy matrix');
    disp('model types in original order');
    for k=1:nmodels
        disp(sprintf('%30s %s',model_types{k},sprintf(' %3.0f',h(k,:))));
    end
end
opts_used.hierarchy=h;
h0=h-min(h*h,1); %
opts_used.hierarchy0=h0;
%
%check that h is complete, i.e., that all implied hierarchies are present
%
if any(any(min(h*h,1)>h))
    disp('nesting hieararchy of models is incomplete.')
end
%
%find a ranking consistent with the hierarchy
%
rank_temp=zeros(1,nmodels);
if_fail=0;
for imodel=2:nmodels
    must_follow=find(h(imodel,1:imodel-1)==1);
    must_precede=find(h(1:imodel-1,imodel)==1)';
    if opts.if_log>=2
        disp(sprintf('model %1.0f',imodel));
        disp('must_follow')
        disp(must_follow);
        disp('must_precede')
        disp(must_precede);
    end
    rank_min=NaN;
    rank_max=NaN;
    if ~(isempty(must_follow))
        rank_min=max(rank_temp(must_follow));
    end
    if ~(isempty(must_precede))
        rank_max=min(rank_temp(must_precede));
    end
    if ~isnan(rank_min) & ~isnan(rank_max)
        if rank_max<=rank_min
            if_fail=1;
            rank_temp(imodel)=NaN;
        else          
            rank_temp(imodel)=(rank_min+rank_max)/2;
        end
    elseif isnan(rank_min)
        rank_temp(imodel)=min(rank_temp(1:imodel-1))-1;
    else
        rank_temp(imodel)=max(rank_temp(1:imodel-1))+1;
    end
    if opts.if_log>=2
        disp(sprintf(' min: %5.3f max: %5.3f assigned: %5.3f',rank_min,rank_max,rank_temp(imodel)))
    end
end
%
%give mean, if present, the lowest rank
%
mean_ptr=strmatch('mean',model_types,'exact');
if ~isempty(mean_ptr)
    rank_temp(mean_ptr)=min(rank_temp)-1;
end
if length(unique(rank_temp))~=length(rank_temp)
    if_fail=1;
end
if if_fail
    disp('nesting of models is inconsistent with a hierarchy')
    return
else
    [rank_temp_sorted,order_ptrs]=sort(rank_temp);
end
h_nest=h(order_ptrs,order_ptrs);
opts_used.hierarchy_nest=h_nest;
opts_used.hierarchy0_nest=h_nest-min(h_nest*h_nest,1);
if opts.if_log>=1
    disp('hierarchy matrix reordered to be consistent with nesting');
    disp('model types in nested order')
    for k=1:nmodels
        disp(sprintf('%30s %s',model_types{order_ptrs(k)},sprintf(' %3.0f',h_nest(k,:))));
    end
end
model_types_nested=model_types(order_ptrs);
nest_rank(order_ptrs)=[1:nmodels];
%
%create a modified model definition, with fewest nestings
%
mdef0=mdef;
for imodel=1:nmodels
    nest_ptrs=find(opts_used.hierarchy0_nest(imodel,:)==1);
    nest_list=cell(1,length(nest_ptrs));
    for iptr=1:length(nest_ptrs)
        nest_list{iptr}=model_types_nested{nest_ptrs(iptr)};
    end
    mdef0.(model_types_nested{imodel}).nested=nest_list;
end
opts_used.mdef=mdef;
opts_used.mdef0=mdef0;
return
end
