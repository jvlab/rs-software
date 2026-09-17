## Installation and Set-up

These tools cover comparing representational spaces (Surrogate MDS analysis) and converting between
file formats (OOO ↔ triadic, `.mat` ↔ NumPy, choices → coordinates). They're all part of the Python
toolkit, available two ways: as importable functions in your own scripts, or through the **Python
tools UI** — a browser-based version of the same tools.

## Python

### Install the package

```bash
pip install jvlab-rs
```

Or install directly from the `rs-software` repository:

```bash
git clone https://github.com/jvlab/rs-software.git
cd rs-software
pip install -e .
```

Use this if you want to call these tools directly from your own Python scripts. See
[Comparing RS → Python](comparing-rs-python.md) and [File conversion → Python](file-conversion-python.md).

### Python tools UI (web-based)

The same tools, running in your browser. See
[Comparing RS → Python tools UI](comparing-rs-streamlit.md) and
[File conversion → Python tools UI](file-conversion-streamlit.md) for the live links.

**The hosted version needs no installation** — just open a link and use it. Running it on your own
machine instead is faster and isn't limited by the hosted version's shared resources, at the cost
of one extra setup step:

```bash
cd rs-software
pip install streamlit plotly pandas matplotlib scikit-learn
streamlit run app.py
```

Then open `http://localhost:8501` in your browser. Each conversion tool is also its own standalone
app — see [File conversion → Python tools UI](file-conversion-streamlit.md) for the file
conversion filenames (`app_ooo.py`, `app_matnpy.py`), or
[Creating RS → Choice → Coordinates](rs-py-choice-to-coords-streamlit.md) for `run_model_fitting_ui.py`,
if you only need one.
