%rs_plot_style_test: test a utility plotting routine 
% 
%   See also:  RS_PLOT_STYLE
% 
% 
if ~exist('opts') opts=struct; end
%
if ~exist('dim_list') dim_list=[2 3]; end
if ~exist('colors') colors={'r',"#009F0F",'blue',[.7 .3 .8]}; end
if ~exist('marker') marker='s'; end %non-default marker
if ~exist('markersize') markersize=12; end %non-default marker size
if ~exist('linewidth') linewidth=3; end  %non-default line width
if ~exist('linestyle') linestyle=':'; end %non-default line style
if ~exist('alphaval') alphaval=0.4; end %non default alpha value
if ~exist('fill_list') fill_list=[1 0 0 1]; end %which colors are filled in
%
if ~exist('npts') npts=20; end
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
                titles{ir,ic}=cat(2,'std marker and line',titles{ir,ic});
            case 2
                styles{ir,ic}.marker='.';
                titles{ir,ic}=cat(2,'std marker, no line',titles{ir,ic});
            case 3
                styles{ir,ic}.marker=marker;
                styles{ir,ic}.markersize=markersize;
                titles{ir,ic}=cat(2,'cust marker, no line',titles{ir,ic});
            case 4
                styles{ir,ic}.marker='none';
                styles{ir,ic}.linewidth=linewidth;
                styles{ir,ic}.linestyle=linestyle;
                titles{ir,ic}=cat(2,'cust line',titles{ir,ic});
            case 5
                styles{ir,ic}.marker=marker;
                styles{ir,ic}.markersize=markersize;
                styles{ir,ic}.linewidth=linewidth;
                styles{ir,ic}.linestyle=linestyle;
                titles{ir,ic}=cat(2,'cust marker and line',titles{ir,ic});
        end
    end
end
for id=1:length(dim_list)
    nds=dim_list(id);
    tstring=sprintf('dim %2.0f: marker %s markersize %2.0f linestyle %s linewidth %2.0f alpha %4.2f',...
        nds,marker,markersize,linestyle,linewidth,alphaval);
    figure;
    set(gcf,'Position',[50 100 1200 800]);
    set(gcf,'NumberTitle','off');
    set(gcf,'Name',tstring);
    %
    for ir=1:nrows
        for ic=1:ncols
            subplot(nrows,ncols,ic+ncols*(ir-1));
            disp(' ');
            disp(cat(2,tstring,' ',titles{ir,ic}));
            hlegend=[];
            for icolor=1:ncolors
                styles{ir,ic}.filled=fill_list(icolor);
                [handles{ir,ic,icolor,id},plotstyles_used{ir,ic,icolor,id},opts_used{ir,ic,icolor,id}]=...
                     rs_plot_style(coords(:,1:nds,icolor),setfield(styles{ir,ic},'color',colors{icolor}),opts);
                if ~isempty(handles{ir,ic,icolor,id}.legend)
                    hlegend(icolor)=handles{ir,ic,icolor,id}.legend;
                else
                    if (icolor==1)
                        rs_warning('No legend handle returned',0);
                    end
                end
                if (~isempty(opts_used{ir,ic,icolor,id}.msgs) & icolor==1)
                    rs_warning(opts_used{ir,ic,icolor,id}.msgs,0);
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
