"""
run_checks -- two small checks for the Surrogate MDS app: how long a run will take, and whether
a fit has levelled off.

estimate_seconds(): from the time of a few timed iterations, the run time of the whole analysis.
cost_plateau():     compares the cost (negative log-likelihood per trial) near the end of a fit with
                    its value over the last part of the run.
"""

import time

import numpy as np

PLATEAU_TOLERANCE = 0.001   # the cost may change by up to 0.1% over the last 20% of the iterations
LAST_FRACTION = 0.2
SURROGATE_SPEEDUP = 1.3     # measured: the app runs 2 surrogates at a time, which is only ~1.3x faster than one


def seconds_per_iteration(fit_fn, short=5, long=25):
    """Seconds per iteration of `fit_fn(n)` (a fit that runs exactly n iterations).

    Two lengths are timed and the slope between them is used, so the fixed set-up time of a fit is left out.
    """
    t0 = time.perf_counter()
    fit_fn(short)
    t1 = time.perf_counter()
    fit_fn(long)
    t2 = time.perf_counter()
    return max((t2 - t1) - (t1 - t0), 1e-6) / (long - short)


def estimate_seconds(sec_per_iter_1, sec_per_iter_2, max_iterations, n_surrogates,
                     surrogate_max_iter, warm_start, speedup=SURROGATE_SPEEDUP):
    """Estimated run time in seconds.

    The real fits and the pooled fit each cost about one fit of each dataset per iteration; every
    surrogate is a pair of fits of the same size, and running several at once speeds them up by `speedup`.
    """
    per_iter = sec_per_iter_1 + sec_per_iter_2
    real_and_pooled = (2 if warm_start else 1) * max_iterations
    surrogates = n_surrogates * surrogate_max_iter / max(1, min(speedup, n_surrogates)) if n_surrogates else 0
    return per_iter * (real_and_pooled + surrogates)


def format_duration(seconds):
    if seconds < 90:
        return f"about {max(1, round(seconds / 5) * 5)} seconds"
    minutes = seconds / 60
    if minutes < 90:
        return f"about {round(minutes)} min"
    return f"about {minutes / 60:.1f} hours"


def cost_plateau(residuals, total_triads, tolerance=PLATEAU_TOLERANCE, last_fraction=LAST_FRACTION):
    """Has the cost levelled off?

    residuals: [(iteration, negative log-likelihood), ...] as logged during the fit.
    Returns (levelled_off, relative_change), where relative_change is how much the cost per trial
    changed between the last `last_fraction` of the run and the end. Returns None when there are too
    few logged points to tell.
    """
    if not residuals or len(residuals) < 3:
        return None
    iters = np.array([i for i, _ in residuals], dtype=float)
    cost = np.array([v for _, v in residuals], dtype=float) / total_triads
    earlier = np.where(iters <= (1 - last_fraction) * iters[-1])[0]
    if len(earlier) == 0:
        return None
    change = abs(cost[earlier[-1]] - cost[-1]) / abs(cost[-1])
    return bool(change <= tolerance), float(change)
