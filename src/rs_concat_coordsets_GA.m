function [data_out,aux_out]=rs_concat_coordsets(data_in1,data_in2,aux)
% Concatenates two dataset structures and checks the result for consistency.
%
% Args:
%   data_in1 (struct): First set of coordinate structures, with fields `ds`
%     (cell array of coordinate structures), `sas` (cell array of metadata
%     structures where `sas{k}.typenames` lists stimulus names), and `sets`
%     (cell array of additional metadata structures). Typically created by
%     `rs_align_coordsets`, but can also come directly from `rs_get_coordsets`,
%     `rs_read_coorddata`, or `rs_import_coordsets` if stimuli are identical
%     across datasets.
%   data_in2 (struct): Second set of coordinate structures, same format as
%     `data_in1`.
%   aux (struct): Auxiliary options, with field `opts_check` (struct) containing
%     `if_warn` (int, default 1) to show warnings when datasets are checked
%     for consistency.
%
% Returns:
%   data_out (struct): Concatenated dataset structures, with fields `ds`
%     (cell array of concatenated coordinate structures), `sas` (cell array
%     of concatenated metadata structures), and `sets` (cell array of
%     concatenated additional metadata structures).
%   aux_out (struct): Auxiliary outputs and parameter values used, with
%     fields `warnings` (warnings generated while creating arguments for
%     `psg_get_coordsets`) and `warn_bad` (int, count of warnings that prevent
%     further processing).
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
