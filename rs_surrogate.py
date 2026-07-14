"""
rs_surrogate.py — Surrogate dataset generation and Procrustes statistical comparison.

Three distinct stages:
  1. Resample:     Generate N surrogate dataset pairs from pooled observations (sequential)
  2. Coordinates:  Run MDS on each surrogate — only this step is parallelized
  3. Compare:      Compute Procrustes disparity for each surrogate pair (sequential)

Usage:
    cd ~/Downloads/rs-software
    python3 ../rs_surrogate.py file1_suniyya.mat file2_suniyya.mat
"""

import sys
import os
import numpy as np
from scipy.linalg import orthogonal_procrustes
import multiprocessing as mp
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) +
                '/rs-software' if 'rs-software' not in os.getcwd() else '.')

from src.rs_py.utils.util import load_choices
from src.rs_py.utils.config import CONFIG
import src.rs_py.model.fit_geometric_models as rs


# ---------------------------------------------------------------------------
# load + MDS helpers
# ---------------------------------------------------------------------------

def load_file(path):
    responses, repeats, metadata, stim_list = load_choices(path)
    return responses, repeats, stim_list


def run_mds_single(responses, repeats, stim_list, dim, max_iterations, log_every=0, label="", start_points=None):
    """Run MDS for one dataset and return coordinates."""
    args = {
        'num_stimuli':    len(stim_list),
        'sigma':          CONFIG['inputs']['model_fit']['sigma'],
        'noise_st_dev':   CONFIG['inputs']['model_fit']['sigma'],
        'tolerance':      CONFIG['inputs']['model_fit']['tolerance'],
        'max_iterations': max_iterations,
        'learning_rate':  CONFIG['inputs']['model_fit']['learning_rate'],
        'minimization':   CONFIG['inputs']['model_fit']['minimization'],
        'n_dim':          dim,
        'log_every':      log_every,
        'label':          label,
    }
    coords, ll, residuals = rs.points_of_best_fit(responses, repeats, args, start_points=start_points)
    return coords, ll, residuals


# ---------------------------------------------------------------------------
# Pooling — combine two datasets (by stimulus name) into one for a compromise fit
# ---------------------------------------------------------------------------

def build_global_stim_list(stims1, stims2):
    """Union of both stimulus lists, plus index maps from each dataset's local index to the global index."""
    global_stims = list(stims1)
    for s in stims2:
        if s not in global_stims:
            global_stims.append(s)
    idx_map1 = {i: global_stims.index(s) for i, s in enumerate(stims1)}
    idx_map2 = {i: global_stims.index(s) for i, s in enumerate(stims2)}
    return global_stims, idx_map1, idx_map2


def remap_choices(resp, rep, idx_map):
    """Re-key a pairwise-choice dict using global stimulus indices."""
    new_resp, new_rep = {}, {}
    for key, count in resp.items():
        (a, b), (c, d) = key
        new_key = ((idx_map[a], idx_map[b]), (idx_map[c], idx_map[d]))
        if new_key not in new_resp:
            new_resp[new_key] = count
            new_rep[new_key] = rep[key]
        else:
            new_resp[new_key] += count
            new_rep[new_key] += rep[key]
    return new_resp, new_rep


def combine_choices(resp1, rep1, resp2, rep2, idx_map1, idx_map2):
    """Merge two datasets' choices into one pooled dataset, keyed by global stimulus indices."""
    r1, p1 = remap_choices(resp1, rep1, idx_map1)
    r2, p2 = remap_choices(resp2, rep2, idx_map2)
    combined_resp = dict(r1)
    combined_rep = dict(p1)
    for key, count in r2.items():
        if key not in combined_resp:
            combined_resp[key] = count
            combined_rep[key] = p2[key]
        else:
            combined_resp[key] += count
            combined_rep[key] += p2[key]
    return combined_resp, combined_rep


