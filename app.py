"""
app.py — Streamlit UI for surrogate MDS analysis.

Run from inside rs-software:
    cd ~/Downloads/rs-software
    streamlit run ../app.py
"""

import sys
import os
import tempfile
import numpy as np
import matplotlib.pyplot as plt
import plotly.graph_objects as go
from scipy.linalg import orthogonal_procrustes
import streamlit as st

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'rs-software')
                if 'rs-software' not in os.getcwd() else '.')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rs_ui import convergence_plot

from src.rs_py.utils.util import load_choices
from src.rs_py.utils.config import CONFIG
import src.rs_py.model.fit_geometric_models as rs

# ---------------------------------------------------------------------------
# defaults
# ---------------------------------------------------------------------------
_CFG = CONFIG['inputs']['model_fit']
DEFAULT_DIM            = 2
DEFAULT_SURROGATES     = 30
DEFAULT_MAX_ITER       = _CFG['max_iterations']
DEFAULT_LEARNING_RATE  = _CFG['learning_rate']

# ---------------------------------------------------------------------------
# core functions
# ---------------------------------------------------------------------------

def load_mat(path):
    try:
        responses, repeats, metadata, stim_list = load_choices(path)
    except (KeyError, TypeError) as e:
        st.error(
            "Could not load this file. Make sure you are uploading a **choices** file "
            "(e.g. `bgca3pt_choices_SN_sess01_10.mat`), not a coordinates file. "
            f"Details: {e}"
        )
        st.stop()
    return responses, repeats, stim_list


def run_mds(responses, repeats, stim_list, dim, max_iterations, learning_rate,
            log_every=0, label="", start_points=None):
    args = {
        'num_stimuli':    len(stim_list),
        'sigma':          _CFG['sigma'],
        'noise_st_dev':   _CFG['sigma'],
        'tolerance':      _CFG['tolerance'],
        'max_iterations': max_iterations,
        'learning_rate':  learning_rate,
        'minimization':   _CFG['minimization'],
        'n_dim':          dim,
        'log_every':      log_every,
        'label':          label,
    }
    coords, ll, residuals = rs.points_of_best_fit(responses, repeats, args, start_points=start_points)
    return coords, ll, residuals


def align_to_shared_stimuli(coords1, stims1, coords2, stims2):
    shared = [s for s in stims1 if s in set(stims2)]
    if len(shared) == 0:
        raise ValueError("No shared stimuli between the two datasets.")
    idx1 = [list(stims1).index(s) for s in shared]
    idx2 = [list(stims2).index(s) for s in shared]
    return coords1[idx1], coords2[idx2], shared


def compute_disparity(coords1, coords2, stims1=None, stims2=None):
    if stims1 is not None and stims2 is not None:
        coords1, coords2, shared = align_to_shared_stimuli(coords1, stims1, coords2, stims2)
        if len(shared) < len(stims1) or len(shared) < len(stims2):
            st.info(f"Note: {len(shared)} shared stimuli found. Procrustes computed on shared stimuli only.")
    c1 = coords1 - coords1.mean(axis=0)
    c2 = coords2 - coords2.mean(axis=0)
    R, _ = orthogonal_procrustes(c1, c2)
    c2_aligned = c2 @ R.T
    return np.linalg.norm(c1 - c2_aligned, 'fro') / np.linalg.norm(c2, 'fro') ** 2


def pool_observations(resp1, rep1, resp2, rep2):
    observations = []
    for key, count in resp1.items():
        total = rep1[key]
        observations.extend([(key, 1)] * count)
        observations.extend([(key, 0)] * (total - count))
    for key, count in resp2.items():
        total = rep2[key]
        observations.extend([(key, 1)] * count)
        observations.extend([(key, 0)] * (total - count))
    return observations


def build_pool(observations):
    pool = {}
    for key, outcome in observations:
        pool.setdefault(key, []).append(outcome)
    return pool


def resample_dataset(pool, resp, rep, method):
    surrogate_responses = {}
    surrogate_repeats = {}

    for key in resp:
        n_trials = rep[key]
        bag = pool.get(key, [])

        if len(bag) == 0:
            raise ValueError(
                f"Pool is empty for trial {key} — something is fundamentally wrong with the data."
            )

        if method == 'with_replacement':
            draws = np.random.choice(bag, size=n_trials, replace=True)

        elif method == 'without_replacement':
            if len(bag) < n_trials:
                raise ValueError(
                    f"Pool has {len(bag)} outcomes but {n_trials} draws requested without replacement "
                    f"for trial {key}. Combined data from both datasets is insufficient."
                )
            idx = np.random.choice(len(bag), size=n_trials, replace=False)
            draws = np.array(bag)[idx]

        surrogate_responses[key] = int(np.array(draws).sum())
        surrogate_repeats[key] = n_trials

    return surrogate_responses, surrogate_repeats


