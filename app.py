"""
app.py — Streamlit UI for surrogate MDS analysis.

Run from inside rs-software:
    cd ~/Downloads/rs-software
    streamlit run app.py
"""

import sys
import os

# Streamlit Cloud's free tier gives the container ~1 shared CPU core. Numpy's
# BLAS backend defaults to spawning multiple threads per call, which just
# fights itself for that one core instead of helping -- pin it to 1 thread
# before numpy is imported.
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")

import tempfile
import numpy as np
import matplotlib.pyplot as plt
import plotly.graph_objects as go
from scipy.linalg import orthogonal_procrustes
import streamlit as st

# repo root — works both locally (cd rs-software && streamlit run app.py) and on Streamlit Cloud
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rs_ui import convergence_plot, slider_with_number, live_progress
from rs_tools.run_checks import cost_plateau, estimate_seconds, format_duration, seconds_per_iteration

from src.rs_py.utils.util import load_choices
from src.rs_py.utils.config import CONFIG
import src.rs_py.model.fit_geometric_models as rs
from rng_control import initialize_random_state

DATASET_COLORS = ("#1F4E8C", "#6FA8DC")   # dataset 1 / dataset 2: two blues
SURROGATE_COLOR = "#D62728"               # all surrogate curves: one red

# ---------------------------------------------------------------------------
# defaults
# ---------------------------------------------------------------------------
_CFG = CONFIG['inputs']['model_fit']
DEFAULT_DIM            = 2
DEFAULT_SURROGATES     = 15   # lowered from 30 -- same free-tier CPU reasoning as DEFAULT_MAX_ITER
CONFIG_MAX_ITER        = _CFG['max_iterations']   # the "full" value from config (2000)
DEFAULT_MAX_ITER       = 150   # lowered further (was 500) -- 500 still timed out / got OOM-restarted
                                # on Streamlit Cloud's free tier for real datasets around ~35 stimuli
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
            log_every=0, label="", start_points=None, if_frozen=-1):
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
    if start_points is None:
        initialize_random_state(if_frozen)
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
st.sidebar.warning(
    "This free web version runs on limited compute — it's meant for small "
    "datasets and a quick look, not a final fit. For larger datasets or a "
    "high-precision result, run this locally instead."
)
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
dim = slider_with_number("Dimensions", 1, 10, DEFAULT_DIM, key="d_dim")

# Number of surrogates
n_surrogates = slider_with_number("Surrogates (0 = prelim run)", 0, 10000, DEFAULT_SURROGATES, key="d_surr")

# Max iterations -- default lowered to 500 (config value is 2000) to stay light
# on Streamlit Cloud's free tier; min is 10 for quick test runs
max_iterations = slider_with_number(
    f"Max iterations ({DEFAULT_MAX_ITER} for a quick look, {CONFIG_MAX_ITER}+ for a final fit)",
    10, 20000, DEFAULT_MAX_ITER, step=10, key="d_iter")

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

# Print convergence interval -- on (50) by default so the page shows live
# progress instead of looking frozen during a slow fit, especially on
# Streamlit Cloud
_c1, _c2 = st.sidebar.columns([3, 1])
print_every = _c1.number_input("Show progress every N iters (0 = off)", min_value=0, max_value=10000,
                                value=50, step=50)
if _c2.button("↺", key="d_pe", help="Reset to default"):
    print_every = 50

# Warm start
show_pooled = st.sidebar.checkbox("Use pooled (A+B) fit as warm start", value=False,
    help="Fits a compromise map from combined A+B data, then uses it as the starting point for individual A and B fits. Also shows the pooled convergence curve.")

if show_pooled:
    _c1, _c2 = st.sidebar.columns([3, 1])
    surrogate_max_iter = _c1.number_input(
        "Surrogate max iterations", min_value=50, max_value=100000,
        value=200, step=50,
        help="Surrogates use the pooled warm start and converge faster — fewer iterations needed.")
    if _c2.button("↺", key="d_surr_iter", help="Reset to default"):
        surrogate_max_iter = 200
    n_surr_conv = _c1.number_input(
        "Show convergence for first N surrogates", min_value=0, max_value=20,
        value=2, step=1,
        help="Plots the convergence curve for the first N surrogates to verify warm start is working.")
    if _c2.button("↺", key="d_surr_conv", help="Reset to default"):
        n_surr_conv = 2
