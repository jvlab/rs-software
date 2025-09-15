function [nr,nc,aused]=nicesubp(nplots,aspect)
%
% [nr,nc,aused]=nicesubp(nplots,aspect) finds a "nice" set of
% rows and columns to put nplots into subplots
%
% nplots: number of plots to use
% aspect: desired aspect ratio (height/width)
%    if aspect is a range, then the value with the best fit
%    (in terms of fewest missing pixels) is used; defaults to 1
%
% nr: number of rows in subplot array
% nc: number of columns in subplot array, with nr*nc<=nplots
% aused: aspect ratio used.
%
if (nargin<=1) aspect=1; end
%
if (nplots<=1)
   nr=1;nc=1;
   return
end
if (length(aspect)==1)
   avals=aspect;
else
   avals=[aspect(1):(aspect(2)-aspect(1))/(sqrt(nplots)*2):aspect(2)]; % a range of values
   %reorder in terms of decreasing distance to midpoint
   dvals=abs(avals-(aspect(1)+aspect(2))/2);
   [sdvals,isort]=sort(-dvals);
   avals=avals(isort);
end
%
missing=inf;
for aval=avals
   nc=sqrt(nplots/aval);
	nr=nc*aval;
	if (aval<=1)
   	nc=ceil(nc*(1-0.5/max(nc,nr)));
   	nr=ceil(nplots/nc);
	else
  		nr=ceil(nr*(1-0.5/max(nc,nr)));
   	nc=ceil(nplots/nr);
   end
   if ((nr*nc-nplots)<=missing); %best yet?
      nrb=nr;
      ncb=nc;
      missing=nr*nc-nplots;
      aused=nr/nc;
   end
end
nr=nrb;
nc=ncb;



   