def extract_local_coords(pooled_coords, idx_map, n_local):
    """Pull out the rows of pooled_coords corresponding to one dataset's local stimulus order."""
    return np.array([pooled_coords[idx_map[i]] for i in range(n_local)])


# ---------------------------------------------------------------------------
# Stage 1: Resample — generate surrogate datasets (sequential)
# ---------------------------------------------------------------------------

def pool_observations(resp1, rep1, resp2, rep2):
    """
    Convert both participants' summary tables into one flat list of individual trial outcomes.

    Each entry is a (trial_key, outcome) tuple where:
      - trial_key  identifies the specific comparison (ref, s1, s2)
      - outcome=1  means s1 was chosen on that trial
      - outcome=0  means s2 was chosen on that trial

    Example: if participant A chose s1 twice out of 3 trials for a given key,
    we add [(key,1), (key,1), (key,0)] — one entry per individual trial.
    """
    observations = []
    for key, count in resp1.items():
        total = rep1[key]
        observations.extend([(key, 1)] * count) #add one key every time participant chose S1
        observations.extend([(key, 0)] * (total - count)) #Add one (key, 0) per time participant chose s2
    for key, count in resp2.items():
        total = rep2[key]
        observations.extend([(key, 1)] * count) #add one key every time particiapnt chose S1
        observations.extend([(key, 0)] * (total - count)) #Add one (key, 0) per time BL chose s2
    return observations


def build_pool(observations):
    """
    Reorganise the flat observations list into a dictionary:
      trial_key -> [outcome1, outcome2, ...]

    This lets us quickly look up all outcomes ever observed for a given trial type,
    across both participants combined. This is the 'bag' we draw from when resampling.
    """
    pool = {}
    for trial_key, outcome in observations:
        pool.setdefault(trial_key, []).append(outcome)
    return pool


def _draw_outcomes(bag, n_draws, replace):
    """
    Draw n_draws outcomes from bag (a list of 0s and 1s).
    Returns the number of times s1 was chosen (i.e. sum of draws).
    """
    if len(bag) == 0:
        raise ValueError(
            f"Pool is empty for this trial key — something is fundamentally wrong with the data."
        )
    if not replace and len(bag) < n_draws:
        raise ValueError(
            f"Pool has {len(bag)} outcomes but {n_draws} draws requested without replacement. "
            f"This means the combined data from both datasets is insufficient for this trial type."
        )
    draws = np.random.choice(bag, size=n_draws, replace=replace)
    return int(draws.sum()), n_draws


def resample_with_replacement(pool, resp, rep):
    """
    Strategy 1 — WITH replacement (default, most conservative).

    For each trial type, draw the required number of outcomes from the
    shared pool, putting each one back before the next draw.
    Both surrogate A and surrogate B draw independently from the full pool,
    so the same outcome can appear in both.

    Analogy: drawing cards from a deck, replacing each card before the next draw.
    """
    surrogate_responses = {}
    surrogate_repeats   = {}
    for trial_key in resp: #Loop through every trial type the real participant did
        n_trials = rep[trial_key] #how many times did the real participant do this trial?- same no. for surrogate
        if trial_key not in pool:
            raise KeyError(f"Trial key {trial_key} missing from pool — this should never happen.") #sanity check as was suggested earlier
        bag = pool[trial_key]
        times_s1_chosen, total = _draw_outcomes(bag, n_trials, replace=True)
        surrogate_responses[trial_key] = times_s1_chosen
        surrogate_repeats[trial_key]   = total
    return surrogate_responses, surrogate_repeats


