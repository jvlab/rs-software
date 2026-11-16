function [dict,opts_used]=btc_define(opts)
% [dict,opts_used]=btc_define(opts) defines a structure "dict" that specifies the names and conventions
% for the first through 4-th order correlation parameters on a 2x2 block of
% a binary texture
%
%  this is needed for the entire btc package, but only needs to be called once.
%
% input structure can specify
%   ifshow:  show a table
%   ifshow_fig: show a figure
%   ordernames: cell array of order names, typically {'gamma','beta','theta','alpha'}
% consistent with getp2x2_corrs:
% corrs.alpha: the fourth-order statistic, 1=even, -1=odd
% corrs.gamma: same as luminance bias, 1=all white, -1=all black
% corrs.beta(1): horizontal second-order correlation
% corrs.beta(2): vertical second-order correlation
% corrs.beta(3): diagonal (upper left to lower right) third-order correlation
% corrs.beta(4): diagonal (upper right to lower left) fourth-order correlation
% corrs.theta(1): third-order correlation of checks A and its flankers, B,C
% corrs.theta(2): third-order correlation of checks B and its flankers, A,D
% corrs.theta(3): third-order correlation of checks C and its flankers, A,D
% corrs.theta(4): third-order correlation of checks D and its flankers, B,C
% checks are
%   A B
%   C D
%  consistent with getp2x2 series, p2x2(ia+1,ib+1,ic+1,id+1) is the probability of [ia ib; ic id]
%
%    See also: BTC_TEST, BTC_CORRS2VEC, BTC_VEC2CORRS, BTC_VEC2LETCODE, BTC_LETCODE2VEC,
%      GETP2X2_CORRS, GETP2X2_ATG, GETP2X2_AG, GETP2X2_TG, GETP2X2_ABG, GTC_DEFINE. 
%
if (nargin<1)
    opts=[];
end
opts=filldefault(opts,'ifshow',0);
opts=filldefault(opts,'ifshow_fig',0);
opts=filldefault(opts,'ordernames',{'gamma','beta','theta','alpha'});
%
dict.ordernames=opts.ordernames;
%
% checks are
%   A B
%   C D
dict.checkdef.A=[0 0];
dict.checkdef.B=[0 1];
dict.checkdef.C=[1 0];
dict.checkdef.D=[1 1];
dict.checks{1}=['A'];
dict.checks{2}=['A','B'];
dict.checks{3}=['A','C'];
dict.checks{4}=['A','D'];
dict.checks{5}=['B','C'];
dict.checks{6}=['B','C','D'];
dict.checks{7}=['A','C','D'];
dict.checks{8}=['A','B','C'];
dict.checks{9}=['A','B','D'];
dict.checks{10}=['A','B','C','D'];
%
dict.codel=['g','b','c','d','e','t','u','v','w','a'];%  single-letter code
%dict.order=[ 1   2   2   2   2   3   3   3   3   4]; % order of correlation
dict.posit=[ 1   1   2   3   4   4   3   1   2   1]; %subscript position in corrs
dict.rot=  [ 0   0   1   0   1   0   1   2   3   0]; %number of 90-deg rotations w.r.t. standard   
dict.mults=ones(2,length(dict.checks));
dict.inpickard=zeros(2,length(dict.checks));
for k=1:length(dict.checks)
    dict.checkcoords{k}=[];
    dict.order(1,k)=length(dict.checks{k});
    dict.name_order{1,k}=dict.ordernames{dict.order(k)};
    dict.name_full{1,k}=sprintf('%s(%1.0f)',dict.name_order{1,k},dict.posit(1,k));
    if (ismember(dict.order(k),[2 3]))
        dict.name{1,k}=dict.name_full{1,k};
    else
        dict.name{1,k}=dict.name_order{1,k};
    end
    for i=1:length(dict.checks{k})
%        dict.checkcoords{k}(i,:)=getfield(dict.checkdef,dict.checks{k}(i));
        dict.checkcoords{k}(i,:)=dict.checkdef.(dict.checks{k}(i));
    end
    % do multiplicities and augmented names (beta_horiz, beta_vert)
    dict.name_order_aug{1,k}=dict.name_order{1,k};
    if (dict.order(1,k)==2)
        if all(sum(dict.checkcoords{k},1)==1)
            dict.name_order_aug{1,k}=cat(2,dict.name_order_aug{1,k},'_diag');
        else
            dict.name_order_aug{1,k}=cat(2,dict.name_order_aug{1,k},'_hv');
        end
    end
    %multiplicity of possible placements along each axis
    dict.mults(:,k)=(2-(max(dict.checkcoords{k},[],1)-min(dict.checkcoords{k},[],1)))';
    dict.mult(1,k)=prod(dict.mults(:,k));
    %do involvements in Pickard
    if (dict.mult(1,k)>1)
        dict.inpickard(:,k)=1;
    else
        if (ismember(dict.order(1,k),[2 3]))
            if ismember('A',dict.checks{k}) & ismember('D',dict.checks{k})
                dict.inpickard(1,k)=1;
            end
            if ismember('B',dict.checks{k}) & ismember('C',dict.checks{k})
                dict.inpickard(2,k)=1;
            end
        end
    end
end
dict.name_order_aug_unique=cellstr(unique(dict.name_order_aug))'; %added 21 Dec 2010 since this is slow to recompute
%
if (opts.ifshow)
    disp(' uid letter rot name_full  name_order      name   checks used name_order_aug  mults    inpickard')
    for k=1:length(dict.checks)
        lstar=' ';
        if (dict.rot(k)==0)
            lstar='*';
        end
        disp(sprintf(' %2.0f    %1s%1s    %1.0f    %8s   %8s   %8s     %4s     %12s  %3.0f %3.0f %3.0f  %1.0f  %1.0f',...
            k,dict.codel(k),lstar,dict.rot(k),dict.name_full{k},dict.name_order{k},dict.name{k},dict.checks{k},dict.name_order_aug{k},...
            dict.mults(:,k),dict.mult(k),dict.inpickard(:,k)));
    end
end
if (opts.ifshow_fig)
    figure;
    set(gcf,'Position',[200 200 1200 500]);
    for k=1:length(dict.checks)
        subplot(2,5,k);
        map=repmat(0.5,4,4);
        map(2:3,2:3)=0;
        for i=1:size(dict.checkcoords{k},1);
            map(2+dict.checkcoords{k}(i,1),2+dict.checkcoords{k}(i,2))=1;
        end
        imagesc(map,[0 1]);
        axis square;
        title(sprintf('param %2.0f: %s=%s',k,dict.codel(k),dict.name{k}));
        axis off;
        colormap gray;
    end
end
opts_used=opts;
return