def resample_paired(pool, resp1, rep1, resp2, rep2):
    remaining = {k: list(v) for k, v in pool.items()}
    surr_resp1, surr_rep1 = {}, {}
    surr_resp2, surr_rep2 = {}, {}

    all_keys = set(resp1.keys()) | set(resp2.keys())
    for key in all_keys:
        n1 = rep1.get(key, 0)
        n2 = rep2.get(key, 0)
        available = remaining.get(key, [])

        if key in resp1:
            if len(available) < n1:
                raise ValueError(
                    f"Pool has {len(available)} outcomes for trial {key} but dataset A needs "
                    f"{n1} draws. Something is fundamentally wrong with the data."
                )
            chosen_indices = set(np.random.choice(len(available), size=n1, replace=False))
            a_draws  = [available[i] for i in chosen_indices]
            leftover = [available[i] for i in range(len(available)) if i not in chosen_indices]
            surr_resp1[key] = int(sum(a_draws))
            surr_rep1[key]  = n1
        else:
            leftover = list(available)

        if key in resp2:
            if len(leftover) < n2:
                raise ValueError(
                    f"After dataset A drew, only {len(leftover)} outcomes remain for trial {key} "
                    f"but dataset B needs {n2}. Pool is too small."
                )
            b_draws = leftover[:n2]
            surr_resp2[key] = int(sum(b_draws))
            surr_rep2[key]  = n2

    return surr_resp1, surr_rep1, surr_resp2, surr_rep2


# ---------------------------------------------------------------------------
# Streamlit app
# ---------------------------------------------------------------------------

st.set_page_config(page_title="Surrogate MDS", layout="wide")

st.sidebar.title("Surrogate MDS")
st.sidebar.caption("Compare two datasets' perceptual maps and test whether the difference is statistically meaningful.")
st.sidebar.markdown("---")

# --- file input ---
st.sidebar.subheader("Datasets")
input_mode = st.sidebar.radio("Input method", ["Upload files", "Enter file paths"], horizontal=True)

if input_mode == "Upload files":
    file1 = st.sidebar.file_uploader("Dataset 1 (.mat)", type="mat", key="f1")
    file2 = st.sidebar.file_uploader("Dataset 2 (.mat)", type="mat", key="f2")
    path1_direct = None
    path2_direct = None
else:
    file1 = None
    file2 = None
    path1_direct = st.sidebar.text_input("Path to dataset 1", placeholder="/path/to/file1.mat")
    path2_direct = st.sidebar.text_input("Path to dataset 2", placeholder="/path/to/file2.mat")

st.sidebar.markdown("---")

# --- Required settings ---
st.sidebar.subheader("Required settings")

# Dimensions
_c1, _c2 = st.sidebar.columns([3, 1])
dim = _c1.slider("Dimensions", 1, 10, DEFAULT_DIM)
if _c2.button("↺", key="d_dim", help="Reset to default"):
    dim = DEFAULT_DIM

# Number of surrogates
_c1, _c2 = st.sidebar.columns([3, 1])
n_surrogates = _c1.number_input("Surrogates (0 = prelim run)", min_value=0, max_value=10000,
                                 value=DEFAULT_SURROGATES, step=1)
if _c2.button("↺", key="d_surr", help="Reset to default"):
    n_surrogates = DEFAULT_SURROGATES

# Max iterations
_c1, _c2 = st.sidebar.columns([3, 1])
max_iterations = _c1.number_input("Max iterations", min_value=100, max_value=100000,
                                   value=DEFAULT_MAX_ITER, step=100)
if _c2.button("↺", key="d_iter", help="Reset to default"):
    max_iterations = DEFAULT_MAX_ITER

# Resampling method
resample_method = st.sidebar.selectbox(
    "Resampling method",
    ["with_replacement", "without_replacement", "without_replacement_paired"],
    format_func=lambda x: {
        "with_replacement": "With replacement (default)",
        "without_replacement": "Without replacement",
        "without_replacement_paired": "Without replacement, paired",
    }[x]
)

st.sidebar.markdown("---")

# --- Optional settings ---
st.sidebar.subheader("Optional settings")

# Learning rate
_c1, _c2 = st.sidebar.columns([3, 1])
learning_rate = _c1.number_input("Learning rate", min_value=0.001, max_value=1.0,
                                  value=float(DEFAULT_LEARNING_RATE), step=0.001, format="%.3f")
