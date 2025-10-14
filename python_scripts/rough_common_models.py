"""
Here I calculate the log-likelihoods of models that are calculated from raw choice probabilities and are
independent of the Euclidean modeling pipeline.

The models considered are the following:
- average subject model: choice probabilities are averaged across subjects.
- n-1 model: for each subject, leave out that subject and average the responses of the remaining subjects and use that
            to predict the left-out subject's responses.

The goal of this is to see if there is a common model subjects are using, i.e., how much common structure underlies
subject responses. It would be interesting to see if the structure is seen across domains. It could potentially be a
similar analysis to the heatmap analysis, however, now we would be able to compare how well a common model explained the
data relative to the random and best models. Anyway, the question being asked here is somewhat different than just
comparing pairs of subjects and their chocie probabilities.
"""


from analysis.util import json_to_pairwise_choice_probs
from pairwise_likelihood_analysis import calculate_ll, best_model_ll

import logging
import pprint
import random
import numpy as np
import pandas as pd
from sklearn.manifold import smacof
from scipy.spatial.distance import pdist

import analysis.model_fitting.mds as mds
import analysis.model_fitting.run_mds_seed as rs
import analysis.model_fitting.pairwise_likelihood_analysis as an
from analysis.util import read_in_params


logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger(__name__)


def average_dict(dicts):
    """
    Average values for keys over a list of dictionaries
    @param dicts: list of dictionaries with common keys
    @return: the average dictionary with values for each key, that are averaged across dicts
    """
    mean_dict = {}
    num_dicts = len(dicts)
    for key in dicts[0].keys():
        mean_dict[key] = sum(d[key] for d in dicts) / num_dicts
    return mean_dict


def average_subject_choice_probs(domain):
    # read in a set of json files for a domain
    DOMAIN = domain
    DIRECTORY = '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/experiments/experiments'
    SUBS1 = ['MC', 'BL', 'EFV', 'SJ', 'SAW', 'YCL', 'SA', 'JF']
    SUBS2 = ['MC', 'BL', 'EFV', 'SJ', 'SAW', 'YCL', 'SA', 'NK']
    SUBJECTS_BY_DOMAIN = {
        'word': ['MC', 'BL', 'SJ', 'SAW', 'YCL', 'SA', 'JF'],  # remove EFV
        'image': SUBS2,
        'intermediate_object': SUBS2,
        'intermediate_texture': SUBS1,
        'texture': ["BL", "EFV", "SJ", "YCL", "SA", "JF"],
        'texture_color': ["MC", "SAW", "NK"],
        'texture_grayscale': ["MC", "SAW", "SA"]
    }
    NAMES_TO_ID = read_in_params()[2]
    PATH = '{}/{}_exp/subject-data/preprocessed/{}_{}_exp.json'
    data = {}

    for subject in SUBJECTS_BY_DOMAIN[DOMAIN]:
        file = PATH.format(DIRECTORY, DOMAIN, subject, DOMAIN)
        data[subject], repeats = json_to_pairwise_choice_probs(file)

    # get average choice probabilities
    data['average'] = average_dict([data[sub] for sub in SUBJECTS_BY_DOMAIN[DOMAIN]])

    # get n-1 choice probabilities for each subject
    minus1 = {}
    for subject in SUBJECTS_BY_DOMAIN[DOMAIN]:
        remaining = [s for s in SUBJECTS_BY_DOMAIN[DOMAIN] if s != subject]
        minus1[subject] = average_dict([data[s] for s in remaining])
    return minus1, data


