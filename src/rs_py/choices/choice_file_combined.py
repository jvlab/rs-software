"""
    Aggregate trial-level comparison judgments into a consolidated choice file.

    This script is the downstream aggregation step following
    `rs_detailed_choice.py`, which produces trial-level triadic (or tetradic)
    distance comparisons from ranking experiment click-order data. Unlike the
    preceding utilities, which emit one row per comparison per trial, this module
    collapses across trials to produce a summary of unique comparisons.

    The script:
      1. Takes as input a detailed choices file in which the same comparison
         (defined by two pairs of stimulus IDs) may appear multiple times.
      2. Groups comparisons that are identical under canonicalization
         (standardized stimulus ordering).
      3. Tallies how many times each unique comparison appears, stored in a new
         column `N(comparisons)`.
      4. Sums judgments across occurrences of each comparison, yielding the total
         number of times the first stimulus pair was judged more dissimilar than
         the second.
      5. Drops all trial-level information; the `trial` field is not retained.

    The resulting file is intended for downstream modeling and inference methods
    that operate on aggregated choice counts rather than individual trials, such as
    distance-based embedding and psychophysical scaling approaches
    (e.g., Waraich and Victor, 2022; 2024).

    Notes
    -----
    - Assumes comparisons have already been standardized and, if applicable,
      stimulus labels replaced with numeric IDs.
"""

import os
import numpy as np
from scipy.io import savemat, loadmat


def build_combine_choice_mat_triadic_format(input_mat_path, output_dir, exp_name, subject):
    """
        Combine judgments across repeated traidic or tetradic comparisons across all trials
    """
    data = loadmat(input_mat_path, squeeze_me=True)

    responses = data['responses']
    colnames = [name.strip() for name in data['response_colnames']]
    metadata = data['metadata']

    COL_REF = colnames.index("ref")
    COL_S1 = colnames.index("s1")
    COL_S2 = colnames.index("s2")
    COL_JUDGMENT = colnames.index("N(D(ref, s1) > D(ref, s2))")

    aggregated_responses = {}
    comparison_repeats = {}

    for row in responses:
        key = (
            int(row[COL_REF]),
            int(row[COL_S1]),
            int(row[COL_S2])
        )
        if key not in aggregated_responses:
            aggregated_responses[key] = row[COL_JUDGMENT]
            comparison_repeats[key] = 1
        else:
            aggregated_responses[key] += row[COL_JUDGMENT]
            comparison_repeats[key] += 1

    comb_response_colnames = ['ref', 's1', 's2', 'N(D(ref, s1) > D(ref, s2))', 'N_Repeats(D(ref, s1) > D(ref, s2))']
    col_ref = 0
    col_s1 = 1
    col_s2 = 2
    col_judgment = 3
    col_count = 4

    comb_responses = np.zeros((len(comparison_repeats), len(comb_response_colnames)), dtype=int)
    i = 0
    for key in aggregated_responses:
        comb_responses[i, col_ref] = key[0]
        comb_responses[i, col_s1] = key[1]
        comb_responses[i, col_s2] = key[2]
        comb_responses[i, col_judgment] = aggregated_responses[key]
        comb_responses[i, col_count] = comparison_repeats[key]
        i += 1

    combined_choices = {
        'metadata': metadata,
        'response_colnames': comb_response_colnames,
        'responses': comb_responses
    }
    output_path = os.path.join(output_dir, f"{exp_name}_combined_choices_{subject}.mat")
    savemat(output_path, combined_choices)
    print(f"Saved results to {output_path}")


def build_combine_choice_mat(input_mat_path, output_dir, exp_name, subject, from_triadic=False):
    """
        Combine judgments across repeated traidic or tetradic comparisons across all trials
    """
    data = loadmat(input_mat_path, squeeze_me=True)

    responses = data['responses']
    colnames = [name.strip() for name in data['response_colnames']]
    metadata = data['metadata']

    COL_S1 = colnames.index("s1")
    COL_S2 = colnames.index("s2")
    COL_S3 = colnames.index("s3")
    COL_S4 = colnames.index("s4")
    COL_JUDGMENT = colnames.index("N(D(s1, s2) > D(s3, s4))")

    aggregated_responses = {}
    comparison_repeats = {}

    for row in responses:
        key = (
            int(row[COL_S1]),
            int(row[COL_S2]),
            int(row[COL_S3]),
            int(row[COL_S4])
        )
        if key not in aggregated_responses:
            aggregated_responses[key] = row[COL_JUDGMENT]
            comparison_repeats[key] = 1
        else:
            aggregated_responses[key] += row[COL_JUDGMENT]
            comparison_repeats[key] += 1

    comb_response_colnames = ['s1', 's2', 's3', 's4', 'N(D(s1, s2) > D(s3, s4))', 'N_Repeats(D(s1, s2) > D(s3, s4))']
    COL_S1 = 0
    COL_S2 = 1
    COL_S3 = 2
    COL_S4 = 3
    COL_JUDGMENT = 4
    COL_COUNT = 5

    comb_responses = np.zeros((len(comparison_repeats), len(comb_response_colnames)), dtype=int)
    i = 0
    for key in aggregated_responses:
        comb_responses[i, COL_S1] = key[0]
        comb_responses[i, COL_S2] = key[1]
        comb_responses[i, COL_S3] = key[2]
        comb_responses[i, COL_S4] = key[3]
        comb_responses[i, COL_JUDGMENT] = aggregated_responses[key]
        comb_responses[i, COL_COUNT] = comparison_repeats[key]
        i += 1

    combined_choices = {
        'metadata': metadata,
        'response_colnames': comb_response_colnames,
        'responses': comb_responses
    }
    output_path = os.path.join(output_dir, f"{exp_name}_combined_choices_{subject}.mat")
    savemat(output_path, combined_choices)
    print(f"Saved results to {output_path}")

# use
# if __name__ == '__main__':
#     rs_template
#     aux = kwargs in python.
#     if user passes in a small dict, fill in defaults
#     based on a setup file. different from matlab python file.
#     aux_default_define
#     creates a mat file.
