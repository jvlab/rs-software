function [persp,y_fit,opts_used]=persp_xform_find(x,y,opts)
% [persp,y_fit,opts_used]=persp_xform_find(x,y,opts) fits a projective transformation
%
% Args: 
%   x (float 2-D array): array of size [npts, nd], the (row) vectors to be transformed; npts is the number of vectors to be transformed
%
%   y (float 2-D array): array of size [npts, nd], its row vectors are the to be fit by applying the transformatoin to x
%
%   opts (struct): an options structure, may be omitted, with fields
%
%     - method (char): optimization method to use, can be 'fmin','oneshot','best'; default is 'oneshot' but this is overridden to 'best' when used by rs software; see note below regarding optimization methods
%     - if_cycle (int): relevant if  opts.method='oneshot' or 'best'; see note below regarding optimization methods
%     - fmin_opts (struct): relevant if opts_method='fmin' or 'best; see note below regarding optimization methods
%
% Returns:
%   persp (float 2-D array): array of size [nd+1 nd+1] specifying the transformation; persp*[x ones(npts,1)] are the homogeneous coordinates cooresponding to y
%
%   y_fit (float 2-D array): array of size [npts nd], the fitted values, i.e., the mapping of x via persp (see `persp_apply` for further details)
%
%   opts_used (struct): options used, along with
%
%     - ssq (float): sum of squares of deviations of y_fit from y
%     - oneshot (struct): detailed results from 'oneshot' method
%     - fmin (struct): detailed results from 'fmin' method
%
% Note: Optimization methods
%   - 'fmin': an iterative method: An initial specifier of the perspective component (c in `persp_apply`) is guessed. Based on c, 
%   the other components of the transformation (a and b in `persp_apply`) are determined by linear regresssion,
%   yielding a squared-error residual. The residual is then minimized by adjusting c via MATLAB's fmin, which is called with the options in opts.fmin_opts
%   - 'oneshot': This is an implementation of method 2 of The method Z. Zhang, Estimating Projective Transformation Matrix (Collineation, Homography),
%   Microsoft Research Techical Report MSR-TR-2010-63, November 1993;
%   Updated May 29, 2010.  It is most apprpriate when the transformation
%   is highly overdetermined, i.e, when there are a large number of data
%   points. If opts.if_cycle=1 (default is 0), this cycles through assignments of which data point is treated as the first point; the one that yields the best fit is returned in opts_used.best_point. 
%   - 'best': Methods 'fmin' and 'oneshot' are both are used, and the results of the method that yields the smallest squared-error residuals is returned
%
% See also: FILLDEFAULT, PERSP_SSQDIF, PERSP_SSQDIF_FIT.
%
if (nargin<=2) opts=struct; end
opts=filldefault(opts,'method','oneshot');
opts=filldefault(opts,'if_cycle',0);
opts=filldefault(opts,'fmin_opts',struct());
opts_used=opts;
%
npts=size(x,1);
nd=size(x,2);
if (npts<=nd+1)
    warning(sprintf('perspective fitting is underdetermined.  need npts>=nd+2, nd=%3.0f npts=%3.0f',nd,npts));
end
switch opts.method   
    case 'oneshot'
        [persp,y_fit,opts_used]=persp_xform_find_oneshot(x,y,opts_used);
    case 'fmin'
        [persp,y_fit,opts_used]=persp_xform_find_fmin(x,y,opts_used);
    case 'best'
        z=struct;
        [z.oneshot.persp,z.oneshot.y_fit,z.oneshot.opts_used]=persp_xform_find_oneshot(x,y,opts_used);
        [z.fmin.persp,z.fmin.y_fit,z.fmin.opts_used]=persp_xform_find_fmin(x,y,opts_used);
        if z.fmin.opts_used.ssq<=z.oneshot.opts_used.ssq
            method_best='fmin';
        else
            method_best='oneshot';
        end
        opts_used.method_best=method_best;
        opts_used.oneshot=z.oneshot;
        opts_used.fmin=z.fmin;
        persp=z.(method_best).persp;
        y_fit=z.(method_best).y_fit;
        opts_used.ssq=z.(method_best).opts_used.ssq;
