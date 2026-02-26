import logging
import pprint
import random
import numpy as np
import pandas as pd
from sklearn.manifold import smacof
from scipy.spatial.distance import pdist

import src.rs_py.utils.mds_embedding as mds
import src.rs_py.model.fit_geometric_models as rs
import src.rs_py.choices.choice_likelihoods as an
from src.rs_py.utils.helpers import read_in_params
from src.rs_py.utils.util import json_to_pairwise_choice_probs


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    LOG = logging.getLogger(__name__)

    SHOW_MDS = False
    CONFIG, NAMES_TO_ID, ID_TO_NAME = read_in_params()

    # enter path to subject data (json file)
    FILEPATH = input("Path to json file containing subject's preprocessed data"
                     " (e.g., ./sample-materials/subject-data/preprocessed/S7_sample_word_exp.json: ")
    CHOICEFILEPATH = input("")
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
    pairwise_comparison_responses, pairwise_comparison_num_repeats = json_to_pairwise_choice_probs(FILEPATH)
    pairwise_comparison_responses2, pairwise_comparison_num_repeats2 = read_combined_choices(CHOICEFILEPATH)
    # get MDS starting coordinates
    D = mds.format_distances(mds.heuristic_distances(
        pairwise_comparison_responses, pairwise_comparison_num_repeats))
    coordinates2d, stress = smacof(D, n_components=2, metric=True, eps=1e-9)

    # only consider a subset of trials
    if CONFIG['max_trials'] < len(pairwise_comparison_responses):
        indices = random.sample(pairwise_comparison_responses.keys(), CONFIG['max_trials'])
        subset = {key: pairwise_comparison_responses[key] for key in indices}
    else:
        subset = pairwise_comparison_responses

    # initialize results dataframe
    total_num_triads = sum([pairwise_comparison_num_repeats[k] for k in subset.keys()])
    result = {'Model': [], 'Log Likelihood': [], 'number of points': [],
              'Experiment': [EXP] * (2 + len(CONFIG['model_dimensions'])),
              'Subject': [SUBJECT] * (2 + len(CONFIG['model_dimensions'])),
              'Curvature': []}

    # MODELING WITH DIFFERENT EUCLIDEAN MODELS ###################################################
    num_trials = len(subset)
    for dim in CONFIG['model_dimensions']:
        LOG.info('#######  {} dimensional model'.format(dim))
        model_name = str(dim) + 'D'
        CONFIG['n_dim'] = dim
        x, ll_nd = rs.points_of_best_fit(subset, pairwise_comparison_num_repeats, CONFIG)
        LOG.info("Points: ")
        print(x)
        outfilename = '{}/{}_{}_anchored_points_sigma_{}_dim_{}'.format(
            OUTDIR,
            SUBJECT, EXP,
            str(CONFIG['sigmas']['compare'] + CONFIG['sigmas']['dist']),
            dim
        )
        np.save(outfilename, x)
        LOG.info("Distances: ")
        distances = pdist(x)
        ll_nd = -ll_nd / float(total_num_triads)
        LOG.info('####### LL: {}'.format(np.round(ll_nd, 4)))
        result['Model'].append(model_name)
        result['Log Likelihood'].append(ll_nd)
        result['number of points'].append(CONFIG['num_stimuli'])
        result['Curvature'].append('')
        # the ii for loop can be taken out later. just need it for a plot
        #   plt.plot(fmin_costs)
        # plt.show()

        # RANDOM AND BEST MODELS ####################################################################
        ll_best = an.best_model_ll(
            subset, pairwise_comparison_num_repeats)[0] / float(total_num_triads)
        result['Model'].append('best')
        result['Log Likelihood'].append(ll_best)
        result['number of points'].append(CONFIG['num_stimuli'])
        result['Curvature'].append('')
        ll_random = an.random_choice_ll(
            subset, pairwise_comparison_num_repeats)[0] / float(total_num_triads)
        result['Model'].append('random')
        result['Log Likelihood'].append(ll_random)
        result['number of points'].append(CONFIG['num_stimuli'])
        result['Curvature'].append('')
    # OUTPUT RESULTS ###############################################################################
    data_frame = pd.DataFrame(result)
    sigma = CONFIG['sigmas']['compare'] + CONFIG['sigmas']['dist']
    data_frame.to_csv('{}/{}-{}-geometry-likelihoods_with_{}_trials_sigma_{}_{}pts_anchored.csv'
                      .format(OUTDIR,
                              SUBJECT,
                              EXP,
                              CONFIG['max_trials'],
                              sigma,
                              CONFIG['num_stimuli'])
                      )
