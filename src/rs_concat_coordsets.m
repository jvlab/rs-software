function [data_out,aux_out]=rs_concat_coordsets(data_in1,data_in2,aux)
% Concatenates two dataset structures and checks concatenated dataset structure for consistency
%
% Args:
%   data_in1 (struct): first dataset structure, containing k_1 records, with fields
%
%     - ds: `coordinate structure`, ds{k_1}{idim} is an array of [nstims idim] of coordinates for the (k_1)th record
%     - sas: `stimulus metadata structure`, sas{k_1} is the stimulus metadata for the (k_1)th record
%     - sets: `set metadata structure`, sets{k_1} is the response metadata for the (k_1)th record
%
%   data_in2 (struct): second dataset structure, containing k_2 records, same format as `data_in1`
%
%   aux (struct): auxiliary options, may be omitted, with field
%
%     - opts_check (struct): options for consistency checking, with field
%
%       - if_warn (int) 1 (default) to show warnings when datasets are checked for consistency; otherwise 0
% 
% Returns:
%   data_out (struct): concatenated dataset structure with k_1+k_2 records, same format as  as `data_in1`
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - opts_check (struct): options used for consistency checking
%     - warnings (char): warnings generated during consistency check
%     - warn_bad (int): number of warnings that prevent further processing
%
% Notes:
%   `data_in1` and `data_in2` are typically created by `rs_get_coordsets`, `rs_align_coordsets`, or `rs_import_coordsets`
%
%  See also: RS_AUX_CUSTOMIZE, RS_CHECK_COORDSETS, RS_EXTRACT_COORDSETS.
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
fns={'ds','sas','sets'}; %fields to concatenate
%
ns=zeros(2,length(fns)); %check that fields to concatenate have same length
for ifn=1:length(fns)
    fn=fns{ifn};
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
    for ifn=1:length(fns)
        fn=fns{ifn};
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