end %opts.method       
return
end

function [persp,y_fit,opts_used]=persp_xform_find_oneshot(xi,yi,opts)
npts=size(xi,1);
ndx=size(xi,2);
ndy=size(yi,2);
if ndx<ndy
    x=[xi,zeros(npts,ndy-ndx)];
else
    x=xi;
end
if ndy<ndx
    y=[yi,zeros(npts,ndx-ndy)];
else
    y=yi;
end
%Zhang method
opts_used=opts;
nd=size(x,2);
%
x_aug_orig=[x,ones(npts,1)];
y_aug_orig=[y,ones(npts,1)];
%
p=zeros(nd+1,nd+1);
if (opts.if_cycle==0)
    ncycle=1;
else
    ncycle=npts;
end
persp=zeros(nd+1,nd+1);
y_fit=zeros(npts,nd,ncycle);
sumsq=Inf;
opts_used.oneshot.sumsq_trial=zeros(1,ncycle);
for icycle=0:ncycle-1
    cyc=mod(icycle+[0:npts-1],npts)+1;
    x_aug=x_aug_orig(cyc,:);
    y_aug=y_aug_orig(cyc,:);    
    %
    %create the "A" matrix 
    %
    A=zeros((nd+1)*npts,(nd+1)^2-1+npts);
    for ipt=1:npts
        Mi=zeros(nd+1,(nd+1)^2);
        for id=1:nd+1
            Mi(id,(nd+1)*(id-1)+[1:(nd+1)])=x_aug(ipt,:);
        end
        Arows=(nd+1)*(ipt-1)+[1:(nd+1)];
        A(Arows,1:(nd+1)^2)=Mi;
        if (ipt>1)
            A(Arows,(nd+1)^2+ipt-1)=y_aug(ipt,:)';
        end  
    end
    b=zeros((nd+1)*npts,1);
    b(1:nd+1)=y_aug(1,:);
    %
    S=regress(b,A);
    persp_trial=reshape(S(1:(nd+1)^2),nd+1,nd+1);
    y_fit_hom=x_aug_orig*persp_trial;
    y_fit_trial=y_fit_hom(:,1:nd)./repmat(y_fit_hom(:,nd+1),1,nd);
    sumsq_trial=sum((y_fit_trial(:)-y(:)).^2);
    opts_used.oneshot.sumsq_trial(icycle+1)=sumsq_trial;
    if (sumsq_trial<sumsq)
        persp=persp_trial;
        sumsq=sumsq_trial;
        opts_used.oneshot.best_point=icycle+1;
        y_fit=y_fit_trial;
        opts_used.ssq=sumsq;
    end
end
y_fit=y_fit(:,1:ndy);
persp=persp([1:ndx end],[1:ndy end]);
return
end

function [persp,y_fit,opts_used]=persp_xform_find_fmin(x,y,opts)
%search via fmin
%strategy is to search over the column vector that forms the denominator. 
%here, it is c -- the column vector which, if zero, makes the transformation affine.  This is the "p" in psg_geo_projective.
opts_used=opts;
npts=size(x,1);
nd=size(x,2);
%
fminsearch_opts=optimset('fminsearch');
fields=fieldnames(opts.fmin_opts);
for ifn=1:length(fields)
    fn=fields{ifn};
    fminsearch_opts.(fn)=opts.fmin_opts.(fn);
end
[c,fval,exitflag,output]=fminsearch(@(c) persp_ssqdif_fit(c,x,y),zeros(nd,1),fminsearch_opts);
opts_used.fmin.ssq=fval;
opts_used.fmin.exitflag=exitflag;
opts_used.fmin.fminsearch_opts=fminsearch_opts;
opts_used.fmin.output=output;
[ssq,y_fit,a,b]=persp_ssqdif_fit(c,x,y);
opts_used.ssq=ssq;
persp=[a c;b 1];
return
end

