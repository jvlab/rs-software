"""
Here, given a data set, generate surrogate datasets that are drawn from the original choice probablities.
Then, for each surrogate dataset, essentially calculate LLs for a range of curvatures and (chosen/ adjusted)
sigma values.

This should yield a scatterplot of model LLs by curvature values. We start by doing so for the 2D case and we can
progress to higher dimensions as needed.
######## DEPRECATED - DO NOT USE ###########

The inputs are
- a range of curvature values
- dimensions for which to apply the analysis. Minimum dimension is 2.
- path to json files for individual datasets.
- optionally, can and probably should pass in a legend for when multiple curves are drawn
- number of iterations (surrogates)
- max number of iterations to run the model_fitting pipeline with.
"""

import pprint
import copy
import logging
import numpy as np
from analysis.model_fitting import run_mds_seed as rs
import pandas as pd
from analysis.util import read_in_params, json_to_pairwise_choice_probs

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger(__name__)

CONFIG, STIMULI, NAMES_TO_ID, ID_TO_NAME = read_in_params()
# disable unneeded params
CONFIG['curvature'] = None
CONFIG['spherical'] = None
CONFIG['hyperbolic'] = None


def run(args):
    judgments, repeats, CONFIG, subject, domain, dim, OUTDIR = args
    # sigma_val = CONFIG['sigmas']
    # CONFIG['sigmas'] = {'compare': sigma_val, 'dist': 0}
    degree_curvature = [0.05, 0.15, 0.25]
    degree_curvature_h = []  # -0.1, -0.2, -0.3, -0.4, -0.5, -0.6, -0.7, -0.8, -0.9, -1]

    def fit_model(similarity_judgments, num_repeats_dict, curvature, params, dim, start_points):
        params_copy = copy.deepcopy(params)
        num_judgments = len(similarity_judgments)
        total_num_triads = sum([num_repeats_dict[k] for k in similarity_judgments.keys()])
        noise = np.sqrt(params['sigmas']['compare'] ** 2 + params['sigmas']['dist'] ** 2)
        params_copy['n_dim'] = dim  # ensure correct model is tested
        if curvature == 0:
            # fit Euclidean model
            x, ll = rs.points_of_best_fit(similarity_judgments, repeats, params_copy, start_points)
            ll = -1 * ll / total_num_triads
        elif curvature > 0:
            # fit spherical model
            curvature_val = curvature
            params_copy['curvature'] = curvature_val
            x, ll = rs.spherical_points_of_best_fit(similarity_judgments, repeats, params_copy, start_points)
            ll = -1 * ll / total_num_triads
        else:
            # fit hyperbolic model
            curvature_val = -1 * curvature
            params_copy['curvature'] = curvature_val
            x, ll = rs.hyperbolic_points_of_best_fit(similarity_judgments, repeats, params_copy, start_points)
            ll = -1 * ll / total_num_triads
        return ll, curvature, noise, x

    results = {'Log Likelihood': [], 'Lambda-Mu': [], 'Curvature of Space': [], 'Sigma': [], 'Dimension': [], 'Subject': [],
               'Domain': []}
    start_euclidean = None
    for _c in range(len(degree_curvature)):
        c = degree_curvature[_c]
        if _c == 0:
            start = None
        log_likelihood, curvature_val, sigma, coords = fit_model(judgments, repeats, c, CONFIG, dim, start)
        if c == 0:
            start_euclidean = coords
        LOG.info("Log Likelihood: {}".format(log_likelihood))
        LOG.info("Sph fit points: ")
        print(coords)
        outfilename = '{}/{}_{}_spherical_model_coords_sigma_{}_dim_{}_mu_{}'.format(
            OUTDIR,
            subject, domain,
            str(CONFIG['sigmas']['compare'] + CONFIG['sigmas']['dist']),
            dim,
            curvature_val
        )
        np.save(outfilename, coords)
        start = coords
        # write to pandas file
        results['Lambda-Mu'].append(curvature_val)
        results['Curvature of Space'].append(curvature_val * 2) # 2 mu
        results['Log Likelihood'].append(log_likelihood)
        results['Sigma'].append(sigma)
        results['Dimension'].append(dim)
        results['Subject'].append(subject)
        results['Domain'].append(domain)
        pprint.pprint(results)
    for _c in range(len(degree_curvature_h)):
        c = degree_curvature_h[_c]
        if _c == 0:
            start = start_euclidean
        log_likelihood, curvature_val, sigma, coords = fit_model(judgments, repeats, c, CONFIG, dim, start)
        LOG.info("Log Likelihood: {}".format(log_likelihood))
        LOG.info("Hyp fit points: ")
        print(coords)
        outfilename = '{}/{}_{}_hyperbolic_model_coords_sigma_{}_dim_{}_lambda_{}'.format(
            OUTDIR,
            subject, domain,
            str(CONFIG['sigmas']['compare'] + CONFIG['sigmas']['dist']),
            dim,
            curvature_val
        )
        np.save(outfilename, coords)
        start = coords
        # write to pandas file
        results['Lambda-Mu'].append(curvature_val)
        results['Curvature of Space'].append(curvature_val)  # curv = lambda, for hyp case
        results['Log Likelihood'].append(log_likelihood)
        results['Sigma'].append(sigma)
        results['Dimension'].append(dim)
        results['Subject'].append(subject)
        results['Domain'].append(domain)
        pprint.pprint(results)
    # # write df
    df = pd.DataFrame(results)
    return df


# NOTE: ########################################
# Values of lambda and mu are hard-coded inside run function
# curvature was lambda^2 and mu^2 = 1/R^2 according to definition of Gaussian curvature...
# now corrected to lambda for hyp and 2mu for sph

print(CONFIG)

domain = input('Domain: ')
SUBJECTS = input('Subjects (separated by spaces): ').split(' ')
print(SUBJECTS)
proceed = input('If subjects correct, press "y" to proceed')
if proceed != 'y':
    raise IOError

DIM = int(input('Number of Dimensions: '))
OUTDIR = input('Output directory for LLs and coordinates: ')


for subject in SUBJECTS:
    print(subject)
    INPUT_DATA = '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/experiments/' \
                 'experiments/{}_exp/subject-data/preprocessed/{}_{}_exp.json'.format(domain, subject, domain)
    judgments, repeats = json_to_pairwise_choice_probs(INPUT_DATA)

    dfs = []
    ARGS = (judgments, repeats, CONFIG, subject, domain, DIM, OUTDIR)
    result = run(ARGS)
    dfs.append(result)

    total_df = pd.concat(dfs)
    print(total_df)
    total_df.to_csv('{}/curvature_and_LL_{}-{}-{}_combined_likelihoods.csv'.format(OUTDIR, subject, domain, DIM))
