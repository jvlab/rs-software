"""
run_model_fitting_ui.py — Streamlit UI wrapper for demo_fit_euclidean logic.
Converts a choice .mat file → coordinate .mat file (Suniyya's format).

Run from inside rs-software:
    cd ~/Downloads/rs-software
    streamlit run ../run_model_fitting_ui.py
"""

import sys
import os
import tempfile
import numpy as np
import plotly.graph_objects as go
import streamlit as st

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'rs-software')
                if 'rs-software' not in os.getcwd() else '.')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rs_ui import convergence_plot
from rng_control import initialize_random_state

from src.rs_py.utils.util import load_choices
from src.rs_py.utils.config import CONFIG
from src.rs_py.utils.helpers import bias_dict, read_out_median_bias, create_coords_file
import src.rs_py.model.fit_geometric_models as rs
import src.rs_py.choices.choice_likelihoods as an
from scipy.io import savemat
from scipy.spatial.distance import pdist

# ---------------------------------------------------------------------------
# Defaults (from CONFIG)
# ---------------------------------------------------------------------------
DEFAULTS = CONFIG['inputs']['model_fit']
DEFAULT_SIGMA         = DEFAULTS['sigma']
DEFAULT_MIN_DIM       = 1
DEFAULT_MAX_DIM       = 5
DEFAULT_MAX_ITER      = DEFAULTS['max_iterations']
DEFAULT_TOLERANCE     = DEFAULTS['tolerance']
DEFAULT_LEARNING_RATE = DEFAULTS['learning_rate']
DEFAULT_MINIMIZATION  = DEFAULTS['minimization']

# ---------------------------------------------------------------------------
# Backend
# ---------------------------------------------------------------------------

def run_mds_single_dim(responses, repeats, n_stim, dim, sigma, max_iter, tolerance,
                        learning_rate, minimization, log_every=0, label=""):
    args = {
        'num_stimuli':    n_stim,
        'sigma':          sigma,
        'noise_st_dev':   sigma,
        'tolerance':      tolerance,
        'max_iterations': max_iter,
        'learning_rate':  learning_rate,
        'minimization':   minimization,
        'n_dim':          dim,
        'log_every':      log_every,
        'label':          label,
    }
    coords, ll, residuals = rs.points_of_best_fit(responses, repeats, args)
    return coords, ll, residuals


def build_mat_output(coords_by_dim, lls_by_dim, stim_list, model_dimensions, sigma):
    """Build output dict matching Suniyya's create_coords_file format."""
    data = {}
    bias_df = bias_dict()
    rms_dists_by_dim = {}

    for d in model_dimensions:
        pts = coords_by_dim[d]
        data[f"dim{d}"] = pts
        distances = pdist(pts)
        rms_dists_by_dim[d] = np.sqrt(np.mean([x ** 2 for x in distances]))

    raw_lls = np.array([lls_by_dim[d] for d in model_dimensions])
    best_ll = lls_by_dim['best']
    rand_ll = lls_by_dim['random']

    # bias estimation per dimension
    bias_estimates = []
    for d in model_dimensions:
        try:
            b = float(read_out_median_bias(bias_df, d, rms_dists_by_dim[d]))
            bias_estimates.append(b)
        except (ValueError, Exception):
            bias_estimates.append(0.0)
    bias_estimates = np.array(bias_estimates)

    debiased = raw_lls - best_ll + bias_estimates

    data['rawLLs']             = raw_lls
    data['bestModelLL']        = best_ll
    data['randModelLL']        = rand_ll
    data['biasEstimate']       = bias_estimates
    data['debiasedRelativeLL'] = debiased
    max_len = max(len(s) for s in stim_list)
    data['stim_list']          = np.array(stim_list, dtype=f'S{max_len}')
    data['readme'] = (
        "README\n\n"
        "rawLLs[i] is the raw model LL for model with i dimensions\n"
        "biasEstimate[i] is the median bias estimated for the i-dimensional model,\n"
        "  based on the RMS distance: sigma\n\n"
        "debiasedRelativeLL = (rawLLs + biasEstimate) - bestModelLL\n"
        "--------------------------------------------------------------------------"
    )
    return data

# ---------------------------------------------------------------------------
# Streamlit UI
# ---------------------------------------------------------------------------

st.set_page_config(page_title="MDS Fitting", layout="wide")

st.sidebar.title("MDS Fitting")
st.sidebar.caption("Turn a single participant's raw choice data into a perceptual coordinate map.")
st.sidebar.markdown("---")

# --- file input ---
st.sidebar.subheader("Input")
input_mode = st.sidebar.radio("Input method", ["Upload file", "Enter file path"], horizontal=True)

