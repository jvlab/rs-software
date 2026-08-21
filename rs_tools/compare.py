"""
compare — Surrogate MDS comparison pipeline.

Given two triadic choice datasets, fits a perceptual map to each using MDS,
then generates surrogate (null) datasets via resampling to compute a p-value
for the Procrustes disparity between the two maps.
"""

import numpy as np
from scipy.linalg import orthogonal_procrustes
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
import sys, os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from src.rs_py.utils.config import CONFIG
import src.rs_py.model.fit_geometric_models as rs

_CFG = CONFIG['inputs']['model_fit']


def run_mds(resp, rep, stims, dim, max_iter, learning_rate=None, start=None, seed=None):
    """Fit an MDS coordinate map to a triadic choice dataset."""
    if learning_rate is None:
        learning_rate = _CFG['learning_rate']
    args = {
        'num_stimuli':    len(stims),
        'sigma':          _CFG['sigma'],
        'noise_st_dev':   _CFG['sigma'],
        'tolerance':      _CFG['tolerance'],
        'max_iterations': max_iter,
        'learning_rate':  learning_rate,
        'minimization':   _CFG['minimization'],
        'n_dim':          dim,
        'log_every':      0,
        'label':          '',
    }
    coords, ll, _ = rs.points_of_best_fit(resp, rep, args, start_points=start, seed=seed)
    return coords, ll


def procrustes_disparity(coords1, stims1, coords2, stims2):
    """Compute Procrustes disparity between two coordinate maps on shared stimuli."""
    shared = [s for s in stims1 if s in set(stims2)]
    if len(shared) < 3:
        raise ValueError(f"Too few shared stimuli: {len(shared)}")
    i1 = [list(stims1).index(s) for s in shared]
    i2 = [list(stims2).index(s) for s in shared]
    c1 = coords1[i1].copy(); c2 = coords2[i2].copy()
    c1 -= c1.mean(0); c2 -= c2.mean(0)
    R, _ = orthogonal_procrustes(c1, c2)
    return np.linalg.norm(c1 - c2 @ R.T, 'fro') / np.linalg.norm(c2, 'fro') ** 2, len(shared)


def pool_observations(resp1, rep1, resp2, rep2):
    """Combine two datasets into a pooled observation pool for resampling."""
    pool = defaultdict(list)
    for resp, rep in [(resp1, rep1), (resp2, rep2)]:
        for key, count in resp.items():
            total = rep[key]
            pool[key].extend([1] * count + [0] * (total - count))
    return dict(pool)


def resample(pool, resp, rep, method='with_replacement'):
    """Resample a dataset from the pooled pool."""
    sr, srep = {}, {}
    for key in resp:
        n = rep[key]; bag = pool.get(key, [])
        if method == 'with_replacement':
            draws = np.random.choice(bag, size=n, replace=True)
        else:
            draws = np.array(bag)[np.random.choice(len(bag), size=n, replace=False)]
        sr[key] = int(draws.sum()); srep[key] = n
    return sr, srep


def resample_paired(pool, resp1, rep1, resp2, rep2):
    """Paired resampling — draw for dataset A first, then B from what remains."""
    rem = {k: list(v) for k, v in pool.items()}
    sr1, srep1, sr2, srep2 = {}, {}, {}, {}
    for key in set(resp1) | set(resp2):
        n1 = rep1.get(key, 0); n2 = rep2.get(key, 0)
        avail = rem.get(key, [])
        if key in resp1:
            idx = set(np.random.choice(len(avail), size=n1, replace=False))
            sr1[key] = int(sum(avail[i] for i in idx)); srep1[key] = n1
            avail = [avail[i] for i in range(len(avail)) if i not in idx]
        if key in resp2:
            sr2[key] = int(sum(avail[:n2])); srep2[key] = n2
    return sr1, srep1, sr2, srep2


