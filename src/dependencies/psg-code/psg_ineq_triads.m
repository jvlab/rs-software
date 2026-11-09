function [triads,lets,descs]=psg_ineq_triads(config_type)
% function [triads,lets,descs]=psg_ineq_triads(config_type) sets up a table of
% triads for a triplet, tent, tetrahedron, or cycle of 4
%
% config_type: 'triplet','tent','tripod','tetra','tetrahedron' (same as tetra), cyc4
% triads: an array of [nc,3] designating the triadic comparisons
%   corresponding to each dimension of a partition of probability space provided by psg_ineq_logic.
% lets: the canonical letters
% descs: array of nc descriptive strings
%
%  See also:  PSG_INEQ_LOGIC, PSG_INEQ_LOOKUP.
%
switch config_type
    case 'triplet'
        lets={'a','b','c'};
        %   P(d(a,b)<d(a,c)), P(d(b,c)<d(b,a)), P(d(c,a)<d(c,b)),
        triads=[1 2 3;2 3 1;3 1 2];
    case 'tripod' %first half of a tent
        lets={'a','b','c','z'};
        %  P(d(z,b)<d(z,c)), P(d(z,c)<d(z,a)), P(d(z,a)< d(z,b)
        triads=[4 2 3;4 3 1;4 1 2];
    case 'tent'
        lets={'a','b','c','z'};
        %  P(d(z,b)<d(z,c)), P(d(z,c)<d(z,a)), P(d(z,a)< d(z,b), P(d(a,b)<d(a,c)), P(d(b,c)<d(b,a)), P(d(c,a)<d(c,b))
        triads=[4 2 3;4 3 1;4 1 2;1 2 3;2 3 1;3 1 2];
    case {'tetra','tetrahedron'}
        lets={'a','b','c','z'};
        %  P(d(z,b)<d(z,c)), P(d(z,c)<d(z,a)), P(d(z,a)< d(z,b), P(d(a,b)<d(a,c)), P(d(b,c)<d(b,a)), P(d(c,a)<d(c,b))
        %  P(d(z,b)<d(z,c)), P(d(z,c)<d(z,a)), P(d(z,a)< d(z,b), P(d(a,b)<d(a,c)), P(d(b,c)<d(b,a)), P(d(c,a)<d(c,b))
        triads=[...
            4 2 3;4 3 1;4 1 2;...
            1 2 3;2 3 1;3 1 2;...
            1 2 4;2 3 4;3 1 4;...
            1 3 4;2 1 4;3 2 4];
    case 'cyc4' %cyclic order is z c a b
        lets={'a','b','c','z'};
        %  P(d(z,b)<d(z,c)), P(d(c,z)<d(c,a)), P(d(a,c)< d(a,b), P(d(b,a)<d(b,z))
        triads=[4 2 3;3 4 1;1 3 2;2 1 4];
    otherwise
        error('unknown option');
end
nc=size(triads,1);
for inc=1:nc
    descs(inc,:)=sprintf('P(d(%s,%s)<d(%s,%s))',...
        lets{triads(inc,1)},...
        lets{triads(inc,2)},...
        lets{triads(inc,1)},...
        lets{triads(inc,3)});
end
return
