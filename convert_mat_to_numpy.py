"""
convert_mat_to_numpy.py — Convert a .mat choice file to a 5-column NumPy array.

Column order:
    0: ref   — index of the reference stimulus (1-indexed)
    1: s1    — index of stimulus 1 (1-indexed)
    2: s2    — index of stimulus 2 (1-indexed)
    3: N(s1 chosen)   — number of times s1 was chosen over s2
    4: N_repeats      — total number of trials for this comparison

Usage:
    cd ~/Downloads/rs-software
    python3 convert_mat_to_numpy.py path/to/choices.mat output.npy
"""

import sys
import numpy as np
from pathlib import Path

sys.path.insert(0, '.')
from src.rs_py.utils.util import load_choices


def mat_to_numpy(mat_path):
    """
    Load a .mat choice file and return a 5-column NumPy array and stimulus list.

    Returns:
        array: shape (n_trials, 5) — [ref, s1, s2, n_s1_chosen, n_repeats] (1-indexed)
        stim_list: list of stimulus names in index order
    """
    resp, rep, metadata, stim_list = load_choices(mat_path)

    rows = []
    for (ref_s1, s1), (ref_s2, s2) in resp.keys():
        # trial key format: ((ref, s1), (ref, s2)) — ref appears in both pairs
        ref = ref_s1  # same as ref_s2
        key = ((ref_s1, s1), (ref_s2, s2))
        n_chosen = resp[key]
        n_total  = rep[key]
        # store as 1-indexed to match MATLAB convention
        rows.append([ref + 1, s1 + 1, s2 + 1, n_chosen, n_total])

    array = np.array(rows, dtype=np.float64)
    return array, stim_list


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 convert_mat_to_numpy.py <input.mat> <output.npy>")
        sys.exit(1)

    mat_path = sys.argv[1]
    out_path = sys.argv[2]

    array, stim_list = mat_to_numpy(mat_path)
    np.save(out_path, array)

    print(f"Saved: {out_path}")
    print(f"Shape: {array.shape}  (rows=trials, cols=[ref, s1, s2, n_chosen, n_repeats])")
    print(f"Stimuli ({len(stim_list)}): {stim_list[:5]}{'...' if len(stim_list) > 5 else ''}")
    print(f"\nFirst 5 rows:")
    print(array[:5])