if input_mode == "Upload file":
    uploaded = st.sidebar.file_uploader("Choice file (.mat)", type="mat")
    path_direct = None
else:
    uploaded = None
    path_direct = st.sidebar.text_input("Path to choice file", placeholder="/path/to/choices.mat")

st.sidebar.markdown("---")

# --- settings ---
st.sidebar.subheader("Settings")

use_defaults = st.sidebar.checkbox("Use all defaults", value=False)

# Dimension range
col1, col2 = st.sidebar.columns(2)
with col1:
    min_dim = st.number_input("Min dim", min_value=1, max_value=10,
                               value=DEFAULT_MIN_DIM, disabled=use_defaults)
with col2:
    max_dim = st.number_input("Max dim", min_value=1, max_value=10,
                               value=DEFAULT_MAX_DIM, disabled=use_defaults)
if use_defaults:
    min_dim, max_dim = DEFAULT_MIN_DIM, DEFAULT_MAX_DIM
if max_dim < min_dim:
    st.sidebar.warning("Max dim must be ≥ min dim.")
    max_dim = min_dim

model_dimensions = list(range(int(min_dim), int(max_dim) + 1))
st.sidebar.caption(f"Will fit dimensions: {model_dimensions}")

# Max iterations
max_iter = st.sidebar.number_input(
    f"Max iterations (default {DEFAULT_MAX_ITER})",
    min_value=100, max_value=10000,
    value=DEFAULT_MAX_ITER, step=100,
    disabled=use_defaults
)
if use_defaults:
    max_iter = DEFAULT_MAX_ITER

sigma     = DEFAULT_SIGMA
tolerance = DEFAULT_TOLERANCE

# Print LL interval
print_every = st.sidebar.number_input(
    "Print LL every N iterations (0 = off)",
    min_value=0, max_value=1000,
    value=0, step=50
)

st.sidebar.markdown("---")

# Random seed control -- the MDS fit starts from a random position, so this
# controls whether that starting point is random, fixed, or a fixed-plus-offset
# (see rng_control.py for the exact if_frozen convention)
st.sidebar.subheader("Random seed")
seed_mode = st.sidebar.radio(
    "Starting position",
    ["Random each run", "Same every run (reproducible)", "Custom offset"],
    index=0, disabled=use_defaults,
    help="Random each run: normal use, a fresh random starting point every time. "
         "Same every run: forces the exact same starting point, so re-running gives "
         "identical results -- useful for verification/benchmarking. "
         "Custom offset: same starting seed, but skips ahead N draws first."
)
if use_defaults:
    seed_mode = "Random each run"

if seed_mode == "Random each run":
    if_frozen = 0
elif seed_mode == "Same every run (reproducible)":
    if_frozen = 1
else:
    seed_offset = st.sidebar.number_input(
        "Offset (draws to skip)", min_value=1, max_value=1000, value=3, step=1
    )
    if_frozen = -int(seed_offset)

st.sidebar.markdown("---")

# Subject / experiment metadata for output filename
st.sidebar.subheader("Output labels (optional)")
subject_label = st.sidebar.text_input("Subject ID", value="S1")
exp_label     = st.sidebar.text_input("Experiment name", value="exp")

st.sidebar.markdown("---")
run_btn = st.sidebar.button("Run MDS", type="primary", use_container_width=True)

# ---------------------------------------------------------------------------
# Main area
# ---------------------------------------------------------------------------
st.title("MDS Fitting: Choice → Coordinates")

# readiness check
if input_mode == "Upload file":
    ready = uploaded is not None
else:
    ready = bool(path_direct) and os.path.exists(path_direct)

if not ready:
    if input_mode == "Enter file path" and path_direct and not os.path.exists(path_direct):
        st.error(f"File not found: {path_direct}")
    else:
        st.info("Upload a .mat choice file or enter its path to get started.")
    st.stop()

if not run_btn:
    if input_mode == "Upload file":
        name = uploaded.name.replace('_suniyya.mat', '').replace('.mat', '')
    else:
        name = os.path.basename(path_direct).replace('_suniyya.mat', '').replace('.mat', '')
    st.markdown(f"**File:** `{name}`")
    st.markdown(f"Ready: dims **{model_dimensions}**, **{max_iter}** max iterations, sigma **{sigma}**")
    st.stop()

# --- resolve file path ---
if input_mode == "Upload file":
    with tempfile.NamedTemporaryFile(suffix='.mat', delete=False) as tmp:
        tmp.write(uploaded.read())
        filepath = tmp.name
    name = uploaded.name.replace('_suniyya.mat', '').replace('.mat', '')
