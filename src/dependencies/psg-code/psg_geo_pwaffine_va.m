function [d,transform,u,opts_used]=psg_geo_pwaffine_va(y,x,vcut,acut,opts)
%
% [d,transform,u,opts_used]=psg_geo_pwaffine_va(y,x,vcut,acut,opts) finds the best
% piecewise affine model, given one or more cutplanes
%
% y: reference dataset, [npts dim_xy], dim_xy >= dim_x
% x: dataset to adjust, [npts dim_x]
% vcut: [ncuts dim_x], stack of row vectors of length dim_x, orthogonal to cut planes
%   The lengths of vcut must all be 1.
% acut: cut values (row vector of length ncuts)
% opts.tol_cut: tolerance for cutpoints (defaults to 10^-7);
% opts.if_orth: set to 1 to orthonormalize analysis coordinates below vcut
%     Always done if ncut>1
%
% d: residuals, normalized for squared dev of y
% transform: transform structure, see psg_geo_pwaffine
% u: basis used for analysis. vcut spans the first ncuts rows of u (and vice versa); remaining rows of u are orthogonal to vcut
%    * The coordinates in the analysis basis are given by post-multiplying x by uinv.
%    * Note that u depends on vcut but not acut
%    * The first ncuts columns of inv(u) are the rows of vcut.
%    *  If if_orth=1 or ncuts>1, the last (dim_x-ncuts) rows of u are orthogonal, and these are orthogonal to the first ncuts rows.
%    The first ncuts rows of u may not be orthogonal to each other, as they are unit vectors orthogonal to the cutplanes.
%    *  If if_orth=0 and ncuts=1, the last (dim_x-1) rows of u are orthogonal to the first row, but may not be orthogonal to each other.
% opts_used: options used
%
% 11Dec23: add option for if_orth=0
% 18Dec23: begin multi-cut options
%
%    See also:  PSG_GEO_PWAFFINE, REGRESS, EXTORTHB, EXTORTHBN, GRMSCMDT, PSG_PWAFFINE_APPLY.
%
if (nargin<=4)
    opts=struct;
end
opts=filldefault(opts,'tol_cut',10^-7);
opts=filldefault(opts,'if_orth',1); %whether to orthogonalize within the complementary subspace to the space spanned by vcut
opts_used=opts;
%
ncuts=size(vcut,1);
dim_x=size(x,2); %data to adjust
dim_xy=size(y,2); %reference data (to fit), already augmented
npts=size(x,1);
n_pw=2^ncuts; %number of regions
%
if (opts.if_orth) | ncuts>1
    %always orthogonalize complementary subspace if ncuts>1, to avoid
    %possible numeric problems with finding a basis
    if ncuts==1
        [basis,q]=extorthb(vcut'); %i_dir: vectors are rows but extorthb wants columns
        %this is the new orthonormal basis, as rows
        %coordinates in the new orthonormal basis are given by post-multiplying by u'=q
        uinv=q; %q is orthonormal, uinv=inv(q'); first column of uinv is vcut'
    else
        [vcb,vcbn]=grmscmdt(vcut'); %vcb is an orthonormal basis for the cut space
        [basis,q]=extorthb_gen(vcbn); %extend to whole space
        uinv=q; % q is orthonormal
        uinv(:,[1:ncuts])=vcut'; %first ncuts columns of uinv is vcut', and not typically orthogonal to each other
    end
    u=inv(uinv);
else %only if ncuts=1 and if_orth=0.
    %skip orthogonalization in the complementary subspace, and need an explicit inverse
    %first row of u is vcut
    %remaining rows of u are the identity, with the row closest to vcut removed
    remove=min(find(abs(vcut)==max(abs(vcut))));
    ulower=eye(dim_x);
    ulower=ulower(setdiff((1:dim_x),remove),:);
    %then orthogonalize each row of ulower w.r.t. vcut
    ulower=ulower-ulower*vcut'*vcut;
    u=[vcut;ulower];
    uinv=inv(u); %first col of uinv is vcut' because rest of u is orthogonal to first row  
end
%
x_prime=x*uinv; %the kth element of a row of x_prime is the amount of the kth row of u in x.
xpa=x_prime(:,[1:ncuts])-repmat(acut,npts,1); %xpa is [npts ncuts], the criteria for which side of the boundary is each point
%
%set up regions
%
insides=zeros(npts,ncuts,2);
insides(:,:,1)=double(xpa>opts.tol_cut);
insides(:,:,2)=double(xpa<-opts.tol_cut);
%create augmented regressor matrix
%x_prime_aug=zeros(npts,dim_x+2);
x_prime_aug=zeros(npts,dim_x+ncuts+1); 
%each cut generates an extra row (we native row but gain two auxiliary rows)
% one one final row for constant term
for icut=1:ncuts %fill in two columns at a time
    x_prime_aug(insides(:,icut,1)>0,2*icut-1)=xpa(insides(:,icut,1)>0,icut);
    x_prime_aug(insides(:,icut,2)>0,2*icut)  =xpa(insides(:,icut,2)>0,icut);
end
%
empties=find(reshape(all(insides==0,1),[ncuts,2])'); %a list of the rows of x_prime_aug that have no entries
nonempties=setdiff([1:dim_x+ncuts+1],empties);
%
x_prime_aug(:,(2*ncuts+1):(dim_x+ncuts))=x_prime(:,(ncuts+1):dim_x);
x_prime_aug(:,dim_x+ncuts+1)=1;
s_aug=zeros(dim_x+ncuts+1,dim_xy);
s_nz=zeros(length(nonempties),dim_xy);
%do the regression on nonzero regressors
for icol=1:dim_xy
    s_nz(:,icol)=regress(y(:,icol),x_prime_aug(:,nonempties));
end
s_aug(nonempties,:)=s_nz; %restore coefs for empty regressors
%unpack the results
h=s_aug(dim_x+ncuts+1,:); %last row
T=zeros(dim_x,dim_xy,n_pw);
c=zeros(n_pw,dim_xy);
%loop through all combinations of + and - signs
%      sign_ind=1       for sign_vec=[+ + .... +]
%      sign_ind=2       for sign_vec=[- + .... +]
%      sign_ind=3       for sign_vec=[+ - .... +]
%      sign_ind=4       for sign_vec=[- - .... +]
%         ....
%      sign_ind=2^ncuts for sign_vec=[- - .... -]
sign_table=ones(n_pw,ncuts);
for icut=1:ncuts
    sign_table(:,icut)=repmat([ones(2^(icut-1),1);-ones(2^(icut-1),1)],2^(ncuts-icut),1);
end
for i_pw=1:n_pw
    signs=sign_table(i_pw,:);
    rowsel=2*[1:ncuts]-(1+signs)/2; %selects rows 1,3,5,... for signs=1, or rows 2,4,6, ... for signs=-1
    T(:,:,i_pw)=uinv*s_aug([rowsel (2*ncuts+1):(dim_x+ncuts)],:); %omit a row
    c(i_pw,:)=h-acut*s_aug(rowsel,:);
end
%save transform and compute residuals
transform=struct;
transform.b=1;
transform.T=T;
transform.c=c;
transform.vcut=vcut;
transform.acut=acut;
yfit=psg_pwaffine_apply(transform,x);
d_num=sum(sum((y-yfit).^2,1));
d_den=sum(sum((y-repmat(mean(y,1),npts,1)).^2,1));
d=d_num/d_den;
return
end
