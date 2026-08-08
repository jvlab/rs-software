"""
mat_to_numpy — Convert a triadic choice .mat file to a 5-column NumPy array.

Output columns (1-indexed):
    0: ref          — reference stimulus index
    1: s1           — stimulus 1 index
    2: s2           — stimulus 2 index
    3: N(s1 chosen) — times s1 was chosen over s2
    4: N_repeats    — total trials for this comparison
"""

import sys
import numpy as np

sys.path.insert(0, __import__('os').path.join(__import__('os').path.dirname(__file__), '..'))
from src.rs_py.utils.util import load_choices


def mat_to_numpy(mat_path):
    """
    Load a triadic choice .mat file and return a 5-column NumPy array.

    Args:
        mat_path: path to .mat choices file

    Returns:
        array:     shape (n_trials, 5) — [ref, s1, s2, n_s1_chosen, n_repeats] (1-indexed)
        stim_list: list of stimulus names
    """
    resp, rep, metadata, stim_list = load_choices(mat_path)

    rows = []
    for (ref_s1, s1), (ref_s2, s2) in resp.keys():
        ref = ref_s1
        key = ((ref_s1, s1), (ref_s2, s2))
        rows.append([ref + 1, s1 + 1, s2 + 1, resp[key], rep[key]])

    array = np.array(rows, dtype=np.float64)
    return array, list(stim_list)
