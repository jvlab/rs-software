"""
Utilities for computing log-likelihoods for geometry-based comparison data.

This file provides methods for evaluating the log-likelihood of aggregated
comparison counts under a distance-geometry response model. The observed data
are of the form $N((i, j) > (k, l))$, meaning the number of times one pair of
stimuli was judged more different than another pair.

The model computes choice probabilities from interstimulus distances using an
error-function approximation, then evaluates the corresponding log-likelihood.
It also includes reference calculations for random-choice and empirical
best-case benchmarks.

Note:
The likelihood calculations use log2, so the returned values are in bits.
When `sigma_point = 0`, the Gaussian-noise assumption matches the erf-based
probability exactly. When `sigma_point > 0`, the `erf` probability is only an
approximation because the full noise model is not strictly Gaussian.
(By `sigma_point`, we mean the standard deviation of additive noise on stimulus
 coordinates before distances are computed.)
"""

import logging
import numpy as np
from numpy import concatenate, log2
from scipy.special import erf
from scipy.spatial.distance import pdist, squareform
from ..utils import util
from ..utils.anchor_coordinates import params_to_points

LOG = logging.getLogger(__name__)
EPSILON = 1e-30


def calculate_ll(counts, probs, num_repeats):
    """
        Calculate the log-likelihood of observed counts given model probabilities.

        This function augments each comparison with its reverse outcome, checks whether
        the model assigns zero probability to any observed event, and returns the
        log-likelihood using a base-2 logarithm.

        Args:
            counts (numpy.ndarray): Observed counts for each comparison direction.
            probs (numpy.ndarray): Model probabilities for the corresponding
            comparisons.
            num_repeats (numpy.ndarray): Total number of repeats for each comparison.

        Returns:
            tuple[float, bool]: The log-likelihood and a boolean flag indicating whether the model is infeasible.
            The flag is `True` when an observed event has zero model probability.

        Note:
            The function uses a variable called `EPSILON` set to `1e-30.` This very small positive constant is added only when a model assigns
            zero probability to an observed comparison. It prevents `log2(0)` from causing an error
            during likelihood computation, while keeping the adjustment negligible.
    """

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
    """
        Compute the log-likelihood under a specific perceptual space model with given distances between points.

        This function converts stimulus coordinates into a full pairwise distance
        matrix, computes comparison probabilities with `find_probabilities`, and then
        evaluates the log-likelihood against the observed judgment counts.

        Args:
            pair_a (numpy.ndarray): Array of index pairs defining the first distance in
            each comparison.
            pair_b (numpy.ndarray): Array of index pairs defining the second distance
            in each comparison.
            judgment_counts (numpy.ndarray): Observed counts for the first pair being
            judged more dissimilar than the second.
            judgment_repeats (numpy.ndarray): Total number of repeats for each
            comparison.
            params (dict): Model parameters. Must contain `noise_st_dev`.
            stimuli (numpy.ndarray): Stimulus coordinates used to compute pairwise
            distances.

        Returns:
            tuple[float, bool]: The log-likelihood and the infeasibility flag returned by `calculate_ll`.

        See Also:
            find_probabilities: Convert distance differences into choice probabilities.
    """
    # get geometry probabilities and join counts and geometry prob for each trial (N, p)
    interstimulus_distances = squareform(pdist(stimuli))
    probs = find_probabilities(interstimulus_distances, pair_a, pair_b, params['noise_st_dev'])
    # calculate log-likelihood, is_bad flag
    return calculate_ll(judgment_counts, probs, judgment_repeats)


def find_probabilities(distances, pair_a, pair_b, noise_st_dev):
    """
        Compute choice probabilities from pairwise distance differences.

        For each comparison, this function subtracts the second pair distance from the
        first pair distance and converts that difference into a probability that the
        first pair is judged more different.

        Args:
            distances (numpy.ndarray): Square matrix of pairwise stimulus distances.
            pair_a (numpy.ndarray): Array of index pairs defining the first distance in
            each comparison.
            pair_b (numpy.ndarray): Array of index pairs defining the second distance in each comparison.
            noise_st_dev (float): Standard deviation of the combined Gaussian noise term.

        Returns:
            numpy.ndarray: Probability that the first pair is judged more different than the second.

        Note:
            When `noise_st_dev = 0`, the output is deterministic, with probabilities `0`, `0.5`, or `1`
            depending on the sign of the distance difference. When `noise_st_dev > 0`, the probability
             is computed using an approximation based on the erf function.
    """
    difference = distances[pair_a[:, 0], pair_a[:, 1]] - distances[pair_b[:, 0], pair_b[:, 1]]
    if noise_st_dev == 0:
        # if (sigmas['compare'] + sigmas['dist'] == 0) or no_noise is True:
        probabilities = (difference < 0) * 0 + (difference > 0) * 1 + (difference == 0) * 0.5
    else:
        # total_st_dev = sqrt((sigmas['dist'] ** 2) + sigmas['compare'] ** 2)
        probabilities = 0.5 * (1 + erf(difference / float(2 * noise_st_dev)))
    return probabilities


