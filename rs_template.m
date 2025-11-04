function [data_out,aux_out]=rs_template(data_in,aux)
% [data_out,aux_out]=rs_template(data_in,aux) is a template for rs modules
% that accept one or more input datasets, process it, and produce one or more output datasets
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
