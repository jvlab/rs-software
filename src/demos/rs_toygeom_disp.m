%rs_toygeom_disp:  display the results of rs_toygeom_demo
%
% sims: a structure containing simulations, geometric model fits, and key parameters
% 
%   See also: RS_TOYGEOM_DEMO, RS_DISP_GEOFIT.
%
if ~exist('opts_dgeo') opts_dgeo=struct; end
aux_dgeo=struct;
aux_dgeo.opts_dgeo=opts_dgeo;
if ~exist('transforms_fit_show') transforms_fit_show=sims.transform_names; end
if ~exist('paradigms_fit_show') paradigms_fit_show=sims.paradigms_all; end
if ~exist('subjs_fit_show') subjs_fit_show=[1:sims.nsubjs]; end
%
for it=1:length(sims.transform_names)
    transform_name=sims.transform_names{it};
    for ip=1:length(sims.paradigms_all)
        paradigm_name=sims.paradigms_all{ip};
        for is=1:sims.nsubjs
            if ~isempty(strmatch(transform_name,transforms_fit_show,'exact'))  & ~isempty(strmatch(paradigm_name,paradigms_fit_show,'exact')) & ismember(is,subjs_fit_show)
                aux_dgeo_out=rs_disp_geofit(sims.gfs{it,ip}{is}.gf,aux_dgeo);
                fig_handles=aux_dgeo_out.opts_dgeo.fig_handles;
                fig_names=aux_dgeo_out.opts_dgeo.fig_names;
                for ifig=1:length(fig_handles)
                    figure(fig_handles{ifig});
                    set(gcf,'Name',cat(2,fig_names{ifig},sprintf(' subj %1.0f',is),' ',transform_name,' ',paradigm_name));
                    if exist('scenario_name')
                        axes('Position',[0.80,0.05,0.01,0.01]); %for text
                        text(0,0,scenario_name,'Interpreter','none');
                        axis off;
                    end
                    axes('Position',[0.50,0.05,0.01,0.01]); %for text
                    text(0,0,fig_names{ifig},'Interpreter','none');
                    axis off;
                    axes('Position',[0.50,0.03,0.01,0.01]); %for text
                    text(0,0,sprintf('transform: %s, paradigm %s',transform_name,paradigm_name),'Interpreter','none');
                    axis off;
                    axes('Position',[0.50,0.01,0.01,0.01]);
                    text(0,0,sprintf('subject %2.0f: transform noise %4.2f additive noise %4.2f',is,sims.noise_transform(is),sims.noise_add(is)));
                    axis off;
               end 
            end %select
        end %subject
    end %paradigm name
end %transform