if _c2.button("↺", key="d_lr", help="Reset to default"):
    learning_rate = DEFAULT_LEARNING_RATE

# Print convergence interval
_c1, _c2 = st.sidebar.columns([3, 1])
print_every = _c1.number_input("Print LL every N iters (0 = off)", min_value=0, max_value=10000,
                                value=0, step=50)
if _c2.button("↺", key="d_pe", help="Reset to default"):
    print_every = 0

# Warm start
show_pooled = st.sidebar.checkbox("Use pooled (A+B) fit as warm start", value=False,
    help="Fits a compromise map from combined A+B data, then uses it as the starting point for individual A and B fits. Also shows the pooled convergence curve.")

st.sidebar.markdown("---")

# Use all defaults — at the bottom so users see all parameters first
if st.sidebar.button("Use all defaults", use_container_width=True):
    dim           = DEFAULT_DIM
    n_surrogates  = DEFAULT_SURROGATES
    max_iterations = DEFAULT_MAX_ITER
    learning_rate  = DEFAULT_LEARNING_RATE
    print_every    = 0

st.sidebar.markdown("---")
run_btn = st.sidebar.button("Run analysis", type="primary", use_container_width=True)

# --- main area ---
st.title("Surrogate MDS Analysis")

# check inputs ready
if input_mode == "Upload files":
    ready = file1 is not None and file2 is not None
else:
    ready = bool(path1_direct) and bool(path2_direct) and os.path.exists(path1_direct) and os.path.exists(path2_direct)

if not ready:
    if input_mode == "Upload files":
        st.info("Upload two .mat files in the sidebar to get started.")
    else:
        if path1_direct and not os.path.exists(path1_direct):
            st.error(f"File not found: {path1_direct}")
        elif path2_direct and not os.path.exists(path2_direct):
            st.error(f"File not found: {path2_direct}")
        else:
            st.info("Enter paths to two .mat files in the sidebar to get started.")
    st.stop()

if not run_btn:
    if input_mode == "Upload files":
        n1 = file1.name.replace('_suniyya.mat', '').replace('.mat', '')
        n2 = file2.name.replace('_suniyya.mat', '').replace('.mat', '')
    else:
        n1 = os.path.basename(path1_direct).replace('_suniyya.mat', '').replace('.mat', '')
        n2 = os.path.basename(path2_direct).replace('_suniyya.mat', '').replace('.mat', '')
    st.markdown(f"**Dataset 1:** {n1}")
    st.markdown(f"**Dataset 2:** {n2}")
    st.markdown(f"Ready to run: **{dim}D**, **{n_surrogates} surrogates**, **{max_iterations} max iterations**, learning rate **{learning_rate}**")
    st.stop()

# --- resolve paths ---
if input_mode == "Upload files":
    with tempfile.NamedTemporaryFile(suffix='.mat', delete=False) as tmp1:
        tmp1.write(file1.read())
        path1 = tmp1.name
    with tempfile.NamedTemporaryFile(suffix='.mat', delete=False) as tmp2:
        tmp2.write(file2.read())
        path2 = tmp2.name
    name1 = file1.name.replace('_suniyya.mat', '').replace('.mat', '')
    name2 = file2.name.replace('_suniyya.mat', '').replace('.mat', '')
else:
    path1 = path1_direct
    path2 = path2_direct
    name1 = os.path.basename(path1).replace('_suniyya.mat', '').replace('.mat', '')
    name2 = os.path.basename(path2).replace('_suniyya.mat', '').replace('.mat', '')

st.subheader(f"{name1}  vs  {name2}")
st.caption(f"{dim}D · {n_surrogates} surrogates · {max_iterations} max iterations · learning rate {learning_rate} · {resample_method.replace('_', ' ')}")

# load files
with st.spinner("Loading files..."):
    resp1, rep1, stims1 = load_mat(path1)
    resp2, rep2, stims2 = load_mat(path2)

total_triads1 = sum(rep1.values())
total_triads2 = sum(rep2.values())

