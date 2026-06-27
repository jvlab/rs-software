function [shuffs,gp_info,opts_used]=multi_shuff_groups(gps,opts)
% [shuffs,gp_info,opts_used]=multi_shuff_groups(gps,opts) creates lists of shuffles between groups, that optionally:
%   * is exhaustive
%   * preserve an auxiliary tag
%   * if exhaustive, is optionally reduced by symmetry so that groups of the same size, and that contain the same number
%     of items for each tag, are considered identical.  That is, for every set of groups that have the same 
%     number of items with each tag, the groups are ordered in order of the lowest-occurring element within each group.
%     Note that groups that have the same size but differ in the number of elements that they contain of each tag
%     are considered different.  For example, if gps=[1 1 1 2 2 2] and tags=[1 1 2 2 2 1], then items [1 2 6] can be permuted (tag=1), and independently
%     items [3 4 5] can be permuted (tag=2), but even though both groups have 3 elements, the first group is distinguished since it has two elements
%     with a tag of 1. But if gps=[1 1 1 2 2 2] and tags=[1 1 2 1 1 2], then there are 6 rearrangements of items [1 2 4 5], and 2 rearrangeents of items [3 6],
%     but the 12=6*2 shuffles are reduced by a factor of two since the first and second groups both have the same complements of each tag.
% 
% Implementation of auxiliary tags relies on recursion, but recursion only one step deep
%
% gps: a row vector of length n, that indicates the assignment of each
%   element to [1:ngps].  Not all of [1:ngps] must be present.
% opts: options
%  if_log: 1 to log, defaults to 0
%  if_ask: 1 to ask if_reduce, if_exhaust, nshuffs, defaults to 0; -1: ask only about if_exhaust and nshuffs
%  if_exhaust: 1 to do exhaustive list, defaults to 0 (for random list)
%  if_reduce: 1 to reduce by symmetrizing, defaults to 0, ignored if if_exhaust=0
%  if_justcount: just count up number of shuffles, do not create them, defaults to 0
%  if_nowarn: 1 to suppress warnings, defaults to 0
%  if_sortrows: 1 to sort shuffle list by rows, defaults to 0
%  nshuffs: number of shuffles, defaults to 1000
%  exhaust_raw_max: maximum number for exhaustive list, before reduction (defaults to 10^9)
%  exhaust_reduced_max: maximum number for exhuastive list, after reduction (defaults to 10^6)
%  nshuffs_max: maximum number of shuffles, defaults to min(exhaust_raw_max,exhaust_reduced_max)
%  tags: array of size [1:n], containing values [1:ntags].
%   shuffles will only exchange values with the same tags.
%   If empty or all values equal, this is ignored.  Not all of [1:ntags] need be represented.
%
% shuffs: the shuffles; each row is a perm of [1:n], and shuffles(is,:) goes into gps(:)
% gp_info: group information
%   gp_info.ngps: number of groups
%   gp_info.gps_unique: unique group numbers, in order
%   gp_info.gp_list: cell(1,ngps); which elements in each group, in order of gps_unique
%   gp_info.nsets_gp: (1,ngps); number of datasets in each group, in order of gps_unique
%   gp_info.exhaust_raw: number of shuffles if exhaustive, prior to reduction
%   gp_info.exhaust_reduced: number of shuffles if exhaustive, if reduced
%   gp_info.tags{itag}: gp_info for subsets with each tag.
% opts_used: options used
% 
% 24Mar25: add if_ask=-1
%
%  See also:  NCHOOSEK, FILLDEFAULT, MULTI_SHUFF_ENUM, MULTI_SHUFF_GROUPS_TEST, PSG_ALIGN_VARA_DEMO, MULTI_SHUFF_MIXENT,
%   HLID_GEOM_TRANSFORM_STATS, MULTI_BOOT_GROUPS, PSG_ALIGN_VARA_DEMO.
%
if nargin<2
    opts=struct;
end
gp_info=struct;
opts=filldefault(opts,'if_log',0);
opts=filldefault(opts,'if_ask',0);
opts=filldefault(opts,'if_exhaust',0);
opts=filldefault(opts,'if_reduce',0);
opts=filldefault(opts,'if_justcount',0);
opts=filldefault(opts,'if_nowarn',0);
opts=filldefault(opts,'if_sortrows',0);
opts=filldefault(opts,'nshuffs',1000);
opts=filldefault(opts,'exhaust_raw_max',10^9);
opts=filldefault(opts,'exhaust_reduced_max',10^6);
opts=filldefault(opts,'nshuffs_max',min(opts.exhaust_raw_max,opts.exhaust_reduced_max));
opts=filldefault(opts,'tags',ones(1,length(gps)));
%
if opts.if_ask>0
    opts.if_reduce=getinp('1 to reduce exhaustive shuffles by considering groups of same size (and tag counts) to be equivalent','d',[0 1]);
end
if length(opts.tags)~=length(gps)
    if opts.if_nowarn==0 & (length(opts.tags)>0)
        warning(sprintf('length(tags), %3.0f, not equal to length(gps), %3.0f; tags ignored',length(opts.tags),length(gps)));
    end
    opts.tags=ones(1,length(gps));
