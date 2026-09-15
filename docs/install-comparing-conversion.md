## Installation and Set-up

These tools cover comparing representational spaces (Surrogate MDS analysis) and converting between
file formats (OOO ↔ triadic, `.mat` ↔ NumPy, choices → coordinates). They're available two ways:
as importable Python functions, or as browser-based Streamlit apps that need no installation at all.

### Option 1: Streamlit apps (no installation)

The fastest way to use these tools — nothing to install, runs in your browser. See
[Comparing RS → Streamlit option](comparing-rs-streamlit.md) and
[File conversion → Streamlit option](file-conversion-streamlit.md) for the live links.

### Option 2: Python package

If you want to call these tools directly from your own Python scripts:

```bash
pip install jvlab-rs
```

Or install directly from the `rs-software` repository:

```bash
git clone https://github.com/jvlab/rs-software.git
cd rs-software
pip install -e .
```

### Option 3: Run the Streamlit apps locally

If you'd rather run the same apps on your own machine instead of the hosted versions:

```bash
cd rs-software
pip install streamlit plotly pandas matplotlib scikit-learn
streamlit run app.py
```

Then open `http://localhost:8501` in your browser. Each conversion tool is also its own standalone
app — see [File conversion → Streamlit option](file-conversion-streamlit.md) for the individual
filenames (`app_ooo.py`, `app_matnpy.py`, `run_model_fitting_ui.py`) if you only need one.
