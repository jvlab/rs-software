"""
convert_mat_to_numpy.py — Convert a .mat choice or coordinates file to NumPy array(s).

Choice files -> a 5-column array:
    0: ref   — index of the reference stimulus (1-indexed)
    1: s1    — index of stimulus 1 (1-indexed)
    2: s2    — index of stimulus 2 (1-indexed)
    3: N(s1 chosen)   — number of times s1 was chosen over s2
    4: N_repeats      — total number of trials for this comparison

Coordinates files -> one (n_stimuli, dim) array per fitted dimensionality
(the 'dim1', 'dim2', ... fields written by create_coords_file / build_mat_output).

Usage:
    cd ~/Downloads/rs-software
    python3 convert_mat_to_numpy.py path/to/choices_or_coords.mat output.npy
"""

import re
import sys
import numpy as np
import scipy.io as sio
from pathlib import Path

sys.path.insert(0, '.')
from rs_tools.choice_loader import load_choices


def mat_file_kind(mat_path):
    """
    Inspect a .mat file's top-level fields to tell a choices file from a
    coordinates file, without fully parsing either.

    Returns: 'choices', 'coords', or 'unknown'
    """
    raw = sio.loadmat(mat_path)
    keys = [k for k in raw if not k.startswith('__')]
    if any(re.match(r'^dim\d+$', k) for k in keys):
        return 'coords'
    if 'responses' in keys:
        return 'choices'
    return 'unknown'


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


def _label_to_str(label):
    """One stimulus label as a clean string, whether the .mat stored it as a plain
    string, a one-element array (nested cell), or a row of characters."""
    if isinstance(label, np.ndarray):
        label = "".join(str(x) for x in label.ravel())
    return str(label).strip()


def coords_to_numpy(mat_path):
    """
    Load a .mat coordinates file (the output of a model fit) and return the
    coordinate array for each fitted dimensionality.

    Returns:
        coords_by_dim: dict {dim: array of shape (n_stimuli, dim)}, e.g. {2: ..., 3: ...}
        stim_list: list of stimulus names in index order
    """
    raw = sio.loadmat(mat_path, squeeze_me=True)

    coords_by_dim = {}
    for key, value in raw.items():
        m = re.match(r'^dim(\d+)$', key)
        if m:
            arr = np.asarray(value)
            # squeeze_me collapses a one-column dim1 to a flat vector; it is a column of
            # coordinates (one per stimulus), not a single row
            if arr.ndim < 2:
                arr = arr.reshape(-1, 1)
            coords_by_dim[int(m.group(1))] = arr

    if not coords_by_dim:
        raise ValueError(
            "No 'dimN' coordinate fields found — this doesn't look like a coordinates file."
        )

    stim_key = 'stim_labels' if 'stim_labels' in raw else 'stim_list'
    if stim_key not in raw:
        raise ValueError(
            "No stimulus name field ('stim_labels' or 'stim_list') found in this file."
        )
    stim_list = [_label_to_str(s) for s in np.atleast_1d(raw[stim_key])]

    for dim, arr in coords_by_dim.items():
        if arr.shape[0] != len(stim_list) or arr.shape[1] != dim:
            raise ValueError(
                f"'dim{dim}' has shape {arr.shape}, but a {dim}-dimensional file with "
                f"{len(stim_list)} stimuli should have shape ({len(stim_list)}, {dim})."
            )

    return coords_by_dim, stim_list


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