def resample_without_replacement_unpaired(pool, resp, rep):
    """
    Strategy 2 — WITHOUT replacement, unpaired.

    For each trial type, draw the required outcomes WITHOUT putting them back,
    so no outcome is repeated within one participant's draw.
    However, A and B still draw independently — they can end up with the same
    outcomes as each other.

    Analogy: dealing a hand from a shuffled deck without replacement,
    but then reshuffling and dealing again for the second player.
    Raises ValueError if the pool is smaller than n_draws.
    """
    surrogate_responses = {}
    surrogate_repeats   = {}
    for trial_key in resp:
        n_trials = rep[trial_key]
        if trial_key not in pool:
            raise KeyError(f"Trial key {trial_key} missing from pool — this should never happen.")
        bag = pool[trial_key]
        times_s1_chosen, total = _draw_outcomes(bag, n_trials, replace=False) #different logic as compared to prev fucntion, replace=false #_draw_outcomes has a fallback — if the bag is too small to draw n_trials without replacement, it silently switches back to replace=True for that trial
        surrogate_responses[trial_key] = times_s1_chosen
        surrogate_repeats[trial_key]   = total
    return surrogate_responses, surrogate_repeats


def resample_without_replacement_paired(pool, resp1, rep1, resp2, rep2): #add a line or two to verify if the choices are all the same as the og dataset
    """
    Strategy 3 — WITHOUT replacement, paired (most constrained).

    For each trial type, participant A draws first without replacement.
    Participant B automatically receives whatever A did NOT take.
    Together they consume every outcome in the pool exactly once —
    like splitting a deck of cards perfectly between two players.

    Raises ValueError if the pool is too small — this indicates a data problem.
    Returns surrogate datasets for both participants at once (since they are linked).
    """
    
    remaining_pool = {trial_key: list(outcomes) for trial_key, outcomes in pool.items()} #make a copy of the pool as a regular Python dict of lists- because we're going to physically remove items as we draw #also the for is compact way to build a dictionary in one line

    surr_resp1, surr_rep1 = {}, {}
    surr_resp2, surr_rep2 = {}, {}

    # process every trial type that appears in either participant's data
    all_trial_keys = set(resp1.keys()) | set(resp2.keys()) #set is for removing duplicate trial types

    for trial_key in all_trial_keys:
        n1 = rep1.get(trial_key, 0)   # how many trials participant A did
        n2 = rep2.get(trial_key, 0)   
        available = remaining_pool.get(trial_key, []) #grab the current bag for this trial- this bag starts as all pooled outcomes combined, and shrinks as A draws from it

        
        if trial_key in resp1:
            if len(available) >= n1: #do we even have enough outcomes in the bag to give A what they need?
                # pick n1 random indices from the available outcomes
                chosen_indices = set(np.random.choice(len(available), size=n1, replace=False)) #picks randomly
                a_draws  = [available[i] for i in chosen_indices]
                leftover = [available[i] for i in range(len(available)) if i not in chosen_indices]
            else:
                raise ValueError(
                    f"Pool has {len(available)} outcomes for trial {trial_key} but dataset A needs "
                    f"{n1} draws. Something is fundamentally wrong with the data."
                )
            surr_resp1[trial_key] = int(sum(a_draws)) Ehow many times was s1 chosen?
            surr_rep1[trial_key]  = n1
        else:
            # A didn't do this trial — all outcomes go to leftover for B
            leftover = list(available)

        # participant b	
        if trial_key in resp2:
            if len(leftover) >= n2:
                b_draws = leftover[:n2]
            else:
                raise ValueError(
                    f"After dataset A drew from the pool, only {len(leftover)} outcomes remain for "
                    f"trial {trial_key} but dataset B needs {n2}. Pool is too small."
                )
            surr_resp2[trial_key] = int(sum(b_draws))
            surr_rep2[trial_key]  = n2

    return surr_resp1, surr_rep1, surr_resp2, surr_rep2


