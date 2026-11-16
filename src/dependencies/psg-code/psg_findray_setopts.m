function opts_use=psg_findray_setopts(setup_filename,opts)
% opts_use=psg_findray_setopts(setup_filename,opts) sets up special options for
% finding rays in a btc setup for psg experiments
%
% setup_filename: name of setup file, e.g., bcpm24pt9.mat
% opts: options for psg_findrays, can be omitted
%
% opts_use: modified opts, with fields over-written according to special requirements of the setup file
%
% Note that only un-specified fields of opts are over-written
%
%  See also: PSG_FINDRAYS, PSG_GET_COORDSETS, PSG_VISUALIZE_DEMO, PSG_DEFOPTS, FILLDEFAULT.
%
if nargin<2
    opts=struct();
end
%
ray_defaults=struct();
ray_defaults.bcpm24.ray_minpts=2;
ray_defaults.bcpm24.ray_dirkeep='card_diag';
%
ray_defaults.bcpp55.ray_dirkeep='card';
ray_defaults.bcpm55.ray_dirkeep='card';
ray_defaults.bcmp55.ray_dirkeep='card';
ray_defaults.bcmm55.ray_dirkeep='card';
%
fnames=fieldnames(ray_defaults);
for ifn=1:length(fnames)
    if contains(setup_filename,fnames{ifn})
        s=ray_defaults.(fnames{ifn});
        snames=fieldnames(s);
        for is=1:length(snames)
            opts=filldefault(opts,snames{is},s.(snames{is}));
        end
    end
end
opts_use=opts;
return
