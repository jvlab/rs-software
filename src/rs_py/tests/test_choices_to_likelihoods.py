import warnings
from math import log2

import numpy as np
import pytest

from src.rs_py.choices import choice_likelihoods as ll
from src.rs_py.utils import util, anchor_coordinates


def test_ll_random_log_likelihood_is_correct():
    # LL = sum_i (Ni log2(0.5))
    counts = {
        ((0, 1), '>', (0, 2)): 3,
        ((0, 2), '>', (0, 3)): 5,
        ((0, 1), '>', (0, 3)): 2,
    }
    repeats = {key: 5 for key in counts}

    random_ll, is_bad = ll.random_choice_ll(counts, repeats)

    assert random_ll == log2(0.5) * sum(repeats.values())
    assert not is_bad


def test_ll_best_log_likelihood_is_correct():
    counts = {
        ((0, 1), '>', (0, 2)): 3,
        ((0, 2), '>', (0, 3)): 5,
        ((0, 1), '>', (0, 3)): 2,
    }
    repeats = {key: 5 for key in counts}

    calculated_ll = 3 * log2(3 / 5.0) + 2 * log2(2 / 5.0)
    calculated_ll += (
        5 * log2(1)
        + 2 * log2(2 / 5.0)
        + 3 * log2(3 / 5.0)
    )

    best_ll, is_bad = ll.best_model_ll(counts, repeats)

    assert best_ll == calculated_ll
    assert best_ll < 0
    assert not is_bad


def test_ll_dist_vectorized_noise_gives_correct_ll():
    pair_a = np.array([[0, 1], [0, 2], [0, 1]])
    pair_b = np.array([[0, 2], [0, 3], [0, 3]])
    judgment_counts = np.array([3, 5, 2])
    judgment_repeats = np.array([5, 5, 5])

    params = {'noise_st_dev': 0.1}

    stimuli = np.array([
        [0, 0, 0],
        [1, 0, 0],
        [0, 1, 0],
        [0, 0, 1],
    ])

    # All compared distances equal 1, so each probability is 0.5.
    calculated_ll = log2(0.5) * ((3 + 2) + (5 + 0) + (2 + 3))

    dist_ll, is_bad = ll.dist_model_ll_vectorized(
        pair_a,
        pair_b,
        judgment_counts,
        judgment_repeats,
        params,
        stimuli,
    )

    assert dist_ll == pytest.approx(calculated_ll, rel=0, abs=1e-12)
    assert not is_bad


def test_ll_dist_vectorized_no_noise_0_prob_judgment_gives_bad_ll():
    # Comparisons:
    # D(0, 1) > D(0, 2): 3 of 5
    # D(0, 2) > D(0, 3): 5 of 5
    # D(0, 1) > D(0, 3): 2 of 5
    pair_a = np.array([[0, 1], [0, 2], [0, 1]])
    pair_b = np.array([[0, 2], [0, 3], [0, 3]])
    judgment_counts = np.array([3, 5, 2])
    judgment_repeats = np.array([5, 5, 5])

    params = {'noise_st_dev': 0}

    stimuli = np.array([
        [0, 0, 0],
        [1, 0.3, 0],
        [1, 0, 0],
        [0, 0.2, 0],
    ])

    dist_ll, is_bad = ll.dist_model_ll_vectorized(
        pair_a,
        pair_b,
        judgment_counts,
        judgment_repeats,
        params,
        stimuli,
    )

    # Without noise, these comparisons have probability 1.
    # Observed reverse outcomes therefore make the model infeasible.
    assert is_bad


def test_x0_to_coordinates_arranges_params_in_coordinates():
    params = [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
        11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
        21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    ]
    n_dim = 6
    num_stimuli = 5

    points = anchor_coordinates.params_to_points(
        params, num_stimuli, n_dim
    )

    assert sum(points[0]) == 0
    assert sum(points[1][1:]) == 0
    assert sum(points[2][2:]) == 0
    assert sum(points[3][3:]) == 0
    assert sum(points[4][4:]) == 0
    assert len(points) == num_stimuli
    assert len(points[0]) == n_dim


def test_points_to_params_arranges_coordinates_into_varying_params():
    points = np.array([
        [0, 0, 0, 0, 0, 0],
        [1, 0, 0, 0, 0, 0],
        [2, 3, 0, 0, 0, 0],
        [4, 5, 6, 0, 0, 0],
        [7, 8, 9, 10, 0, 0],
        [11, 12, 13, 14, 15, 0],
        [16, 17, 18, 19, 20, 21],
        [22, 23, 24, 25, 26, 27],
        [28, 29, 30, 31, 32, 33],
    ])

    params = anchor_coordinates.points_to_params(points)

    assert len(params) == 33
    assert params[-1] == 33
    assert params == list(range(1, 34))
    assert (
        anchor_coordinates.params_to_points(params, 9, 6) == points
    ).all()


def test_calculate_ll_output_is_correct():
    counts = np.array([4, 1, 9])
    probs = np.array([1, 0.01, 1])
    num_repeats = 10

    correct_ll = (
            4 * log2(1)
            + 6 * log2(1e-30)
            + 1 * log2(0.01)
            + 9 * log2(0.99)
            + 9 * log2(1)
            + 1 * log2(1e-30)
    )
    calc_ll, bad_model = ll.calculate_ll(counts, probs, num_repeats)

    counts2 = np.array([10, 1, 0])
    probs2 = np.array([1, 0.01, 0])

    calc_ll2, bad_model2 = ll.calculate_ll(
        counts2, probs2, num_repeats
    )
    correct_ll2 = (
            10 * log2(1)
            + 1 * log2(0.01)
            + 9 * log2(0.99)
            + 10 * log2(1)
    )

    assert calc_ll == pytest.approx(correct_ll, rel=0, abs=1e-12)
    assert bad_model
    assert not bad_model2
    assert calc_ll2 == pytest.approx(correct_ll2, rel=0, abs=1e-8)