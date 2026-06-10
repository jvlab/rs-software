function [nr,nc,aused]=nicesubp(nsubplots,aspect)
% [nr,nc,aused]=nicesubp(nsubplots,aspect) finds a nice number of rows and columns to put nsubplots into a figure
%
% Args:
%   nsubplots (int): number of subplots to position
%
%   aspect (float): desired aspect ratio of overall plot; default is 1
%   
%     - If a scalar, the height/width ratio
%     - if [v1,v2], the allowed range
%
% Returns:
%   nr (int): number of rows in subplot array
%
%   nc (int): number of columns in subplot array
%
%   aused (float): aspect ratio used
%
if (nargin<=1) aspect=1; end
%
if (nsubplots<=1)
   nr=1;nc=1;
   return
end
if (length(aspect)==1)
   avals=aspect;
else
   avals=[aspect(1):(aspect(2)-aspect(1))/(sqrt(nsubplots)*2):aspect(2)]; % a range of values
   %reorder in terms of decreasing distance to midpoint
   dvals=abs(avals-(aspect(1)+aspect(2))/2);
   [sdvals,isort]=sort(-dvals);
   avals=avals(isort);
end
%
missing=inf;
for aval=avals
   nc=sqrt(nsubplots/aval);
	nr=nc*aval;
	if (aval<=1)
   	nc=ceil(nc*(1-0.5/max(nc,nr)));
   	nr=ceil(nsubplots/nc);
	else
  		nr=ceil(nr*(1-0.5/max(nc,nr)));
   	nc=ceil(nsubplots/nr);
   end
   if ((nr*nc-nsubplots)<=missing); %best yet?
      nrb=nr;
      ncb=nc;
      missing=nr*nc-nsubplots;
      aused=nr/nc;
   end
end
nr=nrb;
nc=ncb;



   
