function h=surf_augvec(varargin)
% function h=surf_augvec plots a surface, even if the surface values
% are one-dimensional
% 
% only some of Matlab's calling methods are allowed:
% surf_augvec(x,y,z)
% surf_augvec(x,y,z,c)
% surf_augvec(z)
% surf_augvec(z,c)
% or any of the above preceded by a handle
%
% See also:  SURF.
%
if isgraphics(varargin{1},'axes')
    h=varargin{1};
    nh=1;
else
    h=[];
    nh=0;
end
c=[];
switch length(varargin)-nh
    case 1
        z=varargin{1+nh};
        c=z;
        x=[1:size(z,2)];
        y=[1:size(z,1)];
    case 2
        z=varargin{1+nh};
        c=varargin{2+nh};
        x=[1:size(z,2)];
        y=[1:size(z,1)];
    case 3
        x=varargin{1+nh};
        y=varargin{2+nh};
        z=varargin{3+nh};
        c=z;
    case 4
        x=varargin{1+nh};
        y=varargin{2+nh};
        z=varargin{3+nh};
        c=varargin{4+nh};
end
nx=size(z,2);
ny=size(z,1);
xa=x;
ya=y;
za=z;
ca=c;
nxa=nx;
if nx==1
    za=[nan(ny,1),za,nan(ny,1)];
    ca=[nan(ny,1),ca,nan(ny,1)];
    xa=[xa(1)-1 xa(:)' xa(end)+1];
    nxa=nx+2;
end
if ny==1
    za=[nan(1,nxa);za;nan(1,nxa)];
    ca=[nan(1,nxa);ca;nan(1,nxa)];
    ya=[ya(1)-1 ya(:)' ya(end)+1];
end
h=surf(xa,ya,za,ca);
if (nx==1)
    set(gca,'XLim',x+[-0.5 0.5]);
end
if (ny==1)
    set(gca,'YLim',y+[-0.5 0.5]);
end
%set(gca,'XLim',[min(x(:)),max(x(:))]);
%set(gca,'YLim',[min(y(:)),max(y(:))]);
return
