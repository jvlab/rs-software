# File conversion — Streamlit option

Browser-based converters — no installation required. Each conversion tool is now its own
standalone app.

## Live apps

| App | URL | File |
|---|---|---|
| Convert .mat → NumPy | [mds-app-matnpy.streamlit.app](https://mds-app-matnpy.streamlit.app) | `app_matnpy.py` |
| OOO → Triadic | [ooo-triadic.streamlit.app](https://ooo-triadic.streamlit.app) | `app_ooo.py` |
| Choice → Coordinates | [choice2coord.streamlit.app](https://choice2coord.streamlit.app/) | `run_model_fitting_ui.py` |

> Note: apps may be asleep if inactive — click the link and wait a moment for them to wake up.

## Running locally

```bash
cd rs-software
pip install streamlit plotly pandas matplotlib scikit-learn
streamlit run app_matnpy.py       # or app_ooo.py, or run_model_fitting_ui.py
```

---

## Convert .mat → NumPy

Convert a `.mat` triadic choice file to a 5-column NumPy array.

**Output columns:** `ref, s1, s2, N(s1 chosen), N_repeats` (1-indexed)

1. Upload a `.mat` choice file
2. Preview the array in the browser
3. Download as `.npy`

---

## OOO → Triadic

Convert an odd-one-out `.mat` file to standard triadic choice format.

Each OOO judgment generates exactly 2 triadic entries: if X is chosen as odd one out from
(X, Y, Z), this yields `ref=Y, chosen=Z` and `ref=Z, chosen=Y`.

**Input format:** `s1, s2, s3, N(s1 odd out), N(s2 odd out), N(s3 odd out)`

**Output format:** `ref, s1, s2, N(s1 chosen), N_repeats`

1. Upload an OOO `.mat` file
2. Preview the converted triadic table
3. Download as `.mat`

The output file can be used directly in the **Comparing RS** or **Choice → Coordinates** tools.

---

## Choice → Coordinates

Fit an MDS perceptual map from a choice file and download the result as a coordinates `.mat` file.

1. Upload a `.mat` choice file
2. Set dimension range, max iterations, and random seed mode
3. Click **Run MDS**

**Output `.mat` fields:**

| Field | Size | Description |
|---|---|---|
| `dim1`...`dimN` | n_stim × N | Coordinates for each fitted dimension |
| `rawLLs` | 1 × N | Raw log-likelihood for each model |
| `bestModelLL` | 1 × 1 | Log-likelihood of best possible model |
| `randModelLL` | 1 × 1 | Log-likelihood of random-choice model |
| `biasEstimate` | 1 × N | Median bias estimate per dimension |
| `debiasedRelativeLL` | 1 × N | `rawLLs + biasEstimate - bestModelLL` |
| `stim_list` | n_stim | Stimulus names |

**Random seed:** choose "Random each run" for normal use, or "Same every run" / "Custom offset"
for a reproducible result — useful when checking output against a benchmark.

For the equivalent Python functions, see [File conversion → Python option](file-conversion-python.md).
