function [pts,opts_used]=hsphere_sample(d,opts)
% [pts,opts_used]=hsphere_sample(d,opts) samples the surface of a hypersphere with a requested number of points
%
% Args:
%   d (int): number of dimensions (2=circle, 3=ordinary sphere)
%  
%   opts (struct): options structure, with fields
%
%      - if_hemisphere (int): 0 to sample whole hypersphere, 1 to sample only the hemi-hypersphere in which first coordinate is >0; default is 0
%
%      - method (char): sampling method to use, with the following options; default is 'random'
%
%          - 'axes': one point on each axis, yields 2\*d/(1+opts.if_hemisphere) points
%          - 'orthants': one point in each orthant, yields 2<sup>d</sup>/(1+opts.if_hemisphere) points
%          - 'axes_and_orthants': one point on each axis and in each orthant, combines 'axes' and 'orthants'
%          - 'random': random
%          - 'fibspiral': Fibonacci spiral
%
%      - nsamps (int): number of points to sample, ignored if method='random' or 'fibspiral'; default is 2<sup>d</sup> for 'random' and 4<sup>d</sup> for 'fibspiral' 
%
% Returns:
%   pts (float 2-D array): array of size [nsamps d]; each row is a unit-length point on the hypersphere
%
%   opts_used (struct): options used
%
% See also:  FILLDEFAULT, INT2NARY, FIBSPIRAL.
%
if (nargin<2)
    opts=struct;
end
opts=filldefault(opts,'method','random');
opts=filldefault(opts,'if_hemisphere',0);
switch opts.method
    case 'axes'
        nsamps=(2*d)/(1+opts.if_hemisphere);
    case 'orthants'
        nsamps=(2^d)/(1+opts.if_hemisphere);
    case 'axes_and_orthants'
        nsamps=(2*d+2^d)/(1+opts.if_hemisphere);
    case 'random'
        opts=filldefault(opts,'nsamps',2^d);
        nsamps=opts.nsamps;
    case 'fibspiral'
        opts=filldefault(opts,'nsamps',4^d);
        nsamps=opts.nsamps;
    otherwise
        nsamps=0;
        warning(sprintf('method %s not recognized',opts.method));
        pts=[];
end
opts_used=opts;
if strfind(opts.method,'orthants')
    pts_orthants=fliplr([(1-2*int2nary([0:2^(d-opts.if_hemisphere)-1]',2,d))/sqrt(d)]);
end
if strfind(opts.method,'axes')
    pts_axes=eye(d);
    if opts.if_hemisphere==0
        pts_axes=[pts_axes;-eye(d)];
    end
end
switch opts.method
    case 'axes'
        pts=pts_axes;
    case 'orthants'
        pts=pts_orthants;
    case 'axes_and_orthants'
        if d>1
            pts=[pts_axes;pts_orthants];
        else
            pts=pts_axes;
            nsamps=2/(1+opts.if_hemisphere);
        end
    case 'random'
        pts=randn(nsamps,d);
        pts=pts./repmat(sqrt(sum(pts.^2,2)),[1 d]);
        if opts.if_hemisphere
            pts(:,1)=abs(pts(:,1));
        end
    case 'fibspiral'
        [pts,ou]=fibspiral(nsamps,d,opts);
        if opts.if_hemisphere
            pts(:,1)=abs(pts(:,1));
        end
        fields=fieldnames(ou);
        for ifn=1:length(fields)
            opts_used=filldefault(opts_used,fields{ifn},ou.(fields{ifn}));
        end
end
opts_used.nsamps=nsamps;
return
end