def warm_start(resp1, rep1, stims1, resp2, rep2, stims2, dim, max_iter=2000, seed=0):
    """Fit pooled (A+B) MDS and return starting coordinates for each dataset.

    seed fixes the pooled fit's own MDS initialization (the one fit in this
    pipeline that runs with no start_points of its own) so the pooled result —
    and everything downstream that warm-starts from it — is reproducible.
    """
    global_stims = list(stims1)
    for s in stims2:
        if s not in global_stims:
            global_stims.append(s)
    idx1 = {i: global_stims.index(s) for i, s in enumerate(stims1)}
    idx2 = {i: global_stims.index(s) for i, s in enumerate(stims2)}

    def remap(resp, rep, idx):
        nr, nrep = {}, {}
        for key, count in resp.items():
            (a, b), (c, d) = key
            nk = ((idx[a], idx[b]), (idx[c], idx[d]))
            nr[nk] = nr.get(nk, 0) + count
            nrep[nk] = nrep.get(nk, 0) + rep[key]
        return nr, nrep

    pr1, pp1 = remap(resp1, rep1, idx1)
    pr2, pp2 = remap(resp2, rep2, idx2)
    pooled_resp = dict(pr1)
    pooled_rep  = dict(pp1)
    for k, v in pr2.items():
        pooled_resp[k] = pooled_resp.get(k, 0) + v
        pooled_rep[k]  = pooled_rep.get(k, 0) + pp2[k]

    pc, _ = run_mds(pooled_resp, pooled_rep, global_stims, dim, max_iter, seed=seed)
    return (np.array([pc[idx1[i]] for i in range(len(stims1))]),
            np.array([pc[idx2[i]] for i in range(len(stims2))]))


def compare(resp1, rep1, stims1, resp2, rep2, stims2,
            dim=3, n_surrogates=100, real_max_iter=2000, surr_max_iter=200,
            resample_method='with_replacement', use_warm_start=True,
            n_workers=8, verbose=True):
    """
    Run a full surrogate MDS comparison between two datasets.

    Args:
        resp1, rep1, stims1: dataset A (from load_choices)
        resp2, rep2, stims2: dataset B (from load_choices)
        dim:              MDS dimensionality (default 3)
        n_surrogates:     number of surrogate datasets (default 100)
        real_max_iter:    max iterations for real fits (default 2000)
        surr_max_iter:    max iterations for surrogate fits (default 200)
        resample_method:  'with_replacement', 'without_replacement',
                          or 'without_replacement_paired'
        use_warm_start:   fit pooled data first as starting point (default True)
        n_workers:        parallel threads for surrogates (default 8)
        verbose:          print progress (default True)

    Returns:
        dict with keys: real_disp, surrogate_disparities, p_value,
                        real_ll1, real_ll2, n_shared
    """
    def log(msg):
        if verbose:
            print(msg)

    start1, start2 = None, None
    if use_warm_start:
        log("Computing warm start...")
        start1, start2 = warm_start(resp1, rep1, stims1, resp2, rep2, stims2, dim, real_max_iter)

    log("Fitting real data...")
    rc1, rll1 = run_mds(resp1, rep1, stims1, dim, real_max_iter, start=start1)
    rc2, rll2 = run_mds(resp2, rep2, stims2, dim, real_max_iter, start=start2)
    real_disp, n_shared = procrustes_disparity(rc1, stims1, rc2, stims2)
    real_ll1 = -rll1 / sum(rep1.values())
    real_ll2 = -rll2 / sum(rep2.values())
    log(f"Real: disparity={real_disp:.4f}  LL1={real_ll1:.4f}  LL2={real_ll2:.4f}  ({n_shared} shared stims)")

    pool = pool_observations(resp1, rep1, resp2, rep2)

    def run_one(seed):
        np.random.seed(seed)
        if resample_method == 'without_replacement_paired':
            sr1, srp1, sr2, srp2 = resample_paired(pool, resp1, rep1, resp2, rep2)
        else:
            sr1, srp1 = resample(pool, resp1, rep1, resample_method)
            sr2, srp2 = resample(pool, resp2, rep2, resample_method)
        sc1, _ = run_mds(sr1, srp1, stims1, dim, surr_max_iter, start=start1)
        sc2, _ = run_mds(sr2, srp2, stims2, dim, surr_max_iter, start=start2)
        disp, _ = procrustes_disparity(sc1, stims1, sc2, stims2)
        return disp

    log(f"Running {n_surrogates} surrogates ({resample_method})...")
    with ThreadPoolExecutor(max_workers=n_workers) as ex:
        surrogate_disparities = np.array(list(ex.map(run_one, range(n_surrogates))))

    p_value = float(np.mean(surrogate_disparities >= real_disp))
    log(f"p-value={p_value:.4f}  surr_mean={surrogate_disparities.mean():.4f}")

    return {
        'real_disp':            real_disp,
        'surrogate_disparities': surrogate_disparities,
        'p_value':              p_value,
        'real_ll1':             real_ll1,
        'real_ll2':             real_ll2,
        'n_shared':             n_shared,
    }