else:
    surrogate_max_iter = max_iterations
    n_surr_conv = 0

# Random seed for the real dataset A/B fits. The surrogates already seed
# deterministically per-surrogate (seed = surrogate index), so they don't need
# this control -- this only governs the real-data fit, decoupled from the
# surrogate pool per JV's request.
st.sidebar.markdown("**Random seed** (real data fit)")
_c1, _c2 = st.sidebar.columns([3, 1])
seed_mode = _c1.radio(
    "Starting position", ["Random each run", "Same every run (reproducible)", "Custom random seed"],
    index=2, horizontal=False,
    help="Random each run: a fresh random starting point every time. Same every run: forces "
         "the exact same starting point, for verification/benchmarking. Custom random seed: same "
         "starting seed, but skips ahead N draws first. Doesn't apply when using pooled warm "
         "start above, since that fixes the starting point directly."
)
if _c2.button("↺", key="d_seed", help="Reset to default"):
    seed_mode = "Custom random seed"

if seed_mode == "Random each run":
    real_if_frozen = 0
elif seed_mode == "Same every run (reproducible)":
    real_if_frozen = 1
else:
    _c1, _c2 = st.sidebar.columns([3, 1])
    seed_offset = _c1.number_input("Offset (draws to skip)", min_value=1, max_value=1000, value=1, step=1)
    if _c2.button("↺", key="d_seed_offset", help="Reset to default"):
        seed_offset = 1
    real_if_frozen = -int(seed_offset)

# Learning rate
_c1, _c2 = st.sidebar.columns([3, 1])
learning_rate = _c1.number_input("Learning rate", min_value=0.001, max_value=1.0,
                                  value=float(DEFAULT_LEARNING_RATE), step=0.001, format="%.3f",
                                  help="Step size of each update. Only change it if the convergence plot is unstable.")
if _c2.button("↺", key="d_lr", help="Reset to default"):
    learning_rate = DEFAULT_LEARNING_RATE

st.sidebar.markdown("---")

# Use all defaults — at the bottom so users see all parameters first
if st.sidebar.button("Use all defaults", use_container_width=True):
    dim           = DEFAULT_DIM
    n_surrogates  = DEFAULT_SURROGATES
    max_iterations = DEFAULT_MAX_ITER
    learning_rate  = DEFAULT_LEARNING_RATE
    print_every    = 50
    real_if_frozen = -1

st.sidebar.markdown("---")
run_btn = st.sidebar.button("Run analysis", type="primary", use_container_width=True)

def remove_temp_copies(*paths):
    # only the temporary copies made for uploaded files are deleted; files given by path are the user's own
    if input_mode == "Upload files":
        for path in paths:
            os.unlink(path)


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
st.caption(f"{dim}D · {n_surrogates} surrogates · {max_iterations} max iterations · learning rate {learning_rate} · {resample_method.replace('_', ' ')} · seed: {seed_mode if not show_pooled else 'pooled warm start'}")

# load files
with st.spinner("Loading files..."):
    resp1, rep1, stims1 = load_mat(path1)
    resp2, rep2, stims2 = load_mat(path2)

total_triads1 = sum(rep1.values())
total_triads2 = sum(rep2.values())

# estimated run time, from timing a few iterations of each dataset's fit
def _time_iterations(resp, rep, stims):
    # a fixed start point, so the timing fits do not touch the random state the real fits use
    start = np.random.RandomState(0).randn(len(stims), dim)
    return seconds_per_iteration(lambda n: run_mds(resp, rep, stims, dim, n, learning_rate, start_points=start.copy()))

with st.spinner("Timing a few iterations..."):
    _spi1 = _time_iterations(resp1, rep1, stims1)
    _spi2 = _time_iterations(resp2, rep2, stims2)
