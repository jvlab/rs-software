"""
ooo_to_triadic — Convert odd-one-out choice data to standard triadic format.

Odd-one-out paradigm: subject sees three stimuli (A, B, C) and picks the most different one.

Conversion logic (JV rule, corrected Jul 27 2026):
    If X is chosen as odd one out from (X, Y, Z):
        → ref=Y, s1=Z chosen  (Z is closer to Y than X)
        → ref=Z, s1=Y chosen  (Y is closer to Z than X)

    Each ooo judgment generates exactly 2 triadic entries.
    Non-ref stimuli are sorted alphabetically (Suniyya's standardize_comparison_keys convention).

Input .mat columns:  s1, s2, s3, N(s1 odd), N(s2 odd), N(s3 odd)
Output .mat columns: ref, s1, s2, N(s1 chosen), N_repeats
"""

import numpy as np
from scipy.io import loadmat, savemat
from collections import defaultdict


def ooo_to_triadic(ooo_path, out_path=None):
    """
    Convert an odd-one-out .mat file to standard triadic choice format.

    Args:
        ooo_path: path to input .mat file with 6-column responses
        out_path: path to save output .mat file (optional)

    Returns:
        resp:      dict {((ref, s1), (ref, s2)): n_s1_chosen}  (0-indexed)
        rep:       dict {((ref, s1), (ref, s2)): n_repeats}    (0-indexed)
        stim_list: list of stimulus names
    """
    d = loadmat(ooo_path)
    responses = d['responses']
    stim_list = list(d['stim_list'].squeeze())
    if hasattr(stim_list[0], 'item'):
        stim_list = [s.item() for s in stim_list]

    triadic_chosen  = defaultdict(int)
    triadic_repeats = defaultdict(int)

    for row in responses:
        s1, s2, s3 = int(row[0]) - 1, int(row[1]) - 1, int(row[2]) - 1
        n1_odd, n2_odd, n3_odd = int(row[3]), int(row[4]), int(row[5])

        for odd, near1, near2, n_odd in [
            (s1, s2, s3, n1_odd),
            (s2, s1, s3, n2_odd),
            (s3, s1, s2, n3_odd),
        ]:
            if n_odd == 0:
                continue

            # Column meaning is N(D(ref,s1) > D(ref,s2)) -- count goes on whichever of
            # s1/s2 is the FARTHER (odd) stimulus, not the closer one.
            if stim_list[near2] <= stim_list[odd]:
                key1 = ((near1, near2), (near1, odd))
                chosen1 = 0       # s1=near2 is the closer stimulus
            else:
                key1 = ((near1, odd), (near1, near2))
                chosen1 = n_odd   # s1=odd is the farther stimulus
            triadic_chosen[key1]  += chosen1
            triadic_repeats[key1] += n_odd

            if stim_list[near1] <= stim_list[odd]:
                key2 = ((near2, near1), (near2, odd))
                chosen2 = 0       # s1=near1 is the closer stimulus
            else:
                key2 = ((near2, odd), (near2, near1))
                chosen2 = n_odd   # s1=odd is the farther stimulus
            triadic_chosen[key2]  += chosen2
            triadic_repeats[key2] += n_odd

    resp = dict(triadic_chosen)
    rep  = dict(triadic_repeats)

    if out_path is not None:
        rows = []
        for (ref, s1), (_, s2) in resp.keys():
            key = ((ref, s1), (ref, s2))
            rows.append([ref + 1, s1 + 1, s2 + 1, resp[key], rep[key]])
        arr = np.array(rows, dtype=np.float64)
        max_len = max(len(s) for s in stim_list)
        savemat(out_path, {
            'responses':          arr,
            'responses_colnames': ['ref', 's1', 's2',
                                    'N(D(ref, s1) > D(ref, s2))',
                                    'N_Repeats(D(ref, s1) > D(ref, s2))'],
            'stim_list':          np.array(stim_list, dtype=f'S{max_len}'),
            'readme': (
                "Converted from odd-one-out format using the standard conversion rule.\n"
                "Each ooo judgment generates 2 triadic entries.\n"
                "Columns: ref, s1, s2, N(D(ref, s1) > D(ref, s2)), N_Repeats(D(ref, s1) > D(ref, s2)). "
                "Indices are 1-based."
            )
        })
        print(f"Saved: {out_path}  ({len(resp)} triadic trials, {len(stim_list)} stimuli)")

    return resp, rep, stim_list
