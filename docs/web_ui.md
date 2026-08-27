# Web-based interfaces

A browser-based graphical interface for representational similarity tools, built with [Streamlit](https://streamlit.io).
No coding required — upload your files, set parameters, and download results.

## Live apps

| App | URL | Description |
|---|---|---|
| Surrogate MDS + Conversion tools | [mds-app.streamlit.app](https://mds-app-hbl7gjkk5xukwuxovchox3.streamlit.app/) | Main interface: analysis, mat→numpy, OOO→triadic |
| Choice → Coordinates | [choice2coord.streamlit.app](https://choice2coord.streamlit.app/) | Fit MDS coordinates from a choice file |

> Note: apps may be asleep if inactive — click the link and wait a moment for them to wake up.

## Running locally

```bash
cd rs-software
pip install streamlit plotly pandas matplotlib scikit-learn
streamlit run app.py
```

Then open `http://localhost:8501` in your browser.

---

## Tabs

### Surrogate MDS Analysis

Compare two choice datasets and test whether the difference in their perceptual maps is statistically meaningful.

**How to use:**
1. Upload two `.mat` choice files (or enter their file paths)
2. Set dimensions, number of surrogates, and resampling method
3. Click **Run analysis**

**Output:**
- Log-likelihood and Procrustes disparity for each dataset
- Convergence plot (log-likelihood per iteration)
- Null distribution of surrogate disparities vs. real disparity
- p-value: fraction of surrogates with disparity ≥ real

**Resampling methods:**

| Method | Description |
|---|---|
| With replacement | Draw observations with replacement from pooled data (default) |
| Without replacement | Draw without replacement from pooled data |
| Without replacement, paired | Draw without replacement, keeping A and B draws non-overlapping |

---

### Convert .mat → NumPy

Convert a `.mat` triadic choice file to a 5-column NumPy array.

**Output columns:** `ref, s1, s2, N(s1 chosen), N_repeats` (1-indexed)

**How to use:**
1. Upload a `.mat` choice file
2. Preview the array in the browser
3. Download as `.npy`

---

### Choice → Coordinates

Fit an MDS perceptual map from a choice file and download the result as a coordinates `.mat` file.

**How to use:**
1. Upload a `.mat` choice file
2. Set max iterations and learning rate
3. Click **Fit coordinates (1–7D)**

**Output `.mat` fields:**

| Field | Size | Description |
|---|---|---|
| `dim1` | n_stim × 1 | Coordinates for 1D model |
| `dim2` | n_stim × 2 | Coordinates for 2D model |
| ... | ... | ... |
| `dim7` | n_stim × 7 | Coordinates for 7D model |
| `rawLLs` | 1 × 7 | Raw log-likelihood for each model |
| `bestModelLL` | 1 × 1 | Log-likelihood of best model |
| `stim_labels` | n_stim | Stimulus names |

Note: `biasEstimate` and `debiasedRelativeLL` are not computed by this interface (requires bias-estimation simulation files).

---

### OOO → Triadic

Convert an odd-one-out `.mat` file to standard triadic choice format.

Each OOO judgment generates exactly 2 triadic entries using JV's conversion rule:
if X is chosen as odd one out from (X, Y, Z), this yields `ref=Y, chosen=Z` and `ref=Z, chosen=Y`.

**Input format:** `s1, s2, s3, N(s1 odd out), N(s2 odd out), N(s3 odd out)`

**Output format:** `ref, s1, s2, N(s1 chosen), N_repeats`

**How to use:**
1. Upload an OOO `.mat` file
2. Preview the converted triadic table
3. Download as `.mat`

The output file can be used directly in the **Surrogate MDS Analysis** or **Choice → Coordinates** tabs.