def random_choice_ll(judgments, judgment_repeats):
    """
    Compute the log-likelihood under a random-choice benchmark.

    This benchmark assumes every comparison direction is equally likely, so each
    observed judgment has probability 0.5.

    Args:
        judgments (dict): Mapping from comparison keys to observed judgment counts.
        judgment_repeats (dict): Mapping from comparison keys to total repeats.

    Returns:
        tuple[float, bool]: The log-likelihood and infeasibility flag returned by `calculate_ll`.
 """
    counts = []
    probs = []
    repeats = []
    for (k, v) in judgments.items():
        counts.append(v)
        probs.append(0.5)
        repeats.append(judgment_repeats[k])
    return calculate_ll(np.array(counts), np.array(probs), np.array(repeats))


def best_model_ll(judgments, judgment_repeats):
    """
        Compute the log-likelihood under an empirical best-case benchmark.

        This benchmark assigns each comparison the probability estimated from its
        observed frequency in the data.

        Args:
            judgments (dict): Mapping from comparison keys to observed judgment counts.
            judgment_repeats (dict): Mapping from comparison keys to total repeats.

        Returns:
            tuple[float, bool]: The log-likelihood and infeasibility flag returned by `calculate_ll`.
    """
    counts = []
    probs = []
    repeats = []
    for (k, v) in judgments.items():
        counts.append(v)
        probs.append(v / judgment_repeats[k])
        repeats.append(judgment_repeats[k])
    return calculate_ll(np.array(counts), np.array(probs), np.array(repeats))


# def cost_of_model_fit(stimulus_params, pair_a, pair_b, judgment_counts, judgment_repeats, params):
#     """
#         Compute the negative log-likelihood for model fitting.
#
#         This function reconstructs stimulus coordinates from a flattened parameter
#         vector, evaluates the perceptual space based log-likelihood, and returns the
#         negative value so an optimizer can minimize it.
#
#         Args:
#             stimulus_params (numpy.ndarray): Flattened nonzero coordinates for all stimuli.
#             pair_a (numpy.ndarray): Array of index pairs defining the first distance in each comparison.
#             pair_b (numpy.ndarray): Array of index pairs defining the second distance in each comparison.
#             judgment_counts (numpy.ndarray): Observed counts for each comparison.
#             judgment_repeats (numpy.ndarray): Total number of repeats for each comparison.
#             params (dict): Model parameters. Must include `num_stimuli`, `n_dim`, and `noise_st_dev`.
#
#         Returns:
#             float: Negative log-likelihood.
#     """
#     # get points from params
#     points = params_to_points(stimulus_params, params['num_stimuli'], params['n_dim'])
#     # calculate likelihood using distance geometry and given points
#     ll, is_bad = dist_model_ll_vectorized(pair_a, pair_b, judgment_counts, judgment_repeats, params, points)
#     LOG.debug('geometry is good: {}'.format(not is_bad))
#     if is_bad:
#         LOG.info("WARNING: This model is infeasible.")
#     return -1 * ll


# def log_likelihood_of_choice_probs(json_file_path, path_to_npy_file, noise_st_dev):
#     """
#         Compute normalized log-likelihoods for choice-probability data.
#
#         This function loads pairwise choice probabilities from a JSON file, converts
#         them into array form, evaluates the geometry-based model for a set of stimulus
#         coordinates loaded from disk, and also computes random-choice and empirical
#         best-case benchmarks.
#
#         Args:
#             json_file_path (str): Path to the JSON file containing ranking or choice data.
#             path_to_npy_file (str): Path to the `.npy` file containing stimulus coordinates.
#             noise_st_dev (float): Standard deviation of the combined noise term used by the model.
#
#         Returns:
#             tuple[float, float, float]: The model, random-choice, and best-case log-likelihoods,
#             each normalized by the total number of triads or comparisons.
#     """
#     # break up ranking responses into pairwise judgments
#     pairwise_responses, pairwise_num_repeats = util.json_to_pairwise_choice_probs(json_file_path)
#     pairs_a, pairs_b, response_counts, comp_repeats = util.judgments_to_arrays(pairwise_responses, pairwise_num_repeats)
#     points = np.load(path_to_npy_file)
#     params = {'noise_st_dev': noise_st_dev, 'no_noise': False}
#     num_triads = sum([pairwise_num_repeats[k] for k in pairwise_responses.keys()])
#     # calculate likelihood using distance geometry and given points
#     ll, is_bad = dist_model_ll_vectorized(pairs_a, pairs_b, response_counts, comp_repeats, params, points)
#     LOG.debug('geometry is good: {}'.format(not is_bad))
#     if is_bad:
#         LOG.info("WARNING: This model is infeasible.")
#     rand_ll = random_choice_ll(pairwise_responses, pairwise_num_repeats)[0]
#     best_ll = best_model_ll(pairwise_responses, pairwise_num_repeats)[0]
#     return ll / num_triads, rand_ll / num_triads, best_ll / num_triads

