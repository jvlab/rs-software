"""Script wrapper for the geometric model fit demo."""

import random
import numpy as np
import pandas as pd
from copy import deepcopy
from scipy.spatial.distance import pdist
import src.rs_py.model.fit_geometric_models as rs
import src.rs_py.choices.choice_likelihoods as an
from src.rs_py.utils.helpers import create_coords_file
from src.rs_py.utils.util import read_combined_choices

from src.rs_py.utils.config import CONFIG

REQUIRED_KEYS = ("filepath", "output_dir")


def build_model_fit_args(user_params):
    """
    Args:
        user_params (dict):
            Partial parameter dictionary supplied by the caller.
            Any keys present here override the defaults in CONFIG["inputs"]["model_fit"].
            If provided, this may include required keys such as "filepath" and "output_dir",
            along with optional settings like "sigma" or "model_dimensions".
    Returns:
        args (dict):
        A complete parameter dictionary for the model-fit runner.
        This is built from CONFIG["inputs"]["model_fit"] plus any overrides from user_params.

    Notes:
        The returned dict is intended to be passed directly to the run function.
         Required keys must still be present after merging.
    """
    params = deepcopy(CONFIG["inputs"]["model_fit"])

    # Merge a partial user dict over the defaults.
    if user_params:
        params.update(user_params)

    missing = [k for k in REQUIRED_KEYS if not params.get(k)]
    if missing:
        raise ValueError(f"Missing required parameter(s): {', '.join(missing)}")

    args = {
        "filepath": params["filepath"],
        "outdir": params["output_dir"],
        "exp_name": params["exp_name"],
        "subject": params["subject"],
        "sigma": params["sigma"],
        "model_dimensions": params["model_dimensions"],
        "learning_rate": params["learning_rate"],
        "tolerance": params["tolerance"],
        "max_iterations": params["max_iterations"],
        "minimization": params["minimization"],
        "filter_trials": params["max_trials"],
    }

    # Convenience alias used by the fitting code.
    args["noise_st_dev"] = args["sigma"]

    return args