def calculate_model_lls(minus1, choice_prob_dict, repeats, domain, subjects_by_domain):
    results = {'Domain': [], 'Subject': [], 'LL': [], 'Model': [], 'Best LL': []}
    params = {
        'num_repeats': 5,
        'epsilon': 1e-30
    }
    num_judgments = len(choice_prob_dict['average'])
    for subject in subjects_by_domain[domain]:
        counts = []
        avg_probs = []
        minus1_probs = []
        for k, v in choice_prob_dict[subject].items():
            counts.append(v)
            avg_probs.append(choice_prob_dict['average'][k] / repeats[k])
            minus1_probs.append(minus1[subject][k] / repeats[k])

        # calculate best model LL
        best_ll = best_model_ll(choice_prob_dict[subject], params)[0]
        best_ll = best_ll / (num_judgments * params['num_repeats'])

        ll = calculate_ll(np.array(counts), np.array(avg_probs), repeats)[0]
        num_triads = sum([repeats[k] for k in choice_prob_dict.keys()])
        ll = ll / num_triads
        results['Domain'].append(domain)
        results['Subject'].append(subject)
        results['LL'].append(ll)
        results['Model'].append('Average')
        results['Best LL'].append(best_ll)

        # calculate n-1 model LL
        ll = calculate_ll(np.array(counts), np.array(minus1_probs))[0]
        ll = ll / (num_judgments * params['num_repeats'])
        results['Domain'].append(domain)
        results['Subject'].append(subject)
        results['LL'].append(ll)
        results['Model'].append('n-1')
        results['Best LL'].append(best_ll)

    df = pd.DataFrame(results)
    df.to_csv('{}-non-geometric-models.csv'.format(domain))


