# File formats, data structures, and other key elements

## Choice file

A `choice file` is a .mat file that contains a set of similarity comparisons, typically collected in a psychophysical experiment.
It contains three variables: 'stim\_list', 'responses', and 'responses_colnames'.  'stim\_list' is a character array in which each row is a unique stimulus label.

File names should contain the string '\_choices\_', preceded by a designation of the domain or paradigm, and followed by an identifier for the subject or data source.

Two options are available for 'responses' and 'responses_colnames':

* triadic comparisons

    * The first three columns of 'responses' are the 1-based indices into stim\_list of the reference stimulus and two comparison stimuli (s1 and s2).
    * Column 4 of 'responses' is the number of times that s1 is judged more dis-similar to the reference than s2
    * Column 5 of 'responses' is the number of times the triad is presented
    * 'responses_colnames' are text strings that label these columns

* tetradic comparisons

    * The first four columns of 'responses' are the 1-based indices into stim\_list for the stimuli s1, s2, s3, and s4 in the comparison
    * Column 5 of 'responses' is the number of times that s1 and s2 are judged more dis-similar than s3 and s4
    * Column 6 of 'responses' is the number of times the tetrad is presented
    * 'responses_colnames' are text strings that label these columns

See samples/animals/image\_choices\_S\*.mat or samples/bwtextures/bgca3pt\_choices\_\*\_sess01\_10.mat for examples of triadic comparisons, and see samples/bwtextures/bgca3pt\_choices\_\*-gp\_sess01\_20.mat for examples of tetradic comparisons.

## Coordinate file

A `coordinate file` is a .mat file that contains sets of coordinates for the elements of a representational space. It contains a variable 'stim\_labels', a character array in which each row is a unique stimulus label. This corresponds to the `stim\_list` variable in a `choice file`, but the stimuli need not be listed in the same order. A `coordinate file` also contains one or more variables with names such as 'dim1', 'dim2', ..., 'dim10'. 'dim[k]' specifies the k-dimensional representational space:  each row corresponds to a stimulus in `stim\_labels`; the k columns are the k coordinate values.

File names should contain the string '\_coords\_', preceded by a designation of the domain or paradigm, and followed by an identifier for the subject or data source.

Optional variables (produced by the modeling of choice data by this package but not required) are:

* rawLLs: log(2) likelihood of the observed responses for each of k-dimensional models, uncorrected for overfitting
* bestModelLL: log(2) likelihood of the observed responses, given a model that exactly matches the observed choice probabilities but is geometrically unconstrained
* debiasedRelativeLL: relative log(2) likelihood, compared to bestModelLL, after correction for overfitting: debiasedRelativeLL = (rawLLs + biasEstimate) - bestModelLL
* biasEstimate: overfitting bias estimate
* metadata: summary of the above description

See samples/animals/image\_coords\_S\*.mat for examples that contain these optional variables, and samples/bwtextures/bgca3pt\_cooords\_\*\_sess01\_10.mat for examples that do not.


## Dataset structure

