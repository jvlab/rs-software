# rs-software

**Tools to construct and analyze representational spaces.**


A "representational space" is a construct in which elements in a domain are points, and the
distances between the points correspond to dis-similarity. Often, representational spaces are
constructed for perceptual domains: for example, colors, animals, musical instruments, etc., and
are then referred to as "perceptual spaces." Representational spaces may also be constructed from
neural data, e.g., fMRI or multineuronal recordings.

The package has two main components that may be used together or independently.

* One component enables creation of representational spaces from similarity data; its output
  consists of coordinate sets, metadata, and statistics. Implementations are provided in
  [Python](https://jvlab.github.io/rs-software/rs-py-overview/), via a
  [Matlab wrapper over Python code](https://jvlab.github.io/rs-software/python-matlab-octave/#running-python-inside-matlab).
  Web-based access to the Python tools (no installation required) is also available.
* A second component of the software consists of tools to analyze, manipulate, and compare
  representational spaces. While it is designed to operate on the outputs of the first
  component, it functions independently, and can readily import coordinate data and metadata
  from another source. As the appropriate number of dimensions for a representational space is
  typically unknown, the software is designed to process representations across a range of
  dimensions in parallel. Implementations are available in
  [Matlab](https://jvlab.github.io/rs-software/rs-ml-overview/) or via a
  [Python wrapper over Matlab code](https://jvlab.github.io/rs-software/python-matlab-octave/#running-matlab-inside-python).
* In addition, tools are available for analysis of the perceptual judgments directly. These
  include a comparison of the perceptual judgments via the representational spaces they
  generate, and analyses of statistics of triadic judgments.


## Requirements, Installation and Usage

**See full documentation:** [https://jvlab.github.io/rs-software/](https://jvlab.github.io/rs-software/)


## Contact

Jonathan D. Victor, Weill Cornell Medicine.
Guillermo Aguilar, Technische Universität Berlin