st.info(f"Estimated run time: {format_duration(estimate_seconds(_spi1, _spi2, max_iterations, n_surrogates, surrogate_max_iter, show_pooled))}")

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
        pooled_log = st.empty()
        with live_progress(pooled_log):
            pooled_coords, pooled_ll, pooled_residuals = run_mds(
                pooled_resp, pooled_rep, global_stims, dim, max_iterations, learning_rate,
                log_every=print_every if print_every > 0 else 0, label="Pooled", if_frozen=1)
        pooled_log.empty()
        start1 = np.array([pooled_coords[idx_map1[i]] for i in range(len(stims1))])
        start2 = np.array([pooled_coords[idx_map2[i]] for i in range(len(stims2))])
        st.success(f"Pooled LL: {-pooled_ll/total_triads_pooled:.4f} — using as warm start for A and B fits")

# real data MDS
st.markdown("#### Real data MDS")
prog = st.progress(0, text="Fitting real data...")
progress_log = st.empty()   # live iteration-by-iteration progress, so the page doesn't look frozen

with st.spinner(f"Running {dim}D MDS on dataset 1..."):
    with live_progress(progress_log):
        real_coords1, real_ll1, residuals1 = run_mds(
            resp1, rep1, stims1, dim, max_iterations, learning_rate,
            log_every=print_every if print_every > 0 else 0, label=name1,
            start_points=start1, if_frozen=real_if_frozen)
prog.progress(50, text="Dataset 1 done...")

with st.spinner(f"Running {dim}D MDS on dataset 2..."):
    with live_progress(progress_log):
        real_coords2, real_ll2, residuals2 = run_mds(
            resp2, rep2, stims2, dim, max_iterations, learning_rate,
            log_every=print_every if print_every > 0 else 0, label=name2,
            start_points=start2, if_frozen=real_if_frozen)
prog.progress(100, text="Real data done.")
progress_log.empty()

real_disparity = compute_disparity(real_coords1, real_coords2, stims1, stims2)
final_ll1 = -real_ll1 / total_triads1
final_ll2 = -real_ll2 / total_triads2

col1, col2, col3 = st.columns(3)
col1.metric(f"{name1} LL", f"{final_ll1:.4f}", help="Log-likelihood per trial. Closer to 0 = better fit. Best possible model is the empirical choice probability itself.")
col2.metric(f"{name2} LL", f"{final_ll2:.4f}", help="Log-likelihood per trial. Closer to 0 = better fit.")
col3.metric("Real Procrustes D", f"{real_disparity:.4f}")

# convergence plot
if residuals1 or residuals2:
    st.markdown("#### Convergence")
    res_dict = {name1: residuals1, name2: residuals2}
    tri_dict = {name1: total_triads1, name2: total_triads2}
    styles = {name1: {"color": DATASET_COLORS[0]}, name2: {"color": DATASET_COLORS[1]}}
    if show_pooled and pooled_residuals:
        res_dict["Pooled (A+B)"] = pooled_residuals
        tri_dict["Pooled (A+B)"] = total_triads_pooled
        styles["Pooled (A+B)"] = {"color": "purple", "dash": "dash"}
    convergence_plot(res_dict, tri_dict, styles)

    # has the log-likelihood levelled off? (needs the progress log, so not when progress is off)
    _plateau = {name1: cost_plateau(residuals1, total_triads1), name2: cost_plateau(residuals2, total_triads2)}
    _still_improving = {n: r[1] for n, r in _plateau.items() if r is not None and not r[0]}
    if _still_improving:
        st.warning("Log-likelihood is still improving for " + ", ".join(
            f"{n} (changed {c:.2%} over the last 20% of iterations)" for n, c in _still_improving.items())
            + ". Consider more iterations.")
    elif all(r is not None for r in _plateau.values()):
        st.success("Log-likelihood has levelled off for both datasets.")

# surrogate convergence plot (warm start verification) — shown after real convergence, before surrogate run
# We'll render it after surrogates complete below. Store a flag here.
_show_surr_conv = show_pooled and n_surr_conv > 0

# prelim mode — stop here
if n_surrogates == 0:
    st.success("Preliminary run complete. Check the convergence plot above to decide how many iterations you need, then rerun with surrogates.")
    remove_temp_copies(path1, path2)
    st.stop()

