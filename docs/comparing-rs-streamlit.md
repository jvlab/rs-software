# Comparing RS — Streamlit option

A browser-based interface for the Surrogate MDS comparison — no installation required.

## Live app

| App | URL |
|---|---|
| Surrogate MDS Analysis | *Live link coming soon — run locally in the meantime (below)* |

> Note: the app may be asleep if inactive — click the link and wait a moment for it to wake up.

## Running locally

```bash
cd rs-software
pip install streamlit plotly pandas matplotlib scikit-learn
streamlit run app.py
```

Then open `http://localhost:8501` in your browser.

## How to use

Compare two choice datasets and test whether the difference in their perceptual maps is
statistically meaningful.

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

**Random seed:** the sidebar has a "Random seed" control for the real-data fit specifically
(surrogates are already seeded deterministically per-surrogate) — choose "Random each run" for
normal use, or "Same every run" / "Custom offset" for a reproducible result.

For the equivalent Python function, see [Comparing RS → Python option](comparing-rs-python.md).
