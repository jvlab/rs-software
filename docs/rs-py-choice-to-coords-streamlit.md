# Choice → Coordinates — Python tools UI (web-based)

Fit an MDS perceptual map from a choice file and download the result as a coordinates `.mat`
file — no installation required to use the hosted version below.

## Live app

| App | URL | File |
|---|---|---|
| Choice → Coordinates | [choicetocoord.streamlit.app](https://choicetocoord.streamlit.app/) | `run_model_fitting_ui.py` |

> Note: the app may be asleep if inactive — click the link and wait a moment for it to wake up.
> The hosted version runs on limited, shared resources — best for small datasets and a quick
> look, not a final fit.

## Running locally

Faster than the hosted version, and not limited by its shared resources:

```bash
cd rs-software
pip install streamlit plotly pandas matplotlib scikit-learn
streamlit run run_model_fitting_ui.py
```

Then open `http://localhost:8501` in your browser.

## How to use

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
| `stim_labels` | n_stim | Stimulus names (coords files use `stim_labels`; choice files use `stim_list`) |

**Random seed:** choose "Random each run" for normal use, or "Same every run" / "Custom offset"
for a reproducible result — useful when checking output against a benchmark.

For the equivalent Python functions, see [Choice → Coordinates → Python](rs-py-choice-to-coords.md).
