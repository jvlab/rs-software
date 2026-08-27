"""
verify_triadic_matches_ooo.py — checks that a converted triadic .mat file actually
agrees with the raw OOO file it was converted from.

For every (ref, stimA, stimB) pair (stimA < stimB by raw index), independently
computes from the raw judgments: how many times was stimA judged farther from
ref than stimB, and how many total trials of that comparison occurred. Then
reads the same two numbers back out of the triadic file (regardless of which
column it stored stimA/stimB in) and checks they match exactly.

Usage:
    python3 verify_triadic_matches_ooo.py <raw_ooo.mat> <converted_triadic.mat>
"""

import sys
from collections import defaultdict
from scipy.io import loadmat


def expected_from_raw(raw_path):
    """key = (ref, lo, hi) with lo < hi (raw indices). value = (times lo was
    judged farther than hi, total trials of that comparison)."""
    raw = loadmat(raw_path)
    stims = [s.strip() for s in raw['stim_list']]

    farther_count = defaultdict(int)
    total = defaultdict(int)

    for row in raw['responses']:
        s1, s2, s3 = int(row[0]) - 1, int(row[1]) - 1, int(row[2]) - 1
        n1, n2, n3 = int(row[3]), int(row[4]), int(row[5])
        for odd, near1, near2, n_odd in [(s1, s2, s3, n1), (s2, s1, s3, n2), (s3, s1, s2, n3)]:
            if n_odd == 0:
                continue
            # dist(near1,odd) > dist(near1,near2) : from near1, odd is farther than near2
            # dist(near2,odd) > dist(near2,near1) : from near2, odd is farther than near1
            for ref, farther, closer in [(near1, odd, near2), (near2, odd, near1)]:
                lo, hi = min(farther, closer), max(farther, closer)
                key = (ref, lo, hi)
                total[key] += n_odd
                if farther == lo:
                    farther_count[key] += n_odd
                # else farther == hi, so lo was NOT farther this time -> add 0 (default)

    return farther_count, total, stims


def actual_from_file(triadic_path, raw_stims):
    """Same key format, read from the triadic output file. Remaps file's own
    stimulus indices to raw_stims' indices by name, in case ordering differs."""
    d = loadmat(triadic_path)
    file_stims = [s.strip() for s in d['stim_list']]
    to_raw_idx = [raw_stims.index(name) for name in file_stims]

    farther_count = defaultdict(int)
    total = defaultdict(int)

    for row in d['responses']:
        ref_f, s1_f, s2_f, count, reps = int(row[0]) - 1, int(row[1]) - 1, int(row[2]) - 1, int(row[3]), int(row[4])
        ref, s1, s2 = to_raw_idx[ref_f], to_raw_idx[s1_f], to_raw_idx[s2_f]
        lo, hi = min(s1, s2), max(s1, s2)
        key = (ref, lo, hi)
        total[key] += reps
        # count = number of times s1 was judged farther than s2
        lo_was_farther_count = count if s1 == lo else (reps - count)
        farther_count[key] += lo_was_farther_count

    return farther_count, total


def check(raw_path, triadic_path):
    exp_farther, exp_total, raw_stims = expected_from_raw(raw_path)
    act_farther, act_total = actual_from_file(triadic_path, raw_stims)

    mismatches = []
    for key, exp_f in exp_farther.items():
        exp_t = exp_total[key]
        act_f = act_farther.get(key, None)
        act_t = act_total.get(key, None)
        if act_f is None:
            mismatches.append((key, 'MISSING FROM FILE'))
        elif act_f != exp_f or act_t != exp_t:
            mismatches.append((key, f'expected farther={exp_f}/{exp_t}', f'got farther={act_f}/{act_t}'))

    return len(exp_farther), mismatches, raw_stims


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 verify_triadic_matches_ooo.py <raw_ooo.mat> <converted_triadic.mat>")
        sys.exit(1)

    total_keys, mismatches, stims = check(sys.argv[1], sys.argv[2])
    print(f"Checked {total_keys} independently-derived (ref, pair) facts against the triadic file.")
    print(f"Mismatches: {len(mismatches)}")
    if mismatches:
        print("FAIL -- triadic output does not match raw judgments. First 5 mismatches:")
        for (ref, lo, hi), *rest in mismatches[:5]:
            print(f"  ref={stims[ref]} pair=({stims[lo]},{stims[hi]})", *rest)
    else:
        print("PASS -- every fact independently derived from raw judgments matches the triadic file exactly.")
