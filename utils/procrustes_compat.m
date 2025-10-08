function t_new=procrustes_compat(t)
% t_new=procrustes_compat(t) is a utility that changes the names of the fields in 
% a transformation structure prodcued by procrustes_consensus into a structure compatible
% with psg_geomodels_apply and Matlab's procrustes but for Matlab's
%    procrustes, the offset field, b, needs to be replicated for each data point)
%
% t: a transformation with fields scaling, orthog, and translation
%   znew=ts.scaling*z*ts.orthog+repmat(ts.translation,size(z,1))
% ts: fields are now b, T, and c
%
% if scaling is omitted, b is set to 1
% if translation is omitted, c is set to zeros(size(orthog,2))
%
% See also:  FILLDEFAULT, PROCRUSTES_CONSENSUS, PROCRUSTES, PSG_GEOMODELS_APPLY.
%
t=filldefault(t,'scaling',1);
t=filldefault(t,'translation',zeros(1,size(t.orthog,2)));
%
t_new=struct;
t_new.T=t.orthog;
t_new.b=t.scaling;
t_new.c=t.translation;
%
return
end
