function [ifdif,maxdiff,maxdiff_noflip,diffs,diffs_noflip,signs]=compare_signflip(x,y,dimflip)
% [ifdif,maxdiff,maxdiff_noflip,diffs,diffs_noflip,signs]=compare_signflip(x,y,dimflip) 
% compares two arrays, allowing for sign flips along any dimension.
% 
% All arrays (or sub-arrays, if cells) must be numeric.
%
% x, y: data to be compared. can be cell arrays, but must have same shapes
% dimflip: dimension that can be flipped, defaults to 1
%
% ifdif: empty if identical, possibly after sign flips
%        otherwise, 'different values', 'different shapes' or 'different types'
% diffs: maximum abs of difference, after possible sign flips
% diffs_noflip: maximum abs of difference, without sign flips
% signs: +1 or -1, indicating flip, 0 if x and y are both 0
%
% ifdif records first kind of differnce encountered, empty if no differences (including possible sign flips)
% maxdiff, maxdiff_noflip are maxima across all comparisons
% diffs,diffs_noflip, signs all have same shape as x and y except on dimflip, where they have length 1
%
% recursive logic
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
