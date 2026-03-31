# Data structures

## Dataset structure 

Here description of what a dataset structure is. It can include visualizations 
or code blocks.


## Coordinate structure 

Same here...

## Ray structure

...
## Stimulus metadata structure 

...

## Set metadata structure 

...

## Transformation structure 

Very rough:

These are the structures created by `rs_geofit.m` [how to hyperlink?] and `rs_xform_specify` [how to hyperlink?] , and applied by `rs_xform_apply` [how to hyperlink?] .
They are linear transformations and several generalizations.


%       - affine: [output(istim,:)]=ts.b * [input(istim,:)] * ts.T + ts.c;
%       where size(b)=1, size(T)=[idim,idim], and size(c)=[1 idim]. If these fields are not present and xform.class='affine', then
%       alternative parameter names are allowed: 'scaling' for b, 'orthog' for T, and 'translation' for c.
%       This allows for compatibility with the transformations produced by `procrustes_consensus`.

%       - procrustes: same as affine, but ts.b=1 and abs(det(T))=1.  *These are not checked.*
%       - mean: same as affine, but ts.b=1, T=0. *These are not checked.*
%       - projective: affine parameters and also p, size [isim 1]. p=0
%       reduces to affine.  See `transformation structure` for further details.
%       - pwaffine (piecewise affine): b as in affine.  T has size [idim idim 2^ncuts] and c
%       has size [2^nchuts idim], specifying the affine transformation on
%       each cut. vcut has size [ncuts idim], each row is a unit vector,
%       orthogonal to the cutplanes. acut has size [1 2^ncuts], specifying the cutpoints.
%       See `transformation structure` for further details.
%       - pwprojective (piecewise projective): parameters as in pwaffine, and also p, of size [idim, 2^ncuts], used as in projective for each component
%       See `transformation structure` for further details. 

%
% Definitions and parameters for the other classes, in addition to b, T, and c.
% All must be supplied in xforms.ts{k}{idim}
%
%   projective: p: column vector of length idim
%     The transformation adjoins a final 1 to each row of coordinates, and then applies the transformation.
%       [bT| p]
%       [-----]
%       [c | 1]
%    to each row of the coordinates producing coordinates of dimension idim+1. These are then divided by the final column.
%    So if p=zero, then this reduces to an affine transformation , then divided by the final colummn
%
%   pwaffine (piecewise affine)
%    T: is a stack of matrices, size [idim idm 2^ncuts], where ncuts is the number of cuts
%      often ncuts=1, but in general, to transform a vector x:
%      let sign_vecs=sign(x*vcut'-a), of size [npts,ncuts] (with equality going to 1)
%      consider each row of sign_vecs:
%      sign_ind=1       for sign_vec=[+ + .... +]
%      sign_ind=2       for sign_vec=[- + .... +]
%      sign_ind=3       for sign_vec=[+ - .... +]
%      sign_ind=4       for sign_vec=[- - .... +]
%         ....
%      sign_ind=2^ncuts for sign_vec=[- - .... -]
%      Then the transform used for x is T(:,:,sign_ind) for transformation
%   c: stack of offsets, size [2^ncuts idim], use (sign_ind,:)
%   vcut: unit vectors, stack of rows, size [ncuts dim_x], orthog to cut planes
%   acut: vector of length ncuts, the cutpoints
%      [y,sign_vecs,sign_inds,ypw,unsign_vecs]=psg_pwaffine_apply(ts{:},x) 
%      
%  pwprojective (piecewise projective)
%
% x: original coordinates, size=[npts,dim_x]
%   T as in pwaffine
%   b as in pwaffine
%   c as in pwaffine
%   vcut as in pwaffine
%   acut as in pwaffine
%   p: an array of size [idim, 2^ncuts], used as in projective; p(:,sign_ind) is used along with T(:,:,sign_ind)
%
%Remember to indicate that the parametric description of a transformation is not unique -- T can be multipled by a constant K, and b divided by K^(-idim), for example
%Remember to indicate taht continuity at cutponts is not checked.


...

## Stimulus coordinates
Very rough:

Here describe the idea of conceptual coordinates

...

## Ray structure
Very rough:

Here describe rays, rings, nearest neighhbors, and how they are found and used

...

## Binary texture domain
Very rough:

Briefly introduce the textuers and the coordinates
Provide pointers to literature

...

