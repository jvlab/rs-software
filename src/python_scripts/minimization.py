
import logging
import numpy as np
from numpy import eye, tile, apply_along_axis

logging.basicConfig(level=logging.INFO)
LOG = logging.getLogger(__name__)
LOG.setLevel(logging.INFO)


def calculate_gradient(costfunc, vector, pair_a, pair_b, counts, repeats, params, vector_length, delta=1e-03):
    baseline_loss = costfunc(vector, pair_a, pair_b, counts, repeats, params)
    deltas = eye(vector_length) * delta
    vectors = tile(vector.reshape(vector_length, 1), (1, vector_length))
    delta_vectors = vectors + deltas
    new_loss_vector = apply_along_axis(costfunc, 0, delta_vectors, pair_a, pair_b, counts, repeats, params)
    gradient = new_loss_vector - baseline_loss
    return gradient


def gradient_descent(costfunc, start, pair_a, pair_b, counts, repeats, params):
    """"
    Implements stochastic gradient descent.
    The code below is my first attempt and not an optimized program
    Based on a tutorial on realpython.com
    """
    vector = np.array(start)
    vector_length = len(vector)
    # breakpoint()
    # vector = vector.reshape(len(vector), 1)  # in case it was a row, vector, make column vector
    for _ in range(params['max_iterations']):
        # print(_)
        diff = -params['learning_rate'] * calculate_gradient(costfunc, vector, pair_a, pair_b,
                                                             counts, repeats, params, vector_length)
        if np.all(np.abs(diff) <= params['tolerance']):
            print("Stopped on Iteration number {}".format(_ + 1))
            break
        vector += diff
        if _ % 1000 == 0:
            print('{} Iterations done'.format(_))
    print("Stopped on Iteration number {}".format(_))
    # vector = vector.reshape(1, len(vector))  # returned vector must be a regular 1D array
    return vector

