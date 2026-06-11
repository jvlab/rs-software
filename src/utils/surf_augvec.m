function h=surf_augvec(varargin)
% h=surf_augvec plots a surface, extending MATLAB's `surf` to cases inwhich the surface to be plotted has a dimension of length 1.
% 
% Args:
%   varargin (float array or sequence of float arrays): arguments to MATLAB's `surf` in one of the following formats
%
%     - surf_augvec(x,y,z,c), where x and y are the independent variables as 1-D vectors, z is surface height as 2-D array, c is color as 2-D array
%     - surf_augvec(x,y,z), as above, with c proportional to surface height
%     - surf_augvec(z,c), as above, with x=[1:size(z,2)] and y=[1:size(z,1)]
%     - surf_augvec(z), as above, with x=[1:size(z,2)] and y=[1:size(z,1)] and c proportional to surface height
%     - or any of the above preceded by a handle of the axis to plot into
% 
% Returns:
%   h (handle): handle to the surface
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
