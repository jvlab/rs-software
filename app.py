"""
app.py — Streamlit UI for surrogate MDS analysis.

Run from inside rs-software:
    cd ~/Downloads/rs-software
    streamlit run app.py
"""

import sys
import os
import tempfile
import numpy as np
import matplotlib.pyplot as plt
import plotly.graph_objects as go
from scipy.linalg import orthogonal_procrustes
import streamlit as st

# repo root — works both locally (cd rs-software && streamlit run app.py) and on Streamlit Cloud
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rs_ui import convergence_plot

from src.rs_py.utils.util import load_choices
from src.rs_py.utils.config import CONFIG
import src.rs_py.model.fit_geometric_models as rs
from rng_control import initialize_random_state

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
                                  value=float(DEFAULT_LEARNING_RATE), step=0.001, format="%.3f",
                                  help="Controls how fast the model updates at each step. The default (0.05) works well for most datasets — only adjust if the convergence plot shows instability.")
if _c2.button("↺", key="d_lr", help="Reset to default"):
    learning_rate = DEFAULT_LEARNING_RATE
st.sidebar.caption("ℹ️ Learning rate rarely needs changing. Default of 0.05 is appropriate for most runs.")

# Print convergence interval
_c1, _c2 = st.sidebar.columns([3, 1])
print_every = _c1.number_input("Print LL every N iters (0 = off)", min_value=0, max_value=10000,
                                value=0, step=50)
if _c2.button("↺", key="d_pe", help="Reset to default"):
    print_every = 0

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
        value=1, step=1,
        help="Plots the convergence curve for the first N surrogates to verify warm start is working.")
    if _c2.button("↺", key="d_surr_conv", help="Reset to default"):
        n_surr_conv = 1
else:
    surrogate_max_iter = max_iterations
    n_surr_conv = 0

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
st.title("rs-software")
tab_analysis, tab_convert, tab_c2c, tab_ooo = st.tabs(["Surrogate MDS Analysis", "Convert .mat → NumPy", "Choice → Coordinates", "OOO → Triadic"])

with tab_convert:
    st.header("Convert choice file to NumPy")
    st.markdown(
        "Upload a `.mat` choices file and download it as a `.npy` array "
        "with columns: `[ref, s1, s2, n_s1_chosen, n_repeats]` (1-indexed)."
    )
    conv_file = st.file_uploader("Upload .mat choices file", type=["mat"], key="conv_upload")
    if conv_file is not None:
        with tempfile.NamedTemporaryFile(suffix=".mat", delete=False) as tmp:
            tmp.write(conv_file.read())
            tmp_path = tmp.name
        try:
            from convert_mat_to_numpy import mat_to_numpy
            arr, stim_list = mat_to_numpy(tmp_path)
            st.success(f"Loaded: **{arr.shape[0]} trials**, **{len(stim_list)} stimuli**")
            st.markdown(f"**Stimuli:** {', '.join(stim_list[:10])}{'...' if len(stim_list) > 10 else ''}")
            st.dataframe(
                {"ref": arr[:,0].astype(int), "s1": arr[:,1].astype(int),
                 "s2": arr[:,2].astype(int), "n_s1_chosen": arr[:,3].astype(int),
                 "n_repeats": arr[:,4].astype(int)},
                use_container_width=True, height=300
            )
            buf = arr.tobytes()
            out_name = conv_file.name.replace(".mat", ".npy")
            st.download_button("Download .npy file", data=buf, file_name=out_name, mime="application/octet-stream")
        except Exception as e:
            st.error(f"Conversion failed: {e}")
        finally:
            os.unlink(tmp_path)