def generate_surrogate_pairs(observations, resp1, rep1, resp2, rep2, n_surrogates, method='with_replacement'):
    """
    Stage 1: Generate N surrogate dataset pairs using the chosen resampling method.

    Each surrogate pair is one fake (participant A, participant B) — created by
    randomly splitting the pooled real data. Running MDS on many such pairs
    builds the null distribution: how different two maps look when there is
    no genuine difference between participants.

    method options:
      'with_replacement'           — Strategy 1 (default, most conservative)
      'without_replacement'        — Strategy 2 (no repeats within each draw)
      'without_replacement_paired' — Strategy 3 (A and B split the pool perfectly)
    """
    pool  = build_pool(observations)
    pairs = []

    for seed in range(n_surrogates):
        np.random.seed(seed)   # fix seed so results are reproducible

        if method == 'with_replacement':
            s_resp1, s_rep1 = resample_with_replacement(pool, resp1, rep1)
            s_resp2, s_rep2 = resample_with_replacement(pool, resp2, rep2)

        elif method == 'without_replacement':
            s_resp1, s_rep1 = resample_without_replacement_unpaired(pool, resp1, rep1)
            s_resp2, s_rep2 = resample_without_replacement_unpaired(pool, resp2, rep2)

        elif method == 'without_replacement_paired':
            s_resp1, s_rep1, s_resp2, s_rep2 = resample_without_replacement_paired(
                pool, resp1, rep1, resp2, rep2)

        else:
            raise ValueError(f"Unknown resampling method: {method}")

        pairs.append((s_resp1, s_rep1, s_resp2, s_rep2))

    return pairs


# ---------------------------------------------------------------------------
# Stage 2: Coordinates — run MDS (parallelized)
# ---------------------------------------------------------------------------

def run_mds_worker(args_tuple):
    """Worker: runs MDS on one surrogate dataset. Called in parallel."""
    job_idx, s_resp, s_rep, stim_list, dim, max_iterations, print_every = args_tuple
    surrogate_num = job_idx // 2 + 1
    dataset_label = "A" if job_idx % 2 == 0 else "B"
    label = f"Surrogate {surrogate_num}{dataset_label}"
    print(f"  [{label}] starting...")
    coords, ll, residuals = run_mds_single(s_resp, s_rep, stim_list, dim, max_iterations, log_every=print_every if print_every > 0 else 0, label=label)
    total = sum(s_rep.values())
    print(f"  [{label}] done. LL={-ll / total:.4f}")
    return coords, ll


def run_mds_parallel(surrogate_pairs, stim_list, dim, max_iterations, print_every=0):
    """
    Stage 2: Run MDS on all surrogate datasets in parallel.
    Each pair needs 2 MDS runs (one per resampled dataset),
    so total jobs = 2 * n_surrogates.
    """
    jobs = []
    for idx, (s_resp1, s_rep1, s_resp2, s_rep2) in enumerate(surrogate_pairs):
        jobs.append((idx * 2,     s_resp1, s_rep1, stim_list, dim, max_iterations, print_every))
        jobs.append((idx * 2 + 1, s_resp2, s_rep2, stim_list, dim, max_iterations, print_every))

    print(f"  Running {len(jobs)} MDS fits across {mp.cpu_count()} cores...")
    with mp.Pool(processes=mp.cpu_count()) as pool:
        results = pool.map(run_mds_worker, jobs)

    # unpack coords and lls
    all_coords = [r[0] for r in results]
    all_lls    = [r[1] for r in results]

    # print LL table — one row per surrogate pair
    total_triads = sum(jobs[0][1].values())  # rep1 from first job
    print(f"\n  {'Surrogate':>10}  {'LL (dataset A)':>16}  {'LL (dataset B)':>16}")
    print(f"  {'-'*46}")
    for i in range(0, len(all_lls), 2):
        ll_a = -all_lls[i]   / total_triads
        ll_b = -all_lls[i+1] / total_triads
        print(f"  {i//2 + 1:>10}  {ll_a:>16.4f}  {ll_b:>16.4f}")

    # jobs were interleaved [A1, B1, A2, B2, ...] — re-pair them
    coord_pairs = [(all_coords[i], all_coords[i + 1]) for i in range(0, len(all_coords), 2)]
    return coord_pairs