else:
    filepath = path_direct
    name = os.path.basename(path_direct).replace('_suniyya.mat', '').replace('.mat', '')

st.subheader(name)
st.caption(f"Dims {model_dimensions} · {max_iter} max iterations · sigma={sigma} · seed: {seed_mode}")

# --- load ---
with st.spinner("Loading file..."):
    try:
        responses, repeats, metadata, stim_list = load_choices(filepath)
    except Exception as e:
        st.error(f"Could not load file: {e}\n\nMake sure this is a **choice** file, not a coordinate file.")
        st.stop()

total_triads = sum(repeats.values())
n_stim = len(stim_list)
st.success(f"Loaded: {n_stim} stimuli, {total_triads} total trials")

# --- fit each dimension ---
coords_by_dim = {}
lls_by_dim    = {}
residuals_by_dim = {}

progress_bar = st.progress(0)
status_text  = st.empty()

for i, dim in enumerate(model_dimensions):
    status_text.text(f"Fitting {dim}D model ({i+1}/{len(model_dimensions)})...")
    initialize_random_state(if_frozen)  # reseed right before the random MDS start point is drawn
    coords, ll, residuals = run_mds_single_dim(
        responses, repeats, n_stim, dim, sigma, max_iter, tolerance,
        DEFAULT_LEARNING_RATE, DEFAULT_MINIMIZATION,
        log_every=print_every if print_every > 0 else 0,
        label=f"{name} {dim}D"
    )
    coords_by_dim[dim] = coords
    lls_by_dim[dim]    = -ll / total_triads   # normalized per triad, positive = better
    residuals_by_dim[dim] = residuals
    progress_bar.progress((i + 1) / len(model_dimensions))

status_text.text("Computing baselines (best / random models)...")
ll_best,   _ = an.best_model_ll(responses, repeats)
ll_random, _ = an.random_choice_ll(responses, repeats)
lls_by_dim['best']   =  ll_best   / total_triads
lls_by_dim['random'] =  ll_random / total_triads

progress_bar.empty()
status_text.empty()

# --- results table ---
st.markdown("#### Results")
import pandas as pd
rows = []
for dim in model_dimensions:
    rows.append({"Dimensions": dim, "LL per triad": round(lls_by_dim[dim], 5)})
rows.append({"Dimensions": "best",   "LL per triad": round(lls_by_dim['best'],   5)})
rows.append({"Dimensions": "random", "LL per triad": round(lls_by_dim['random'], 5)})
st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)

# --- convergence plot ---
st.markdown("#### Convergence")
res_dict = {f"{d}D": residuals_by_dim[d] for d in model_dimensions if residuals_by_dim[d]}
tri_dict = {f"{d}D": total_triads for d in model_dimensions}
convergence_plot(res_dict, tri_dict)

# --- coordinates table (for highest dim) ---
best_dim = model_dimensions[-1]
st.markdown(f"#### Coordinates (highest dim = {best_dim}D)")
coord_df = pd.DataFrame(
    coords_by_dim[best_dim],
    index=stim_list,
    columns=[f"dim{i+1}" for i in range(best_dim)]
)
st.dataframe(coord_df, use_container_width=True)

# --- build output mat ---
st.markdown("#### Download")

with st.spinner("Computing bias estimates and building output file..."):
    try:
        out_dict = build_mat_output(coords_by_dim, lls_by_dim, stim_list, model_dimensions, sigma)
        bias_ok = True
    except Exception as e:
        st.warning(f"Could not compute bias estimates ({e}). Saving without bias fields.")
        out_dict = {}
        for dim in model_dimensions:
            out_dict[f"dim{dim}"] = coords_by_dim[dim]
        out_dict['rawLLs']      = np.array([lls_by_dim[d] for d in model_dimensions])
        out_dict['bestModelLL'] = lls_by_dim['best']
        out_dict['randModelLL'] = lls_by_dim['random']
        max_len = max(len(s) for s in stim_list)
        out_dict['stim_list']   = np.array(stim_list, dtype=f'S{max_len}')
        bias_ok = False

out_filename = f"{exp_label}_coords_{subject_label}.mat"
with tempfile.NamedTemporaryFile(suffix='.mat', delete=False) as tmp_out:
    savemat(tmp_out.name, out_dict)
    with open(tmp_out.name, 'rb') as f:
        mat_bytes = f.read()

st.download_button(
    label=f"Download {out_filename}",
    data=mat_bytes,
    file_name=out_filename,
    mime="application/octet-stream"
)

if bias_ok:
    st.caption("Output format matches Suniyya's `create_coords_file`: includes `rawLLs`, `biasEstimate`, `debiasedRelativeLL`, `bestModelLL`, `randModelLL`, `stim_list`.")
