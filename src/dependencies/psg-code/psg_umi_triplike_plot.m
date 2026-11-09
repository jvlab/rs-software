function [opts_used,figh]=psg_umi_triplike_plot(r,opts)
% [opts_used,figh]=psg_umi_triplike_plot(r,opts) plots rank-choice probability data 
%
% r: results, typically from psg_umi_triplike_demo or psg_tentlike_demo
%  r.dirichlet: fitting of choice probability distribution
%  r.(opts.llr_field): the log likelihood data
% opts: options
%  llr_field: name of likelihood field, su if plotting data from psg_umi_triplike_demo, adt if data from psg_tentlike_demo
%  ipg_min: 1 if private data present, 2 if not
%  data_fullname: name of data file to appear in plot
%
% opts_used: options used
% figh: figure handle
%
% 12Mar23: script->function
% 19Mar23: simplify errorbar logic
% 04May23: allow for plotting conform 
% 24Jun23: add opts.sel_desc
%
% See also:  PSG_UMI_TRIPLIKE_DEMO, PSG_TENTLIKE_DEMO, PSG_UMI_TRIPLIKE_DEMO, PSG_UMI_TRIPLIKE_PLOTA.
%
if (nargin<=1)
    opts=[];
end
opts=filldefault(opts,'llr_field','su');
opts=filldefault(opts,'ipg_min',1);
opts=filldefault(opts,'data_fullname',[]);
opts=filldefault(opts,'sel_desc',[]);
switch opts.llr_field
    case 'su'
        ineq_set_name='triplet';
        nllr=2; %number of log likelihood ratios
        llr_names={'sym','umi'};
        llr_labels={'sym vs (sym or asym)','umi vs (umi or not umi)'};
        fig_name='sym and umi analysis';
    case 'adt'
        ineq_set_name='tent';
        nllr=1;
        llr_names={'adt'};
        llr_labels={'adt and sym/trans vs sym/trans'};
        fig_name='tent addtree analysis';
