function figh=psg_knit_stats_plot(ra,ra_setup)
% figh=psg_knit_stats_plot(ra,ra_setup) plots the results of psg_[knit|align]_stats
% A wrapper for psg_align_stats_plot, as functionality of knitting and aligning have been combined
%
%   See also: PSG_ALIGN_STATS_PLOT.
%
figh=psg_align_stats_plot(ra,ra_setup);
return
end
