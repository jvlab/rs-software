%rs_plot_style_test: test a utility plotting routine 
% 
%   See also:  RS_PLOT_STYLE
%
%testing is in several sets, each of which contains (by rs_auto_test) one test, so ntests=1 but testset may be > 1
rs_module='plot_style';
testset=1; 
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
aux_outs=cell(1); %no outputs in this module
%
opts=struct;
%
dim_list=[2 3];
colors={'r',"#009F0F",'blue',[.7 .3 .8]};
colors_fill={'k',"#009F0F",'blue',[.2 .9 .1]};
marker='s'; %non-default marker
markersize=12; %non-default marker size
linewidth=3;  %non-default line width
linestyle=':'; %non-default line style
alphaval=0.4; %non default alpha value
fill_list=[1 0 0 1]; %which colors are filled in
%
npts=20;
ncolors=length(colors);
%
% data are Gaussian clouds
%
rng('default');
coords=randn(npts,max(dim_list),ncolors); %make Gaussian clouds
coords=coords+repmat(randn(1,max(dim_list),ncolors),[npts 1 1]); %add offsets
styles=cell(2,5); %rows: alpha 1 and non-default; cols: dot marker and std line, std marker and no line, custom marker and no line, no marker and custom line, custom marker and custom line
titles=cell(2,5);
nrows=size(styles,1);
ncols=size(styles,2);
%
handles=cell(nrows,ncols,ncolors,length(dim_list));
plotstyles_used=cell(nrows,ncols,ncolors,length(dim_list));
opts_used=cell(nrows,ncols,ncolors,length(dim_list));
%
for ir=1:nrows   
    for ic=1:ncols
        styles{ir,ic}=struct;
        titles{ir,ic}='';
        if ir==2
            styles{ir,ic}.alpha=alphaval;
            titles{ir,ic}=', alpha';
        end
        switch ic
            case 1
                styles{ir,ic}.marker='.';
                styles{ir,ic}.linestyle='-';
                titles{ir,ic}=cat(2,'std  marker, std  line',titles{ir,ic});
            case 2
                styles{ir,ic}.marker='.';
                titles{ir,ic}=cat(2,'std  marker, no   line',titles{ir,ic});
            case 3
                styles{ir,ic}.marker=marker;
                styles{ir,ic}.markersize=markersize;
                styles{ir,ic}.linewidth=linewidth;
                titles{ir,ic}=cat(2,'cust marker, no   line',titles{ir,ic});
            case 4
                styles{ir,ic}.marker='none';
                styles{ir,ic}.linewidth=linewidth;
                styles{ir,ic}.linestyle=linestyle;
                titles{ir,ic}=cat(2,'no   marker, cust line',titles{ir,ic});
            case 5
                styles{ir,ic}.marker=marker;
                styles{ir,ic}.markersize=markersize;
                styles{ir,ic}.linewidth=linewidth;
                styles{ir,ic}.linestyle=linestyle;
                titles{ir,ic}=cat(2,'cust marker, cust line',titles{ir,ic});
        end
    end
end
param_string=sprintf('marker %s markersize %2.0f linestyle %s linewidth %2.0f alpha %4.2f',...
    marker,markersize,linestyle,linewidth,alphaval);
for id=1:length(dim_list)
    nds=dim_list(id);
    tstring=sprintf('dim %2.0f: %s',nds,param_string);
    disp(' ');
    disp(tstring)
    figure;
    set(gcf,'Position',[50 100 1200 800]);
    set(gcf,'NumberTitle','off');
    set(gcf,'Name',tstring);
    %
    for ir=1:nrows
        for ic=1:ncols
            subplot(nrows,ncols,ic+ncols*(ir-1));
            disp(titles{ir,ic});
            hlegend=[];
            for icolor=1:ncolors
                styles{ir,ic}.filled=fill_list(icolor);
                [handles{ir,ic,icolor,id},plotstyles_used{ir,ic,icolor,id},opts_used{ir,ic,icolor,id}]=...
                     rs_plot_style(coords(:,1:nds,icolor),...
                     setfield(setfield(styles{ir,ic},'color',colors{icolor}),'color_fill',colors_fill{icolor}),...
                     opts);
                if ~isempty(handles{ir,ic,icolor,id}.legend)
                    hlegend(icolor)=handles{ir,ic,icolor,id}.legend;
                else
                    if (icolor==1)
                        rs_warning('No legend handle returned',0);
                    end
                end
                if ~isempty(opts_used{ir,ic,icolor,id}.msgs)
                    for k=1:size(opts_used{ir,ic,icolor,id}.msgs,1)
                        rs_warning(cat(2,sprintf(' color combination %2.0f: ',icolor),opts_used{ir,ic,icolor,id}.msgs(k,:),0));
                    end
                end
            end
            axis equal
            set(gca,'XLim',[-3 3]);
            set(gca,'YLim',[-3 3]);
            if (nds==3)
                set(gca,'ZLim',[-3 3]);
                axis vis3d
                box on;
                grid on;
            end
            title(titles{ir,ic});
            if ~isempty(hlegend)
                legend(hlegend,'Location','South');
            end
        end %ic
    end %ir
    axes('Position',[0.01,0.02,0.01,0.01]); %for text
    text(0,0,tstring,'Interpreter','none');
    axis off;
end %id
%
if if_save_and_close
    rs_save_figs(sprintf('./tests/rs_disp_coordsets_testset%1.0f',testset),'all',setfield(struct(),'if_log',1));
else
    getinp('1 when ready to close and compare','d',[1 1],1);
end
close all;
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
