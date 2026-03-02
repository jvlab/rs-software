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

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    LOG = logging.getLogger(__name__)

    SHOW_MDS = False
    CONFIG, STIMULI, NAMES_TO_ID, ID_TO_NAME = read_in_params()
    ORIGINAL_CURVATURE = CONFIG['scripts']


    def demo_inputs():
        """
        Populate demo defaults.
        Adjust the default filepath/outdir to wherever your sample materials live.
        """
        CONFIG, STIMULI, NAMES_TO_ID, ID_TO_NAME = read_in_params()

        defaults = {
            "filepath": "./sample-materials/subject-data/preprocessed/S7_sample_word_exp.json",
            "exp_name": "sample_word",
            "subject": "S7",
            "outdir": "./sample-materials/subject-data",
            "use_default_sigma": True,
            "sigma_value": CONFIG["sigmas"]["compare"] + CONFIG["sigmas"]["dist"],
            "show_mds": False,
            "config": CONFIG,  # pass through for convenience
        }
        return defaults


    def _use_default(val):
        if val.strip == "" or val.strip() == "0":
            return True
        else:
            return False


    # enter path to subject data (json file)
    FILEPATH = input("Path to json file containing subject's preprocessed data"
                     " (e.g., ./sample-materials/subject-data/preprocessed/S7_sample_word_exp.json: ")
    EXP = input("Experiment name (e.g., sample_word): ")
    SUBJECT = input("Subject name or ID (e.g., S7): ")
    OUTDIR = input("Output directory (e.g., ./sample-materials/subject-data) : ")
    SIGMA = input("Enter number or 'y' to use default ({}):".format(str(
        CONFIG['sigmas']['compare'] + CONFIG['sigmas']['dist'])))
    if SIGMA != 'y':
        CONFIG['sigmas'] = {
            'dist': 0,
            'compare': float(SIGMA)
        }
    if OUTDIR[-1] == '/':
        OUTDIR = OUTDIR[:-1]
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