A `dataset structure` is a container for representational spaces to be analyzed in parallel -- for example, determining a consensus between them via `rs_knit_coordsets`, visualizing them via `rs_disp_coordsets`, or transforming them via `rs_apply_xform'. 

It consists of three components:  a `coordinate structure` ('ds'), a `stimulus metadata structure` ('sas'), and a `set metadata structure` ('sets'), each of which is a MATLAB cell array with the same number of records.  A single record contains the coordinates and metadata for a representational space models of one or more dimensions, all derived from a common dataset.

Typically a `dataset structure` is created by reading one or more `coordinate files` via `rs_get_coordsets`, a single `coordinate file` via `rs_read_coorddata`, or imported from coordinate arrays with user-supplied metadata via `rs_import_coordsets`.

* ## Coordinate structure

    * For each record, 'ds{irec}', is a cell array in which 'd{irec}{k}' contains the coordinates for the k-dimensional model, as contained in the `coordinate file`. d{irec}{k} may be empty ('[]') if no model is available. 


* ## Stimulus metadata structure

    * This contains the metadata that defines the stimulus set, and, optionally, data related to the analysis of 'choice files'.  For each record, 'sas{irec}' has the following fields:

        * nstims: number of stimuli
        * typenames: a 1-D cell array of stimulus labels.  Entries will match 'stim\_labels' in the `coordinate file` that was used to create the `dataset structure`.
        * type\_coords: a 2-D array of `stimulus coordinates`, if the domain has a priori coordinates; typically empty if not. See `stimulus coordinates` for further details.
        * the optional variables *LL* and metadata from a `coordinate file`


* ## Set metadata structure

    * This contains dataset origin.  For each record, 'sets{irec}' has the following fields:

        * dim\_list: list of available dimensions in ds{irec}
        * nstims: number of stimuli
        * label\_long: long file name, typically full file name and path
        * label: shortened file name, suitable for display
        * paradigm_name: a designator such as 'cars' or 'animals'
        * paradigm_type: overall paradigm category; may be the same as paradigm_name
        * subj\_ID: unique subject identifier
        * subj\_ID_short: short form of subject identifier, suitable for display
        * pipeline: structure describing the processing stages leading to this record

For an example of a `dataset structure` with one record and without `stimulus coordinates`, run the demo `rs_read_coorddata_demo_cars` and look at 'data_out'.
For an example of a `dataset structure` with three records and with `stimulus coordinates`, run the demo `rs_read_coorddata_demo_opposites` and look at 'data_out'.

## Stimulus coordinates

examples of simple; mention binary texture coordinates
## Ray structure

This contains metadata specifying rays (stimuli that lie on an approximate straight line from the origin) and
rings (stimuli that lie in a plane at approximate equal distances from the origin).

Options

created by rs\_findrays

...

## Transformation structure

Very rough:

These are the structures created by `rs\_geofit.m` and `rs\_xform\_specify`, and applied by `rs\_xform\_apply`.
They are linear transformations and several generalizations.



%       - affine: \[output(istim,:)]=ts.b \* \[input(istim,:)] \* ts.T + ts.c;
%       where size(b)=1, size(T)=\[idim,idim], and size(c)=\[1 idim]. If these fields are not present and xform.class='affine', then
%       alternative parameter names are allowed: 'scaling' for b, 'orthog' for T, and 'translation' for c.
%       This allows for compatibility with the transformations produced by `procrustes\_consensus`.

%       - procrustes: same as affine, but ts.b=1 and abs(det(T))=1.  *These are not checked.*
%       - mean: same as affine, but ts.b=1, T=0. *These are not checked.*
%       - projective: affine parameters and also p, size \[isim 1]. p=0
%       reduces to affine.  See `transformation structure` for further details.
%       - pwaffine (piecewise affine): b as in affine.  T has size \[idim idim 2^ncuts] and c
%       has size \[2^nchuts idim], specifying the affine transformation on
%       each cut. vcut has size \[ncuts idim], each row is a unit vector,
%       orthogonal to the cutplanes. acut has size \[1 2^ncuts], specifying the cutpoints.
%       See `transformation structure` for further details.
%       - pwprojective (piecewise projective): parameters as in pwaffine, and also p, of size \[idim, 2^ncuts], used as in projective for each component
%       See `transformation structure` for further details.

%
% Definitions and parameters for the other classes, in addition to b, T, and c.
% All must be supplied in xforms.ts{k}{idim}
%
%   projective: p: column vector of length idim
%     The transformation adjoins a final 1 to each row of coordinates, and then applies the transformation.
%       \[bT| p]
%       \[-----]
%       \[c | 1]
%    to each row of the coordinates producing coordinates of dimension idim+1. These are then divided by the final column.
%    So if p=zero, then this reduces to an affine transformation , then divided by the final colummn
%
%   pwaffine (piecewise affine)
%    T: is a stack of matrices, size \[idim idm 2^ncuts], where ncuts is the number of cuts
%      often ncuts=1, but in general, to transform a vector x:
%      let sign\_vecs=sign(x\*vcut'-a), of size \[npts,ncuts] (with equality going to 1)
%      consider each row of sign\_vecs:
%      sign\_ind=1       for sign\_vec=\[+ + .... +]
%      sign\_ind=2       for sign\_vec=\[- + .... +]
%      sign\_ind=3       for sign\_vec=\[+ - .... +]
%      sign\_ind=4       for sign\_vec=\[- - .... +]
%         ....
%      sign\_ind=2^ncuts for sign\_vec=\[- - .... -]
%      Then the transform used for x is T(:,:,sign\_ind) for transformation
%   c: stack of offsets, size \[2^ncuts idim], use (sign\_ind,:)
%   vcut: unit vectors, stack of rows, size \[ncuts dim\_x], orthog to cut planes
%   acut: vector of length ncuts, the cutpoints
%      \[y,sign\_vecs,sign\_inds,ypw,unsign\_vecs]=psg\_pwaffine\_apply(ts{:},x)
%  
%  pwprojective (piecewise projective)
%
% x: original coordinates, size=\[npts,dim\_x]
%   T as in pwaffine
%   b as in pwaffine
%   c as in pwaffine
%   vcut as in pwaffine
%   acut as in pwaffine
%   p: an array of size \[idim, 2^ncuts], used as in projective; p(:,sign\_ind) is used along with T(:,:,sign\_ind)
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

## Animal domain

Very rough:

Briefly introduce the animal domain
Provide pointers to J Neurosci



<figure markdown="span">
  !\[Animal domain](images/animal\_domain\_fig1\_jneuro.jpg){ width="400" }
  <figcaption>Stimuli from the animal domain. Taken from Waraich \& Victor (2024).</figcaption>
</figure>



## MPI faces domain

Very rough:

Introduce the coordinates

%Ebner, N. C., Riediger, M., \& Lindenberger, U. (2010). FACES—A database of facial expressions in young, middle-aged, and older women and men:
% Development and validation. Behavior Research Methods, 42, 351-362. doi:10.3758/BRM.42.1.351.

...



## Setup metadata

for Binary texture domain
or if configured

## Quadratic form model

