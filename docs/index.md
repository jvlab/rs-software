# Welcome to Representational Spaces software (rs-software)

## 

## Overview

This software package is a set of tools to construct and analyze representational spaces.

A "representational space" is a construct in which elements in a domain are points, and the distances between the points correspond to similarities in the space.

Often, representational spaces are constructed for perceptual domains: for example, colors, animals, musical instruments, etc., and are then referred to as "perceptual spaces." Representational spaces may also be constructed from neural data, e.g., fMRI or multineuronal recordings.

This software enables creation of representational spaces from similarity data, and once such spaces have been created, comparisons between spaces and assessment of models that relate one space to another.

As the appropriate number of dimensions for a representational space is typically unknown, the software is designed to process representations across a range of dimensions in parallel.

The software has two main entry points:

* Perceptual judgments
* Coordinate sets

    * inferred from perceptual judgments via other procedures, such as multidimensional scaling
    * obtained in any other way -- for example, from neural data or following a dimension-reduction technique such as principal components analysis

The software produces several kinds of outputs:

* Coordinate sets
* Visualization of representational spaces
* Geometric transformations between representational spaces

## Creating representational spaces from perceptual judgments

Two kinds of paradigms are supported

* "triadic" judgments:  is A or B more similar to S?
* "tetradic" judgments: which is more similar: A and B, or C and D?"

The main outputs are files containing sets of coordinates and the associated metadata, which embody a  `dataset structure`, along with statistics to assess the goodness of fit of the model.

This component is written in Python.  It may be run from a MATLAB/Octave environment as shown here ??

Key demos are ??

## Manipulating representational spaces

The primary input is the `dataset structure`.

The key operations that are performed are

* Combining representational spaces from multiple sources (`rs_knit_coordsets`)

    * finding a consensus space across several sources
    * knitting together spaces with partially overlapping elements

* Visualizations ('rs_disp_coordsets`)
* Modeling transformations between perceptual spaces: affine, projective, piecewise affine (`rs_geofit`)
* Statistics related to these operations

This component is written in MATLAB, and is Octave-compatible.  It may be run from a Python environment as shown here ??

## Credits and feedback

Jonathan Victor <jdvicto@med.cornell.edu> (please direct feedback)

Suniyya Waraich <swaraich@ucdavis.edu>

Guillermo Aguilar <guillermo.aguilar@mail.tu-berlin.de>

