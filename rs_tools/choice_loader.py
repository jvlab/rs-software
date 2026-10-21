"""
choice_loader -- read a choice .mat file (triadic or tetradic) into the dictionary form the
filtering tool works on.

load_choices(path) returns (responses, repeats, metadata, stim_list):
    responses: {trial_key: times the first pair was judged more different}
    repeats:   {trial_key: times the trial was shown}
    trial_key: ((a, b), (c, d)) -- a pair of pairs, 0-based stimulus indices. A triadic
               trial is ((ref, s1), (ref, s2)); a tetradic trial is ((s1, s2), (s3, s4)).

Handles both file layouts: "original" files (stim_list, responses_colnames, responses) and
"combined" files that carry a metadata variable. These functions are copies of the ones in
src/rs_py/utils/util.py (rs-software's streamlit-ui branch), kept here so the filtering tool
does not depend on that file.
"""

import re

from scipy.io import loadmat


def matlab_stim_list_to_pylist(stim_list):
    # turn the nested MATLAB-loaded object into one string
    s = str(stim_list[0][0])
    # extract the quoted stimulus names
    items = re.findall(r"'([^']*)'", s)
    # strip padding
    return [x.strip() for x in items]


def read_original_choices(filepath):
    """
    Load an original (non-suniyya) .mat file.
    Format: stim_list, responses_colnames, responses (N x 5 matrix).
    Columns: ref, s1, s2, N(D(ref,s1)>D(ref,s2)), N_Repeats(...)
    """
    matfile = loadmat(filepath)
    stim_list = [s.strip() for s in matfile['stim_list'].ravel()]
    colnames = [str(x).strip() for x in matfile['responses_colnames'].ravel()]
    col_idx = {name: i for i, name in enumerate(colnames)}

    responses_mat = matfile['responses']
    pairwise_responses = {}
    pairwise_num_repeats = {}

    ref_col = next((c for c in col_idx if c.startswith('ref')), None)
    s1_col  = next((c for c in col_idx if c.startswith('s1')), None)
    s2_col  = next((c for c in col_idx if c.startswith('s2')), None)
    n_col   = next((c for c in col_idx if c.startswith('N(D')), None)
    nr_col  = next((c for c in col_idx if c.startswith('N_Repeats')), None)

    s3_col = next((c for c in col_idx if c == 's3'), None)
    s4_col = next((c for c in col_idx if c == 's4'), None)

    for row in responses_mat:
        count   = int(row[col_idx[n_col]])
        repeats = int(row[col_idx[nr_col]])
        if ref_col is not None:
            # triadic format: ref, s1, s2
            ref = int(row[col_idx[ref_col]]) - 1
            s1  = int(row[col_idx[s1_col]])  - 1
            s2  = int(row[col_idx[s2_col]])  - 1
            key = ((ref, s1), (ref, s2))
        else:
            # 4-stimulus format: s1, s2, s3, s4
            s1 = int(row[col_idx[s1_col]]) - 1
            s2 = int(row[col_idx[s2_col]]) - 1
            s3 = int(row[col_idx[s3_col]]) - 1
            s4 = int(row[col_idx[s4_col]]) - 1
            key = ((s1, s2), (s3, s4))
        if key not in pairwise_responses:
            pairwise_responses[key] = count
            pairwise_num_repeats[key] = repeats
        else:
            pairwise_responses[key] += count
            pairwise_num_repeats[key] += repeats

    metadata = {'stim_list': stim_list}
    return pairwise_responses, pairwise_num_repeats, metadata, stim_list


def load_choices(filepath):
    """
    Universal loader — auto-detects suniyya vs original .mat format.
    Returns (responses, repeats, metadata, stim_list).
    """
    matfile = loadmat(filepath)
    if 'metadata' in matfile:
        return read_combined_choices(filepath)
    else:
        return read_original_choices(filepath)


def read_combined_choices(filepath):
    # input path to combined choice file
    matfile = loadmat(filepath)
    responses = matfile["responses"]
    metadata = matfile["metadata"]
    stim_list = matlab_stim_list_to_pylist(metadata['stim_list'])

    colnames = [str(x).strip() for x in matfile["response_colnames"].ravel()]
    col_idx = {name: i for i, name in enumerate(colnames)}

    pairwise_responses = {}
    pairwise_num_repeats = {}

    for row in responses:
        if "ref" in col_idx:
            ref = int(row[col_idx["ref"]])
            s1 = int(row[col_idx["s1"]])
            s2 = int(row[col_idx["s2"]])
            key = ((ref - 1, s1 - 1), (ref - 1, s2 - 1))
            count = int(row[col_idx["N(D(ref, s1) > D(ref, s2))"]])
            repeats = int(row[col_idx["N_Repeats(D(ref, s1) > D(ref, s2))"]])

        else:
            s1 = int(row[col_idx["s1"]])
            s2 = int(row[col_idx["s2"]])
            s3 = int(row[col_idx["s3"]])
            s4 = int(row[col_idx["s4"]])
            key = ((s1 - 1, s2 - 1), (s3 - 1, s4 - 1))
            count = int(row[col_idx["N(D(s1, s2) > D(s3, s4))"]])
            repeats = int(row[col_idx["N_Repeats(D(s1, s2) > D(s3, s4))"]])

        if key not in pairwise_responses:
            pairwise_responses[key] = count
            pairwise_num_repeats[key] = repeats
        else:
            pairwise_responses[key] += count
            pairwise_num_repeats[key] += repeats

    return pairwise_responses, pairwise_num_repeats, metadata, stim_list
