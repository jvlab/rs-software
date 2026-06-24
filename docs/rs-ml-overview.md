This component of the package provides for visualization of representational spaces, manipulating them, and modeling relationships between them.

* Visualization: Plots of 2- and 3-dimensional representational spaces, and of 2- and 3-dimensional projections of higher-dimensional spaces, with many options for combined plots of multiple datasets.

    * Basic visualizations: `rs_disp_coordsets`
    * Visualizations for representational spaces whose domains are structured by `stimulus coordinates`: `rs_disp_enh_coordsets`

* Manipulation: Combining and transforming representational spaces 

    * Merging partially overlapping datasets: `rs_knit_coordsets`
    * Principal components analysis: `rs_xform_specify`
    * Applying linear and nonlinear transformations: `rs_xform_apply`

* Modeling relationships between representational spaces

    * Finding a consensus across multiple datasets: `rs_knit_coordsets`
    * Fitting linear and nonlinear geometric transformations to the relationship between two representational spaces: `rs_geofit`

* Utilities

    * Reading and importing: `rs_get_coordsets`, `rs_read_coorddata`, `rs_import_coordsets`
    * Writing: `rs_write_coorddata`
    * Extracting and concatenating datasets: `rs_extract_coordsets`, `rs_concat_coordsets`