# --- surrogates ---
st.markdown("#### Surrogate runs")

observations = pool_observations(resp1, rep1, resp2, rep2)
pool = build_pool(observations)

def _run_one_surrogate(args):
    seed, s_resp1, s_rep1, s_resp2, s_rep2, stims1, stims2, dim, max_iterations, learning_rate, start1, start2, track_conv = args
    log_every = 1 if track_conv else 0
    coords1, ll1, res1 = run_mds(s_resp1, s_rep1, stims1, dim, max_iterations, learning_rate,
                                  log_every=log_every, label="Surrogate A", start_points=start1)
    coords2, ll2, res2 = run_mds(s_resp2, s_rep2, stims2, dim, max_iterations, learning_rate,
                                  log_every=log_every, label="Surrogate B", start_points=start2)
    disp = compute_disparity(coords1, coords2, stims1, stims2)
    ll_a = -ll1 / sum(s_rep1.values())
    ll_b = -ll2 / sum(s_rep2.values())
    return disp, ll_a, ll_b, res1 if track_conv else [], res2 if track_conv else []

# build all surrogate pairs
jobs = []
for seed in range(n_surrogates):
    np.random.seed(seed)
    if resample_method == 'without_replacement_paired':
        s_resp1, s_rep1, s_resp2, s_rep2 = resample_paired(pool, resp1, rep1, resp2, rep2)
    else:
        s_resp1, s_rep1 = resample_dataset(pool, resp1, rep1, resample_method)
        s_resp2, s_rep2 = resample_dataset(pool, resp2, rep2, resample_method)
    track = (seed < n_surr_conv)
    jobs.append((seed, s_resp1, s_rep1, s_resp2, s_rep2, stims1, stims2, dim,
                 surrogate_max_iter, learning_rate, start1, start2, track))

from concurrent.futures import ThreadPoolExecutor
# max_workers lowered from 8 -- Streamlit Cloud's free tier gives each app
# ~1 shared CPU core, so 8 parallel CPU-heavy fits were fighting over that
# one core instead of actually running faster, and triggering the platform's
# throttling/OOM-restart under load. 2 is much lighter, still parallel.
with st.spinner(f"Running {n_surrogates} surrogates..."):
    with ThreadPoolExecutor(max_workers=min(2, len(jobs))) as ex:
        results = list(ex.map(_run_one_surrogate, jobs))

surrogate_disparities = np.array([r[0] for r in results])
surrogate_lls = [(r[1], r[2]) for r in results]
surrogate_conv_results = [(r[3], r[4]) for r in results if r[3]]  # only tracked surrogates

p_value = float(np.mean(surrogate_disparities >= real_disparity))

# --- results ---
st.markdown("#### Results")

m1, m2, m3, m4 = st.columns(4)
m1.metric("Real Procrustes D", f"{real_disparity:.4f}")
m2.metric("Surrogate mean", f"{surrogate_disparities.mean():.4f}", help="Mean Procrustes D across the surrogate pairs.")
m3.metric("Surrogate std", f"{surrogate_disparities.std():.4f}", help="Standard deviation of Procrustes D across the surrogate pairs.")
m4.metric("p-value", f"{p_value:.2f}", help="Fraction of surrogates with Procrustes D ≥ real.")

if p_value < 0.05:
    st.success(f"Statistically significant at p = 0.05 (p = {p_value:.2f}) — the two maps are more different than expected by chance.")
else:
    st.warning(f"Not statistically significant at p = 0.05 (p = {p_value:.2f}) — cannot rule out that the difference is due to chance.")

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
# level the real disparity must exceed to be significant at 0.05: 5% of surrogates are at or above it
# (a 1% level can be added the same way, once there are enough surrogates for it to mean something)
critical_5pct = float(np.quantile(surrogate_disparities, 0.95))
fig_dist.add_vline(
    x=critical_5pct, line_color="#1F4E8C", line_dash="dot",
    annotation_text=f"5% level: {critical_5pct:.4f}", annotation_position="top left"
)
fig_dist.update_layout(
    xaxis_title="Procrustes D", yaxis_title="Count",
    height=300, margin=dict(l=40, r=20, t=20, b=40),
    showlegend=False
)
st.plotly_chart(fig_dist, use_container_width=True)
st.caption("Red dashed line = real Procrustes D. Dark blue dotted line = 5% level of the surrogates.")

