function [data_out,aux_out]=rs_import_coordsets(coords,aux)
% [data_out,aux_out]=rs_import_coordsets(data_in,aux) imports a set of coordinates
% into a data structure for use by the rs package
%
% coords: a cell array of coordinates
%   coords{1,id} should be either empty, or an array of size [nstims id],
%
% aux:
%  aux.opts_import:
%  aux.opts_check.if_warn: defaults to 1, set to 0 to turn off warnings
%  aux.opts_check.if_warn_traceback: set to 1 to give full traceback of warnings, defaults to value in overall section of rs_aux_defaults, set by rs_aux_customize.
% 
% data_out.ds{1},sas{1},sets{1}:  coordinates after processing
% aux_out: auxiliary outputs and parameter values used, and also
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS.
%
if (nargin<=1)
    aux=struct;
end
%set up sub-structure options
aux=filldefault(aux,'opts_import',struct); %options for this module (psg_template)
%
aux=filldefault(aux,'opts_check',struct); %options for this module (psg_template)
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
aux=rs_aux_customize(aux,'rs_import');
%
data_out=struct;
aux_out=struct;
aux_out.opts_import=aux.opts_import;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
ds=coords;
nstims=0;
dimlist=[];
for k=1:length(coords)
    if ~isempty(coords{k})
        if nstims==0
            nstims=size(coords{k},1);
        end
        dimlist=[dimlist,size(coords{k},2)];
    end
end
sas=struct;
%
sets=struct;
sets.nstims=nstims;
sets.pipeline=[];
%
data_out=struct;
data_out.ds{1}=ds;
data_out.sas{1}=sas;
data_out.sets{1}=sets;
%
[check,opts_used]=rs_check_coordsets(data_out,aux.opts_check);
aux_out.warnings=check.warnings;
aux_out.warn_bad=check.warn_bad;
%
aux_out.opts_import=aux.opts_import;
%
if aux_out.warn_bad>0
    disp('cannot proceed');
    data_out=[];
end
return
end