end
%
if_tagged=double(~(min(opts.tags)==max(opts.tags)));
%
n=length(gps);
gps_unique=unique(gps,'stable'); %unique group IDs, but in same order as in gps
ngps=length(gps_unique);
gp_list=cell(1,ngps);
nsets_gp=zeros(1,ngps);
%
shuffs=zeros(0,n);
%
for k=1:ngps
    gp_list{k}=find(gps==gps_unique(k));
    nsets_gp(k)=length(gp_list{k});
end
exhaust_raw=1;
exhaust_reduced=1;
%
%if if_tagged, recursive call to get counts
%
opts.if_tagged=if_tagged;
if if_tagged
    opts_recur=opts;
    opts_recur.if_log=0;
    opts_recur.if_ask=0;
    opts_recur.if_reduce=0; %only reduce at end
    opts_recur.if_exhaust=0; %irrelevant since if_justcount=1
    opts_recur.if_justcount=1;
    opts_recur.if_nowarn=1;
    tags=unique(opts.tags);
    ntags=length(tags);
    gp_info.tags=cell(1,ntags);
    gps_tag=cell(1,ntags);
    for itag=1:ntags %treat each tag as a separate subset
        gps_tag{itag}=gps(opts.tags==tags(itag));
        if ~isempty(gps_tag{itag})
            if opts.if_log
                disp(sprintf('multi_shuff_groups called recursively for counting, tag %1.0f [applies to %4.0f items]',tags(itag),length(gps_tag{itag})));
            end
            opts_recur.tags=ones(1,length(gps_tag{itag})); %will prevent further recursion
            [shuffs,gp_info_tag]=multi_shuff_groups(gps_tag{itag},opts_recur);
            exhaust_raw=exhaust_raw*gp_info_tag.exhaust_raw;
            gp_info.tags{itag}.gp_info=gp_info_tag;
            gp_info.tags{itag}.tag=tags(itag);
        end
    end
    exhaust_reduced=exhaust_raw;
    %determine whather any groups have the same number of each tag
    gp_profile=zeros(ngps,ntags);
    for igp=1:ngps
        for itag=1:ntags
            gp_profile(igp,itag)=sum((gps==gps_unique(igp)) & opts.tags==tags(itag));
        end
    end
    gp_profile_unique=unique(gp_profile,'rows');
    nu=size(gp_profile_unique,1);
    for iu=1:nu
        nk=sum(all(repmat(gp_profile_unique(iu,:),size(gp_profile,1),1)==gp_profile,2));
        exhaust_reduced=exhaust_reduced/factorial(nk);      
    end
else
    ntags=1;
    for k=2:ngps
        if k>1 %work iteratively to avoid quotients of large integers
            newmult=nchoosek(sum(nsets_gp(1:k)),nsets_gp(k));
            exhaust_raw=exhaust_raw*newmult;
            exhaust_reduced=exhaust_reduced*newmult/sum(double(nsets_gp(1:k)==nsets_gp(k))); %divide by multiplicity
        end
    end
    if sum(nsets_gp)~=n
        if opts.nowarn==0
            warning('some group numbers are not integers in the range [1 ngps]');
        end
    end