# ---------------------------------------------------------------------------
# Stage 3: Compare — compute Procrustes disparities (sequential)
# ---------------------------------------------------------------------------

def align_to_shared_stimuli(coords1, stims1, coords2, stims2):
    """
    Find shared stimuli between two datasets and reorder both coordinate
    matrices so that row i refers to the same stimulus in both.
    Returns (c1_shared, c2_shared, shared_stims).
    Works even if the datasets have different stimuli or different orderings.
    """
    shared = [s for s in stims1 if s in set(stims2)]
    if len(shared) == 0:
        raise ValueError("No shared stimuli between the two datasets — cannot compare.")
    if len(shared) < len(stims1) or len(shared) < len(stims2):
        print(f"  Note: {len(shared)} shared stimuli out of "
              f"{len(stims1)} (dataset 1) and {len(stims2)} (dataset 2). "
              f"Procrustes computed on shared stimuli only.")
    idx1 = [list(stims1).index(s) for s in shared]
    idx2 = [list(stims2).index(s) for s in shared]
    return coords1[idx1], coords2[idx2], shared


def compute_disparity(coords1, coords2, stims1=None, stims2=None):
    """
    Orthogonal Procrustes disparity between two coordinate sets.
    Normalized by norm² of C2 (standard convention per JV).
    If stims1/stims2 are provided, compares only shared stimuli
    and handles different orderings automatically.
    """
    if stims1 is not None and stims2 is not None:
        coords1, coords2, _ = align_to_shared_stimuli(coords1, stims1, coords2, stims2)
    c1 = coords1 - coords1.mean(axis=0)
    c2 = coords2 - coords2.mean(axis=0)
    R, _ = orthogonal_procrustes(c1, c2)
    c2_aligned = c2 @ R.T
    disparity = np.linalg.norm(c1 - c2_aligned, 'fro') / np.linalg.norm(c2, 'fro') ** 2
    return disparity


def compute_surrogate_disparities(coord_pairs, stims1=None, stims2=None):
    """Stage 3: Compute Procrustes disparity for each surrogate pair."""
    return [compute_disparity(c1, c2, stims1, stims2) for c1, c2 in coord_pairs]


# ---------------------------------------------------------------------------
# Dialogue box — ask user for settings interactively
# ---------------------------------------------------------------------------