end
opts=filldefault(opts,'llr_minplot_per_ineq',-5);
opts=filldefault(opts,'llr_minplot_per_trial',-1);
opts_used=opts;
%
%recover some variables
%
data_fullname=opts.data_fullname;
nhfix=length(r.h_fixlist);
llr_field=opts.llr_field;
thr_types=r.(llr_field).thr_types;
nthr_types=length(thr_types);
%if nsurr is not supplied, assume that nconform=0
r=filldefault(r,'nsurr',length(r.(llr_field).llr_d2));
r=filldefault(r,'nconform',0);
nsurr=r.nsurr;
nconform=r.nconform;
%
llr_minplot_per_ineq=opts.llr_minplot_per_ineq; %triplet or tent
llr_minplot_per_trial=opts.llr_minplot_per_trial;
%
thr_symbs={'.','+','*'}; %symbol for each threshold type
thr_symbs_conform={'o','s','p'}; %symbol for each threshold type, for conform data
surr_linetypes={':','--'}; %symbols for each surrogate type after native
hfixed_colors=('rmbcg');
%
figh=figure;
set(gcf,'Position',[50 50 1200 800]);
set(gcf,'NumberTitle','off');
set(gcf,'Name',fig_name');
ncols=3; %dirichlet fits and nllr (sym, umi or just adt)
%
%plot dirichlet fit likelihoods
%
subplot(2,ncols,1)
hl=cell(0);
ht=[];
thr_vals=r.dirichlet.tallies(:,1);
llr_vals=r.dirichlet.ah(:,3);
hd=plot(thr_vals,llr_vals,'k');
hold on;
hl=[hl;hd];
ht=strvcat(ht,'h fit');
for ihfix=1:nhfix
    hcolor=hfixed_colors(1+mod(ihfix-1,length(hfixed_colors)));
    llr_vals=r.dirichlet.a(:,2,ihfix);
    hd=plot(thr_vals,llr_vals,hcolor);
    hl=[hl;hd];
    ht=strvcat(ht,sprintf('h=%6.4f',r.h_fixlist(ihfix)));
end
xlabel('min trials per triad for inclusion');
ylabel('log likelihood per trial');
set(gca,'XLim',[0 max(1,max(thr_vals))]);
set(gca,'YLim',[llr_minplot_per_trial,0.1]);
title('Dirichlet param likelihood ratios');
legend(hl,ht,'FontSize',7,'Location','NorthWest');
%
%plot dirichlet fit parameters
%
subplot(2,ncols,ncols+1)
hl=cell(0);
ht=[];
thr_vals=r.dirichlet.tallies(:,1);
hd=plot(thr_vals,r.dirichlet.ah(:,1),'k');
hold on;
hl=[hl;hd];
ht=strvcat(ht,'a, h fit');
hd=plot(thr_vals,r.dirichlet.ah(:,2),'k:');
hl=[hl;hd];
ht=strvcat(ht,'h, h fit');
for ihfix=1:nhfix
    hcolor=hfixed_colors(1+mod(ihfix-1,length(hfixed_colors)));
    hd=plot(thr_vals,r.dirichlet.a(:,1,ihfix),hcolor);
    hl=[hl;hd];
    ht=strvcat(ht,sprintf('a, h=%6.4f',r.h_fixlist(ihfix)));
    hd=plot(thr_vals,repmat(r.h_fixlist(ihfix),size(thr_vals,1),1),cat(2,hcolor,':'));
    hl=[hl;hd];
    ht=strvcat(ht,sprintf('h, h=%6.4f',r.h_fixlist(ihfix)));
end
xlabel('min trials per triad for inclusion');
ylabel('param value (a or h)');
set(gca,'XLim',[0 max(1,max(thr_vals))]);
set(gca,'YLim',[0 1.2]);
title('Dirichlet parameter values');
legend(hl,ht,'FontSize',7,'Location','NorthWest');
%
%plot likelihood ratios for sym and umi analysis
%
for illr=1:nllr
    llr_name=llr_names{illr};
    llr_label=llr_labels{illr};
    for ipg=opts.ipg_min:2
        switch ipg
        	case 1
                ipg_label='private';
            case 2
                ipg_label='global';
        end
        subplot(2,ncols,1+illr+ncols*(ipg-1));
        ruse=r.(llr_field).(ipg_label).(llr_name);
        ruse_fixed=r.(llr_field).(ipg_label).(cat(2,llr_name,'_hfixed'));
        thr_max=-Inf;
        hl=cell(0);
        ht=[];
        for ithr_type=1:nthr_types
            thr_vals=r.(llr_field).tallies{ithr_type}(:,1);
            nsets=r.(llr_field).tallies{ithr_type}(:,2);
            thr_max=max(thr_max,max(thr_vals));
            means=ruse{1,ithr_type}(:,1);
            means_per_set=means./nsets;
            means_per_set(~isfinite(means_per_set))=NaN;
            hd=plot(r.(llr_field).tallies{ithr_type}(:,1),means_per_set,cat(2,'k',thr_symbs{ithr_type}));
            hold on;
            set(hd,'tag','inlegend');
            hl=[hl;hd];
            ht=strvcat(ht,cat(2,'thr: ',thr_types{ithr_type}));
            hd=plot(r.(llr_field).tallies{ithr_type}(:,1),means_per_set,'k');
            if (ithr_type==1)
                set(hd,'tag','inlegend');
                hl=[hl;hd];
                ht=strvcat(ht,'h fit');
            end
            %conform
            for ic=1:nconform
                means=ruse{1,ithr_type}(:,nsurr+ic);
                means_per_set=means./nsets;
                means_per_set(~isfinite(means_per_set))=NaN;
                hd=plot(r.(llr_field).tallies{ithr_type}(:,1),means_per_set,cat(2,'k',thr_symbs_conform{ithr_type}));
                hold on;
                set(hd,'tag','inlegend');
                hl=[hl;hd];
                ht=strvcat(ht,cat(2,'thr: ',thr_types{ithr_type},' conf:',sprintf('%1.0f',ic)));
            end
            %plot mean and 1 s.d. of surrogates
            for isurr=2:nsurr %for each kind of surrogate (surrogate 1 is original data)
                linetype=surr_linetypes{mod(isurr,length(surr_linetypes))+1};
                means_surr=ruse{1,ithr_type}(:,isurr);
                vars_surr=ruse{2,ithr_type}(:,isurr);
                eb_means=means_surr./nsets;
                eb_means(~isfinite(eb_means))=NaN;
                eb_hi=(means_surr+sqrt(vars_surr(:)))./nsets;
                eb_lo=(means_surr-sqrt(vars_surr(:)))./nsets;
                hd=errorbar(r.(llr_field).tallies{ithr_type}(:,1),eb_means,eb_hi-eb_means,eb_means-eb_lo,cat(2,'k',linetype));
            end
            %
            for ihfix=1:nhfix
                hcolor=hfixed_colors(1+mod(ihfix-1,length(hfixed_colors)));
                means=ruse_fixed{1,ithr_type}(:,1,ihfix);
                means_per_set=means./nsets;
                means_per_set(~isfinite(means_per_set))=NaN;
                hd=plot(r.(llr_field).tallies{ithr_type}(:,1),means_per_set,cat(2,hcolor,thr_symbs{ithr_type}));
                hd=plot(r.(llr_field).tallies{ithr_type}(:,1),means_per_set,hcolor);
                if (ithr_type==1) %suffices to label just one threshold type
                    set(hd,'tag','inlegend');
                    hl=[hl;hd];
                    ht=strvcat(ht,sprintf('h=%6.4f',r.h_fixlist(ihfix)));
                end
                %conform
                for ic=1:nconform
                    means_fixed=ruse_fixed{1,ithr_type}(:,nsurr+ic,ihfix);
                    means_per_set=means./nsets;
                    means_per_set(~isfinite(means_per_set))=NaN;
                    hd=plot(r.(llr_field).tallies{ithr_type}(:,1),means_per_set,cat(2,hcolor,thr_symbs_conform{ithr_type}));
                    hold on;
                end
                %plot mean and 1 s.d. of surrogates
                for isurr=2:nsurr %for each kind of surrogate (surrogate 1 is original data)
                    linetype=surr_linetypes{mod(isurr,length(surr_linetypes))+1};
                    means_surr=ruse_fixed{1,ithr_type}(:,isurr,ihfix);
                    vars_surr=ruse_fixed{2,ithr_type}(:,isurr,ihfix);
                    eb_means=means_surr./nsets;
                    eb_means(~isfinite(eb_means))=NaN;
                    eb_std=sqrt(vars_surr(:))./nsets;
                    hd=errorbar(r.(llr_field).tallies{ithr_type}(:,1),eb_means,eb_std,cat(2,hcolor,linetype));
                end
            end
        end
        xlabel('min trials per triad for inclusion');
        ylabel(cat(2,'log likelihood ratio per ',ineq_set_name));
        set(gca,'XLim',[0 max(1,thr_max)]);
        set(gca,'YLim',[llr_minplot_per_ineq,0.3]);
        title(cat(2,llr_label,' param fits:',ipg_label));
        if (ipg==opts.ipg_min) & (illr==nllr)
            legend(hl,ht);
            %clean legends
            hc=get(gca,'Children');
            tags=cell(length(hc),1);
            for ich=1:length(hc)
                tags{ich}=get(hc(ich),'Tag');
            end
            hc_keep=find(contains(tags,'inlegend'));
            legend(hc(hc_keep),'FontSize',7,'Location','SouthWest');
        end
    end %ipg
end %illr
axes('Position',[0.01,0.04,0.01,0.01]); %for text
text(0,0,cat(2,data_fullname,' eb: 1 SD',' ',opts.sel_desc),'Interpreter','none','FontSize',8);
axis off;