def fit(params):
    """
    Fit Euclidean geometric models to aggregated choice data and save model outputs.

    This function loads a combined choice file, optionally subsamples a fixed
    number of unique triadic judgments, fits Euclidean models across one or more
    requested dimensions, compares them against best-choice and random-choice
    baselines, and saves both a CSV summary and a `.mat` file of fitted
    coordinates.

    Args:
        params (dict):
            Dictionary of run parameters. Common keys include:

            Required:
                filepath (str):
                    Path to the combined choices `.mat` file.
                outdir (str):
                    Directory where output files will be written.

            Recommended / commonly used:
                exp_name (str):
                    Experiment name used in output filenames.
                subject (str):
                    Subject ID used in output filenames.
                model_dimensions (list[int]):
                    Dimensions to fit, for example `[1, 2, 3, 4, 5]`.
                    The default is typically a small set of low-dimensional models,
                    but this can be changed depending on the number of stimuli and
                    the modeling goal. Tested values may extend beyond the default
                    range.
                sigma (float):
                    Noise standard deviation used in the choice model. This is a
                    required scale parameter and is usually kept near 1.
                learning_rate (float):
                    Learning rate for optimization.
                tolerance (float):
                    Convergence tolerance used by the optimizer. This is most
                    relevant for gradient-descent-based fitting.
                max_iterations (int):
                    Maximum number of optimization iterations.
                minimization (str):
                    Optimization method. Supported values include
                    `gradient-descent` and `nelder-mead`.
                    Gradient descent is typically faster and the recommended
                    default.
                filter_trials (int):
                    Maximum number of unique triadic judgments to use. Set to 0
                    or omit to use all available data. If this is smaller than the
                    total number of unique comparisons, the function samples a
                    random subset.

    Returns:
        None:
            Writes output files to `outdir` and prints a summary to the console.

    Raises:
        FileNotFoundError:
            If the input file does not exist.
        ValueError:
            If no triadic judgments are found after loading or filtering.

    Notes:
        - The input file is expected to be a combined choice file produced by the
          earlier aggregation step.
        - `sigma` is a required noise scale and controls the uncertainty in
          distance comparisons.
        - `model_dimensions` should be chosen with the number of stimuli and the
          intended model complexity in mind.
        - The function saves fitted coordinates for each dimension, along with a
          CSV comparing model log-likelihoods.
    """
    print("\n" + "=" * 70)
    print("GEOMETRIC MODEL FIT")
    print("=" * 70)

    print("DATA")
    print("-" * 70)
    print(f"Filepath:            {params['filepath']}")
    print(f"Experiment:          {params['exp_name']}")
    print(f"Subject:             {params['subject']}")
    print(f"Output directory:    {params['outdir']}")
    print(f"Max trials used:     {params['filter_trials']}")

    print("\nOPTIMIZATION SETTINGS")
    print("-" * 70)
    print(f"Max iterations:      {params['max_iterations']}")
    print(f"Learning rate:       {params['learning_rate']}")
    print(f"Tolerance:           {params['tolerance']}")

    print("\nNOISE PARAMETERS")
    print("-" * 70)
    print(f"Sigma (compare):     {params['sigma']:.6f}")

    print("=" * 70)

    # break up ranking responses into pairwise judgments
    pairwise_responses, pairwise_num_repeats, metadata, stim_list = read_combined_choices(params['filepath'])
    params["num_stimuli"] = len(stim_list)

    print("\nLoaded pairwise judgments")
    print("-" * 60)
    print(f"Number of unique comparisons: {len(pairwise_responses)}")
    print(f"Total triads (including repeats): {sum(pairwise_num_repeats.values())}")
    print("-" * 60)

    # only consider a subset of trials
    subset = {}
    if params['filter_trials']:
        if params['filter_trials'] < len(pairwise_responses):
            all_keys = list(pairwise_responses.keys())
            chosen = random.sample(all_keys, params['filter_trials'])
            subset = {k: pairwise_responses[k] for k in chosen}

            print("\nUsing subset of trials")
            print("-" * 60)
            print(f"Trials used: {len(subset)}")
            print(f"Total triads used: {sum(pairwise_num_repeats[k] for k in subset)}")
            print("=" * 60)
        else:
            subset = pairwise_responses
    else:
        subset = pairwise_responses

    # initialize results dataframe
    total_num_triads = sum([pairwise_num_repeats[k] for k in subset.keys()])
    if total_num_triads == 0:
        raise ValueError("No triads found (total_num_triads == 0). Check input data or arguments.")

    # initialize results
    result = {
        "Model": [],
        "Log Likelihood": [],
        "number of points": [],
        "Experiment": [],
        "Subject": []
    }

    # Euclidean models across dimensions
    coords_by_dim = {}
    lls_by_dim = {}

    for dim in params['model_dimensions']:
        print("\n" + "=" * 60)
        print(f"FITTING {dim}D EUCLIDEAN MODEL")
        print("=" * 60)

        model_name = f"{dim}D"
        params["n_dim"] = dim

        model_coords, ll_nd = rs.points_of_best_fit(subset, pairwise_num_repeats, params)

        # (Distances computed previously; keep if useful for debugging)
        _ = pdist(model_coords)
        coords_by_dim[dim] = model_coords
        lls_by_dim[dim] = ll_nd

        print("\nOptimized embedding:")
        print("-" * 60)
        print(f"Shape: {model_coords.shape}")
        print(f"Mean coordinate value: {np.mean(model_coords):.4f}")
        print(f"Std of coordinates:    {np.std(model_coords):.4f}")
        print(f"Min/Max coordinate:    {np.min(model_coords):.4f} / {np.max(model_coords):.4f}")
        print("-" * 60)

        outfilename = '{}/{}_{}_anchored_points_sigma_{}_dim_{}'.format(
            params['outdir'], params['subject'], params['exp_name'], params['sigma'], dim
        )
        np.save(outfilename, model_coords)

        ll_nd = -ll_nd / float(total_num_triads)
        print(f"Negative Log Likelihood per triad of the model: {ll_nd:.4f}")

        result['Model'].append(model_name)
        result['Log Likelihood'].append(ll_nd)
        result['number of points'].append(params['num_stimuli'])

    # ---- Best and random baselines ----
    ll_best = an.best_model_ll(
        subset, pairwise_num_repeats)[0] / float(total_num_triads)
    result['Model'].append('best')
    result['Log Likelihood'].append(ll_best)
    result['number of points'].append(params['num_stimuli'])

    ll_random = an.random_choice_ll(
        subset, pairwise_num_repeats)[0] / float(total_num_triads)
    result['Model'].append('random')
    result['Log Likelihood'].append(ll_random)
    result['number of points'].append(params['num_stimuli'])

    print("\n" + "=" * 60)
    print("BASELINE COMPARISON")
    print("=" * 60)
    print(f"Best possible model LL:   {ll_best:.4f}")
    print(f"Random choice model LL:   {ll_random:.4f}")
    print("=" * 60)

    # Fill Experiment/Subject columns to match row count
    n_rows = len(result["Model"])
    result["Experiment"] = [params['exp_name']] * n_rows
    result["Subject"] = [params['subject']] * n_rows

    # ---- Output results ----
    data_frame = pd.DataFrame(result)

    print("\nFINAL MODEL COMPARISON")
    print("=" * 60)
    print(data_frame.to_string(index=False))
    print("=" * 60)

    data_frame.to_csv('{}/{}-{}-geometry-likelihoods_with_{}_trials_sigma_{}_{}_pts_anchored.csv'
                      .format(params['outdir'],
                              params['subject'],
                              params['exp_name'],
                              'all' if not params['filter_trials'] else params['filter_trials'],
                              params['sigma'],
                              params['num_stimuli']
                              ), index=False)

    # write combined file with coords and lls
    stimuli = stim_list
    lls_by_dim['best'] = ll_best
    lls_by_dim['random'] = ll_random

    mat_path = create_coords_file(
        outdir=params['outdir'],
        exp=params['exp_name'],
        subject=params['subject'],
        model_dimensions=params['model_dimensions'],
        points=coords_by_dim,
        lls=lls_by_dim,
        stim_labels=stimuli
    )
    print("Saved:", mat_path)


def run(user_params):
    params = build_model_fit_args(user_params)
    fit(params)
