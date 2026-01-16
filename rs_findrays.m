function [rays,wmsg,opts_rays_used]=rs_findrays(sa,label,opts_rays)
% [rays,wmsg,opts_rays_used]=rs_findrays(sa,label,opts_rays) is a utility to
% create a ray structure from metadata that specifies stimulus coordinates
%  sa: metadata structure, containing stmulus coordinates, 
%    type_coords for generic experiments, btc_specoords or btc_augcoords for btc experiments
%  label: a string, to be searched in psg_findray_setopts for identifiers
%     that require special params for psg_findrays, such as 'bcpm24', 'bcmm55'
%  opts_rays: options for psg_findrays, from psg_defopts or
%     rs_aux_customize.  Can also have a field 'coord_names', which
%     defaults to {'type_coords','btc_specoords','btc_augcoords'}, in order of priority
%
%  rays: ray structure
%  wmsg: warning message, if any
%  opts_rays_used: ray options used for psg_findrays
%
%   See also:  PSG_DEFOPTS, PSG_FINDRAYS.
%
if (nargin<=1)
    label=[];
end
if (nargin<=2)
    opts_rays=struct;
end
opts_rays=filldefault(opts_rays,'coord_names',getfield(psg_defopts,'coord_fields')); % was ,{'type_coords','btc_specoords','btc_augcoords'});
wmsg=[];
rays=struct;
opts_rays_used=struct; %in case psg_findrays is not called
stim_coords=[];
ncn=length(opts_rays.coord_names);
icn_used=0;
for icn=1:ncn
    cn=opts_rays.coord_names{icn};
    if isfield(sa,cn)
        if isempty(stim_coords)
            stim_coords=sa.(cn);
            cn_used=icn;
        end
    end
end
if ~isempty(stim_coords)
    opts_rays=setfield(opts_rays,'coord_names',{opts_rays.coord_names{cn_used}});
    if ~isempty(label)
        opts_rays=psg_findray_setopts(label,opts_rays);
    end
    [rays,opts_rays_used]=psg_findrays(stim_coords,opts_rays);
else
    wmsg=sprintf('cannot find stimulus coordinates, so cannot identify rays');
end
return
end
