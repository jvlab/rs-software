% rs_disp_coordsets_demo3 demonstrate display of datasets with several customizations
%
% options illustrated:
%  generation of datasets "from scratch"
%  options for interpreter
%  filled symvbols and symbols with contrasting interiors
%  alpha-blending
%
%  See also:  RS_DISP_COORDSETS, RS_DISP_COORDSETS_DEMO, , RS_DISP_COORDSETS_DEMO2, ZPAD, PSG_MAKE_SETSTRUCT.
%
if ~exist('dim_list') dim_list=[2 3]; end
if ~exist('nsets') nsets=4; end
if ~exist('nstims') nstims=10; end
if ~exist('colors') colors={'r',"#009F0F",'blue',[.7 .3 .8],[.2 .3 0],'c'}; end  %intentionally of length 6 in case nsets>4
if ~exist('markers') markers={'s','h','>','o'}; end 
if ~exist('markersizes') markersizes=[6 8 10 12 14]; end %intentionally of length 5 in case nsets>4
%options not yet implemented
if ~exist('colors_fill') colors_fill={'k',"#009F0F",'blue',[.2 .9 .1]}; end
if ~exist('markersize') markersize=12; end %non-default marker size
if ~exist('alphaval') alphaval=0.4; end %non default alpha value
if ~exist('fill_list') fill_list=[1 0 0 1]; end %which colors are filled in

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
aux_out=cell(nrows,ncols,length(dim_list));
for ip=1:length(dim_list)
    k=dim_list(ip);
    hfig=figure;
    set(gcf,'Position',[100 100 1200 700]);
    set(gcf,'NumberTitle','off');
    set(gcf,'Name',sprintf('dim %1.0f',k));
    hax=cell(nrows,ncols);
    for iplot=1:3
        irow=mod(iplot-1,ncols)+1;
        icol=ceil(iplot/ncols);
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
        switch mod(iplot,3)
            case 0
            case 1
                opts_disp.connect_data_method='chain';
                opts_disp.connect_data_linestyles={':','--'};
            case 2
                opts_disp.connect_sets_method='chain';
        end
        %
        aux_out{irow,icol,ip}=rs_disp_coordsets(data_in,setfield(struct(),'opts_disp',opts_disp));
    end
end
