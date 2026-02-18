function [data_out,aux_out]=rs_visualze_coordsets(data_in,aux)
% [data_out,aux_out]=rs_visualize_coordsets(data_in,aux) is a visualization tool for
% one or more datasets
%
% input data are plotted together
% This needs to be accompanied by a module that specifies a transofrmation (based on datasets),
% and a module that applies a transformation
%
%       The transformation is  [output]=ts.scaling*[input]*ts.orthog+ts.translation
%
% see also function coords_new=psg_geomodels_apply(model_class,coords,transform)
% coords_new=psg_geomodels_apply(model_class,coords,transform) applies any of several
%   transform.b=ts.scaling, transform.T=ts.orthog, transform.c=ts.translation
%      and projective parameters p (see psg_pwaffine_apply, psg_pwprojective_apply)
%
%
%
% aux give the following:
%  optional handle to figure
%  optional handle to subplots
% select a model dimension to plot (k)
%  optionally rotate:  to PCA, w.r.t. 0, or the centroid, do this for each dataset or globally
%  optionally center each dataset:  to the centroid, to a specific stimulus,
%    or to a value and this for each dataset or globally
%  Now select how many dimensions are plotted together: 2,3, or possibly 4
%  Select how these subsets are chosen:  each subset is a new subplot,
%  modes as in psg*
%
%  Choose how labels are created
%  Choose how axes are labeled (pc, or dim)
%  Choose marker, marker color,marker size for each set
%  Choose line color, width, style for each set if any connections within set
%  Choose how to connect between sets (modes as in psg_*)
%  Legend
%  Label on figure
%  
% data_out shows the coordinates actually plotted, both at the level of
% after rotation and centering, and, for each subplot
% aux_out gives the transformations and handles to the plots and subplots
%
% data_in.ds{k},sas{k},sets{k}: the structures of coordinates (ds) and metadata (sas,sets)
%   These are typically created by rs_align_coordsets, but could also be directly from 
%   rs_get_coordsets or rs_read_coorddata if stimuli are identical across
%   datasets, as listed in data_in.sas{k}.typenames
%
% aux:
%  a structure with substructures such as opts_knit, opts_pca, opts_read, opts_write
%  aux.opts_knit.if_log: 1 to log progress
%  *may also have some bare options
% 
% data_out.ds{k},sas{k},sets{k}:  coordinates after processing
% aux_out: auxiliary outputs and parameter values used
%    opts_knit: overall options used
%    *may have additional fields, typically
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%
if (nargin<=1)
    aux=struct;
end
%set up sub-structure options
aux=filldefault(aux,'opts_temp',struct); %options for this module (psg_template)
aux.opts_knit=filldefault(aux.opts_knit,'if_log',1);
%
aux=filldefault(aux,'opts_othr',struct); %options for other modules called
aux.opts_othr=filldefault(aux.opts_othr,'if_log',0);
aux.opts_othr=filldefault(aux.opts_othr,'nd_max',Inf);
%
aux=filldefault(aux,'opts_oth2',struct);
%fill in any other options with default values, naming this module
aux=rs_aux_customize(aux,'rs_template');
%
data_out=struct;
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
%validate input parameters for consistency, etc.
%
if (condition)
    wmsg=sprintf('xxx');
    warning(wmsg);
    aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    aux_out.warn_bad=aux_out.warn_bad+1;
end
if aux_out.warn_bad==0
%process
    data_out.ds{*}=;
    data_out.sas{*}=sas_knitted;
    data_out.sets{*}=sets_knitted;
    %
    aux_out.opts_knit=aux.opts_temp; %the main options for this module
    aux_out.opts_othr=opts_othr_used; %options for other routines called
    aux_out.opts_oth2=opts_oth2_used;
else
    disp('cannot proceed');
end
return
end
