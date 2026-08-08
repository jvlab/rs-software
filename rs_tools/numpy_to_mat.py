"""
numpy_to_mat — Convert a 5-column NumPy array back to a .mat triadic choice file.

Expected input columns (1-indexed):
    0: ref          — reference stimulus index
    1: s1           — stimulus 1 index
    2: s2           — stimulus 2 index
    3: N(s1 chosen) — times s1 was chosen
    4: N_repeats    — total trials

Stimulus names are optional — defaults to stim_01, stim_02, ... if not provided.
"""

import numpy as np
from scipy.io import savemat


def numpy_to_mat(array, stim_list=None, out_path=None):
    """
    Convert a 5-column NumPy array to .mat triadic choice format.

    Args:
        array:     shape (n_trials, 5) — [ref, s1, s2, n_s1_chosen, n_repeats] (1-indexed)
        stim_list: list of stimulus names (optional — auto-generated if None)
        out_path:  path to save .mat file (optional — returns dict if None)

    Returns:
        data dict (also saved to out_path if provided)
    """
    n_stim = int(array[:, :3].max())

    if stim_list is None:
        stim_list = [f"stim_{i+1:02d}" for i in range(n_stim)]
    elif len(stim_list) < n_stim:
        for i in range(len(stim_list), n_stim):
            stim_list.append(f"stim_{i+1:02d}")

    max_len = max(len(s) for s in stim_list)
    data = {
        'responses':          array.copy(),
        'responses_colnames': ['ref', 's1', 's2', 'N(D(ref,s1)>D(ref,s2))', 'N_Repeats'],
        'stim_list':          np.array(stim_list, dtype=f'S{max_len}'),
        'readme': (
            "Converted from 5-column NumPy array.\n"
            "Columns: ref, s1, s2, N(s1 chosen), N_repeats. All indices are 1-based."
        )
    }

    if out_path is not None:
        savemat(out_path, data)
        print(f"Saved: {out_path}  ({len(array)} trials, {n_stim} stimuli)")

    return data