def get_user_inputs():
    print("\n=== Surrogate Analysis Settings ===")
    print("  Tip: enter 0 surrogates for a quick prelim run to check convergence first.\n")

    dim_input = input("Dimensions [default: 2]: ").strip()
    dim = int(dim_input) if dim_input else 2

    n_input = input("Number of surrogates [default: 100, enter 0 for prelim]: ").strip()
    n_surrogates = int(n_input) if n_input else 100

    iter_input = input("Max iterations per MDS fit [default: 2000]: ").strip()
    max_iterations = int(iter_input) if iter_input else 2000

    print_input = input("Print convergence table every N iterations [default: 0 = off]: ").strip()
    print_every = int(print_input) if print_input else 0

    print("  Resampling method:")
    print("    1 = with replacement (default)")
    print("    2 = without replacement, unpaired")
    print("    3 = without replacement, paired")
    method_input = input("  Choice [default: 1]: ").strip()
    method_map = {
        '1': 'with_replacement',
        '2': 'without_replacement',
        '3': 'without_replacement_paired',
    }
    method = method_map.get(method_input, 'with_replacement')

    mode = "PRELIM (no surrogates)" if n_surrogates == 0 else f"{n_surrogates} surrogates"
    print(f"\n  Settings: {dim}D  |  {mode}  |  {max_iterations} max iterations  |  print every {print_every if print_every else 'off'}  |  {method}")
    return dim, n_surrogates, max_iterations, print_every, method


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main():
    positional = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(positional) < 2:
        print("Usage: python3 rs_surrogate.py file1_suniyya.mat file2_suniyya.mat")
        sys.exit(1)

    path1, path2 = positional[0], positional[1]

    print(f"\n{'='*60}")
    print(f"Loading files...")
    resp1, rep1, stims1 = load_file(path1)
    resp2, rep2, stims2 = load_file(path2)
    print(f"  Dataset 1: {os.path.basename(path1)} — {len(stims1)} stimuli")
    print(f"  Dataset 2: {os.path.basename(path2)} — {len(stims2)} stimuli")

    # get settings interactively
    dim, n_surrogates, max_iterations, print_every, method = get_user_inputs()

    label1 = os.path.basename(path1).replace('_suniyya.mat', '')
    label2 = os.path.basename(path2).replace('_suniyya.mat', '')
    total_triads1 = sum(rep1.values())
    total_triads2 = sum(rep2.values())

    # --- optional: pooled (compromise) fit + warm start ---
    pool_input = input("\nCompute pooled (A+B combined) fit and use it as the starting point "
                        "for the real-data fits? [y/N]: ").strip().lower()
    use_pooled_start = pool_input == 'y'

    pooled_coords, pooled_ll, pooled_residuals, total_triads_pooled = None, None, [], None
    start1, start2 = None, None
    if use_pooled_start:
        print(f"\n{'='*60}")
        print(f"Fitting pooled (compromise) dataset ({dim}D)...")
        global_stims, idx_map1, idx_map2 = build_global_stim_list(stims1, stims2)
        pooled_resp, pooled_rep = combine_choices(resp1, rep1, resp2, rep2, idx_map1, idx_map2)
        total_triads_pooled = sum(pooled_rep.values())
        pooled_coords, pooled_ll, pooled_residuals = run_mds_single(
            pooled_resp, pooled_rep, global_stims, dim, max_iterations,
            log_every=1, label="Pooled"
        )
        print(f"  Pooled final LL: {-pooled_ll / total_triads_pooled:.4f}")
        start1 = extract_local_coords(pooled_coords, idx_map1, len(stims1))
        start2 = extract_local_coords(pooled_coords, idx_map2, len(stims2))

    # real Procrustes distance
    print(f"\n{'='*60}")
    print(f"Running MDS on real data ({dim}D)...")

    real_coords1, real_ll1, residuals1 = run_mds_single(resp1, rep1, stims1, dim, max_iterations, log_every=1, label=f"Real {label1}", start_points=start1)
    real_coords2, real_ll2, residuals2 = run_mds_single(resp2, rep2, stims2, dim, max_iterations, log_every=1, label=f"Real {label2}", start_points=start2)
    real_disparity = compute_disparity(real_coords1, real_coords2, stims1, stims2)
    print(f"  {label1} final LL: {-real_ll1 / total_triads1:.4f}")
    print(f"  {label2} final LL: {-real_ll2 / total_triads2:.4f}")
    print(f"  Real Procrustes disparity: {real_disparity:.6f}")

    # convergence table + plot if log_every was set
    if (residuals1 or residuals2 or pooled_residuals):
        # convergence table — only if user asked for it
        if print_every > 0:
            pooled_col = "  Pooled" if pooled_residuals else ""
            print(f"\n  Convergence ({dim}D) — every {print_every} iterations:")
            print(f"  {'Iteration':>12}  {label1:>16}  {label2:>16}{pooled_col:>16}")
            print(f"  {'-'*(48 + (16 if pooled_residuals else 0))}")
            d1 = {i: l for i, l in residuals1}
            d2 = {i: l for i, l in residuals2}
            dp = {i: l for i, l in pooled_residuals}
            all_itrs = sorted(set([i for i, _ in residuals1] + [i for i, _ in residuals2] + [i for i, _ in pooled_residuals]))
            for itr in all_itrs:
                if itr % print_every == 0 or itr == all_itrs[-1]:
                    ll1_str = f"{-d1[itr]/total_triads1:.4f}" if itr in d1 else "—"
                    ll2_str = f"{-d2[itr]/total_triads2:.4f}" if itr in d2 else "—"
                    row = f"  {itr:>12}  {ll1_str:>16}  {ll2_str:>16}"
                    if pooled_residuals:
                        llp_str = f"{-dp[itr]/total_triads_pooled:.4f}" if itr in dp else "—"
                        row += f"  {llp_str:>16}"
                    print(row)

        # save convergence plot
        fig, ax = plt.subplots(figsize=(10, 5))
        if residuals1:
            itrs1, lls1 = zip(*residuals1)
            ax.plot(itrs1, [-l/total_triads1 for l in lls1], label=label1, marker='o', markersize=3)
        if residuals2:
            itrs2, lls2 = zip(*residuals2)
            ax.plot(itrs2, [-l/total_triads2 for l in lls2], label=label2, marker='s', markersize=3)
        if pooled_residuals:
            itrsp, llsp = zip(*pooled_residuals)
            ax.plot(itrsp, [-l/total_triads_pooled for l in llsp], label="Pooled (A+B)", marker='^', markersize=3, linestyle='--', color='purple')
        ax.set_xlabel("Iteration")
        ax.set_ylabel("LL per triad")
        ax.set_title(f"Convergence ({dim}D)")
        ax.legend()
        ax.grid(True, alpha=0.3)
        plt.tight_layout()
        plot_path = os.path.join(os.path.dirname(path1), f"convergence_{dim}d.png")
        plt.savefig(plot_path, dpi=150)
        plt.close()
        print(f"\n  Convergence plot saved: {plot_path}")

    # prelim mode: stop here
    if n_surrogates == 0:
        print(f"\n  Prelim run complete. Check convergence plot, then rerun with surrogates.")
        return

    # Stage 1: resample
    print(f"\n{'='*60}")
    print(f"Stage 1: Generating {n_surrogates} surrogate dataset pairs...")
    observations = pool_observations(resp1, rep1, resp2, rep2)
    surrogate_pairs = generate_surrogate_pairs(
        observations, resp1, rep1, resp2, rep2, n_surrogates, method=method)
    print(f"  Done — {len(surrogate_pairs)} pairs generated.")

    # Stage 2: MDS (parallelized)
    print(f"\n{'='*60}")
    print(f"Stage 2: Running MDS on surrogate datasets ({dim}D)...")
    coord_pairs = run_mds_parallel(surrogate_pairs, stims1, dim, max_iterations)
    print(f"  Done — {len(coord_pairs)} coordinate pairs computed.")

    # Stage 3: Procrustes
    print(f"\n{'='*60}")
    print(f"Stage 3: Computing Procrustes disparities...")
    surrogate_disparities = np.array(compute_surrogate_disparities(coord_pairs, stims1, stims2))
    print(f"  Done.")

    # statistical summary
    p_value = np.mean(surrogate_disparities >= real_disparity)

    print(f"\n{'='*60}")
    print(f"RESULTS ({dim}D, {n_surrogates} surrogates)")
    print(f"{'='*60}")
    print(f"  Real Procrustes disparity:      {real_disparity:.4f}")
    print(f"  Surrogate mean disparity:       {surrogate_disparities.mean():.4f}")
    print(f"  Surrogate std:                  {surrogate_disparities.std():.4f}")
    print(f"  Surrogate range:                {surrogate_disparities.min():.4f} – {surrogate_disparities.max():.4f}")
    print(f"  p-value (surrogates >= real):   {p_value:.4f}")
    print()

    print(f"{'='*60}")

    # save results
    out_path = os.path.join(os.path.dirname(path1),
                            f"surrogate_results_{dim}d_{n_surrogates}surrogates.npz")
    np.savez(out_path,
             real_disparity=real_disparity,
             surrogate_disparities=surrogate_disparities,
             p_value=p_value)
    print(f"\n  Results saved: {out_path}")


if __name__ == '__main__':
    main()