if __name__ == '__main__':
#     import glob
#     import seaborn as sns
#     import matplotlib.pyplot as plt
#
#     df = pd.concat([pd.read_csv(f) for f in glob.glob('./*non-geometric-models.csv')])
#     df = df.loc[df['Domain'].isin(['texture', 'intermediate_texture', 'intermediate_object', 'image', 'word'])]
#
#     # add new fields
#     df['Best Rel to Random'] = df['Best LL'] - (-1)
#     df['LL Rel to Random'] = df['LL'] - (-1)
#     df['Percentage LL Explained'] = 100 * df['LL Rel to Random'] / df['Best Rel to Random']
#
#     g = sns.catplot(data=df, x='Subject', col='Domain', y='LL Rel to Random', hue='Model')
#     for i in range(len(g.axes[0])):
#         for j in range(len(g.axes)):
#             g.axes[j, i].axhline(0, color='k')
#     plt.show()
#
#     df_word = df.loc[df['Domain'] == 'word']
#     df_image = df.loc[df['Domain'] == 'image']
#     df_intermediate_object = df.loc[df['Domain'] == 'intermediate_object']
#     df_intermediate_texture = df.loc[df['Domain'] == 'intermediate_texture']
#     df_texture = df.loc[df['Domain'] == 'texture']
#     g = sns.catplot(data=df_word, x='Subject', y='Percentage LL Explained', kind='bar', hue='Model', height=3)
#     plt.axhline(0, color='k')
#     plt.ylim([-10, 100])
#     plt.show()
#     sns.catplot(data=df_image, x='Subject', y='Percentage LL Explained', kind='bar', hue='Model', height=3)
#     plt.axhline(0, color='k')
#     plt.ylim([-10, 100])
#     plt.show()
#     sns.catplot(data=df_intermediate_object, x='Subject', y='Percentage LL Explained', kind='bar', hue='Model', height=3)
#     plt.axhline(0, color='k')
#     plt.ylim([-10, 100])
#     plt.show()
#     sns.catplot(data=df_intermediate_texture, x='Subject', y='Percentage LL Explained', kind='bar', hue='Model', height=3)
#     plt.axhline(0, color='k')
#     plt.ylim([-10, 100])
#     plt.show()
#     sns.catplot(data=df_texture, x='Subject', y='Percentage LL Explained', kind='bar', hue='Model', height=3)
#     plt.axhline(0, color='k')
#     plt.ylim([-10, 100])
#     plt.show()
#
#
#
# ######
# df = pd.concat([pd.read_csv(f) for f in glob.glob('./curvature_and_LL*combined.csv')])
# sns.catplot(data=df, col='Domain', hue='Subject', x='Curvature', y='LL')
# sns.pointplot(data=df, col='Domain', hue='Subject', x='Curvature', y='LL')

    CONFIG, STIMULI, NAMES_TO_ID, ID_TO_NAME = read_in_params()
    ORIGINAL_CURVATURE = CONFIG['curvature']

    # enter path to subject data (json file)
    EXP = input("Experiment name (e.g., sample_word): ")
    SUBJECT = input("Subject name or ID (e.g., S7): ")
    ITERATIONS = int(input("Number of iterations - how many times this should analysis be run (e.g. 1) : "))
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

    AVERAGED_PROBS = average_subject_choice_probs(EXP)[1]

    for ii in range(ITERATIONS):
        # read json file into dict
        pairwise_comparison_responses_by_trial = AVERAGED_PROBS['average']
        # get MDS starting coordinates
        D = mds.format_distances(mds.heuristic_distances(pairwise_comparison_responses_by_trial, 5))
        coordinates2d, stress = smacof(D, n_components=2, metric=True, eps=1e-9)

        # only consider a subset of trials
        if CONFIG['max_trials'] < len(pairwise_comparison_responses_by_trial):
            indices = random.sample(pairwise_comparison_responses_by_trial.keys(), CONFIG['max_trials'])
            subset = {key: pairwise_comparison_responses_by_trial[key] for key in indices}
        else:
            subset = pairwise_comparison_responses_by_trial

        # initialize results dataframe
        result = {'Model': [], 'Log Likelihood': [], 'number of points': [],
                  'Experiment': [EXP] * (2 + len(CONFIG['model_dimensions'])),
                  'Subject': [SUBJECT] * (2 + len(CONFIG['model_dimensions'])),
                  'Curvature': []}

        # MODELING WITH DIFFERENT EUCLIDEAN MODELS ###################################################
        num_trials = len(subset)
        for dim in CONFIG['model_dimensions']:
            LOG.info('#######  {} dimensional geometry'.format(dim))
            model_name = str(dim) + 'D'
            CONFIG['n_dim'] = dim
            x, ll_nd, fmin_costs = rs.points_of_best_fit(subset, CONFIG)
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
            ll_nd = -ll_nd / float(num_trials * CONFIG['num_repeats'])
            result['Model'].append(model_name)
            result['Log Likelihood'].append(ll_nd)
            result['number of points'].append(CONFIG['num_stimuli'])
            result['Curvature'].append('')
        # the ii for loop can be taken out later. just need it for a plot
        #   plt.plot(fmin_costs)
        # plt.show()

        # RANDOM AND BEST MODELS ####################################################################
        LOG.info('#######  Random and best geometry')
        ll_best = an.best_model_ll(
            subset, CONFIG)[0] / float(num_trials * CONFIG['num_repeats'])
        result['Model'].append('best')
        result['Log Likelihood'].append(ll_best)
        result['number of points'].append(CONFIG['num_stimuli'])
        result['Curvature'].append('')
        ll_random = an.random_choice_ll(
            subset, CONFIG)[0] / float(num_trials * CONFIG['num_repeats'])
        result['Model'].append('random')
        result['Log Likelihood'].append(ll_random)
        result['number of points'].append(CONFIG['num_stimuli'])
        result['Curvature'].append('')

        # OUTPUT RESULTS ###############################################################################
        data_frame = pd.DataFrame(result)
        sigma = CONFIG['sigmas']['compare'] + CONFIG['sigmas']['dist']
        data_frame.to_csv('{}/{}-{}-geometry-likelihoods_with_{}_trials_sigma_{}_{}pts_anchored_{}.csv'
                          .format(OUTDIR,
                                  SUBJECT,
                                  EXP,
                                  CONFIG['max_trials'],
                                  sigma,
                                  CONFIG['num_stimuli'],
                                  ii))


