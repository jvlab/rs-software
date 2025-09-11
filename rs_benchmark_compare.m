function [ifdif,t,b,opts_used]=rs_benchmark_compare(rs_outfile,opts)
% [ifdif,t,b,opts_used]=rs_benchmark_compare(rs_outfile,opts) compares the contents of a test file with a benchmark
%
% rs_outfile: name of file to compare, e.g., rs_aux_customize_test
% opts: options
%
% ifdif: empty if contents are identical, otherwise a string describing the differences
% t: test structure
% b: benchmark structure
%
%   See also:  FILLDEFAULT.
%
if (nargin<=1)
    opts=struct;
end
opts=filldefault(opts,'dir_test','tests');
opts=filldefault(opts,'dir_benchmark','benchmarks');
opts=filldefault(opts,'if_log',1);
%
tf=cat(2,opts.dir_test,filesep,rs_outfile,'.mat');
tf=strrep(tf,'.mat.mat','.mat');
bf=cat(2,opts.dir_benchmark,filesep,rs_outfile,'.mat');
bf=strrep(bf,'.mat.mat','.mat');
if exist(tf,'file')
    t=load(tf);
else
    warning(sprintf('%s not found',tf));
    t=struct;
end
if exist(bf,'file')
    b=load(bf);
else
    warning(sprintf('%s not found',bf));
    b=struct;
end
ifdif=compstruct('benchmark',b,'test',t);
if ~isempty(ifdif)
    warning(sprintf('%s: benchmark comparison fails',rs_outfile));
else
    if (opts.if_log)
        disp(sprintf('%s: benchmark comparison ok',rs_outfile));
    end
end
opts_used=opts;
return