# surrogate convergence (warm start verification)
if _show_surr_conv and surrogate_conv_results:
    st.markdown("#### Warm start verification — surrogate convergence")
    st.caption(f"First {len(surrogate_conv_results)} surrogate(s) (dashed) and the real fits (solid).")
    surr_res_dict = {name1: residuals1, name2: residuals2}
    surr_tri_dict = {name1: total_triads1, name2: total_triads2}
    surr_styles = {name1: {"color": DATASET_COLORS[0]}, name2: {"color": DATASET_COLORS[1]}}
    for i, (res_a, res_b) in enumerate(surrogate_conv_results):
        lbl_a = f"Surrogate {i+1} A"
        lbl_b = f"Surrogate {i+1} B"
        surr_res_dict[lbl_a] = res_a
        surr_res_dict[lbl_b] = res_b
        surr_tri_dict[lbl_a] = sum(jobs[i][2].values())   # s_rep1 total
        surr_tri_dict[lbl_b] = sum(jobs[i][4].values())   # s_rep2 total
        surr_styles[lbl_a] = {"color": SURROGATE_COLOR, "dash": "dash", "name": "Surrogates",
                              "legendgroup": "surrogates", "showlegend": i == 0}
        surr_styles[lbl_b] = {"color": SURROGATE_COLOR, "dash": "dash", "name": "Surrogates",
                              "legendgroup": "surrogates", "showlegend": False}
    convergence_plot(surr_res_dict, surr_tri_dict, surr_styles)

# surrogate LL table
st.markdown("#### Surrogate log-likelihoods")
import pandas as pd
full_tbl = {
    "Surrogate": list(range(1, n_surrogates + 1)),
    f"LL ({name1})": [f"{r[0]:.4f}" for r in surrogate_lls],
    f"LL ({name2})": [f"{r[1]:.4f}" for r in surrogate_lls],
    "Procrustes D": [f"{d:.4f}" for d in surrogate_disparities],
}
st.dataframe(full_tbl, use_container_width=True, hide_index=True)

# --- download results as files (machine-readable, for the lab's comparison tables) ---
from rs_tools.results_export import (build_record, record_bytes, bundle_zip, table_csv,
                                     coords_csv, convergence_csv, summary_table_csv)

st.markdown("#### Download results")
st.caption("Save this whole run as files: settings, real and surrogate Procrustes D and log-likelihoods, the "
           "p-value, both fitted maps (raw and aligned), the convergence curves, the surrogate table and the "
           "histogram. \"Download everything\" packs all of it into one zip.")

# the two maps on the shared stimuli, centered, with dataset 2 rotated onto dataset 1
# (the alignment behind the disparity)
_a1, _a2, _shared = align_to_shared_stimuli(real_coords1, stims1, real_coords2, stims2)
_a1 = _a1 - _a1.mean(axis=0)
_a2 = _a2 - _a2.mean(axis=0)
_rot, _ = orthogonal_procrustes(_a1, _a2)
_a2 = _a2 @ _rot.T


def _curve(residuals, total_triads):
    # residuals are (iteration, negative log-likelihood) pairs; the plots show log-likelihood per triad
    if not residuals or not total_triads:
        return None
    return np.array([[it, -nll / total_triads] for it, nll in residuals], dtype=float)


_conv1, _conv2 = _curve(residuals1, total_triads1), _curve(residuals2, total_triads2)
_conv_pooled = _curve(pooled_residuals, total_triads_pooled) if show_pooled else None

