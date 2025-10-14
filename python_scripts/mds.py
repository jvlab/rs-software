# noinspection SpellCheckingInspection
"""
To improve ordinary Nelder-Mead minimization, I can initialize the minimization with coordinates returned by
metric multidimensional scaling (MDS). This file is to test if this alternate seeding can help.

To get coordinates from MDS, I first need a distance matrix. The simulated judgments do not directly provide pairwise
distances. Instead they provide data on comparisons of pairs of pairs of stimuli - all we know is if one distance is
larger than another. We do not know the magnitude of any distance.

We can work around this by using a heuristic as follows.
Let d(i, j) be (a + 1)/ (a + b + 2), where
a is the number of times d(i, j) was judged to be LARGER than another distance d(m, n)
    a is counted by iterating over all comparisons of (i, j) with other pairs (m, n).
b is the number of times d(i, j) was judged to be SMALLER than another distance d(m, n), summed over all pairs m, n
"""

import logging

import numpy as np
from sklearn.manifold import smacof

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger(__name__)


def heuristic_distances(judgments, repeats):
    """
    Returns a numeric value for each distance (i, j) in judgments: d = (a + 1)/ (a + b + 2)
    a is number of times a distance is greater than another
    :param repeats: number of times each pairwise comparison is repeated
    :param judgments: (dict) key: pairs of distances (i,j) (m,n), value: counts
    :return: dict of distances (pair (i, j) -> distance value)
    """

    def increment(d, key, val):
        if key not in d:
            d[key] = val
        else:
            d[key] += val

    # take a pass through judgments and keep track of 'a' (win) and 'b' (loss) for each distance
    win = {}  # for readability, call 'a' WIN and call 'b' LOSS
    loss = {}
    distance = {}
    for comparison, count in judgments.items():
        increment(win, comparison[0], count)
        increment(loss, comparison[0], repeats[comparison] - count)
        increment(loss, comparison[-1], count)
        increment(win, comparison[-1], repeats[comparison] - count)

    # map win, loss values to distances
    for pair in win:
        distance[pair] = (win[pair] + 1) / float(win[pair] + loss[pair] + 2)

    return distance


def format_distances(distance_dict):
    """
    Take in dict of distances and convert to a symmetric matrix. Leave any unknown distance values 0
    :param distance_dict: e.g. (0,1) -> 3
    :return: distance matrix, e.g. D[0, 3] = D[3, 0] = 3
    """
    current = 0
    for pair in distance_dict.keys():
        a, b = pair
        current = max(current, max(int(a), int(b)))

    # initialize distance matrix and fill
    distance_matrix = np.zeros((current + 1, current + 1))
    for pair, val in distance_dict.items():
        index_a, index_b = pair
        distance_matrix[index_a, index_b] = val
        distance_matrix[index_b, index_a] = val

    return distance_matrix


def get_coordinates(n_dim, judgments, repeats, epsilon=1e-9, seed=None):
    """Given judgments and number of dimensions, return an estimate of point coordinates using MDS
    :param seed: for MDS (int)
    :param judgments (dict)
    :param repeats (int)
    :param n_dim (int)
    :param epsilon: error threshold which controls when MDS terminates
    """
    if seed is not None:
        np.random.seed(seed)
    distance_matrix = format_distances(heuristic_distances(judgments, repeats))
    LOG.info('#################  Running MDS')
    coordinates, stress = smacof(distance_matrix, n_components=n_dim, metric=True, eps=epsilon)
    return coordinates, stress
