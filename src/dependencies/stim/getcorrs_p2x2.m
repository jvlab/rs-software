function corrs=getcorrs_p2x2(p2x2,nowarn,justbtc)
% corrs=getcorrs_p2x2(p2x2,nowarn,justbtc) gets correlations from 2x2 block probabilities
%
% p2x2: an array of size [2 2 2 2], indicating the probability of each 2x2 block
%   p2x2(ia+1,ib+1,ic+1,id+1) is the probability of [ia ib; ic id]
%
% nowarn: if 1 (defaults to 0), suppresses output of a warning if
% probabilities not in range
% justbtc: if 1 (defaults to 0), suppresses contribution of entropies and cig_conds
%   if -1 only suppresses calculatyion of cig_conds
%
% corrs.norm: normalization (should be 1); sum of values in p2x2
% corrs.pmin: minimum of values in p2x2
% corrs.pmax: maximum of values in p2x2
% corrs.ok:   1 if all values in p2x2 are within range [0, 1]
% corrs.alpha: the fourth-order statistic, 1=even, -1=odd
% corrs.gamma: same as luminance bias, 1=all white, -1=all black
% corrs.beta(1): horizontal second-order correlation
% corrs.beta(2): vertical second-order correlation
% corrs.beta(3): diagonal (upper left to lower right) third-order correlation
% corrs.beta(4): diagonal (upper right to lower left) fourth-order correlation
% corrs.theta(1): third-order correlation of checks A and its flankers, B,C
% corrs.theta(2): third-order correlation of checks B and its flankers, A,D
% corrs.theta(3): third-order correlation of checks C and its flankers, A,D
% corrs.theta(4): third-order correlation of checks D and its flankers, B,C
% corrs.entropy:   entropy of the resulting MRF, assuming existence of MRF consistent with p2x2
% corrs.entropy_area: entropy of the 2x2 probability distributions (not entropy per unit area)
% corrs.cig_conds: a 2x4 array; corrs.cig_conds(u,k)=extent to which, for a cell in position
%    k assigned to u (u=2 for bright, u=1 for dark), that the neighbors of k are conditionally 
%    independent.  Pickard conditions: all 0's in column 1 and column 4, or all 0's in columns 2 and 3.
%
%   Example:
%   corrs=getcorrs_p2x2(getp2x2_pabcde(getpabcde_ag(.1,.4)))
%
% 07Feb20: add option of justbtc, only compute gamma, beta, theta, alpha
% 11Jan26: add -1 option for justbtc
%
%   See also:  GETP2X2_CORRS, GETP2X2_PABCDE, GETPABCDE_AG, GENMRFM, GETFTPS_P2X2, GETMOMS_P2X2, BTCSTATS, MLIS_BTCSTATS.
%
corrs.ok=0;
corrs.alpha=[];
corrs.beta=[];
corrs.theta=[];
corrs.gamma=[];
%
if (nargin<=1) nowarn=0; end
if (nargin<=2) justbtc=0; end
%
if ~(length(size(p2x2))==4)
   warning(' p2x2 does not have 4 dimensions.');
   return
end
if ~(min(size(p2x2)==[2 2 2 2]))
   warning(' p2x2 is not of size [2 2 2 2]');
   return
end
p2x2r=reshape(p2x2,1,16);
corrs.norm=sum(p2x2r);
corrs.pmin=min(p2x2r);
corrs.pmax=max(p2x2r);
corrs.ok=1;
if (corrs.pmin<0)
   if (nowarn==0)
       warning(' p2x2 has values < 0');
   end
    corrs.ok=0;
end
if (corrs.pmax>1)
   if (nowarn==0)
       warning(' p2x2 has values > 1');
   end
   corrs.ok=0;
end
%
%calculate corrs.alpha
parity2=[1 -1;-1 1];
parity3=cat(3,parity2,-parity2);
parity4=cat(4,parity3,-parity3);
corrs.alpha=sum(p2x2r.*reshape(parity4,1,16))/corrs.norm;
%
%calculate corrs.gamma
% could also do this by summing over irrelevant locations, e.g., sum(sum(sum(p2x2,2),3),4)+...
numwhite2=[0 1;1 2];
numwhite3=cat(3,numwhite2,1+numwhite2);
numwhite4=cat(4,numwhite3,1+numwhite3);
pw=sum(p2x2r.*reshape(numwhite4,1,16))/4/corrs.norm;
corrs.gamma=2*pw-1;
%
%calculate corrs.theta -- sum over irrelevant locations
for loc=1:4
   pt=squeeze(sum(p2x2,5-loc));
   corrs.theta(loc)=-sum(reshape(pt,1,8).*reshape(parity3,1,8))/corrs.norm;
end
%
%calculate corrs.beta -- sum over irrelevant locations
pb{1}=0.5*(squeeze(sum(sum(p2x2,1),2))+squeeze(sum(sum(p2x2,3),4))); %horiz
pb{2}=0.5*(squeeze(sum(sum(p2x2,1),3))+squeeze(sum(sum(p2x2,2),4))); %vert
pb{3}=squeeze(sum(sum(p2x2,2),3)); %upper left to lower right
pb{4}=squeeze(sum(sum(p2x2,1),4)); %upper right to lower left
for loc=1:4
   corrs.beta(loc)=sum(reshape(pb{loc},1,4).*reshape(parity2,1,4))/corrs.norm;
end
%
if (justbtc==1) %quick return to save time
    return
end
%calculate overall entropy
pv=reshape(p2x2,1,16)/corrs.norm;
pvnz=pv(find(pv>0));
corrs.entropy_area=-sum(pvnz.*log(pvnz))/log(2);
%turn this into entropy per unit area
for id=1:2
   pv=(1+[-2*corrs.gamma+corrs.beta(id),2*corrs.gamma+corrs.beta(id),-corrs.beta(id),-corrs.beta(id)])/4;
   pvnz=pv(find(pv>0));
   ent2x1(id)=-sum(pvnz.*log(pvnz))/log(2);
end
pv=(1+[-corrs.gamma,corrs.gamma])/2;
pvnz=pv(find(pv>0));
ent1x1=-sum(pvnz.*log(pvnz))/log(2);
%
corrs.entropy=corrs.entropy_area-sum(ent2x1)+ent1x1;
if (justbtc==-1) %also to save time
    return
end
%
% calculate something equivalent to conditional independence of neighbors of k
for iu=1:2
   for k=1:4
      if (k==1) p_ku=squeeze(sum(p2x2(iu,:,:,:),4)); end
      if (k==2) p_ku=squeeze(sum(p2x2(:,iu,:,:),3)); end
      if (k==3) p_ku=squeeze(sum(p2x2(:,:,iu,:),2)); end
      if (k==4) p_ku=squeeze(sum(p2x2(:,:,:,iu),1)); end
      corrs.cig_conds(iu,k)=p_ku(1,1)*sum(sum(p_ku))-sum(p_ku(1,:))*sum(p_ku(:,1)); 
   end
end
%
return

