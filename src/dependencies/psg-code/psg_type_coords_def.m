function [type_coords,opts_used]=psg_type_coords_def(nstims,opts)
% [type_coords,opts_used]=psg_type_coords_def(nstims,opts) sets up conceptual coordinate values
%
%   nstims: number of stimuli
%   opts: 
%      opts.type_coords_def: 'eye' (default) or 'ones' or 'zeros' or 'none'
%
%   type_coords: array of size [nstims *], depending on opts.type_coords_def
%   opts_used: options used
%
% 02Feb26: add 'none' (non-default)
% 21Feb26: add 'zeros'
%
%  See also: PSG_ALIGN_COORDSETS.
%
if (nargin<=1)
    opts=struct;
end
opts=filldefault(opts,'type_coords_def','eye');
opts_used=opts;
switch opts.type_coords_def
    case 'eye'
        type_coords=eye(nstims);
    case 'ones'
        type_coords=ones(nstims,1);
    case 'zeros'
        type_coords=zeros(nstims,1);       
    case 'none'
        type_coords=[];
    otherwise
        type_coords=zeros(nstims,[]);
        warning(sprintf('type_coords_def value %s not recognized.',opts.type_coords_def));
end
return
end
