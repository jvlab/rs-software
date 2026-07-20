"""
convert_numpy_to_mat.py — Convert a 5-column NumPy array back to a .mat choice file.

Expected column order in the array:
    0: ref          — reference stimulus index (1-indexed)
    1: s1           — stimulus 1 index (1-indexed)
    2: s2           — stimulus 2 index (1-indexed)
    3: N(s1 chosen) — number of times s1 was chosen
    4: N_repeats    — total number of trials

If no stimulus names are provided, defaults to stim_01, stim_02, ... stim_N.

Usage:
    cd ~/Downloads/rs-software
    python3 convert_numpy_to_mat.py input.npy output.mat
    python3 convert_numpy_to_mat.py input.npy output.mat --stims stim_list.txt
"""

import sys
import numpy as np
from scipy.io import savemat
from pathlib import Path


def numpy_to_mat(array, stim_list=None, out_path=None):
    """
    Convert a 5-column NumPy array to .mat choice file format.

    Args:
        array:     shape (n_trials, 5) — [ref, s1, s2, n_s1_chosen, n_repeats] (1-indexed)
        stim_list: list of stimulus names. If None, defaults to ['stim_01', 'stim_02', ...]
        out_path:  path to save .mat file. If None, returns the data dict only.

    Returns:
        data dict saved to out_path (or returned if out_path is None)
    """
    # infer number of stimuli from max index in array
    n_stim = int(array[:, :3].max())

    if stim_list is None:
        # generate default names: stim_01, stim_02, ...
        stim_list = [f"stim_{i+1:02d}" for i in range(n_stim)]
    elif len(stim_list) < n_stim:
        # pad with defaults if list is too short
        for i in range(len(stim_list), n_stim):
            stim_list.append(f"stim_{i+1:02d}")

    # build resp and rep dicts (0-indexed keys to match load_choices format)
    resp = {}
    rep  = {}
    for row in array:
        ref, s1, s2, n_chosen, n_total = int(row[0]), int(row[1]), int(row[2]), int(row[3]), int(row[4])
        # convert back to 0-indexed
        key = ((ref - 1, s1 - 1), (ref - 1, s2 - 1))
        resp[key] = n_chosen
        rep[key]  = n_total

    # build responses matrix (same format as write_choice_probs_to_mat)
    col_names = ['ref', 's1', 's2', 'N(D(ref,s1)>D(ref,s2))', 'N_Repeats']
    responses = array.copy()  # already in correct column order

    max_len = max(len(s) for s in stim_list)
    data = {
        'responses':         responses,
        'responses_colnames': col_names,
        'stim_list':         np.array(stim_list, dtype=f'S{max_len}'),
        'readme': (
            "Converted from 5-column NumPy array.\n"
            "Columns: ref, s1, s2, N(s1 chosen), N_repeats. All indices are 1-based."
        )
    }

    if out_path is not None:
        savemat(out_path, data)

    return data


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 convert_numpy_to_mat.py <input.npy> <output.mat> [--stims stim_list.txt]")
        sys.exit(1)

    npy_path = sys.argv[1]
    out_path = sys.argv[2]

    stim_list = None
    if '--stims' in sys.argv:
        stims_file = sys.argv[sys.argv.index('--stims') + 1]
        with open(stims_file) as f:
            stim_list = [line.strip() for line in f if line.strip()]

    array = np.load(npy_path)
    data  = numpy_to_mat(array, stim_list=stim_list, out_path=out_path)

    print(f"Saved: {out_path}")
    print(f"Stimuli ({len(data['stim_list'])}): {list(data['stim_list'][:5])}{'...' if len(data['stim_list']) > 5 else ''}")
    print(f"Trials: {len(array)}")
