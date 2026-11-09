function p2x2=getp2x2_corrs(corrs)
% p2x2=getp2x2_corrs(corrs) gets block probablities from correlations
%
% p2x2: an array of size [2 2 2 2], indicating the probability of each 2x2 block
%   p2x2(ia+1,ib+1,ic+1,id+1) is the probability of [ia ib; ic id]
%
% corrs.alpha: the fourth-order statistic, 1=even, -1=odd
% corrs.gamma: same as luminance bias, 1=all white, -1=all black
% corrs.beta(1): horizontal second-order correlation
% corrs.beta(2): vertical second-order correlation
% corrs.beta(3): diagonal (upper left to lower right) second-order correlation
% corrs.beta(4): diagonal (upper right to lower left) second-order correlation
% corrs.theta(1): third-order correlation of checks A and its flankers, B,C
% corrs.theta(2): third-order correlation of checks B and its flankers, A,D
% corrs.theta(3): third-order correlation of checks C and its flankers, A,D
% corrs.theta(4): third-order correlation of checks D and its flankers, B,C
%
%   getcorrs_p2x2(getp2x2_corrs(corrs)) gives corrs
%   getp2x2_corrs(getcorrs_p2x2(p2x2))  gives a set of block probabilities with same
%     corrs as p2x2 (i.e., p2x2 symmetrized)
%
%   See also:  GETCORRS_P2X2, GETP2X2_PABCDE, GETPABCDE_AG, GENMRFM.
%
for ia=0:1
   sa=2*ia-1;
   for ib=0:1
      sb=2*ib-1;
      for ic=0:1
         sc=2*ic-1;
         for id=0:1
            sd=2*id-1;
            %calculate contributin of each order
            kg=(sa+sb+sc+sd)*corrs.gamma;
            kb=sum([(sa*sb+sc*sd),(sa*sc+sb*sd),sa*sd,sb*sc].*corrs.beta);
            kt=sum([sa*sb*sc,sb*sa*sd,sc*sa*sd,sd*sb*sc].*corrs.theta);
            ka=sa*sb*sc*sd*corrs.alpha;
            p2x2(ia+1,ib+1,ic+1,id+1)=(1+kg+kb+kt+ka)/16;
         end
      end
   end
end
%
return