with tab_c2c:
    st.header("Choice → Coordinates")
    st.markdown(
        "Upload a `.mat` choices file, fit MDS models at dimensions 1–7, "
        "and download a coordinates `.mat` file matching JV's format."
    )
    st.info(
        "Fits models at **all 7 dimensions**. Output includes `dim1`–`dim7`, `rawLLs`, `bestModelLL`, "
        "`biasEstimate`, `debiasedRelativeLL`, `metadata`, and `stim_labels`."
    )

    c2c_file = st.file_uploader("Upload .mat choices file", type=["mat"], key="c2c_upload")

    c2c_c1, c2c_c2 = st.columns(2)
    with c2c_c1:
        c2c_max_iter = st.number_input("Max iterations per dimension", min_value=100, max_value=10000,
                                        value=2000, step=100, key="c2c_iter")
    with c2c_c2:
        c2c_lr = st.number_input("Learning rate", min_value=0.001, max_value=1.0,
                                  value=float(DEFAULT_LEARNING_RATE), step=0.001,
                                  format="%.3f", key="c2c_lr",
                                  help="Controls how fast the model updates at each step. Default of 0.05 works for most datasets.")
        st.caption("ℹ️ Learning rate rarely needs changing. Default of 0.05 is appropriate for most runs.")

    c2c_run = st.button("Fit coordinates (1–7D)", type="primary", key="c2c_run")

    if c2c_file is not None and c2c_run:
        with tempfile.NamedTemporaryFile(suffix=".mat", delete=False) as tmp:
            tmp.write(c2c_file.read())
            c2c_tmp = tmp.name
        try:
            with st.spinner("Loading choices..."):
                c2c_resp, c2c_rep, c2c_stims = load_mat(c2c_tmp)

            n_trials = sum(c2c_rep.values())
            st.info(f"Loaded **{len(c2c_stims)} stimuli**, **{n_trials} trials** — fitting 7 models...")

            import io, scipy.io as sio_c2c, pandas as pd

            c2c_out = {}
            raw_lls = {}
            all_residuals = {}
            prog = st.progress(0, text="Fitting 1D...")
            prev_coords = None

            for d in range(1, 8):
                prog.progress(int((d - 1) / 7 * 100), text=f"Fitting {d}D...")
                coords_d, ll_d, res_d = run_mds(
                    c2c_resp, c2c_rep, c2c_stims, d, c2c_max_iter, c2c_lr,
                    log_every=1, label=f"dim{d}", start_points=prev_coords)
                c2c_out[f'dim{d}'] = coords_d[:, :d]
                raw_lls[d] = float(-ll_d)
                all_residuals[f'dim{d}'] = res_d
                # use this dim's coords as warm start for next dim (add small random column to avoid rank deficiency)
                if d < 7:
                    extra = np.random.normal(0, 1e-3, (coords_d.shape[0], 1))
                    prev_coords = np.hstack([coords_d, extra])
                else:
                    prev_coords = coords_d

            prog.progress(100, text="All dimensions done.")

            best_dim = max(raw_lls, key=raw_lls.get)
            best_ll = raw_lls[best_dim]

            st.success(f"Best model: **{best_dim}D** (LL = {best_ll/n_trials:.4f} per trial)")

            # convergence plots
            st.markdown("#### Convergence per dimension")
            st.caption("Each line is one dimension's fit. Flat = converged.")
            convergence_plot(
                {f"dim{d}": all_residuals[f'dim{d}'] for d in range(1, 8)},
                {f"dim{d}": n_trials for d in range(1, 8)},
                {}
            )

            # LL table
            st.markdown("#### Log-likelihoods by dimension")
            ll_df = pd.DataFrame({
                "Dimension": list(range(1, 8)),
                "Raw LL": [raw_lls[d] for d in range(1, 8)],
                "LL per trial": [raw_lls[d] / n_trials for d in range(1, 8)],
            })
            st.dataframe(ll_df, use_container_width=True, hide_index=True)

            # coordinates table (show best dim)
            st.markdown(f"#### Coordinates ({best_dim}D — best model)")
            coord_cols = [f"dim{i+1}" for i in range(best_dim)]
            c2c_df = pd.DataFrame(c2c_out[f'dim{best_dim}'], columns=coord_cols)
            c2c_df.insert(0, "stimulus", c2c_stims)
            st.dataframe(c2c_df, use_container_width=True, height=300)

            # build output .mat
            raw_lls_arr = np.array([raw_lls[d] for d in range(1, 8)])
            c2c_out['rawLLs'] = raw_lls_arr
            c2c_out['bestModelLL'] = float(best_ll)
            c2c_out['stim_labels'] = np.array(c2c_stims)

            # bias estimation
            try:
                from src.rs_py.utils.helpers import bias_dict, read_out_median_bias
                from scipy.spatial.distance import pdist
                bias_df = bias_dict()
                bias_est = []
                for d in range(1, 8):
                    pts = c2c_out[f'dim{d}']
                    rms = np.sqrt(np.mean(pdist(pts) ** 2))
                    bias_est.append(float(read_out_median_bias(bias_df, d, rms)))
                bias_est_arr = np.array(bias_est)
                debiased = raw_lls_arr - float(best_ll) + bias_est_arr
                c2c_out['biasEstimate'] = bias_est_arr
                c2c_out['debiasedRelativeLL'] = debiased
                c2c_out['metadata'] = (
                    "rawLLs[i] is the raw model LL for model with i+1 dimensions. "
                    "biasEstimate[i] is the median bias for the i+1-dimensional model. "
                    "debiasedRelativeLL = rawLLs + biasEstimate - bestModelLL."
                )
                st.success("Bias estimation complete — all fields populated.")
            except Exception as bias_err:
                c2c_out['metadata'] = (
                    "rawLLs[i] is the raw model LL for model with i+1 dimensions. "
                    f"biasEstimate and debiasedRelativeLL not computed: {bias_err}"
                )
                st.warning(f"Bias estimation failed: {bias_err}")

            c2c_buf = io.BytesIO()
            sio_c2c.savemat(c2c_buf, c2c_out)
            c2c_buf.seek(0)
            out_name = c2c_file.name.replace("choices", "coords").replace(".mat", "_7d.mat")
            st.download_button("Download coordinates .mat", data=c2c_buf,
                               file_name=out_name, mime="application/octet-stream")

        except Exception as e:
            st.error(f"Failed: {e}")
        finally:
            os.unlink(c2c_tmp)
    elif c2c_file is None:
        st.info("Upload a choices .mat file above to get started.")

