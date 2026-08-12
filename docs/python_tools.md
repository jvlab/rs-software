# Python Tools

Utility modules for converting and analyzing representational similarity (RS) choice data.
These tools are available as the [`jvlab-rs`](https://pypi.org/project/jvlab-rs/) package on PyPI.

## Installation

```bash
pip install jvlab-rs
```

Or use directly from the `rs-software` repository:

```bash
cd rs-software
pip install -e .
```

---

## `mat_to_numpy` — Load choice file as NumPy array

Loads a `.mat` triadic choice file and returns a 5-column NumPy array.

**Columns:** `ref, s1, s2, N(s1 chosen), N_repeats` (1-indexed)

```python
from rs_tools import mat_to_numpy

array, stim_list = mat_to_numpy("bgca3pt_choices_MC_sess01_10.mat")
print(array.shape)   # (n_trials, 5)
print(stim_list[:5]) # stimulus names
```

---

## `numpy_to_mat` — Save NumPy array as choice file

Converts a 5-column NumPy array back to `.mat` triadic choice format.

```python
from rs_tools import numpy_to_mat

numpy_to_mat(array, "output_choices.mat", stim_list=stim_list)
```

---

## `ooo_to_triadic` — Convert odd-one-out to triadic format

Converts an odd-one-out `.mat` file to standard triadic choice format using JV's conversion rule.
Each OOO judgment generates exactly 2 triadic entries.

**Input format:** `s1, s2, s3, N(s1 odd out), N(s2 odd out), N(s3 odd out)`

**Output format:** `ref, s1, s2, N(s1 chosen), N_repeats`

```python
from rs_tools import ooo_to_triadic

resp, rep, stim_list = ooo_to_triadic("ooo_choices.mat", out_path="triadic_choices.mat")
print(f"{len(resp)} triadic trials from OOO data")
```

---

## `compare` — Surrogate MDS comparison

Runs a full surrogate MDS comparison between two choice datasets and returns a p-value.

```python
from rs_tools.compare import compare
from rs_tools import mat_to_numpy
from src.rs_py.utils.util import load_choices

# load two datasets
resp1, rep1, _, stims1 = load_choices("choices_A.mat")
resp2, rep2, _, stims2 = load_choices("choices_B.mat")

result = compare(resp1, rep1, stims1, resp2, rep2, stims2,
                 dim=3, n_surrogates=100)

print("p-value:", result['p_value'])
print("Real disparity:", result['real_disparity'])
print("Surrogate mean:", result['surrogate_mean'])
```

### Resampling methods

| Method | Description |
|---|---|
| `with_replacement` | Draw observations with replacement (default) |
| `without_replacement` | Draw without replacement from pooled data |
| `without_replacement_paired` | Draw without replacement, keeping A and B draws non-overlapping |

```python
result = compare(resp1, rep1, stims1, resp2, rep2, stims2,
                 dim=3, n_surrogates=100,
                 method='without_replacement_paired')
```

---

## Streamlit UI

A graphical interface for all tools is available:

```bash
cd rs-software
streamlit run app.py
```

Tabs:
- **Surrogate MDS Analysis** — upload two choice files, run comparison, view p-value and null distribution
- **Convert .mat → NumPy** — upload a choice file, preview the array, download as `.npy`
- **Choice → Coordinates** — fit an MDS model and download the coordinate file
- **OOO → Triadic** — convert odd-one-out data to triadic format
