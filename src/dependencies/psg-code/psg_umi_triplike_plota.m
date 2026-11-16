function [opts_used,figh,s]=psg_umi_triplike_plota(r,opts)
% [opts_used,figh,s]=psg_umi_triplike_plota(r,opts) plots rank-choice probability data 
% in summary (asymptotic) form
%
% r: results, typically from psg_umi_triplike_demo or psg_tentlike_demo
%  r.dirichlet: fitting of choice probability distribution
%  r.(opts.llr_field): the log likelihood data
% opts: options
%  llr_field: name of likelihood field, su if plotting data from psg_umi_triplike_demo, adt if data from psg_tentlike_demo
%  data_fullname: name of data file to appear in plot
%  h_fixlist_ptr: pointer to value in h_fixlist used to estimate
%   derivative, should point to smallest nonzero value in h_fixlist; first value is zero so default is 2. 0: requested from user)
%  frac_keep_list: fraction of triplets to keep for summary table,
%   defaults to 2.^(-[0:5])=[1 .5 .25 .125 .0625 .03125]; will be sorted into descending order and a 1 will always be prepended
%  sel_desc: optional selection descriptor
% s: analysis summary structure
%
% opts_used: options used
% figh: figure handle
% in contrast to psg_umi_triplike_plot:
%  * does not plot dirichlet params
%  * only plots global data
%  * plots limiting behavior for h small
%   for sym: log of ratio of likelihoods for h=0 for actual data and surrogates
%   for umi: log of ratio of likelihood at smallest nonzero h - log(h) for actual data and surrogates
%
% 12Mar23: script->function
% 13Mar23: add plotting for fixed or fitted h, remove overhead for compatibility with psg_umi_triplike_plot
% 14Mar23: add computation and plotting of a priori llr
% 19Mar23: add summary tables of likelihood ratios, and opts.frac_keep_list, simplify errorbar logic
% 04Apr23: add s, for compatibility with automated processing
% 05Apr23: add ah_llr to s, add subfields for threshold type, change frac_keep_list, change logic on thresholds
% 04May23: add compatibility with conform surrogates
% 15Jun23: add display of sems for original data
% 24Jun23: add opts.sel_desc
% 28Sep26: add if_plot, default=1
%
% See also:  PSG_UMI_TRIPLIKE_DEMO, PST_TENTLIKE_DEMO, PSG_UMI_TRIPLIKE_PLOT, PSG_INEQ_LOGIC, PSG_INEQ_APPLY.
%
if (nargin<=1)
    opts=[];
