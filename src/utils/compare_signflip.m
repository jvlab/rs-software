function [ifdif,maxdiff,maxdiff_noflip,diffs,diffs_noflip,signs]=compare_signflip(x,y,dimflip)
% [ifdif,maxdiff,maxdiff_noflip,diffs,diffs_noflip,signs]=compare_signflip(x,y,dimflip) compares two numeric arrays, allowing for sign flips
% 
% This is a utility used to verify computations against benchmarks, recognizing that PCA implementations may differ in sign assignemnts.
% 
%  Args:
%    x (array or cell array): one array to be compared
%
%    y (array or cell array): second array to be compared
%
%    dimflip (int): dimension that can be flipped, defaults to 1
%
%  Returns:
%    ifdif (char): empty if x and y are identical or identical after sign flips along dimension 'dimflip'; otherwise, 'different types', 'different shapes' or 'different values', depending on first difference encountered
%
%    maxdiff (float): maximum absolute value of difference between x and y, after sign flips along dimflip to minimize differences
%
%    maxdiff_noflip (float): maximum absolute value of difference between x and y, without sign flips
% 
%    diffs (float array): maximum absolute value of difference between x and y along the dimension 'dimflip', after sign flips to minimize differences
%
%    diffs_noflip (float array): maximum absolute value of difference between x and y along the dimension 'dimflip', without sign flips
%
%    signs (int): +1 or -1, indicating whether the difference between x and y is minimized by a flip; 0 if x and y are both 0
%
%  Note: Array outputs
%
%    The arrays diffs,diffs_noflip, signs all have same shape as x and y except on the dimension 'dimflip', where they have length 1
%
if (nargin<=2)
    dimflip=1;
end
ifcx=iscell(x);
ifcy=iscell(y);
ndx=ndims(x);
ndy=ndims(y);
sx=size(x);
sy=size(y);
%
ifdif=[];
diffs=[];
diffs_noflip=[];
maxdiff=[];
maxdiff_noflip=[];
signs=[];
%
if (ifcx~=ifcy)
    ifdif='different types';
else
    if ndx~=ndy
        ifdif='different shapes';
    elseif any(sx~=sy)
        ifdif='different shapes';
    else % size and shape match
        if ifcx==1 %cell, so recurse
            xr=x(:);
            yr=y(:);
            nrec=length(xr);
            diffs_rec=cell(1,nrec);
            diffs_noflip_rec=cell(1,nrec);
            signs_rec=cell(1,nrec);
            maxdiff=0;
            maxdiff_noflip=0;
            for k=1:length(xr)
                [ifdif_rec{k},maxdiff_rec,maxdiff_noflip_rec,diffs_rec{k},diffs_noflip_rec{k},signs_rec{k}]=compare_signflip(xr{k},yr{k},dimflip);
                if ~isempty(ifdif_rec{k})
                    if isempty(ifdif)
                        ifdif=ifdif_rec{k};
                    end
                end
                if ~isempty(maxdiff_rec)
                    maxdiff=max(maxdiff,maxdiff_rec);
                    maxdiff_noflip=max(maxdiff_noflip,maxdiff_noflip_rec);
                end
            end
            diffs=reshape(diffs_rec,sx);
            diffs_noflip=reshape(diffs_noflip_rec,sx);
            signs=reshape(signs_rec,sx);
        else %do comparisons
            diffs_noflip=max(abs(x-y),[],dimflip);
            diffs_allflip=max(abs(x+y),[],dimflip);
            diffs=min(cat(dimflip,diffs_noflip,diffs_allflip),[],dimflip);
            maxdiff=max(diffs(:));
            maxdiff_noflip=max(diffs_noflip(:));
            signs=sign(diffs_allflip-diffs_noflip);
            if maxdiff>0
                ifdif='different values';
            end
        end
    end
return
end
