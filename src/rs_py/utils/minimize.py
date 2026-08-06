
import logging
import numpy as np

LOG = logging.getLogger(__name__)


def calculate_gradient(costfunc, vector, pair_a, pair_b, counts, repeats, params, vector_length, delta=1e-03):
    baseline_loss = costfunc(vector, pair_a, pair_b, counts, repeats, params)
    deltas = np.eye(vector_length) * delta
    vectors = np.tile(vector.reshape(vector_length, 1), (1, vector_length))
    delta_vectors = vectors + deltas
    new_loss_vector = np.apply_along_axis(costfunc, 0, delta_vectors, pair_a, pair_b, counts, repeats, params)
    gradient = new_loss_vector - baseline_loss
    return gradient


def gradient_descent(costfunc, start, pair_a, pair_b, counts, repeats, params, log_every=0, label=""):
    """"
    Implements stochastic gradient descent.
    The code below is my first attempt and not an optimized program
    Based on a tutorial on realpython.com

    log_every: if > 0, print and record the LL (normalized by total triads) every K iterations.
               if 0 (default), no per-iteration logging.
    Returns: (vector, all_residuals) where all_residuals is a list of
             (iteration, raw_loss) tuples recorded at every log_every step.
    """
    vector = np.array(start)
    vector_length = len(vector)
    all_residuals = []   # list of (iteration, raw_loss) — returned for plotting
    total_triads = int(np.sum(repeats))

    for _ in range(params['max_iterations']):
        diff = -params['learning_rate'] * calculate_gradient(costfunc, vector, pair_a, pair_b,
                                                             counts, repeats, params, vector_length)
        if _ > 0 and np.all(np.abs(diff) <= params['tolerance']):
            loss = costfunc(vector, pair_a, pair_b, counts, repeats, params)
            all_residuals.append((_ + 1, loss))
            print("Stopped on Iteration number {}".format(_ + 1))
            break
        vector += diff

        # record and print residual every K iterations
        if log_every > 0 and (_ + 1) % log_every == 0:
            loss = costfunc(vector, pair_a, pair_b, counts, repeats, params)
            all_residuals.append((_ + 1, loss))
            prefix = f"  [{label}] " if label else "  "
            print(f"{prefix}iter {_ + 1}: LL={-loss/total_triads:.4f}")
        elif log_every == 0 and _ % 1000 == 0:
            prefix = f"  [{params.get('label', '')}] " if params.get('label') else '\t'
            print('{}Iterations completed: {}'.format(prefix, _))

    print("\tStopped on Iteration number {}".format(_))
    params['_all_residuals'] = all_residuals
    params['_checkpoint_lls'] = {itr: loss for itr, loss in all_residuals}
    return vector, all_residuals

