"""
In this file, I write methods to calculate the log likelihood of a set of count data given by
geometry of experiments.

If we have data of the form N((i, j) > (k, l)) i.e. number of times (repeats of trials) pair (i, j)
was judged to be more different from the pair (k, l), then we can calculate the log likelihood, LL
as follows:

LL = sum_{over all i,j,k,l} {
    N((i, j) > (k, l)).ln p((i, j) > (k, l))
} + ln Kx
where K is a combinatorial constant that counts the number of orders in which the responses could
have been made.
p is given by our geometry probability using erf.

Note:
If our sigma_point = 0 then the total noise is comprised of two Gaussian sources so erf is fine.
But if sigma_point > 0, then the noise is the square root of a sum of squares of Gaussian distributions plus two
Gaussian distributions, which is not exactly Gaussian. So erf is merely an approximation of the probability,
since it only accounts for Gaussian sources of noise.
"""
import json

import yaml
import logging
import numpy as np
from numpy import sqrt, zeros, concatenate, log2
from scipy.special import erf
from scipy.spatial.distance import pdist, squareform
import analysis.util as util

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger(__name__)

with open('./analysis/config.yaml', "r") as stream:
    data = yaml.safe_load(stream)
    EPSILON = float(data['epsilon'])


def params_to_points(x0, num_stimuli, n_dim):
    """
    Takes a vector of parameters and separates it into points
    :param x0: all stimulus coordinates (that are nonzero) vectorized
    :param num_stimuli: (int) number of points
    :param n_dim: (int) dimensionality of space points come from
    :return: points is a 2D array containing point coordinates.
            size: num_stimuli x n_dim
    """
    points = zeros((num_stimuli, n_dim))
    pointer = 0
    for i in range(1, min(n_dim, num_stimuli)):
        points[i, 0: i] = x0[pointer: i + pointer]
        pointer = i + pointer
    for j in range(n_dim, num_stimuli):
        points[j] = x0[pointer: pointer + n_dim]
        pointer += n_dim
    return points


def points_to_params(points):
    """
    points is a matrix with at least as many rows as columns.
    d is the number of columns
    n is the number of rows (points)
    This function takes a matrix of the form
    [[0, ..., 0],
    [x1, 0..., 0],
    [x2, x3, ..., 0],
    ...
    [xk, xk+1, ...xl, 0],
    [xl+1, ..., xl+d]
    ...]
    such that the first d points have 0, 1, 2, ..., d non zero params and the following rows all have nonzero params

    Return the nonzero params in an array
    """
    d = points.shape[1]
    params = []
    for row_idx in range(d):
        values = points[row_idx, 0:row_idx]
        params += [element for element in values]
    params = params + list(points[d:, :].flatten())
    return params


def calculate_ll(counts, probs, num_repeats):
    reverse_counts = num_repeats - counts
    reverse_probs = 1 - probs

    probs = concatenate((probs, reverse_probs))
    counts = concatenate((counts, reverse_counts))

    model_bad = False
    # check if geometry is bad, i.e. prob = 0 but count > 0
    prob_zero = probs == 0
    if (counts[prob_zero] > 0).any():
        model_bad = True

    # make sure there are no zero probabilities (avoid log(0) error)
    probs[prob_zero] += EPSILON
    log_likelihood = counts.dot(log2(probs))
    return log_likelihood, model_bad


def dist_model_ll_vectorized(pair_a, pair_b, judgment_counts, judgment_repeats, params, stimuli):
    """ Get the likelihood using probabilities from erf geometry, i.e. the geometry
    that takes into account noise as Gaussian sources. """
    # get geometry probabilities and join counts and geometry prob for each trial (N, p)
    interstimulus_distances = squareform(pdist(stimuli))
    probs = find_probabilities(interstimulus_distances, pair_a, pair_b, params['noise_st_dev'], params['no_noise'])
    # calculate log-likelihood, is_bad flag
    return calculate_ll(judgment_counts, probs, judgment_repeats)


