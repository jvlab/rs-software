function [ra,warnings,details]=psg_knit_stats(ds_align,sas_align,dim_list_in,dim_list_out,opts_pcon)
% [ra,ou,warnings,details]=psg_knit_stats(ds_align,sas_align,dim_list_in,dim_list_out,opts_pcon)
% A wrapper for psg_align_stats, which now contains functionality of knitting, computation 
% of statstics for knitting, and aligning.
%
%  See also:  PSG_ALIGN_STATS
%
[ra,warnings,details]=psg_align_stats(ds_align,sas_align,dim_list_in,dim_list_out,opts_pcon);
return
end
