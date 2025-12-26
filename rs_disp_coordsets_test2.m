% rs_disp_coordsets_test2: demonstrate display of datasets with several customizations
%
% options illustrated:
%  generation of datasets "from scratch"
%  filled symbols and symbols with contrasting interiors
%  alpha-blending
%  options for interpreter
%
%  See also:  RS_DISP_COORDSETS, RS_DISP_COORDSETS_DEMO, RS_DISP_COORDSETS_TEST1, RS_DISP_COORDSETS_TEST3, ZPAD, PSG_MAKE_SETSTRUCT
%    RS_SAVE_FIGS.
%
%testing is in several sets, each of which contains (by rs_auto_test) one test, so ntests=1 but testset may be > 1
rs_module='disp_coordsets';
testset=2; 
ntests=1;
%
if ~exist('if_save_and_close')
    if_save_and_close=0;
end
if if_save_and_close==0
    if_save_and_close=getinp('1 to save and close all figures','d',[0 1]);
end
if if_save_and_close
    close all;
end
%
if ~exist('dim_list') dim_list=[2 3]; end
if ~exist('nsets') nsets=4; end
if ~exist('nstims') nstims=10; end
if ~exist('colors') colors={'r',"#009F0F",'blue',[.7 .3 .8],[.2 .3 0],'c'}; end  %intentionally of length 6 in case nsets>4
if ~exist('markers') markers={'s','h','>','o'}; end 
if ~exist('markersizes') markersizes=[6 8 10 12 14]; end %intentionally of length 5 in case nsets>4
if ~exist('colors_fill') colors_fill={'k',"#009F0F",'blue',[.2 .9 .1]}; end
if ~exist('fill_list') fill_list=[1 0 0 1]; end %which colors are filled in
if ~exist('alphaval') alphaval=[0.3 0.4 0.7]; end %non default alpha values
%
% data are Gaussian clouds
%
rng('default');
coords=randn(nstims,max(dim_list),nsets); %make Gaussian clouds
coords=coords+repmat(randn(1,max(dim_list),nsets),[nstims 1 1]); %add offsets
%
data=struct;
data_in.ds=cell(1,nsets);
data_in.sas=cell(1,nsets);
data_in.sets=cell(1,nsets);
typenames=cell(nstims,1);
for istim=1:nstims
    typenames{istim}=cat(2,'stim ',zpad(istim,3));
end
typenames{1}='stim_1'; %for demonstrating Interpreter
typenames{end}='stim \omega';
type_string='data';
label_long='[unknown]';
pipeline=[];
for iset=1:nsets
    for ip=1:length(dim_list)
        k=dim_list(ip);
        data_in.ds{iset}{1,k}=coords(:,[1:k],iset);       
    end
    data_in.sas{iset}.typenames=typenames;
    data_in.sas{iset}.nstims=nstims;
    data_in.sets{iset}=psg_make_setstruct(type_string,dim_list,label_long,nstims,pipeline);
end
[check,opts_check_used]=rs_check_coordsets(data_in);
%
nrows=2;
ncols=3;
aux_disp=struct;
aux_outs=cell(1);
aux_outs{1}=cell(nrows,ncols,length(dim_list));
for ip=1:length(dim_list)
    k=dim_list(ip);
    hfig=figure;
    set(gcf,'Position',[100 100 1200 700]);
    set(gcf,'NumberTitle','off');
    set(gcf,'Name',sprintf('dim %1.0f',k));
    hax=cell(nrows,ncols);
    for iplot=1:nrows*ncols
        icol=mod(iplot-1,ncols)+1;
        irow=ceil(iplot/ncols);
        hax=subplot(nrows,ncols,iplot);
        %
        opts_disp=struct;
        opts_disp.dim_select=k;
        opts_disp.fig_handle=hfig;
        opts_disp.axis_handles{1}=hax;
        %
        opts_disp.data_label_setsel_method='list';
        opts_disp.data_label_setsel_list=[1 nsets];
        opts_disp.data_label_method='list';
        opts_disp.data_label_list=[1 round(nstims/2) nstims];
        %
        opts_disp.set_colors=colors;
        opts_disp.set_markers=markers;
        opts_disp.set_markersizes=markersizes;
        opts_disp.set_filled=fill_list;
        opts_disp.set_colors_filled=colors_fill;
        %
        opts_disp.callout_amount=0.75;
        opts_disp.data_label_font_size=10;
        opts_disp.legend_font_size=12;
        %
        opts_disp.set_labels={'set 1','set 2_a','set 2\alpha','set 3'};
        if (irow==1 & icol==3)
            opts_disp.legend_interpreter='none';
            opts_disp.data_label_interpreter='none';
        end
        %
        if irow==2
            opts_disp.set_alphas=0.5; %alpha blending
        end
        switch icol
            case 1
            case 2
                opts_disp.connect_data_method='chain';
                opts_disp.connect_data_linestyles={':','--'};
            case 3
                opts_disp.connect_sets_method='chain';
        end
        %
        disp(sprintf(' row %1.0f col %1.0f, dim %1.0f',irow,icol,k));
        aux_outs{1}{irow,icol,ip}=rs_disp_coordsets(data_in,setfield(struct(),'opts_disp',opts_disp));
    end
end
if if_save_and_close
    rs_save_figs(sprintf('./tests/rs_disp_coordsets_testset%1.0f',testset),'all',setfield(struct(),'if_log',1));
    close all;
end
%
fns{1}=sprintf('rs_%s_testset%1.0f',rs_module,testset);
s=struct;
s.aux_out=aux_outs;
rs_save_mat(cat(2,'tests',filesep,fns{1}),s);
%
disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
%
disp(sprintf('testing rs_%s: %s',rs_module,sprintf('testset %1.0f',testset)));
opts_compare=struct;
[ifdif{1},opts_used{1}]=rs_benchmark_compare(fns{1},opts_compare);


