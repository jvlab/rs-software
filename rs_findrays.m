function [rays,wmsg,opts_rays_used]=rs_findrays(sa,label,opts_rays)
% [rays,wmsg,opts_rays_used]=rs_findrays(sa,label,opts_rays) is a utility to
% create a ray structure from metadata that specifies stimulus coordinates
%
%  sa: metadata structure, containing stmulus coordinates, typically btc_specoords or btc_augcoords
%  label: a string, to be searched in psg_findray_setopts for identifiers
%     that require special params for psg_findrays, such as 'bcpm24', 'bcmm55'
%  opts_rays: options for psg_findrays, from psg_defopts or
%     rs_aux_customize.  Can also have a field 'coord_names', which
%     defaults to {'btc_specoords','btc_augcoords'}, in order of priority
%
%  rays: ray structure
%  wmsg: warning message, if any
%  opts_rays_used: ray options used for psg_findrays
%
opts_rays=filldefault(opts_rays,'coord_names',{'btc_specoords','btc_augcoords'});
wmsg=[];
rays=struct;
opts_rays_used=struct; %in case psg_findrays is not called
stim_coords=[];
ncn=length(opts_rays.coord_names);
for icn=1:ncn
    cn=opts_rays.coord_names{icn};
    if isfield(sa,cn)
        if isempty(stim_coords)
            stim_coords=sa.(cn);
        end
    end
end
if ~isempty(stim_coords)
    opts_rays=psg_findray_setopts(label,opts_rays);
    [rays,opts_rays_used]=psg_findrays(stim_coords,opts_rays);
else
    wmsg=sprintf('cannot find stimulus coordinates, so cannot identify rays');
end
return
end
