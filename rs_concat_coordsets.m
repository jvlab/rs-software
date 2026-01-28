function [data_out,aux_out]=rs_concat_coordsets(data_in1,data_in2,aux)
% [data_out,aux_out]=rs_concat_coordsets(data_in1,data_in2,aux)
% concatenates two dataset structures and checks concatenated dataset structure for consistency
%
% data_in[1|2].ds{k},sas{k},sets{k}: two sets of structures of coordinates (ds) and metadata (sas,sets)
%   These are typically created by rs_align_coordsets, but could also be directly from 
%   rs_get_coordsets or rs_read_coorddata or rs_import_coordsets if stimuli are identical across
%   datasets, as listed in data_in[1|2].sas{k}.typenames
%
% aux:
%  a structure with substructures such as opts_temp, opts_othr,
%  aux.opts_check.if_warn: set to 1 (default) to show warnings when datasets are checked for consistency
% 
% data_out.ds{k},sas{k},sets{k}:  coordinates after processing
% aux_out: auxiliary outputs and parameter values used
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS.
%
if (nargin<=2)
    aux=struct;
end
%set up sub-structure options
%
aux=filldefault(aux,'opts_check',struct); %options for other modules called
aux.opts_check=filldefault(aux.opts_check,'if_warn',1);
%
data_out=struct;
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
fns_concat={'ds','sas','sets'}; %fields to concatenate
%
ns=zeros(2,length(fns_concat)); %check that fields to concatenate have same length
for ifn=1:length(fns_concat)
    fn=fns_concat{ifn};
    ns(1,ifn)=length(data_in1.(fn));
    ns(2,ifn)=length(data_in2.(fn));
end
if any(min(ns,[],2)~=max(ns,[],2))
    wmsg='input structures have inconsistent lengths';
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_check.if_warn));
end
%
if aux_out.warn_bad==0
    n1=ns(1,1);
    n2=ns(2,1);
    for ifn=1:length(fns_concat)
        fn=fns_concat{ifn};
        data_out.(fn)=cell(1,n1+n2);
        for k=1:n1
            data_out.(fn){k}=data_in1.(fn){k};            
        end
        for k=1:n2
            data_out.(fn){n1+k}=data_in2.(fn){k};
        end
    end
    [check,opts_used]=rs_check_coordsets(data_out,aux.opts_check);
    aux_out.warnings=check.warnings;
    aux_out.warn_bad=check.warn_bad;
else
    disp('cannot proceed');
    disp(aux_out.warnings);
end
%    
aux_out.opts_check=aux.opts_check;
return
end