with tab_ooo:
    st.header("OOO → Triadic")
    st.markdown(
        "Upload an **odd-one-out** `.mat` file and convert it to standard triadic choice format. "
        "Each OOO judgment generates exactly 2 triadic entries using JV's conversion rule."
    )
    st.info(
        "**Input format:** columns `s1, s2, s3, N(s1 odd), N(s2 odd), N(s3 odd)` (1-indexed)\n\n"
        "**Output format:** columns `ref, s1, s2, N(s1 chosen), N_repeats` (1-indexed)"
    )

    ooo_file = st.file_uploader("Upload OOO .mat file", type=["mat"], key="ooo_upload")

    if ooo_file is not None:
        with tempfile.NamedTemporaryFile(suffix=".mat", delete=False) as tmp:
            tmp.write(ooo_file.read())
            ooo_tmp = tmp.name
        try:
            from convert_ooo_to_triadic import ooo_to_triadic
            resp_ooo, rep_ooo, stims_ooo = ooo_to_triadic(ooo_tmp, out_path=None)

            n_input_triplets = None
            from scipy.io import loadmat as _loadmat
            _d = _loadmat(ooo_tmp)
            if 'responses' in _d:
                n_input_triplets = _d['responses'].shape[0]

            st.success(
                f"Converted: **{n_input_triplets} input triplets** → **{len(resp_ooo)} triadic trials** · **{len(stims_ooo)} stimuli**"
            )
            st.markdown(f"**Stimuli:** {', '.join(stims_ooo[:10])}{'...' if len(stims_ooo) > 10 else ''}")

            # build preview table
            import pandas as pd
            rows = []
            for (ref_s1, s1), (_, s2) in list(resp_ooo.keys())[:200]:
                key = ((ref_s1, s1), (ref_s1, s2))
                rows.append({
                    "ref": ref_s1 + 1,
                    "s1": s1 + 1,
                    "s2": s2 + 1,
                    "n_s1_chosen": resp_ooo[key],
                    "n_repeats": rep_ooo[key],
                    "ref_name": stims_ooo[ref_s1],
                    "s1_name": stims_ooo[s1],
                    "s2_name": stims_ooo[s2],
                })
            st.dataframe(pd.DataFrame(rows), use_container_width=True, height=300)

            # save and offer download
            with tempfile.NamedTemporaryFile(suffix=".mat", delete=False) as out_tmp:
                out_ooo_path = out_tmp.name
            ooo_to_triadic(ooo_tmp, out_path=out_ooo_path)
            with open(out_ooo_path, "rb") as f:
                ooo_bytes = f.read()
            os.unlink(out_ooo_path)

            out_ooo_name = ooo_file.name.replace("ooo", "triadic").replace(".mat", "_triadic.mat")
            if "triadic" not in out_ooo_name:
                out_ooo_name = ooo_file.name.replace(".mat", "_triadic.mat")
            st.download_button("Download triadic .mat", data=ooo_bytes,
                               file_name=out_ooo_name, mime="application/octet-stream")

            # ---- Step 2: fit 2D and 3D coordinates directly from the converted data ----
            st.markdown("---")
            st.subheader("Fit 2D & 3D coordinates")
            st.caption("Runs directly on the triadic data above -- no need to re-upload the download.")

            ooo_max_iter = st.number_input("Max iterations", min_value=100, value=3000, step=100, key="ooo_max_iter")
            if st.button("Fit coordinates", key="ooo_fit_btn"):
                from fit_brightness_ooo import run_mds_single_dim, build_mat_output
                import src.rs_py.choices.choice_likelihoods as an

                total_triads_ooo = sum(rep_ooo.values())
                n_stim_ooo = len(stims_ooo)
                coords_by_dim_ooo = {}
                lls_by_dim_ooo = {}
                progress_ooo = st.progress(0, text="Fitting...")
                for i, dim in enumerate([2, 3]):
                    progress_ooo.progress(i / 2, text=f"Fitting {dim}D model...")
                    coords, ll, _ = run_mds_single_dim(
                        resp_ooo, rep_ooo, n_stim_ooo, dim, CONFIG['inputs']['model_fit']['sigma'],
                        ooo_max_iter, CONFIG['inputs']['model_fit']['tolerance'],
                        CONFIG['inputs']['model_fit']['learning_rate'], CONFIG['inputs']['model_fit']['minimization']
                    )
                    coords_by_dim_ooo[dim] = coords
                    lls_by_dim_ooo[dim] = -ll / total_triads_ooo
                ll_best_ooo, _ = an.best_model_ll(resp_ooo, rep_ooo)
                ll_random_ooo, _ = an.random_choice_ll(resp_ooo, rep_ooo)
                lls_by_dim_ooo['best'] = ll_best_ooo / total_triads_ooo
                lls_by_dim_ooo['random'] = ll_random_ooo / total_triads_ooo
                progress_ooo.progress(1.0, text="Done.")

                st.success(
                    f"2D LL/triad: {lls_by_dim_ooo[2]:.4f}  |  3D LL/triad: {lls_by_dim_ooo[3]:.4f}  "
                    f"(best possible: {lls_by_dim_ooo['best']:.4f}, random: {lls_by_dim_ooo['random']:.4f})"
                )

                # group stimuli by trailing condition code (e.g. sNNcMM -> group MM,
                # ordered by NN) so trajectories can be colored/connected per group,
                # same as plot_ooo_trajectory.py / plot_ooo_trajectory_3d.py.
                # Falls back to a single ungrouped series if names don't match that pattern.
                import re as re_ooo
                groups_ooo = {}
                for i, label in enumerate(stims_ooo):
                    m = re_ooo.match(r's(\d+)c(\d+)', label)
                    level, cond = (int(m.group(1)), m.group(2)) if m else (i, 'all')
                    groups_ooo.setdefault(cond, []).append((level, i, label))
                for cond in groups_ooo:
                    groups_ooo[cond].sort(key=lambda e: e[0])
                palette_ooo = {'01': 'tab:blue', '02': 'tab:orange'}
                palette3d_ooo = {'01': '#1f77b4', '02': '#ff7f0e'}

                st.markdown("**2D map**")
                fig_ooo, ax_ooo = plt.subplots(figsize=(7, 6))
                coords2d_ooo = coords_by_dim_ooo[2]
                for cond, entries in sorted(groups_ooo.items()):
                    color = palette_ooo.get(cond, 'gray')
                    xs = [coords2d_ooo[i, 0] for _, i, _ in entries]
                    ys = [coords2d_ooo[i, 1] for _, i, _ in entries]
                    ax_ooo.plot(xs, ys, color=color, linestyle='--', zorder=1,
                                label=f'contrast c{cond}' if cond != 'all' else None)
                    ax_ooo.scatter(xs, ys, color=color, zorder=5)
                    for level, i, label in entries:
                        ax_ooo.annotate(label, (coords2d_ooo[i, 0], coords2d_ooo[i, 1]),
                                        textcoords="offset points", xytext=(0, 8), ha='center', fontsize=8)
                ax_ooo.set_xlabel("Dimension 1")
                ax_ooo.set_ylabel("Dimension 2")
                ax_ooo.set_title("2D map fitted from the converted OOO data")
                if any(cond != 'all' for cond in groups_ooo):
                    ax_ooo.legend()
                ax_ooo.grid(True)
                st.pyplot(fig_ooo)

                st.markdown("**3D map** (drag to rotate)")
                coords3d_ooo = coords_by_dim_ooo[3]
                fig3d_ooo = go.Figure()
                for cond, entries in sorted(groups_ooo.items()):
                    color = palette3d_ooo.get(cond, 'gray')
                    xs = [coords3d_ooo[i, 0] for _, i, _ in entries]
                    ys = [coords3d_ooo[i, 1] for _, i, _ in entries]
                    zs = [coords3d_ooo[i, 2] for _, i, _ in entries]
                    labels = [label for _, _, label in entries]
                    fig3d_ooo.add_trace(go.Scatter3d(
                        x=xs, y=ys, z=zs, mode='lines+markers+text',
                        line=dict(color=color, dash='dash'), marker=dict(size=5, color=color),
                        text=labels, textposition='top center',
                        name=f'contrast c{cond}' if cond != 'all' else 'stimuli',
                    ))
                fig3d_ooo.update_layout(
                    scene=dict(xaxis_title="Dimension 1", yaxis_title="Dimension 2", zaxis_title="Dimension 3"),
                    margin=dict(l=0, r=0, b=0, t=30),
                    title="3D map fitted from the converted OOO data",
                )
                st.plotly_chart(fig3d_ooo, use_container_width=True)

                import io as io_ooo
                from scipy.io import savemat as savemat_ooo
                out_dict_ooo = build_mat_output(coords_by_dim_ooo, lls_by_dim_ooo, stims_ooo, [2, 3])
                coords_buf = io_ooo.BytesIO()
                savemat_ooo(coords_buf, out_dict_ooo)
                coords_out_name = ooo_file.name.replace(".mat", "_coords.mat")
                st.download_button("Download coords .mat", data=coords_buf.getvalue(),
                                   file_name=coords_out_name, mime="application/octet-stream",
                                   key="ooo_coords_download")

        except Exception as e:
            st.error(f"Conversion failed: {e}")
        finally:
            os.unlink(ooo_tmp)
    else:
        st.info("Upload an OOO .mat file above to get started.")