# ############# COmmon model Procrustes  analysis
# from scipy.linalg import orthogonal_procrustes as orth_proc
#
# avg_word = np.load(
#     '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/geometric-modeling/common-model/average/word/average_word_anchored_points_sigma_0.1_dim_5.npy')
# mc_word = np.load(
#     '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/geometric-modeling/euclidean/word/MC/MC_word_anchored_points_sigma_0.18_dim_5.npy')
# mc_word = np.load(
#     '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/geometric-modeling/euclidean/word/MC/MC_word_anchored_points_sigma_0.18_dim_5.npy')
# ss
# Input
# In[10]
# mc_word = np.load(
#     '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/geometric-modeling/euclidean/word/MC/MC_word_anchored_points_sigma_0.18_dim_5.npy')
# ss
# ^
# SyntaxError: invalid
# syntax
# path_5d = '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/geometric-modeling/euclidean/{}/{}/{}_{}_anchored_points_sigma_0.18_dim_5.npy'
# path_avg = '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/geometric-modeling/common-model/average/{}/average_{}_anchored_points_sigma_0.1_dim_5.npy'
# domains = ['texture', 'intermediate_texture', 'intermediate_object', 'image', 'word']
# subjects = ['MC', 'BL', 'EFV', 'SJ', 'SAW', 'NK', 'YCL', 'SA', 'JF']
# sub_data = {}
# for d in domains:
#     sub_data[d] = {}
# sub_by_domain = {'texture': ['MC', 'BL', 'EFV', 'SJ', 'SAW', 'JF', 'YCL', 'SA'],
#                  'intermediate_texture': ['MC', 'BL', 'EFV', 'SJ', 'SAW', 'JF', 'YCL', 'SA'],
#                  'intermediate_object': ['MC', 'BL', 'EFV', 'SJ', 'SAW', 'NK', 'YCL', 'SA'],
#                  'image': ['MC', 'BL', 'EFV', 'SJ', 'SAW', 'NK', 'YCL', 'SA'],
#                  'word': ['MC', 'BL', 'EFV', 'SJ', 'SAW', 'JF', 'YCL', 'SA']}
# for d in domains:
#     for s in sub_by_domain[d]:
#         path = path_5d.format(d, s, s, d)
#         sub_data[d][s] = np.load(path)
# avg_data = {}
# for d in domains:
#     path = path_avg.format(d, d)
#     avg_data[d] = np.load(path)
#
# a, b, c = orth_proc(avg_data['word'], sub_data['word']['MC'])
#
# a, b, c=proc.procrustes(avg_data['word'], sub_data['word']['JF'])
# for r in range(1000):
#     points = np.random.rand(37, 5)
#     a, b, c = proc.procrustes(points, avg_data['word'])
#     proc_d.append(c)
#
#
# for s in sub_by_domain['word']:
#     a, b, cost = proc.procrustes(avg_data['word'], sub_data['word'][s])
#     plt.plot([cost, cost], [0, 300], c='r')
#     if s =='YCL':
#         plt.text(cost, 265, s)
#     elif s == 'SAW':
#         plt.text(cost, 285, s)
#     else:
#         plt.text(cost, 275, s)
#
# # after null dists and proc distances made^
#
# from analysis.perceptual_space_visualizations import do_pca
#
# a, b, c = proc.procrustes(sub_data['word']['SA'], avg_data['word'])
# pca = PCA(n_components=n_components)
# # obtain the 5 PC directions and project data onto that space
# bl_w = pca.fit_transform(a)
# avg_ws = pca.fit_transform(b)
# plt.scatter(avg_ws[:, 0], avg_ws[:, 1], c='k')
# plt.scatter(bl_w[:, 0], bl_w[:, 1], c='b')
# for _ in range(37):
#     plt.plot([bl_w[_, 0], avg_ws[_, 0]], [bl_w[_, 1], avg_ws[_, 1]], 'k-')
#
# plt.scatter(bl_w[:, 0], bl_w[:, 1], c='b')
# plt.scatter(avg_ws[:, 0], avg_ws[:, 1], c='k')
# plt.axis('square')
#
#
#
# ####### visualiz what transformation would comprise of in 2D
# ### do PCA - don't stretch or normalize axes. Do same for common model and plot. Visually see if scaling and or rotation needed
# n_components = 5
# domain = 'texture'
# pca = PCA(n_components=n_components)
# # obtain the 5 PC directions and project data onto that space
# temp = pca.fit_transform(avg_data[domain])
#
# tempsub = {}
#
# for sub in sub_by_domain[domain]:
#     tempsub[sub] = pca.fit_transform(sub_data[domain][sub])
#
# for i in range(len(sub_by_domain[domain])):
#     sub = sub_by_domain[domain][i]
#     plt.subplot(1, 8, i)
#     plt.plot(tempsub[sub][:, 0], tempsub[sub][:, 1], 'b.')
#     plt.plot(temp[:, 0], temp[:, 1], 'k.')
#     plt.axis('square')
#     plt.xlim([-2, 2])
#     plt.ylim([-2, 2])
#     plt.title(sub)
