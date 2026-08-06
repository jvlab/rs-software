"""
convert_ooo_to_triadic.py — Convert odd-one-out choice data to standard triadic format.

Odd-one-out paradigm: subject sees three stimuli (A, B, C) and picks the most different one.

Conversion logic (from JV, corrected Jul 27 2026):
    If X is chosen as odd one out from (X, Y, Z):
        dist(Y, X) > dist(Y, Z)  →  ref=Y, s1=Z chosen (Z closer to Y than X)
        dist(Z, X) > dist(Z, Y)  →  ref=Z, s1=Y chosen (Y closer to Z than X)

    So each individual odd-one-out judgment generates exactly two triadic choice entries.
    X never appears as a reference — it is always the losing stimulus.

    Key standardization (Suniyya's standardize_comparison_keys convention):
    For each triadic key (ref, s1, s2), the two non-ref stimuli are sorted alphabetically
    so that s1 < s2 always. If the natural assignment would put s2 first, swap s1/s2 and
    set N(s1 chosen) = 0 for that judgment instead of n_odd.

    Note: each row in the input file contains counts across multiple trials (N total per row).
    Each outcome (s1 odd, s2 odd, s3 odd) with count > 0 generates its own 2 triadic entries,
    resulting in up to 6 unique triadic keys per row.

Input .mat format (6 columns):
    s1, s2, s3              — stimulus indices (1-indexed)
    N(s1 odd out)           — times s1 was chosen as most different
    N(s2 odd out)           — times s2 was chosen as most different
    N(s3 odd out)           — times s3 was chosen as most different

Output .mat format (standard triadic choice):
    ref, s1, s2, N(s1 chosen), N_repeats

Usage:
    cd ~/Downloads/rs-software
    python3 convert_ooo_to_triadic.py path/to/ooo_choices.mat output_choices.mat
"""

import sys
import numpy as np
from scipy.io import loadmat, savemat
from collections import defaultdict


def ooo_to_triadic(ooo_path, out_path=None):
    """
    Convert an odd-one-out .mat file to standard triadic choice format.

    Returns:
        resp:      dict — {((ref, s1), (ref, s2)): n_s1_chosen}  (0-indexed, s1 < s2 alphabetically)
        rep:       dict — {((ref, s1), (ref, s2)): n_repeats}    (0-indexed)
        stim_list: list of stimulus names
    """
    d = loadmat(ooo_path)
    responses = d['responses']       # shape (n_triplets, 6)
    stim_list = list(d['stim_list'].squeeze())
    if hasattr(stim_list[0], 'item'):
        stim_list = [s.item() for s in stim_list]

    # accumulate triadic counts
    # key: ((ref, near), (ref, far)) — 0-indexed
    triadic_chosen  = defaultdict(int)
    triadic_repeats = defaultdict(int)

    for row in responses:
        s1, s2, s3 = int(row[0]) - 1, int(row[1]) - 1, int(row[2]) - 1  # convert to 0-indexed
        n1_odd, n2_odd, n3_odd = int(row[3]), int(row[4]), int(row[5])
        n_total = n1_odd + n2_odd + n3_odd

        # For each possible odd one out, apply JV's conversion:
        # If X is odd one out from (X, Y, Z):
        #   → ref=Y, s1=Z chosen (Z closer to Y than X), s2=X
        #   → ref=Z, s1=Y chosen (Y closer to Z than X), s2=X
        for odd, near1, near2, n_odd in [
            (s1, s2, s3, n1_odd),
            (s2, s1, s3, n2_odd),
            (s3, s1, s2, n3_odd),
        ]:
            if n_odd == 0:
                continue

            # entry 1: ref=near1, non-ref are near2 (chosen) and odd (not chosen)
            # Standardize: sort non-ref stimuli alphabetically (Suniyya convention).
            # If near2 is not alpha-first, swap and set chosen=0 for the new s1.
            if stim_list[near2] <= stim_list[odd]:
                key1 = ((near1, near2), (near1, odd))
                chosen1 = n_odd   # s1=near2 was chosen
            else:
                key1 = ((near1, odd), (near1, near2))
                chosen1 = 0       # s1=odd was not chosen
            triadic_chosen[key1]  += chosen1
            triadic_repeats[key1] += n_odd

            # entry 2: ref=near2, non-ref are near1 (chosen) and odd (not chosen)
            if stim_list[near1] <= stim_list[odd]:
                key2 = ((near2, near1), (near2, odd))
                chosen2 = n_odd   # s1=near1 was chosen
            else:
                key2 = ((near2, odd), (near2, near1))
                chosen2 = 0       # s1=odd was not chosen
            triadic_chosen[key2]  += chosen2
            triadic_repeats[key2] += n_odd

    resp = dict(triadic_chosen)
    rep  = dict(triadic_repeats)

    if out_path is not None:
        # build 5-column responses matrix (1-indexed for MATLAB)
        rows = []
        for (ref, s1), (_, s2) in resp.keys():
            key = ((ref, s1), (ref, s2))
            rows.append([ref + 1, s1 + 1, s2 + 1, resp[key], rep[key]])
        arr = np.array(rows, dtype=np.float64)

        max_len = max(len(s) for s in stim_list)
        data = {
            'responses':          arr,
            'responses_colnames': ['ref', 's1', 's2', 'N(s1 chosen)', 'N_repeats'],
            # s1 < s2 alphabetically (Suniyya's standardize_comparison_keys convention)
            'stim_list':          np.array(stim_list, dtype=f'S{max_len}'),
            'readme': (
                "Converted from odd-one-out format using JV conversion rule.\n"
                "Each ooo judgment generates 2 triadic entries.\n"
                "Columns: ref, s1, s2, N(s1 chosen), N_repeats. Indices are 1-based."
            )
        }
        savemat(out_path, data)
        print(f"Saved: {out_path}")
        print(f"Input triplets: {len(responses)}")
        print(f"Output triadic trials: {len(resp)}")
        print(f"Stimuli ({len(stim_list)}): {stim_list[:5]}{'...' if len(stim_list) > 5 else ''}")

    return resp, rep, stim_list


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 convert_ooo_to_triadic.py <input_ooo.mat> <output_triadic.mat>")
        sys.exit(1)

    ooo_path = sys.argv[1]
    out_path = sys.argv[2]
    ooo_to_triadic(ooo_path, out_path=out_path)
