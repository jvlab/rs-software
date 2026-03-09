function [data_out,aux_out]=rs_extract_coordsets(data_in,extract_list,aux)
% Extracts or permutes the records in a dataset structure
%
% Args:
%   data_in (struct): dataset structure, containing n records, with fields
%
%     - ds: `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas: `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets: `set metadata structure`, sets{k} is the response metadata for the kth record
%
%   extract_list (int 1-D array): a subset of [1:n] to extract, the records to extract
%
%   aux (struct): auxiliary options, with field
%
%     - opts_extract (struct): options for consistency checking, with field
%
%       - if_warn (int): 1 to show warnings, 0 to suppress. . Default is 1.)
% 
% Returns:
%   data_out (struct): concatenated dataset structure with length(extract_list) records, same format as  as `data_in1`
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - opts_extract (struct): aux.opts_extract, with defaults filled in
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%
% Notes:
%   -  aux may be omitted; defaults are filled in.
%   -  data_out.sets{k}.pipeline is copied from data_in and is not updated.
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