end
opts=filldefault(opts,'llr_field','su');
opts=filldefault(opts,'data_fullname',[]);
opts=filldefault(opts,'h_fixlist_ptr',2);
opts=filldefault(opts,'frac_keep_list',2.^(-[0:10])); %fraction of triplets to keep for summary table
opts.frac_keep_list=sort(unique([1 opts.frac_keep_list(:)']),'descend');
opts=filldefault(opts,'sel_desc',[]);
opts=filldefault(opts,'if_plot',1);
s=cell(0);
switch opts.llr_field
    case 'su'
        fig_name='sym and umi analysis';
        ineq_set_name='triplet';
        llr_names={'sym','umi'};
        llr_labels={'sym vs (sym or asym)','umi vs (umi or not umi)'};
        llr_neednonzeroh=[0 1]; %h can be zero for sym but not for umi
        llr_descriptors={{'exclude_sym','none'},{'exclude_umi_trans','exclude_trans'}}; %numerator and denominator of what is excluded
        ncomps=3; 
    case 'adt'
        fig_name='tent addtree analysis';
        ineq_set_name='tent';
        llr_names={'adt'};
        llr_labels={'adt and sym/trans vs sym/trans'};
        llr_neednonzeroh=0; %0 h can be zero for adt
        llr_descriptors={{'exclude_addtree_trans','exclude_trans_tent'}}; %numerator and denominator of what is excluded
        ncomps=6;
end
nllr=length(llr_names); %number of log likelihood ratios
%
opts=filldefault(opts,'llr_minplot_per_ineq',-5);
opts=filldefault(opts,'llr_minplot_per_trial',-1);
if opts.h_fixlist_ptr==0
    disp('available nonzero values of h:')
    disp(r.h_fixlist(2:end));
    h_fixlist_ptr=1+getinp('pointer to value to use','d',[1 length(r.h_fixlist)-1],1);
else
    h_fixlist_ptr=opts.h_fixlist_ptr;
end
opts_used=opts;
%
%recover some variables
%
ipg_min=2;
data_fullname=opts.data_fullname;
nhfix=length(r.h_fixlist);
llr_field=opts.llr_field;
thr_types=r.(llr_field).thr_types;
nthr_types=length(thr_types);
%if nsurr is not supplied, assume that nconform=0
r=filldefault(r,'nsurr',length(r.(llr_field).llr_d2));
r=filldefault(r,'nconform',0);
nsurr=r.nsurr; %first surrogate is native
nconform=r.nconform;
%
llr_minplot_per_ineq=opts.llr_minplot_per_ineq; %triplet or tent
llr_minplot_per_trial=opts.llr_minplot_per_trial;
%
thr_symbs={'.','+','*'}; %symbol for each threshold type
thr_symbs_conform={'o','s','p'}; %symbol for each threshold type, for conform data
surr_linetypes={'-',':','--'}; %symbols for each surrogate type after native, changed 18Sep26 ('-' inserted)
surr_types=r.(llr_field).llr_d2;
hfixed_colors=('rmbcg');
%
figh=cell(1);
pchoice_label={'fixed h','fitted h'};
ipg_label='global';
for ipchoice=1:2 %1 for fixed h, 2 for fitted h
    if opts.if_plot
        figh{ipchoice}=figure;
        set(gcf,'Position',[50 50 1200 800]);
        set(gcf,'NumberTitle','off');
        set(gcf,'Name',cat(2,fig_name,' ',pchoice_label{ipchoice}));
    end
    ncols=2; %sym, umi or just adt
    %
    %
    %plot likelihood ratios
    %
    param_a=zeros(1,nllr); %dirichlet param
    param_h=zeros(1,nllr); %edge weight
    ah_llr=zeros(1,nllr); %log likelihood for dirichlet + edge weight fit
    disp(' ');
    disp(sprintf('summary using %s Dirichlet parameter fits, %s:',ipg_label,pchoice_label{ipchoice}));
    for illr=1:nllr
        llr_name=llr_names{illr};
        llr_label=llr_labels{illr};
        if (llr_neednonzeroh(illr)==0) |  ipchoice==1 %if nonzero h is needed, only plot fixed h (ipchoice==1)
            switch llr_neednonzeroh(illr)
                case 0
                    ihfix=1; %use h=0 from fixlist or fitted value
                    ll_offset=0;
                    ylabel_suffix='';
                    ylims=[-2 .3];
                    %assume we use value from fixed-h list
                    param_a(illr)=r.dirichlet.a(1,1,ihfix);
                    param_h(illr)=r.h_fixlist(ihfix);
                    ah_llr(illr)=r.dirichlet.a(1,2,ihfix);
                    switch ipchoice
                        case 1
                            vsuff='_hfixed';
                        case 2
                            vsuff='';
                            if r.dirichlet.ah(1,2)>=0 %replace by fitted values if fitted h>=0
                                param_a(illr)=r.dirichlet.ah(1,1);
                                param_h(illr)=r.dirichlet.ah(1,2);
                                ah_llr(illr)=r.dirichlet.ah(1,3);
                            end
                    end
                case 1
                    ihfix=h_fixlist_ptr; %use smallest nonzero value
                    ll_offset=log(r.h_fixlist(ihfix));
                    ylabel_suffix=' - log(h)';
                    ylims=[-2 2];
                    %
                    vsuff='_hfixed';
                    param_a(illr)=r.dirichlet.a(1,1,h_fixlist_ptr);
                    param_h(illr)=r.h_fixlist(h_fixlist_ptr);
                    ah_llr(illr)=r.dirichlet.a(1,2,h_fixlist_ptr);
            end
            %
            %display info about llrs and compute a priori values
            disp(sprintf(' %25s (%22s/%22s), params: a %6.4f h %6.4f',...
                llr_label,llr_descriptors{illr}{1},llr_descriptors{illr}{2},param_a(illr),param_h(illr)));
            partitions=cell(1,2);
            edge_counts=zeros(ncomps+1,2);
            apriori_nd=zeros(1,2);
            params=struct();
            params.a=param_a(illr);
            params.h=param_h(illr);
            for ind=1:2
                [partitions{1,ind},ou]=psg_ineq_logic(ncomps,llr_descriptors{illr}{ind});
                edge_counts(:,ind)=ou.edge_counts(:);
                apriori_nd(ind)=psg_ineq_apply(params,zeros(ncomps,2),{partitions{1,ind}});
                disp(sprintf('     non-excluded regions for %22s: orthants %4.0f of %4.0f, edges %4.0f of %4.0f',...
                    llr_descriptors{illr}{ind},...
                    2^ncomps-edge_counts(1,ind),2^ncomps,...
                    2^(ncomps-1)*ncomps-edge_counts(2,ind),2^(ncomps-1)*ncomps))                 
            end
            apriori_vals(illr)=log(apriori_nd(1)/apriori_nd(2));
            if llr_neednonzeroh(illr)==1
                apriori_vals(illr)=apriori_vals(illr)-log(params.h);
                loghtext='- log(h)';
            else
                loghtext='        ';
            end
            disp(sprintf('    a priori log likelihood %s: %7.4f',loghtext,apriori_vals(illr)));
            s{ipchoice}.(llr_name).params=params;
            s{ipchoice}.(llr_name).apriori_vals=apriori_vals(illr);
            s{ipchoice}.(llr_name).ah_llr=ah_llr(illr);
            %
            if opts.if_plot               
                subplot(1,ncols,illr);
            end
            ruse=r.(llr_field).(ipg_label).(cat(2,llr_name,vsuff));
            thr_max=-Inf;
            if opts.if_plot
                hl=cell(0);
                ht=[];
            end
            for ithr_type=1:nthr_types
                disp(sprintf('  %25s, with %8ss selected according to %4s number of trials for triads within the %s',...
                    llr_label,ineq_set_name,thr_types{ithr_type},ineq_set_name));
                thr_vals=r.(llr_field).tallies{ithr_type}(:,1);
                nsets=r.(llr_field).tallies{ithr_type}(:,2);
                thr_max=max(thr_max,max(thr_vals));
                %
                means=ruse{1,ithr_type}(:,:,ihfix); %d1: threshold level, d2: surrogate tpye
                means_per_set=means./repmat(nsets,1,nsurr+nconform);
                means_per_set(~isfinite(means_per_set))=NaN;
                means_per_set_adj=means_per_set-ll_offset;
                vars=ruse{2,ithr_type}(:,:,ihfix); %d1: threshold level, d2: surrogate type
                eb_stds=sqrt(vars)./repmat(nsets,1,nsurr+nconform);
                %
                header=sprintf(' frac req frac kept %8ss kept thr(%s)  a priori    %s %10s',ineq_set_name,thr_types{ithr_type});
                for isurr=1:nsurr+nconform
                    header=cat(2,header,sprintf(' %21s          ',surr_types{isurr}));
                end
                disp(header);
%                 disp(sprintf(' frac req frac kept %8ss kept thr(%s)  a priori  %s %10s %31s',ineq_set_name,thr_types{ithr_type},...
%                     surr_types{1},surr_types{2},surr_types{3}));
                tally_table=r.(llr_field).tallies{ithr_type};
                ifok=1;
                ifk_ptr=1;
                %
                s{ipchoice}.(llr_name).thr_type{ithr_type}.tally_table=tally_table;
                s{ipchoice}.(llr_name).thr_type{ithr_type}.means_per_set_adj=means_per_set_adj;
                s{ipchoice}.(llr_name).thr_type{ithr_type}.eb_stds=eb_stds;
                s{ipchoice}.(llr_name).thr_type{ithr_type}.frac_keep_list=opts.frac_keep_list(:); %threshold values
                %
                while (ifok==1) & ifk_ptr<=length(opts.frac_keep_list)
                    fk=opts.frac_keep_list(ifk_ptr);
                    need_keep=tally_table(1,2); %total tents/triplets available
                    thr_ptr_use=min(find(tally_table(:,2)<=need_keep*fk)); %changed 05Apr23
                    if ~isempty(thr_ptr_use)
                        fmt_string=' %7.5f  %7.5f     %8.0f    %6.2f:    %7.4f';
                        vals=[fk,tally_table(thr_ptr_use,2)/tally_table(1,2),tally_table(thr_ptr_use,2)];
                        vals=[vals thr_vals(thr_ptr_use),apriori_vals(illr)];
                        for isurr=1:nsurr+nconform
                            fmt_string=cat(2,fmt_string,'    %7.4f [%7.4f to %7.4f]');
                            vals=[vals means_per_set_adj(thr_ptr_use,isurr)+[0 -1 1]*eb_stds(thr_ptr_use,isurr)];                           
                        end
                        disp(sprintf(fmt_string,vals));
%                        disp(sprintf(' %7.5f  %7.5f     %8.0f    %6.2f:    %7.4f    %7.4f    %7.4f [%7.4f to %7.4f]    %7.4f [%7.4f to %7.4f]',...
%                            fk,tally_table(thr_ptr_use,2)/tally_table(1,2),tally_table(thr_ptr_use,2),...
%                            thr_vals(thr_ptr_use),...
%                            apriori_vals(illr),...
%                            means_per_set_adj(thr_ptr_use,1),...
%                            means_per_set_adj(thr_ptr_use,2)+[0 -1 1]*eb_stds(thr_ptr_use,2),...
%                            means_per_set_adj(thr_ptr_use,3)+[0 -1 1]*eb_stds(thr_ptr_use,3)...
%                            ));
                        s{ipchoice}.(llr_name).thr_type{ithr_type}.thr_ptr_use(ifk_ptr)=thr_ptr_use; %pointers into means_per_set_adj
                        ifk_ptr=ifk_ptr+1;
                    else %did last threshold pointer
                        ifok=0;
                    end 
                    if (thr_ptr_use==size(tally_table,1)) %got to end of tally table
                        ifok=0;
                    end
                end
                %
                if opts.if_plot
                    hcolor='k';
                    hds=plot(tally_table(:,1),means_per_set_adj(:,1),cat(2,hcolor,thr_symbs{ithr_type}));
                    hold on;
                    hd=plot(tally_table(:,1),means_per_set_adj(:,1),hcolor);
                    set(hds,'tag','inlegend');
                    hl=[hl;hds];
                    ht=strvcat(ht,sprintf('h=%6.4f thr: %s',param_h(illr),thr_types{ithr_type}));
                    %conform
                    for ic=1:nconform
                        if all(eb_stds(:,nsurr+ic)==0)
                            hd=plot(tally_table(:,1),means_per_set_adj(:,nsurr+ic),cat(2,hcolor,thr_symbs_conform{ithr_type}));
                        else
                            hd=errorbar(tally_table(:,1),means_per_set_adj(:,nsurr+ic),eb_stds(:,nsurr+ic),cat(2,hcolor,thr_symbs_conform{ithr_type}));
                        end
                        hold on;
                        set(hd,'tag','inlegend');
                        hl=[hl;hd];
                        ht=strvcat(ht,sprintf('h=%6.4f thr: %s, conf: %1.0f',param_h(illr),thr_types{ithr_type},ic));
                    end
                    %plot mean and 1 s.d. of surrogates
                    for isurr=1:nsurr %for each kind of surrogate (surrogate 1 is original data)
                        linetype=surr_linetypes{mod(isurr-1,length(surr_linetypes))+1}; %changed 18Sep26 (-1 inserted)
                        if (isurr==1) & all(eb_stds(:,isurr)==0)
                            hd=plot(tally_table(:,1),means_per_set_adj(:,isurr),cat(2,hcolor,linetype));
                        else
                            hd=errorbar(tally_table(:,1),means_per_set_adj(:,isurr),eb_stds(:,isurr),cat(2,hcolor,linetype));
                        end
                        if (ithr_type==1)
                            set(hd,'tag','inlegend');
                            hl=[hl;hd];
                            ht=strvcat(ht,sprintf('surrogate: %s',surr_types{isurr}));
                        end
                    end
                end %if_plot
            end %ithr_type
            if opts.if_plot
                ha=plot([0 max(1,thr_max)],repmat(apriori_vals(illr),[1 2]),'c');
                set(ha,'tag','inlegend');
                hl=[hl;ha];
                ht=strvcat(ht,'a priori');
                xlabel('min trials per triad for inclusion');
                ylabel(cat(2,'log likelihood ratio per ',ineq_set_name,ylabel_suffix,'  ',...
                    sprintf( 'a=%5.3f h=%5.3f dirichlet llr=%5.3f',param_a(illr),param_h(illr),ah_llr(illr))));
                set(gca,'XLim',[0 max(1,thr_max)]);
                set(gca,'YLim',ylims);
                title(cat(2,llr_label,' param fits:',ipg_label));
                legend(hl,ht,'Interpreter','none');
                %clean legends
                hc=get(gca,'Children');
                tags=cell(length(hc),1);
                for ich=1:length(hc)
                    tags{ich}=get(hc(ich),'Tag');
                end
                hc_keep=find(contains(tags,'inlegend'));
                legend(hc(hc_keep),'FontSize',7,'Location','SouthWest','Interpreter','none');
            end
        end %deriv and ipchoice test
        disp(' ');
    end %illr
    if opts.if_plot
        axes('Position',[0.01,0.04,0.01,0.01]); %for text
        text(0,0,cat(2,data_fullname,' eb: 1 SD, ',pchoice_label{ipchoice},' ',opts.sel_desc),'Interpreter','none','FontSize',8);
        axis off;
    end
end %ipchoice
return
end

