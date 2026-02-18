function [data_out,aux_out]=rs_extract_coordsets(data_in,extract_list,aux)
% data_out,aux_out]=rs_extract_coordsets(data_in,extract_list,aux)
% extracts or permutes a subset of dataset structures
%
% data_in.ds{k},sas{k},sets{k}: a dataset structurein cluding coordinates (ds) and metadata (sas,sets)
%
% extract_list: a subset of [1:length(data_in.ds)] to extract
%  aux.opts_extract.if_warn: set to 1 (default) to show warnings
% 
% data_out.ds{k},sas{k},sets{k}:  extracted dataset structures, in order of listing in extract_list
% aux_out: auxiliary outputs and parameter values used
%   warnings: warnings generated in creating arguments for psg_get_coordsets
%   warn_bad: count of warnings that prevent further processing
%
%  See also: RS_CONCAT_COORDSETS.
%
if (nargin<=2)
    aux=struct;
end
%set up sub-structure options
%
aux=filldefault(aux,'opts_extract',struct); 
aux.opts_extract=filldefault(aux.opts_extract,'if_warn',1);
%
data_out=struct;
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
fns={'ds','sas','sets'}; %fields to extract
%
ns=zeros(1,length(fns)); %check that fields to extractenate have same length
for ifn=1:length(fns)
    fn=fns{ifn};
    ns(ifn)=length(data_in.(fn));
end
if min(ns)~=max(ns)
    wmsg='input structures have inconsistent lengths';
    aux_out=rs_warning(wmsg,1,setfield(aux_out,'if_warn',aux.opts_extract.if_warn));
end
if aux_out.warn_bad==0
    extract_ok=ismember(extract_list,[1:max(ns)]);
    if any (extract_ok==0)
        wmsg=sprintf('extract_list has values not in [1:%2.0f]; will be ignored',max(ns));
        aux_out=rs_warning(wmsg,0,setfield(aux_out,'if_warn',aux.opts_extract.if_warn));
    end
    extract_use=extract_list(extract_ok==1);
    for ifn=1:length(fns)
        fn=fns{ifn};
        data_out.(fn)=cell(1,length(extract_use));
        for k=1:length(extract_use)
            data_out.(fn){k}=data_in.(fn){extract_use(k)};            
        end
    end
else
    disp('cannot proceed');
    disp(aux_out.warnings);
end
%    
aux_out.opts_extract=aux.opts_extract;
return
end
