"""
fit_brightness_ooo.py — fit 2D/3D MDS models to the OOO-converted brightness choice file
and save a coords .mat file, without going through the Streamlit UI.

Mirrors the exact computation path of run_model_fitting_ui.py's run_mds_single_dim() /
build_mat_output(), just without the streamlit dependency, so it can run as a plain script.

Usage:
    cd ~/Downloads/rs-software
    python3 fit_brightness_ooo.py <input_triadic.mat> <output_coords.mat> [--dims 2,3] [--max-iter 5000]
"""

import argparse
import numpy as np
from scipy.spatial.distance import pdist

from src.rs_py.utils.util import load_choices
from src.rs_py.utils.config import CONFIG
from src.rs_py.utils.helpers import bias_dict, read_out_median_bias
import src.rs_py.model.fit_geometric_models as rs
import src.rs_py.choices.choice_likelihoods as an
from scipy.io import savemat

DEFAULTS = CONFIG['inputs']['model_fit']


def run_mds_single_dim(responses, repeats, n_stim, dim, sigma, max_iter, tolerance,
                        learning_rate, minimization):
    args = {
        'num_stimuli':    n_stim,
        'sigma':          sigma,
        'noise_st_dev':   sigma,
        'tolerance':      tolerance,
        'max_iterations': max_iter,
        'learning_rate':  learning_rate,
        'minimization':   minimization,
        'n_dim':          dim,
        'log_every':      0,
        'label':          f"{dim}D",
    }
    coords, ll, residuals = rs.points_of_best_fit(responses, repeats, args)
    return coords, ll, residuals


def build_mat_output(coords_by_dim, lls_by_dim, stim_list, model_dimensions):
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

    bias_estimates = []
    for d in model_dimensions:
        try:
            b = float(read_out_median_bias(bias_df, d, rms_dists_by_dim[d]))
        except Exception:
            b = 0.0
        bias_estimates.append(b)
    bias_estimates = np.array(bias_estimates)

    debiased = raw_lls - best_ll + bias_estimates

    data['rawLLs'] = raw_lls
    data['bestModelLL'] = best_ll
    data['randModelLL'] = rand_ll
    data['biasEstimate'] = bias_estimates
    data['debiasedRelativeLL'] = debiased
    max_len = max(len(s) for s in stim_list)
    data['stim_list'] = np.array(stim_list, dtype=f'S{max_len}')
    return data


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input_path')
    parser.add_argument('output_path')
    parser.add_argument('--dims', default='2,3')
    parser.add_argument('--max-iter', type=int, default=5000)
    args = parser.parse_args()

    model_dimensions = [int(x) for x in args.dims.split(',')]
    sigma = DEFAULTS['sigma']
    tolerance = DEFAULTS['tolerance']
    learning_rate = DEFAULTS['learning_rate']
    minimization = DEFAULTS['minimization']

    print(f"Loading {args.input_path} ...")
    responses, repeats, metadata, stim_list = load_choices(args.input_path)
    total_triads = sum(repeats.values())
    n_stim = len(stim_list)
    print(f"Loaded: {n_stim} stimuli, {len(responses)} unique comparisons, {total_triads} total trials")

    coords_by_dim = {}
    lls_by_dim = {}

    for dim in model_dimensions:
        print(f"\nFitting {dim}D model (max_iter={args.max_iter}) ...")
        coords, ll, residuals = run_mds_single_dim(
            responses, repeats, n_stim, dim, sigma, args.max_iter, tolerance,
            learning_rate, minimization
        )
        coords_by_dim[dim] = coords
        lls_by_dim[dim] = -ll / total_triads
        print(f"  {dim}D LL per triad: {lls_by_dim[dim]:.5f}")

    ll_best, _ = an.best_model_ll(responses, repeats)
    ll_random, _ = an.random_choice_ll(responses, repeats)
    lls_by_dim['best'] = ll_best / total_triads
    lls_by_dim['random'] = ll_random / total_triads
    print(f"\nBest possible LL per triad:   {lls_by_dim['best']:.5f}")
    print(f"Random-choice LL per triad:   {lls_by_dim['random']:.5f}")

    out_dict = build_mat_output(coords_by_dim, lls_by_dim, stim_list, model_dimensions)
    savemat(args.output_path, out_dict)
    print(f"\nSaved: {args.output_path}")