result_record = build_record(
    source="app.py (Surrogate MDS app)", dataset1=name1, dataset2=name2,
    file1=file1.name if input_mode == "Upload files" else os.path.basename(path1_direct),
    file2=file2.name if input_mode == "Upload files" else os.path.basename(path2_direct),
    dim=dim, n_surrogates=n_surrogates,
    max_iterations_real=max_iterations, max_iterations_surrogate=surrogate_max_iter,
    learning_rate=learning_rate, resample_method=resample_method, warm_start=show_pooled,
    seed_mode="pooled warm start" if show_pooled else seed_mode,
    n_shared_stimuli=len(set(stims1) & set(stims2)), n_triads1=total_triads1, n_triads2=total_triads2,
    real_disparity=real_disparity, real_ll1=final_ll1, real_ll2=final_ll2,
    surrogate_disparities=surrogate_disparities,
    surrogate_ll1=[r[0] for r in surrogate_lls], surrogate_ll2=[r[1] for r in surrogate_lls],
    extras={"stim_labels1": stims1, "stim_labels2": stims2,
            "real_coords1": real_coords1, "real_coords2": real_coords2,
            "shared_stim_labels": _shared, "aligned_coords1": _a1, "aligned_coords2": _a2,
            "convergence_dataset1": _conv1, "convergence_dataset2": _conv2,
            "convergence_pooled": _conv_pooled})
st.caption(f"p-value {result_record['p_value']:.2f} is the fraction of surrogates at or above the real Procrustes D "
           f"({result_record['n_surrogates_ge_real']} of {n_surrogates}). With {n_surrogates} surrogates it can only be a "
           f"multiple of 1/{n_surrogates}; 0 means none of them reached the real Procrustes D.")

_surrogate_csv = table_csv(
    ["surrogate", f"ll_per_triad_{name1}", f"ll_per_triad_{name2}", "procrustes_D"],
    [[i + 1, repr(float(r[0])), repr(float(r[1])), repr(float(d))]
     for i, (r, d) in enumerate(zip(surrogate_lls, surrogate_disparities))])
_summary_csv = summary_table_csv(result_record)
_histogram_html = fig_dist.to_html(include_plotlyjs="cdn").encode("utf-8")
_bundle = bundle_zip(result_record, {
    "summary_table.csv": _summary_csv,
    "surrogate_table.csv": _surrogate_csv,
    "coordinates_dataset1.csv": coords_csv(stims1, real_coords1),
    "coordinates_dataset2.csv": coords_csv(stims2, real_coords2),
    "aligned_dataset1.csv": coords_csv(_shared, _a1),
    "aligned_dataset2.csv": coords_csv(_shared, _a2),
    "convergence.csv": convergence_csv({name1: _conv1, name2: _conv2, "pooled": _conv_pooled}),
    "disparity_histogram.html": _histogram_html})

_file_stem = f"{name1}_vs_{name2}_{dim}d_{n_surrogates}surr_{resample_method}"
# Streamlit 1.43+ can skip the page rerun a download click normally causes; this page stops
# without the Run button, so a rerun would wipe the results.
_no_rerun = {"on_click": "ignore"} if tuple(int(x) for x in st.__version__.split(".")[:2]) >= (1, 43) else {}
st.download_button("Download everything (.zip)", _bundle, file_name=f"{_file_stem}_all.zip",
                   mime="application/zip", key="dl_results_all", type="primary", **_no_rerun)
st.caption("Or one file at a time:")
_cols = st.columns(6)
for _col, (_label, _data, _name, _mime) in zip(_cols, [
        ("Summary table .csv", _summary_csv, f"{_file_stem}_summary_table.csv", "text/csv"),
        ("Summary .json", record_bytes(result_record, "json"), f"{_file_stem}.json", "application/json"),
        ("Summary .mat", record_bytes(result_record, "mat"), f"{_file_stem}.mat", "application/octet-stream"),
        ("Summary .npz", record_bytes(result_record, "npz"), f"{_file_stem}.npz", "application/octet-stream"),
        ("Surrogate table .csv", _surrogate_csv, f"{_file_stem}_surrogates.csv", "text/csv"),
        ("Histogram .html", _histogram_html, f"{_file_stem}_histogram.html", "text/html")]):
    _col.download_button(_label, _data, file_name=_name, mime=_mime,
                         key="dl_results_" + _name.rsplit(".", 1)[0].rsplit("_", 1)[-1] + "_" + _name.rsplit(".", 1)[-1],
                         **_no_rerun)

remove_temp_copies(path1, path2)
