"""
    Demo to fit models of Euclidean spaces of different dimensions, from tallied similarity judgments.
    Enter '0' to use default values.
"""
import logging
import random
import numpy as np
import pandas as pd
from pathlib import Path
from scipy.spatial.distance import pdist

import src.rs_py.model.fit_geometric_models as rs
import src.rs_py.choices.choice_likelihoods as an
from src.rs_py.utils.helpers import read_in_params, create_coords_file
from src.rs_py.utils.util import read_combined_choices


def demo_inputs():
    """
    Populate demo defaults.
    Adjust the default filepath/outdir to wherever your sample materials live.
    """
    user_params, names_to_id, id_to_name = read_in_params()
    base_dir = Path(__file__).resolve().parent.parent

    defaults = {
        "filepath": (base_dir / "samples/choice_files/animals_combined_choices_S4.mat").resolve(),
        "exp_name": "animals",
        "subject": "S4",
        "outdir": (base_dir / "samples/models").resolve(),
        'sigma': user_params['inputs']['model_fit']['sigma'],
        'model_dimensions': user_params['inputs']['model_fit']['model_dimensions'],
        'num_stimuli': user_params['inputs']['model_fit']['num_stimuli'],
        'learning_rate': user_params['inputs']['model_fit']['learning_rate'],
        'tolerance': user_params['inputs']['model_fit']['tolerance'],
        'max_trials': None,
        'max_iterations': user_params['inputs']['model_fit']['max_iterations'],
        'minimization': user_params['inputs']['model_fit']['minimization']
    }
    return defaults