# pooled fit (warm start) — must run BEFORE real fits so we can pass start_points
pooled_residuals, total_triads_pooled = [], None #pooled_residuals= convergence log of pooled MDS fit
start1, start2 = None, None
if show_pooled: #if checkbox has been selected (t or f)
    with st.spinner("Running pooled (A+B) MDS for warm start..."): #shows a spinning loading animation 
        global_stims = list(stims1) #global_stims is the pooled stimuli list
        for s in stims2:
            if s not in global_stims:
                global_stims.append(s)
        idx_map1 = {i: global_stims.index(s) for i, s in enumerate(stims1)} #for each dataset, build a lookup table (because A and B use their own local numbering but the pooled dataset needs one consistent numbering)
        idx_map2 = {i: global_stims.index(s) for i, s in enumerate(stims2)}
        def remap(resp, rep, idx_map):
            nr, np_ = {}, {}
            for key, count in resp.items(): #loop through every trial
                (a,b),(c,d) = key
                nk = ((idx_map[a],idx_map[b]),(idx_map[c],idx_map[d])) #translate all four local indices to global indices using the lookup table (nk is the new key in global numbering)
                nr[nk] = nr.get(nk, 0) + count #store the response count and repeat count under the new global key
                np_[nk] = np_.get(nk, 0) + rep[key]
            return nr, np_
        pr1, pp1 = remap(resp1, rep1, idx_map1)
        pr2, pp2 = remap(resp2, rep2, idx_map2)
        pooled_resp = dict(pr1)
        pooled_rep = dict(pp1)
        for key, count in pr2.items():
            pooled_resp[key] = pooled_resp.get(key, 0) + count
            pooled_rep[key] = pooled_rep.get(key, 0) + pp2[key]
        total_triads_pooled = sum(pooled_rep.values())
        pooled_coords, pooled_ll, pooled_residuals = run_mds(
            pooled_resp, pooled_rep, global_stims, dim, max_iterations, learning_rate,
            log_every=1, label="Pooled")
        start1 = np.array([pooled_coords[idx_map1[i]] for i in range(len(stims1))])
        start2 = np.array([pooled_coords[idx_map2[i]] for i in range(len(stims2))])
        st.success(f"Pooled LL: {-pooled_ll/total_triads_pooled:.4f} — using as warm start for A and B fits")

# real data MDS
st.markdown("#### Real data MDS")
st.caption("Fitting an MDS coordinate map to each dataset's actual choices. LL (log-likelihood) measures fit quality — closer to 0 is better. Disparity measures how different the two maps are after alignment.")
prog = st.progress(0, text="Fitting real data...")

with st.spinner(f"Running {dim}D MDS on dataset 1..."):
    real_coords1, real_ll1, residuals1 = run_mds(
        resp1, rep1, stims1, dim, max_iterations, learning_rate, log_every=1, label=name1, start_points=start1)
prog.progress(50, text="Dataset 1 done...")

with st.spinner(f"Running {dim}D MDS on dataset 2..."):
    real_coords2, real_ll2, residuals2 = run_mds(
        resp2, rep2, stims2, dim, max_iterations, learning_rate, log_every=1, label=name2, start_points=start2)
prog.progress(100, text="Real data done.")

real_disparity = compute_disparity(real_coords1, real_coords2, stims1, stims2)
final_ll1 = -real_ll1 / total_triads1
final_ll2 = -real_ll2 / total_triads2

col1, col2, col3 = st.columns(3)
col1.metric(f"{name1} LL", f"{final_ll1:.4f}", help="Log-likelihood per trial. Closer to 0 = better fit. Best possible model is the empirical choice probability itself.")
col2.metric(f"{name2} LL", f"{final_ll2:.4f}", help="Log-likelihood per trial. Closer to 0 = better fit.")
col3.metric("Real disparity", f"{real_disparity:.4f}", help="Procrustes disparity between the two maps. 0 = identical, higher = more different.")

# convergence plot
if residuals1 or residuals2:
    st.markdown("#### Convergence")
    st.caption("Log-likelihood per iteration for each dataset. A flat curve indicates the fit has converged — if it is still decreasing at the end, increase max iterations.")
    res_dict = {name1: residuals1, name2: residuals2}
    tri_dict = {name1: total_triads1, name2: total_triads2}
    styles = {}
    if show_pooled and pooled_residuals:
        res_dict["Pooled (A+B)"] = pooled_residuals
        tri_dict["Pooled (A+B)"] = total_triads_pooled
        styles["Pooled (A+B)"] = {"color": "purple", "dash": "dash"}
    convergence_plot(res_dict, tri_dict, styles)

# prelim mode — stop here
if n_surrogates == 0:
    st.success("Preliminary run complete. Check the convergence plot above to decide how many iterations you need, then rerun with surrogates.")
    os.unlink(path1)
    os.unlink(path2)
    st.stop()

# --- surrogates ---
st.markdown("#### Surrogate runs")
st.caption("Each surrogate is a randomly resampled dataset pair drawn from the pooled observations. Running MDS on many surrogates builds a null distribution — how different two maps look when there is no genuine difference between datasets.")

