# Python Tools

This page documents the Python utilities built for converting, analyzing, and visualizing representational similarity choice data. All tools are available as part of the `rs_tools` package and as tabs in the Streamlit web app.

---

## Installation

Clone the repository and install the package locally:

```bash
git clone https://github.com/jvlab/rs-software.git
cd rs-software
pip install -e .
```

To also install the web app dependencies:

```bash
pip install -e ".[ui]"
```

---

## Web App (Streamlit UI)

The Streamlit app provides a graphical interface for all tools — no terminal required.

```bash
cd rs-software
streamlit run app.py
```

Then open **http://localhost:8501** in your browser. The app has three tabs:

| Tab | What it does |
|---|---|
| **Surrogate MDS Analysis** | Compare two choice files — fits perceptual maps, runs surrogate null distribution, computes p-value |
| **Convert .mat → NumPy** | Upload a choices `.mat` file and download it as a `.npy` array |
| **Choice → Coordinates** | Upload a choices `.mat` file, fit an MDS perceptual map, download the coordinates as `.mat` |

---

## Modules

### `ooo_to_triadic` — Odd-one-out to triadic conversion

Converts raw odd-one-out (OOO) choice data to standard triadic choice format.

**Background:** In the OOO paradigm, a subject sees three stimuli and picks the most different one. Each judgment is converted into two triadic entries using JV's rule:

> If X is the odd one out from (X, Y, Z), then Y and Z are closer to each other than to X.
> This means: ref=Y → Z chosen; ref=Z → Y chosen.

Non-ref stimuli are sorted alphabetically following Suniyya's `standardize_comparison_keys` convention.

**Input `.mat` columns:** `s1, s2, s3, N(s1 odd), N(s2 odd), N(s3 odd)`

**Output `.mat` columns:** `ref, s1, s2, N(s1 chosen), N_repeats`

**Python usage:**

```python
from rs_tools import ooo_to_triadic

resp, rep, stim_list = ooo_to_triadic("ooo_choices.mat", out_path="triadic_choices.mat")
```

**Command line:**

```bash
python3 convert_ooo_to_triadic.py path/to/ooo_choices.mat output_triadic.mat
```

---

### `mat_to_numpy` — Choice `.mat` to NumPy array

Loads a triadic choice `.mat` file and returns a 5-column NumPy array.

**Output columns (1-indexed):**

| Column | Name | Description |
|---|---|---|
| 0 | `ref` | Reference stimulus index |
| 1 | `s1` | Stimulus 1 index |
| 2 | `s2` | Stimulus 2 index |
| 3 | `N(s1 chosen)` | Times s1 was chosen over s2 |
| 4 | `N_repeats` | Total trials for this comparison |

**Python usage:**

```python
from rs_tools import mat_to_numpy

array, stim_list = mat_to_numpy("bgca3pt_choices_MC_sess01_10.mat")
print(array.shape)   # (n_trials, 5)
print(stim_list[:5]) # ['bp0400', 'bp0800', ...]
```

**Command line:**

```bash
python3 convert_mat_to_numpy.py choices.mat output.npy
```

---

### `numpy_to_mat` — NumPy array to choice `.mat`

Converts a 5-column NumPy array back to a `.mat` triadic choice file. Stimulus names are optional — auto-generated as `stim_01, stim_02, ...` if not provided.

**Python usage:**

```python
from rs_tools import numpy_to_mat
import numpy as np

array = np.load("choices.npy")
stim_list = ["bp0400", "bp0800", "bp1600"]  # optional
numpy_to_mat(array, stim_list=stim_list, out_path="choices_out.mat")
```

**Command line:**

```bash
python3 convert_numpy_to_mat.py input.npy output.mat
python3 convert_numpy_to_mat.py input.npy output.mat --stims stim_list.txt
```

---

### `compare` — Surrogate MDS comparison pipeline

Fits perceptual maps to two choice datasets using MDS and computes a p-value for the Procrustes disparity between them via surrogate resampling.

**Three resampling methods:**

| Method | Description |
|---|---|
| `with_replacement` | Bootstrap — draw trials with replacement from the pooled dataset |
| `without_replacement` | Permutation — draw without replacement |
| `without_replacement_paired` | Paired permutation — draw for dataset A first, then B from what remains (strictest) |

**Python usage:**

```python
from rs_tools.compare import compare
from src.rs_py.utils.util import load_choices

resp1, rep1, _, stims1 = load_choices("bgca3pt_choices_MC-br_sess01_10.mat")
resp2, rep2, _, stims2 = load_choices("bgca3pt_choices_MC_sess01_10.mat")

result = compare(
    resp1, rep1, stims1,
    resp2, rep2, stims2,
    dim=3,
    n_surrogates=100,
    resample_method='without_replacement_paired',
    use_warm_start=True,
)

print(f"Real disparity: {result['real_disp']:.4f}")
print(f"p-value:        {result['p_value']:.4f}")
```

**Result dict keys:**

| Key | Description |
|---|---|
| `real_disp` | Procrustes disparity between the two real maps |
| `surrogate_disparities` | Array of surrogate disparities (null distribution) |
| `p_value` | Fraction of surrogates with disparity ≥ real |
| `real_ll1` / `real_ll2` | Log-likelihood per trial for each dataset |
| `n_shared` | Number of shared stimuli used for alignment |

---

## Experimental Results

Results from running all 3 comparisons x 3 resampling methods in 3D with 100 surrogates, 200 surrogate iterations, and warm start:

| Comparison | What it tests | Real disparity | Surrogate mean | p-value | Significant? |
|---|---|---|---|---|---|
| MC-BR vs MC | Same subject, same stimuli, different task | 0.0516 | ~0.009 | 0.0000 | Yes |
| MC bgca vs MC bdce | Same subject, different stimulus set, same task | 0.0847 | ~0.088 | ~0.92 | No |
| MC vs BL bgca | Different subjects, same stimuli, same task | 0.0522 | ~0.008 | 0.0000 | Yes |

Results are consistent across all 3 resampling methods.
