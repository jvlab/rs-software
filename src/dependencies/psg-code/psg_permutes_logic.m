function permutes=psg_permutes_logic(nc,flip_type,subdivs)
%permutes=psg_permutes_logic(nc,flip_type,subdivs) creates a table of permutations for
%statistical analysis of likelihoods for umi, sym, tent by flipping
%rank-choice probabilities.  The permutatons (one in each column)
%are applied to an nc-cube of probabilities, in which, on each dimension, 
% The three values of the coordinates correspond to rank choice probabilities
% (typically, <1/2, = 1/2, and > 1/2).
% So, inverting the rank choice probability corresponds to reversing the order on a dimension.
%
% Note that the dimensions correspond to rank-choice probability estimates
% for triads, and this could also be used to specify ways of permuting them.
% Caution -- permuting the triads is not the same as permuting the stimuli.
% 
% For background, see .../jv/ey07977/psg_umi_notes.doc.
%
% nc: number of rank-choice probability estimates, typically 3 or 6
% flip_type: 'none','flip_all','flip_each','permute_d123'
% subdivs: number of subdivisions on each axis.
%   subdivs=3 for <1/2, = 1/2, and > 1/2.
%   subdivs=2 to omit =1/2
%   If omitted, subdivs=3.    
%
% permutes: array of permutations, dim(permutes,1)=subdivs^nc, and each column of permutes
%  contains [1:subdivs^nc] in some order. permutes(:,1) is the natural order.
%  dim(permutes,2) depends on flip_type.  
%    'none': 1
%    'flip_all':  2
%    'flip_each': 2^nc. Last column of permutes is sane as last column of flip_all.
%    'permute_d123': 6 (all permutations of the first three dimensions
%
% See also:  PSG_INEQ_LOGIC, PSG_INEQ_APPLY, PSG_PROBS_CHECK.
%
if (nargin<=2)
    subdivs=3;
end
v=[1:subdivs^nc];
vc=reshape(v,[repmat(subdivs,1,nc),1]);
switch flip_type
    case 'none'
        permutes=vc(:);
    case 'flip_all'
        permutes=zeros(subdivs^nc,2);
        permutes(:,1)=vc(:);
        vc_flip=vc;
        for idim=1:nc
            vc_flip=flip(vc_flip,idim);
        end
        permutes(:,2)=vc_flip(:);
    case 'flip_each'
        permutes=zeros(subdivs^nc,2^nc);       
        %make a list of all subsets of [1:nc]
        is=[0 1]';
        for id=2:nc
            is=[[is;is],[zeros(2^(id-1),1); ones(2^(id-1),1)]];
        end
        for ip=1:2^nc
            vc_flip=vc;
            perm_list=find(is(ip,:)>0);
            for iflip=1:length(perm_list)
                vc_flip=flip(vc_flip,perm_list(iflip));
            end
            permutes(:,ip)=vc_flip(:);
        end
    case 'permute_d123'
        dm=min(nc,3);
        ds=[1:dm];
        ptable=perms(ds);
        if (nc>dm)
            ptable=[ptable repmat([dm+1:nc],[factorial(dm) 1])];
        end
        permutes=zeros(3^nc,factorial(dm));
        for ip=1:factorial(dm)
            vc_flip=vc;
            vc_flip=permute(vc_flip,ptable(ip,:));
            permutes(:,ip)=vc_flip(:);
        end
    otherwise
        permutes=[];
        disp(sprintf('unknown permutation type: %s',flip_type));
end
return
