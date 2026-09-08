# File conversion — Python option

Utility functions for converting between the file formats used across this toolkit. See
[Installation](install-comparing-conversion.md) to set this up.

## `mat_to_numpy` — Load choice file as NumPy array

Loads a `.mat` triadic choice file and returns a 5-column NumPy array.

**Columns:** `ref, s1, s2, N(s1 chosen), N_repeats` (1-indexed)

```python
from rs_tools import mat_to_numpy

array, stim_list = mat_to_numpy("bgca3pt_choices_MC_sess01_10.mat")
print(array.shape)   # (n_trials, 5)
print(stim_list[:5]) # stimulus names
```

## `numpy_to_mat` — Save NumPy array as choice file

Converts a 5-column NumPy array back to `.mat` triadic choice format.

```python
from rs_tools import numpy_to_mat

numpy_to_mat(array, "output_choices.mat", stim_list=stim_list)
```

## `ooo_to_triadic` — Convert odd-one-out to triadic format

Converts an odd-one-out `.mat` file to standard triadic choice format. Each OOO judgment
generates exactly 2 triadic entries.

**Input format:** `s1, s2, s3, N(s1 odd out), N(s2 odd out), N(s3 odd out)`

**Output format:** `ref, s1, s2, N(s1 chosen), N_repeats`

```python
from rs_tools import ooo_to_triadic

resp, rep, stim_list = ooo_to_triadic("ooo_choices.mat", out_path="triadic_choices.mat")
print(f"{len(resp)} triadic trials from OOO data")
```

## Choices → Coordinates

Fits an MDS perceptual map from a choice file. See `fit_brightness_ooo.run_mds_single_dim` and
`build_mat_output` for the underlying functions, or
[File conversion → Streamlit option](file-conversion-streamlit.md) for the no-code version.

For the full function reference, see [File conversion → Function reference](function-index-python.md).