observations = pool_observations(resp1, rep1, resp2, rep2)
pool = build_pool(observations)

def _run_one_surrogate(args):
    seed, s_resp1, s_rep1, s_resp2, s_rep2, stims1, stims2, dim, max_iterations, learning_rate = args
    coords1, ll1, _ = run_mds(s_resp1, s_rep1, stims1, dim, max_iterations, learning_rate)
    coords2, ll2, _ = run_mds(s_resp2, s_rep2, stims2, dim, max_iterations, learning_rate)
    disp = compute_disparity(coords1, coords2, stims1, stims2)
    ll_a = -ll1 / sum(s_rep1.values())
    ll_b = -ll2 / sum(s_rep2.values())
    return disp, ll_a, ll_b

# build all surrogate pairs
jobs = []
for seed in range(n_surrogates):
    np.random.seed(seed)
    if resample_method == 'without_replacement_paired':
        s_resp1, s_rep1, s_resp2, s_rep2 = resample_paired(pool, resp1, rep1, resp2, rep2)
    else:
        s_resp1, s_rep1 = resample_dataset(pool, resp1, rep1, resample_method)
        s_resp2, s_rep2 = resample_dataset(pool, resp2, rep2, resample_method)
    jobs.append((seed, s_resp1, s_rep1, s_resp2, s_rep2, stims1, stims2, dim, max_iterations, learning_rate))

from concurrent.futures import ThreadPoolExecutor
with st.spinner(f"Running {n_surrogates} surrogates..."):
    with ThreadPoolExecutor(max_workers=min(8, len(jobs))) as ex:
        results = list(ex.map(_run_one_surrogate, jobs))

surrogate_disparities = np.array([r[0] for r in results])
surrogate_lls = [(r[1], r[2]) for r in results]

p_value = float(np.mean(surrogate_disparities >= real_disparity))

# --- results ---
st.markdown("#### Results")
st.caption("The real disparity (red line) is compared against the surrogate null distribution (blue bars). If the real disparity falls in the tail of the distribution, the two datasets are genuinely different.")

m1, m2, m3, m4 = st.columns(4)
m1.metric("Real disparity", f"{real_disparity:.4f}", help="Procrustes disparity between the two real datasets.")
m2.metric("Surrogate mean", f"{surrogate_disparities.mean():.4f}", help="Average disparity across all surrogate pairs — this is what 'no real difference' looks like.")
m3.metric("Surrogate std", f"{surrogate_disparities.std():.4f}", help="Spread of the surrogate distribution. Wider = more variable null.")
m4.metric("p-value", f"{p_value:.4f}", help="Fraction of surrogates with disparity ≥ real. Below 0.05 = statistically significant. Use at least 100 surrogates for a reliable estimate.")

if p_value < 0.05:
    st.success(f"Statistically significant at p = 0.05 (p = {p_value:.4f}) — the two maps are more different than expected by chance.")
else:
    st.warning(f"Not statistically significant at p = 0.05 (p = {p_value:.4f}) — cannot rule out that the difference is due to chance.")

# distribution plot
fig_dist = go.Figure()
fig_dist.add_trace(go.Histogram(
    x=surrogate_disparities.tolist(), name="Surrogates",
    marker_color="#378ADD", opacity=0.75,
    nbinsx=20
))
fig_dist.add_vline(
    x=float(real_disparity), line_color="#E24B4A", line_dash="dash",
    annotation_text=f"Real: {real_disparity:.4f}", annotation_position="top right"
)
fig_dist.update_layout(
    xaxis_title="Procrustes disparity", yaxis_title="Count",
    height=300, margin=dict(l=40, r=20, t=20, b=40),
    showlegend=False
)
st.plotly_chart(fig_dist, use_container_width=True)
st.caption("Blue bars = surrogate null distribution. Red dashed line = real disparity. The further right the red line, the more the two datasets differ.")

# surrogate LL table
st.markdown("#### Surrogate log-likelihoods")
st.caption("Log-likelihood per trial for each surrogate's two datasets. Similar values across surrogates indicate stable fits.")
import pandas as pd
full_tbl = {
    "Surrogate": list(range(1, n_surrogates + 1)),
    f"LL ({name1})": [f"{r[0]:.4f}" for r in surrogate_lls],
    f"LL ({name2})": [f"{r[1]:.4f}" for r in surrogate_lls],
    "Disparity": [f"{d:.4f}" for d in surrogate_disparities],
}
st.dataframe(full_tbl, use_container_width=True, hide_index=True)

os.unlink(path1)
os.unlink(path2)
