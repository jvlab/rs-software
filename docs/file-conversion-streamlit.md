# File conversion — Python tools UI (web-based)

Browser-based converters — no installation required to use the hosted versions below. Each
conversion tool is its own standalone app.

## Live apps

| App | URL | File |
|---|---|---|
| Convert .mat → NumPy | [mds-app-matnpy.streamlit.app](https://mds-app-matnpy.streamlit.app) | `app_matnpy.py` |
| Convert NumPy → .mat | [appnumpytomatpy-dcahmfdqvuqdzyyza3ddyy.streamlit.app](https://appnumpytomatpy-dcahmfdqvuqdzyyza3ddyy.streamlit.app/) | `app_numpy_to_mat.py` |
| OOO → Triadic | [ooo-triadic.streamlit.app](https://ooo-triadic.streamlit.app) | `app_ooo.py` |

> Note: apps may be asleep if inactive — click the link and wait a moment for them to wake up.
> The hosted versions run on limited, shared resources — best for small datasets and a quick
> look, not a final fit.

## Running locally

Faster than the hosted versions, and not limited by their shared resources:

```bash
cd rs-software
pip install streamlit plotly pandas matplotlib scikit-learn
streamlit run app_matnpy.py       # or app_numpy_to_mat.py, app_ooo.py
```

---

## Convert .mat → NumPy

Convert a `.mat` file to a NumPy array. Works with either a **choices** file (raw pairwise
judgments) or a **coordinates** file (the output of a model fit) — the tool detects which one
you uploaded automatically, so you don't need to tell it which kind of file it is.

**Choices file → output columns:** `ref, s1, s2, N(s1 chosen), N_repeats` (1-indexed)

**Coordinates file → output:** an `(n_stimuli, dim)` array of the fitted coordinates. If the file
has more than one fitted dimensionality (e.g. both a 2D and a 3D fit saved together), you'll be
asked which one to export.

1. Upload a `.mat` file (choices or coordinates)
2. Preview the array in the browser
3. Download as `.npy`

---

## Convert NumPy → .mat

Convert a 5-column NumPy choice array back into a `.mat` choice file — the reverse of the
tool above.

**Input columns:** `ref, s1, s2, N(s1 chosen), N_repeats` (1-indexed)

1. Upload a `.npy` choice array
2. Optionally provide stimulus names (typed, uploaded as a text file, or skipped — falls
   back to generic names like `stim_01`)
3. Preview the array in the browser
4. Download as `.mat`

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

The output file can be used directly in the **Comparing RS** or
[Choice → Coordinates](rs-py-choice-to-coords-streamlit.md) tools.

---

## Choice → Coordinates has moved

Fitting coordinates from a choice file is now documented under
[Creating RS → Choice → Coordinates](rs-py-choice-to-coords-streamlit.md), alongside the other
ways to create a representational space from perceptual judgments.
