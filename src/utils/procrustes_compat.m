function t_new=procrustes_compat(t)
% t_new=procrustes_compat(t) converts the fieldnames produced by `procrustes_consensus` to names compatible with `transformation structures`
%
% Args:
%   t (struct): a structure with fields 'scaling', 'orthog', and 'translation'
%
% Returns:
%   t_new (struct): a structure with fields renamed 'b','T','c'
%
% Note: Default values
%   If 'scaling' is unspecified in 't', b is set to 1 in t_new.
% 
%   If 'translation' is unspecified in t, 'c' is set to zeros(size(orthog,2)) in t_new
%
% See also:  FILLDEFAULT, PROCRUSTES_CONSENSUS.
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