def _use_default(val):
    if val.strip() == "" or val.strip() == "0":
        return True
    else:
        return False


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    LOG = logging.getLogger(__name__)

    # enter path to subject data (json file)
    FILEPATH = input("Path to the combined choices file for a participant: ")
    EXP = input("Experiment name: ")
    SUBJECT = input("Subject name or ID: ")
    OUTDIR = input("Output directory : ")
    NUM_STIMULI = input("Enter the number of stimuli in experiment: ")
    print("The following arguments are optional. ")
    MODEL_DIMENSIONS = input("\tEnter the dimensionality of models to fit in a comma separated list: ")
    SIGMA = input("\tEnter a noise level to model error in comparing distances: ")
    FILTER_TRIALS = input("\tEnter the maximum number of triadic judgments to use. Enter 0 to use all data.")
    MAX_ITER = input("\tEnter the maximum number of iterations before returning the final model: ")
    LEARN_RATE = input("\tEnter learning rate to use for minimization: ")
    TOLERANCE = input("\tEnter acceptable tolerance for difference between iterations (stopping criterion): ")
    MINIM = input("\tEnter minimization algorithm (opts: nelder-mead, gradient-descent): ")

    CONFIG = demo_inputs()
    # fill in defaults if missing arguments - for demo provide defaults for required args.
    # in the accompanying script, missing required args will cause an error to be thrown.
    ARGS = {'filepath': CONFIG['filepath'] if _use_default(FILEPATH) else FILEPATH,
            'exp_name': CONFIG['exp_name'] if _use_default(EXP) else EXP,
            'subject': CONFIG['subject'] if _use_default(SUBJECT) else SUBJECT,
            'outdir': CONFIG['outdir'] if _use_default(OUTDIR) else OUTDIR,
            'num_stimuli': CONFIG['num_stimuli'] if _use_default(NUM_STIMULI) else int(NUM_STIMULI),
            'max_iterations': CONFIG['max_iterations'] if _use_default(MAX_ITER) else int(MAX_ITER),
            'learning_rate': CONFIG['learning_rate'] if _use_default(LEARN_RATE) else float(LEARN_RATE),
            'tolerance': CONFIG['tolerance'] if _use_default(TOLERANCE) else float(TOLERANCE),
            'minimization': CONFIG['minimization'] if _use_default(MINIM) else MINIM}

    SIGMA = CONFIG['sigma'] if _use_default(SIGMA) else float(SIGMA)
    ARGS['sigma'] = SIGMA
    if _use_default(MODEL_DIMENSIONS):
        ARGS['model_dimensions'] = CONFIG['model_dimensions']
    else:
        ARGS['model_dimensions'] = [int(x) for x in MODEL_DIMENSIONS.split(',')]
    ARGS['noise_st_dev'] = SIGMA
    FILTER_TRIALS = CONFIG['max_trials'] if _use_default(FILTER_TRIALS) else int(FILTER_TRIALS)

    print("\n" + "=" * 70)
    print("GEOMETRIC MODEL FIT DEMO")
    print("=" * 70)

    print("DATA")
    print("-" * 70)
    print(f"Filepath:            {ARGS['filepath']}")
    print(f"Experiment:          {ARGS['exp_name']}")
    print(f"Subject:             {ARGS['subject']}")
    print(f"Output directory:    {ARGS['outdir']}")
    print(f"Max trials used:     {FILTER_TRIALS}")

    print("\nOPTIMIZATION SETTINGS")
    print("-" * 70)
    print(f"Max iterations:      {ARGS['max_iterations']}")
    print(f"Learning rate:       {ARGS['learning_rate']}")
    print(f"Tolerance:           {ARGS['tolerance']}")

    print("\nNOISE PARAMETERS")
    print("-" * 70)
    print(f"Sigma (compare):     {ARGS['sigma']:.6f}")

    print("=" * 70)

    # break up ranking responses into pairwise judgments
    pairwise_responses, pairwise_num_repeats, metadata = read_combined_choices(ARGS['filepath'])

    print("\nLoaded pairwise judgments")
    print("-" * 60)
    print(f"Number of unique comparisons: {len(pairwise_responses)}")
    print(f"Total triads (including repeats): {sum(pairwise_num_repeats.values())}")
    print("-" * 60)

    # only consider a subset of trials
    subset = {}
    if FILTER_TRIALS:
        if FILTER_TRIALS < len(pairwise_responses):
            all_keys = list(pairwise_responses.keys())
            chosen = random.sample(all_keys, FILTER_TRIALS)
            subset = {k: pairwise_responses[k] for k in chosen}

            print("\nUsing subset of trials")
            print("-" * 60)
            print(f"Trials used: {len(subset)}")
            print(f"Total triads used: {sum(pairwise_num_repeats[k] for k in subset)}")
            print("=" * 60)
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

    num_trials = len(subset)
    for dim in ARGS['model_dimensions']:
        print("\n" + "=" * 60)
        print(f"FITTING {dim}D EUCLIDEAN MODEL")
        print("=" * 60)

        model_name = f"{dim}D"
        ARGS["n_dim"] = dim

        model_coords, ll_nd = rs.points_of_best_fit(subset, pairwise_num_repeats, ARGS)

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
            ARGS['outdir'], ARGS['subject'], ARGS['exp_name'], ARGS['sigma'], dim
        )
        np.save(outfilename, model_coords)

        ll_nd = -ll_nd / float(total_num_triads)
        print(f"Negative Log Likelihood per triad of the model: {ll_nd:.4f}")

        result['Model'].append(model_name)
        result['Log Likelihood'].append(ll_nd)
        result['number of points'].append(ARGS['num_stimuli'])

    # ---- Best and random baselines ----
    ll_best = an.best_model_ll(
        subset, pairwise_num_repeats)[0] / float(total_num_triads)
    result['Model'].append('best')
    result['Log Likelihood'].append(ll_best)
    result['number of points'].append(ARGS['num_stimuli'])

    ll_random = an.random_choice_ll(
        subset, pairwise_num_repeats)[0] / float(total_num_triads)
    result['Model'].append('random')
    result['Log Likelihood'].append(ll_random)
    result['number of points'].append(ARGS['num_stimuli'])

    print("\n" + "=" * 60)
    print("BASELINE COMPARISON")
    print("=" * 60)
    print(f"Best possible model LL:   {ll_best:.4f}")
    print(f"Random choice model LL:   {ll_random:.4f}")
    print("=" * 60)

    # Fill Experiment/Subject columns to match row count
    n_rows = len(result["Model"])
    result["Experiment"] = [ARGS['exp_name']] * n_rows
    result["Subject"] = [ARGS['subject']] * n_rows

    # ---- Output results ----
    data_frame = pd.DataFrame(result)

    print("\nFINAL MODEL COMPARISON")
    print("=" * 60)
    print(data_frame.to_string(index=False))
    print("=" * 60)

    data_frame.to_csv('{}/{}-{}-geometry-likelihoods_with_{}_trials_sigma_{}_{}_pts_anchored.csv'
                      .format(ARGS['outdir'],
                              ARGS['subject'],
                              ARGS['exp_name'],
                              'all' if not FILTER_TRIALS else FILTER_TRIALS,
                              ARGS['sigma'],
                              ARGS['num_stimuli']
                              ), index=False)

    # write combined file with coords and lls
    stimuli = metadata['stim_list'].squeeze().item()
    lls_by_dim['best'] = ll_best
    lls_by_dim['random'] = ll_random

    mat_path = create_coords_file(
        outdir=ARGS['outdir'],
        exp=ARGS['exp_name'],
        subject=ARGS['subject'],
        model_dimensions=ARGS['model_dimensions'],
        points=coords_by_dim,
        lls=lls_by_dim,
        stim_labels=stimuli
    )
    print("Saved:", mat_path)