end
gp_info.ngps=ngps;
gp_info.gps_unique=gps_unique;
gp_info.gp_list=gp_list;
gp_info.nsets_gp=nsets_gp;
gp_info.exhaust_raw=exhaust_raw;
gp_info.exhaust_reduced=exhaust_reduced;
gp_info.if_tagged=if_tagged;
%
exhmsg='exhaustive list too long; will use random strategy';
if ~opts.if_justcount
    %choose reduced vs. non-reduced
    if opts.if_reduce
        exhaust=exhaust_reduced;
        reduced_string='reduced';
        exhaust_max=opts.exhaust_reduced_max;
    else
        exhaust=exhaust_raw;
        reduced_string='not reduced';
        exhaust_max=opts.exhaust_raw_max;
    end
    %show info about number of shuffles
    if opts.if_log | abs(opts.if_ask)
        disp(sprintf('list (%s) will have %10.0f shuffles; max allowed for exhaustive list: %10.0f',reduced_string,exhaust,exhaust_max));
    end
    %ask whether exhaustive if size permits, otherwise force random (non-exhaustive)
    if abs(opts.if_ask)
        if exhaust>exhaust_max
            disp(exhmsg);
            opts.if_exhaust=0;
        else
            opts.if_exhaust=getinp('1 for exhaustive shuffles, 0 for random','d',[0 1]);
        end
        if opts.if_exhaust==0
            opts.nshuffs=getinp('number of shuffles','d',[0 opts.nshuffs_max],opts.nshuffs);
        end
    else %not interactive, make sure that size is OK and if not, log or warn
        if exhaust>exhaust_max & (opts.if_exhaust==1)
            opts.if_exhaust=0;
            if opts.if_log
                disp(exhmsg);
            else
                if opts.if_nowarn==0
                    warning(exhmsg);
                end
            end
        end
    end
    if opts.if_exhaust
        opts.nshuffs=exhaust;
    end
    %
    %now generate the shuffles
    %
    if opts.if_exhaust
        opts_enum=struct;
        opts_enum.if_log=opts.if_log;
        %
        %enumerate all
        %
        if if_tagged %tags present: actor by restriction  and at end apply reduction by symmetry
            opts_enum.if_reduce=0; %reduce at end           
            for itag=1:ntags %treat each tag as a separate subset
                % gps_tag{itag}: the group labels for the subset with this tag
                gp_list_tag=cell(1,ngps);
                for k=1:ngps
                    gp_list_tag{k}=intersect(find(gps==gps_unique(k)),find(opts.tags==tags(itag)));
                end
                items_tag=find(opts.tags==tags(itag));
                if opts.if_log
                    disp(sprintf('multi_shuff_enum called for tag %1.0f [applies to %4.0f items]',tags(itag),length(gps_tag{itag})));
                end
                [a,opts_enum_used]=multi_shuff_enum(gp_profile(:,itag),opts_enum);
                %combine this shuffle with previous as a "tensor product"
                 if (itag>1)
                    s0=size(shuffs,1);
                    shuffs=repmat(shuffs,size(a,1),1); %a copy of each of previous shuffles, one for each row of a
                else
                    shuffs=zeros(size(a,1),n);
                    s0=1;
                end
                %convert a into shuffles, using only with the items from each group that have tags(itag) 
                %do a range of values at once
                for igp=1:ngps
                    for is=1:size(a,1)
                        is_range=[1:s0]+(is-1)*s0;
                        shuffs(is_range(:),gp_list_tag{igp})=repmat(items_tag(find(a(is,:)==igp)),s0,1);
                    end
                end %is
             end
            %apply opts.if_reduce
            if (opts.if_reduce)
                if (opts.if_log)
                    disp('reducing by symmetry');
                    disp('unique group profiles:')
                    disp(gp_profile_unique);
                    disp('group profiles');
                    disp(gp_profile);
                end
                    if (size(gp_profile,1)~=size(gp_profile_unique,1))
                    gp_table=gps(shuffs); %gp_table has the group assignments
                    for iu=1:nu
                        gp_red=find(all(repmat(gp_profile_unique(iu,:),size(gp_profile,1),1)==gp_profile,2));
                        if (opts.if_log)
                            disp(sprintf(' unique group profile %1.0f is %s',iu,sprintf(' %2.0f',gp_profile_unique(iu,:))))
                            disp(sprintf('occurs for group labels %s',sprintf(' %2.0f',gps_unique(gp_red))));
                        end
                        if length(gp_red)>1 %number of groups with identical tag profile
                            %do the reduction: the lowest entry in each group should be in lexicographic order
                            low_entry=zeros(size(gp_table,1),length(gp_red));
                            for ig=1:length(gp_red)
                                low_entry(:,ig)=min(shuffs(:,gps==gps_unique(gp_red(ig))),[],2);                               
                            end
                            seq_ok=all(diff(low_entry,1,2)>0,2);
                            shuffs=shuffs(seq_ok,:);
                            gp_table=gp_table(seq_ok,:);
                        end %if length(gp_red)
                    end %next nique group profile
                end %are there any equivalent groups?
            end %if_reduce
        else
            %
            %untagged:  can apply reduction by symmetry within multi_shuff_enum
            %
            opts_enum.if_reduce=opts.if_reduce; %reduce within multi_shuff_enum
            if opts.if_log
                disp(sprintf('multi_shuff_enum called, untagged , if_reduce=%1.0f [applies to %4.0f items]',opts_enum.if_reduce,n));
            end
            [a,opts_enum_used]=multi_shuff_enum(nsets_gp,opts_enum);
            % convert a into shuffles
            shuffs=zeros(size(a));
            for is=1:size(shuffs,1)
                for igp=1:ngps
                    shuffs(is,gp_list{igp})=find((a(is,:)==igp));
                end
            end
        end %exhaustive enumeration
    else 
        %   
        %random shuffles: do each tagged subset separately
        %
        shuffs=zeros(opts.nshuffs,n);
        for itag=1:ntags
            if (if_tagged)
                items_shuff=find(opts.tags==tags(itag));
                if opts.if_log
                    disp(sprintf('creating %5.0f random shuffles for  tag %1.0f [applies to %4.0f items]',opts.nshuffs,itag,length(items_shuff)))
                end
            else
                items_shuff=1:n;
                if opts.if_log
                    disp(sprintf('creating %5.0f random shuffles for all %4.0f items',opts.nshuffs,n));
                end
            end
            ni=length(items_shuff);
            for ishuff=1:opts.nshuffs
                shuffs(ishuff,items_shuff)=items_shuff(randperm(ni));
            end
        end
    end
    %
    %sort if requested
    %
    if opts.if_sortrows
        shuffs=sortrows(shuffs);
    end 
end %just count
opts_used=opts;
return