def find_probabilities(distances, pair_a, pair_b, noise_st_dev, no_noise=False):
    """
    @param distances: a matrix of distances size (number of stimuli, number of stimuli)
    @param pair_a: a 2D numpy array with a pair of stimulus indices in each row, denoting the first distance
    @param pair_b: a 2D numpy array with a pair of stimulus indices in each row, denoting the second distance
    @param no_noise: boolean, in case needed while calling function in isolation
    @param noise_st_dev: combined noise from compare and dist for two possible noise sources
    """
    difference = distances[pair_a[:, 0], pair_a[:, 1]] - distances[pair_b[:, 0], pair_b[:, 1]]
    if noise_st_dev == 0 or no_noise is True:
        # if (sigmas['compare'] + sigmas['dist'] == 0) or no_noise is True:
        probabilities = (difference < 0) * 0 + (difference > 0) * 1 + (difference == 0) * 0.5
    else:
        # total_st_dev = sqrt((sigmas['dist'] ** 2) + sigmas['compare'] ** 2)
        probabilities = 0.5 * (1 + erf(difference / float(2 * noise_st_dev)))
    return probabilities


def random_choice_ll(judgments, judgment_repeats):
    """ LL is calculated as sum over trials of N(i>j)*P(i>j).
    In this case the P(i> j) for any i or j is 0.5.
    So we sum N*0.5 """
    counts = []
    probs = []
    repeats = []
    for (k, v) in judgments.items():
        counts.append(v)
        probs.append(0.5)
        repeats.append(judgment_repeats[k])
    return calculate_ll(np.array(counts), np.array(probs), np.array(repeats))


def best_model_ll(judgments, judgment_repeats):
    """ Use probabilities from observed judgements to calculate likelihood. So if i> j
    2/5 times, prob = 0.4. """
    counts = []
    probs = []
    repeats = []
    for (k, v) in judgments.items():
        counts.append(v)
        probs.append(v / judgment_repeats[k])
        repeats.append(judgment_repeats[k])
    return calculate_ll(np.array(counts), np.array(probs), np.array(repeats))


def cost_of_model_fit(stimulus_params, pair_a, pair_b, judgment_counts, judgment_repeats, params):
    """
    Stimulus_params is the independent variable. LL is the dependent variable.
    :param stimulus_params: nonzero coordinates of each of the stimuli stretched into one vector
    :param pair_a: pair 1 of stimuli from trial
    :param pair_b: pair 2 of stimuli from trial
    :param judgment_counts: counts per pairwise comparison (array)
    :param params: global params for the exp includes sigmas, num_repeats, n_dim etc.
    :return: negative log-likelihood (return -LL so the minimum -LL can be found)
    @param judgment_repeats:
    """
    # get points from params
    points = params_to_points(stimulus_params, params['num_stimuli'], params['n_dim'])
    # calculate likelihood using distance geometry and given points
    ll, is_bad = dist_model_ll_vectorized(pair_a, pair_b, judgment_counts, judgment_repeats, params, points)
    LOG.debug('geometry is good: {}'.format(not is_bad))
    if is_bad:
        LOG.info("WARNING: This model is infeasible.")
    return -1 * ll


def log_likelihood_of_choice_probs(json_file_path, path_to_npy_file, noise_st_dev):
    """
    Calculate LL of choice probabilities given a set of coordinates. Can be used to recalculate LLs
    or explain one subject's LLs using another's perceptual space model, or explain one domain from another's model.
    Also include best and random LLs
    returns a tuple: LL, random LL and best LL
    """
    # break up ranking responses into pairwise judgments
    pairwise_responses, pairwise_num_repeats = util.json_to_pairwise_choice_probs(json_file_path)
    pairs_a, pairs_b, response_counts, comp_repeats = util.judgments_to_arrays(pairwise_responses, pairwise_num_repeats)
    points = np.load(path_to_npy_file)
    params = {'noise_st_dev': noise_st_dev, 'no_noise': False}
    num_triads = sum([pairwise_num_repeats[k] for k in pairwise_responses.keys()])
    # calculate likelihood using distance geometry and given points
    ll, is_bad = dist_model_ll_vectorized(pairs_a, pairs_b, response_counts, comp_repeats, params, points)
    LOG.debug('geometry is good: {}'.format(not is_bad))
    if is_bad:
        LOG.info("WARNING: This model is infeasible.")
    rand_ll = random_choice_ll(pairwise_responses, pairwise_num_repeats)[0]
    best_ll = best_model_ll(pairwise_responses, pairwise_num_repeats)[0]
    return ll / num_triads, rand_ll / num_triads, best_ll / num_triads
