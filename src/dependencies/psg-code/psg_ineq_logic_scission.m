function [partitions,tetra_table,psub,opts_used]=psg_ineq_logic_scission(ineq_type,opts)
% [partitions,tetra_table,psub,opts_used]=psg_ineq_logic_scission(ineq_type,opts) create a 3^12-element array 
% for the excluded inequalities for a tetrahedron of inequalities, based on scission
%
% addtree excluded if the rank order of the comparison of a with (c,d) differs from the rank order of the comparison of b with (c,d)
%
% ineq_type: currently unused, kept for compatibility with psg_ineq_logic_tetra
%   scissions: array of size [:,4] specifying, in each row, the vertices to be used
%     defaults to all unique [a b c d], with a<b, c<d
%   if_log=1 to log intermediate calculations
%
% partitions: an array of size repmat(3,1,12) of 0's and 1's, specifiying
%    the forbidden inequality combinations in a tetrahedron (1: forbidden) 
% tetra_table: array of size [12 3] indicating the triads for the 12 dimensions of partitions
% psub: masks corresponding to each scission (partitions is the AND of them)
% opts_used: options used
%
% See also:  PSG_INEQ_LOGIC, PSG_INEQ_TRIADS, PSG_INEQ_LOOKUP, PSG_INEQ_LOGIC_TETRA.
%
if (nargin<2)
    opts=[];
end
nv=4;
nc=nv*(nv-1)*(nv-2)/2; %number of triadic comparisons
scissions_def=nchoosek([1:nv],2); %choose any two 
scissions_comp=zeros(size(scissions_def));
for k=1:size(scissions_def,1)
    scissions_comp(k,:)=setdiff([1:nv],scissions_def(k,:));
end
scissions_def=[scissions_def,scissions_comp];
%
opts=filldefault(opts,'if_log',0);
opts=filldefault(opts,'scissions',scissions_def);
opts_used=opts;
%
tetra_table=psg_ineq_triads('tetra');
opts_used.tetra_table=tetra_table;
%
ns=size(opts.scissions,1);
%
if opts.if_log
    disp(sprintf('calculating scission logic with %2.0f scissions',ns));
end
partitions=zeros(repmat(3,1,nc)); %an nc-dimensional array
psub=cell(1,ns);
%
triads=psg_ineq_triads('tetra');
p_template=1-eye(3); %mask out if the two comparisons differ
for is=1:ns
    if opts.if_log
        disp(sprintf(' scission %2.0f: %1.0f %1.0f to %1.0f %1.0f',is,opts.scissions(is,:)));
    end
    %triadic comparisons
    ta=opts.scissions(is,[1 3 4]);
    [ta_ptr,ta_flip]=psg_ineq_lookup(tetra_table,ta);
    tb=opts.scissions(is,[2 3 4]);
    [tb_ptr,tb_flip]=psg_ineq_lookup(tetra_table,tb);
    if opts.if_log
        disp(sprintf(' triad 1: compare %1.0f(ref) with %1.0f and %1.0f found at row %2.0f, iflip %1.0f',ta,ta_ptr,ta_flip));
        disp(sprintf(' triad 2: compare %1.0f(ref) with %1.0f and %1.0f found at row %2.0f, iflip %1.0f',tb,tb_ptr,tb_flip));
    end
    p=p_template;
    %take into account order of comparison
    if (ta_flip~=tb_flip)
        p=fliplr(p); %if order of comparison differ, flip the sign
    end
    pbig=repmat(p,[1 1 repmat(3,1,nc-2)]);
    %put first two dimensions of pbig at dimensions ta_ptr and tb_ptr of psub{is}
    pm=zeros(1,nc);
    pm(ta_ptr)=1;
    pm(tb_ptr)=2;
    pm(pm==0)=[3:nc];
    psub{is}=permute(pbig,pm);
    if opts.if_log
        disp(pm);
    end
    partitions=partitions+psub{is};
end %is
partitions=double(partitions==ns); %only mask if all components are =1 
return