with tab_analysis:

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
                log_every=1, label="Pooled", if_frozen=1)
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

    # surrogate convergence plot (warm start verification) — shown after real convergence, before surrogate run
    # We'll render it after surrogates complete below. Store a flag here.
    _show_surr_conv = show_pooled and n_surr_conv > 0

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
    with st.spinner(f"Running {n_surrogates} surrogates..."):
        with ThreadPoolExecutor(max_workers=min(8, len(jobs))) as ex:
            results = list(ex.map(_run_one_surrogate, jobs))

    surrogate_disparities = np.array([r[0] for r in results])
    surrogate_lls = [(r[1], r[2]) for r in results]
    surrogate_conv_results = [(r[3], r[4]) for r in results if r[3]]  # only tracked surrogates

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

    # surrogate convergence (warm start verification)
    if _show_surr_conv and surrogate_conv_results:
        st.markdown("#### Warm start verification — surrogate convergence")
        st.caption(
            f"Convergence of the first {len(surrogate_conv_results)} surrogate(s) (dashed), overlaid with the real fits (solid). "
            "If warm start is working, surrogates should converge in far fewer iterations."
        )
        surr_res_dict = {name1: residuals1, name2: residuals2}
        surr_tri_dict = {name1: total_triads1, name2: total_triads2}
        surr_styles = {}
        for i, (res_a, res_b) in enumerate(surrogate_conv_results):
            lbl_a = f"Surrogate {i+1} A"
            lbl_b = f"Surrogate {i+1} B"
            surr_res_dict[lbl_a] = res_a
            surr_res_dict[lbl_b] = res_b
            surr_tri_dict[lbl_a] = sum(jobs[i][2].values())   # s_rep1 total
            surr_tri_dict[lbl_b] = sum(jobs[i][4].values())   # s_rep2 total
            surr_styles[lbl_a] = {"color": "#378ADD", "dash": "dash"}
            surr_styles[lbl_b] = {"color": "#E24B4A", "dash": "dash"}
        convergence_plot(surr_res_dict, surr_tri_dict, surr_styles)

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
