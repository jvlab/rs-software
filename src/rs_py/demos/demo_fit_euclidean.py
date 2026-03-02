"""
    Demo to fit models of Euclidean spaces of different dimensions, from tallied similarity judgments.
    Enter '0' to use default values.
"""
import logging
import pprint
import random
import numpy as np
import pandas as pd
from scipy.spatial.distance import pdist

import src.rs_py.model.fit_geometric_models as rs
import src.rs_py.choices.choice_likelihoods as an
from src.rs_py.utils.helpers import read_in_params
from src.rs_py.utils.util import read_combined_choices


def demo_inputs():
    """
    Populate demo defaults.
    Adjust the default filepath/outdir to wherever your sample materials live.
    """
    user_params, stimuli, names_to_id, id_to_name = read_in_params()

    defaults = {
        "filepath": "../samples/choice_files/animals_combined_choices_S4.mat",
        "exp_name": "animals",
        "subject": "S4",
        "outdir": "../samples/models",
        'sigma': user_params['sigma'],
        'num_stimuli': user_params['model_fit']['num_stimuli'],
        'learning_rate': user_params['model_fit']['learning_rate'],
        'tolerance': user_params['model_fit']['tolerance']
    }
    return defaults


def _use_default(val):
    if val.strip == "" or val.strip() == "0":
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
    SIGMA_COMPARE = input("Enter a noise level to model error in comparing distances: ")
    SIGMA_DIST = input("Enter a noise level if you would like to also model error in computing"
                       " distances between stimuli: ")

    CONFIG = demo_inputs()
    # fill in defaults for missing arguments
    FILEPATH = CONFIG['filepath'] if _use_default(FILEPATH) else FILEPATH
    EXP = CONFIG['exp_name'] if _use_default(EXP) else EXP
    SUBJECT = CONFIG['subject'] if _use_default(SUBJECT) else SUBJECT
    OUTDIR = CONFIG['outdir'] if _use_default(OUTDIR) else OUTDIR
    SIGMA_COMPARE = CONFIG['sigma']['compare'] if _use_default(SIGMA_COMPARE) else SIGMA_COMPARE
    SIGMA_DIST = CONFIG['sigma']['dist'] if _use_default(SIGMA_DIST) else SIGMA_DIST

    # print and verify arguments before beginning
    pprint.pprint(CONFIG)
    ok = input("Ok to proceed? (y/n)")
    if ok != 'y':
        raise InterruptedError

    # break up ranking responses into pairwise judgments
    pairwise_responses, pairwise_num_repeats = read_combined_choices(FILEPATH)

    # only consider a subset of trials
    if CONFIG["max_trials"] < len(pairwise_responses):
        all_keys = list(pairwise_responses.keys())
        chosen = random.sample(all_keys, CONFIG["max_trials"])
        subset = {k: pairwise_responses[k] for k in chosen}
    else:
        subset = pairwise_responses

    # initialize results dataframe
    total_num_triads = sum([pairwise_num_repeats[k] for k in subset.keys()])
    if total_num_triads == 0:
        raise ValueError("No triads found (total_num_triads == 0). Check input data.")

    # initialize results
    result = {
        "Model": [],
        "Log Likelihood": [],
        "number of points": [],
        "Experiment": [],
        "Subject": [],
        "Curvature": [],
    }

    # Euclidean models across dimensions
    num_trials = len(subset)
    for dim in CONFIG['model_dimensions']:
        LOG.info("####### %s dimensional model", dim)
        model_name = f"{dim}D"
        CONFIG["n_dim"] = dim

        x, ll_nd = rs.points_of_best_fit(subset, pairwise_num_repeats, CONFIG)

        # (Distances computed previously; keep if useful for debugging)
        _ = pdist(x)

        LOG.info("Points: ")
        print(x)
        outfilename = '{}/{}_{}_anchored_points_sigma_{}_dim_{}'.format(
            OUTDIR,
            SUBJECT, EXP,
            str(CONFIG['sigmas']['compare'] + CONFIG['sigmas']['dist']),
            dim
        )
        np.save(outfilename, x)

        ll_nd = -ll_nd / float(total_num_triads)
        LOG.info('####### LL: {}'.format(np.round(ll_nd, 4)))

        result['Model'].append(model_name)
        result['Log Likelihood'].append(ll_nd)
        result['number of points'].append(CONFIG['num_stimuli'])
        result['Curvature'].append('')

    # ---- Best and random baselines ----
    ll_best = an.best_model_ll(
        subset, pairwise_num_repeats)[0] / float(total_num_triads)
    result['Model'].append('best')
    result['Log Likelihood'].append(ll_best)
    result['number of points'].append(CONFIG['num_stimuli'])
    result['Curvature'].append('')

    ll_random = an.random_choice_ll(
        subset, pairwise_num_repeats)[0] / float(total_num_triads)
    result['Model'].append('random')
    result['Log Likelihood'].append(ll_random)
    result['number of points'].append(CONFIG['num_stimuli'])
    result['Curvature'].append('')

    # Fill Experiment/Subject columns to match row count
    n_rows = len(result["Model"])
    result["Experiment"] = [EXP] * n_rows
    result["Subject"] = [SUBJECT] * n_rows

    # ---- Output results ----
    data_frame = pd.DataFrame(result)
    sigma = CONFIG['sigmas']['compare'] + CONFIG['sigmas']['dist']
    data_frame.to_csv('{}/{}-{}-geometry-likelihoods_with_{}_trials_sigma_{}_{}pts_anchored.csv'
                      .format(OUTDIR,
                              SUBJECT,
                              EXP,
                              CONFIG['max_trials'],
                              sigma,
                              CONFIG['num_stimuli']
                              ), index=False)
