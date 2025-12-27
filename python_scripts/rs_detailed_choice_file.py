"""
Utilities for converting ranking experiment click-order data into triadic or
tetradic distance comparisons.

This module reads response CSV files from ranking experiments, parses per-trial
click orderings relative to a reference stimulus, and generates all corresponding
pairwise distance comparisons. It provides functionality to represent pairwise comparisons in
a standardized way, replace stimulus labels with numeric IDs, and prepare data for
downstream analysis (e.g., MATLAB .mat files), following the framework of Waraich and Victor (2022).

Each row in the output (.mat) file contains information about a judgment between two pairs of stimuli,
and a trial number. It contains a matlab struct, with one field for the trial-by-trial judgments,
and one field for metadata. The metadata in turn contains information regarding the stimuli,
paradigm, number of trials, or any optional information a user may find useful to add. In our case,
(Waraich and Victor, 2024), metadata contains a list of stimuli, number of sessions,
the subject identifier, and the task.
"""

import os
import ast
import csv


def get_response_files(directory, suffix="responses", extension="csv"):
    # directory is path to exp/subject-data
    # noinspection SpellCheckingInspection
    paths = []
    for root, dirs, file_paths in os.walk(directory):
        for f in file_paths:
            if f.endswith("{}.{}".format(suffix, extension)):
                paths.append(os.path.join(root, f))
    return paths


def parse_click_sequence(row):
    """Return a list of stimuli in the order they were clicked for a trial."""
    sequence = ast.literal_eval(row['clicks'])
    return [row[stim_num] for stim_num in sequence]


def generate_comparisons(reference, clicks, trial_num):
    """
   Enumerate all pairwise triadic distance comparisons for one trial
   based on the observed click order of stimuli relative to a reference.

   Given a reference stimulus and an ordered list of non-reference stimuli
   clicked during a trial, this function generates all (n choose 2) pairwise
   comparisons between stimulus pairs (s_i, s_j), each expressed as a
   triadic comparison of the form:

       D(reference, s2) > D(reference, s4)

   For each unordered pair {s_i, s_j}:
     consider their relative order in the click sequence to determine the
     behavioral judgment, then log the comparison using a consistent
     ordering of stimulus labels (s2, s4). If the logged order differs from
     the click order, the judgment is flipped accordingly.

   Each generated comparison dictionary contains:
     - 'trial'    : the trial index for this comparison
     - 's1', 's3' : the reference stimulus (appears in both pairs)
     - 's2', 's4' : the non-reference stimuli defining the comparison
     - 'operator': the comparison operator ('>')
     - 'judgment': a binary indicator encoding the outcome of the comparison

   Parameters
   ----------
   reference : str
       Label of the reference stimulus for the trial.

   clicks : list of str
       Ordered list of non-reference stimulus labels, in the order they were
       clicked during the trial.

   trial_num : int
       Trial index to assign to all generated comparisons.

   Returns
   -------
   comparisons : list of dict
       A list of comparison dictionaries, one for each unordered stimulus
       pair, representing all triadic distance judgments for the trial.

   Notes
   -----
   - The number of generated comparisons is "n choose 2", where n = number of comparison stimuli.
   - Each unordered stimulus pair appears exactly once per trial.
   - Canonicalization of comparison keys and stimulus ID remapping are handled by downstream processing steps.
    """
    comparisons = []
    for i in range(len(clicks)):
        for j in range(i + 1, len(clicks)):
            s_i, s_j = clicks[i], clicks[j]

            if s_i < s_j:
                first = s_i  # determines how comparison will be logged d(ref, first) < d(ref, second)?
                second = s_j
                judgment = 0  # as s_i is clicked before s_j = d(ref, s_i) < d(ref, s_j)
            else:
                first = s_j  # comparison logged as d(ref, s_j) < d(ref, s_i)?
                second = s_i
                judgment = 1  # as s_j is not clicked before s_i

            comparisons.append({
                'trial': trial_num,
                's1': reference,
                's2': first,
                'operator': '>',
                's3': reference,
                's4': second,
                'judgment': judgment  # s_i clicked before s_j, i.e. was d(s1, s2) < d(s3, s4)
            })
    return comparisons


def process_subject_data(input_directory):
    """
    Read response CSV files for a single subject and, for every trial, convert the
    observed click order of stimuli into all (n choose 2) triadic distance comparisons
    relative to the reference stimulus. For example, for trials with 8 comparison stimuli,
    there will be 7*8/2 = 28 such triadic comparisons.

    This function searches recursively under `input_directory` for CSV files
    whose filenames match the response-file pattern (as defined by
    `get_response_files`). Each row of each CSV file is treated as one trial
    of a ranking experiment in which a reference stimulus is presented along
    with a set of surrounding stimuli that are clicked in order of increasing
    (or decreasing, depending on experiment design) distance from the reference.

    For each trial, the function:
      1. Parses the click order to recover the ordered list of surrounding stimuli.
      2. Generates all pairwise triadic comparisons of the form
         D(ref, s_i) > D(ref, s_j) using `generate_comparisons`.
      3. Assigns a monotonically increasing trial number across all files
         and rows, preserving row order within each file.
      4. Accumulates the set of all stimuli encountered (reference and
         non-reference).

    The function does not perform any canonicalization of comparison keys,
    stimulus ID remapping, or aggregation across trials; it is intended to
    provide a clean semantic representation of trial-level comparisons that
    downstream steps may further standardize or serialize.

    Parameters
    ----------
    input_directory : str
        Path to a directory containing one or more response CSV files for a
        single subject. The directory may contain subdirectories; all matching
        response files will be processed.

    Returns
    -------
    all_comparisons : list of dict
        A flat list of comparison dictionaries. Each dictionary corresponds
        to a single triadic comparison and contains at least the keys:
        'trial', 's1', 's2', 'operator', 's3', 's4', and 'judgment'.

    stimuli : set
        A set containing the labels of all stimuli encountered across all
        processed trials, including reference and non-reference stimuli.

    Notes
    -----
    - Trial numbering starts at 1 and increases sequentially across all files
      and rows; no session boundaries are inferred or enforced.
    - The interpretation of click order and judgment semantics is delegated
      to `generate_comparisons`.
    - CSV files are read using UTF-8 with BOM (utf-8-sig) encoding to match
      experimental data exports.
    """
    all_comparisons = []
    stimuli = set()
    trial_num = 1

    resp_files = sorted(get_response_files(input_directory))
    # open response csv files and go through line by line
    for file in resp_files:
        with open(file, newline='', encoding='utf-8-sig') as csv_file:
            reader = csv.DictReader(csv_file)
            for row in reader:
                # eval is usually not secure but here I created the files parsing
                clicked_stimuli = parse_click_sequence(row)
                comparisons = generate_comparisons(row['ref'], clicked_stimuli, trial_num)
                # keep collecting stim
                for stim in clicked_stimuli:
                    stimuli.add(stim)
                stimuli.add(row['ref'])
                all_comparisons += comparisons
                trial_num += 1
    return all_comparisons, stimuli


def standardize_comparison_keys(comparisons, comparison_type='triadic'):
    """
    Takes in a list of comparisons, edits their fields (s1, s2, s3, s4, judgment) and returns the list.
    Enforce a canonical ordering of comparison keys so that equivalent
    comparisons (same two stimulus pairs) are always represented identically.

    If (s2, s4) appears in reverse order, swap them and flip the judgment.
    This ensures downstream tallying and aggregation treat comparisons
    consistently.

    Triadic comparisons: In these cases the reference appears in both pairs of stimuli. The reference
    is chosen as the first stimulus in each pair s1=s3=ref. The choice of which pair is listed first is based
    on alphabetical order of the non-ref elements.
    example - for pairs (k, l), (c, k) -> s1=k, s2=c, s3=k, s4=l

    N/A here:
    Tetradic comparisons: The first pair is the one with the first element alphabetically. Within pairs, order
    of elements again depends on alphabetical order.
    example - for pairs (k, l), (h, w) -> s1=h, s2=w, s3=k, s4=l
    @param: comparisons list [dict]
    @return: comparisons list[dict]
    """
    if comparison_type == 'tetradic':
        for i in range(len(comparisons)):
            c = comparisons[i]

            # Extract pairs
            pair1 = (c['s1'], c['s2'])
            pair2 = (c['s3'], c['s4'])

            # Sort within each pair alphabetically
            p1_sorted = tuple(sorted(pair1))
            p2_sorted = tuple(sorted(pair2))

            # Determine which pair comes first
            if p1_sorted[0] > p2_sorted[0]:
                # Swap pairs and flip judgment
                c['s1'], c['s2'], c['s3'], c['s4'] = (
                    p2_sorted[0], p2_sorted[1],
                    p1_sorted[0], p1_sorted[1],
                )
                c['judgment'] = 1 - c['judgment']
            else:
                # Keep order, but enforce sorted-within-pair
                c['s1'], c['s2'] = p1_sorted
                c['s3'], c['s4'] = p2_sorted

            comparisons[i] = c

    elif comparison_type == 'triadic':
        for i in range(len(comparisons)):
            c = comparisons[i]
            ref1 = c['s1']
            ref2 = c['s3']
            if ref1 != ref2:
                raise ValueError("Triadic comparison must have s1 == s3")

            ref = ref1
            s2 = c['s2']
            s4 = c['s4']
            judgment = c['judgment']

            # Canonicalize ordering of the non-reference stimuli
            # If already ordered, do nothing; otherwise swap and flip judgment
            if s2 > s4:
                c['s2'], c['s4'] = s4, s2
                c['judgment'] = 1 - judgment

            # Explicitly enforce reference placement
            c['s1'] = ref
            c['s3'] = ref

            comparisons[i] = c
    else:
        raise ValueError('Only supported comparison types are triadic or tetradic.')
    return comparisons


def replace_stimuli_with_ids(comparisons, stimuli_set):
    """
    Replace stimulus labels in comparison dictionaries with integer stimulus IDs.

    This function constructs a deterministic mapping from stimulus labels to
    integer IDs based on the sorted order of `stimuli_set`. It then iterates
    over the provided list of comparison dictionaries and replaces the values
    of the stimulus fields ('s1', 's2', 's3', 's4') with their corresponding
    integer IDs.

    The function does not perform any canonicalization, reordering of stimulus
    keys, or judgment flipping. All stimulus fields are replaced directly and
    uniformly according to the generated mapping.

    Parameters
    ----------
    comparisons : list of dict
        List of comparison dictionaries. Each dictionary must contain the keys
        's1', 's2', 's3', and 's4', whose values are stimulus labels present in
        `stimuli_set`. The list is modified in place.

    stimuli_set : set
        Set of all stimulus labels to be mapped to integer IDs. IDs are assigned
        starting from 1, in alphabetical order of the labels.

    Returns
    -------
    comparisons : list of dict
        The input list of comparison dictionaries with stimulus labels replaced
        by integer stimulus IDs.

    Notes
    -----
    - The function mutates the input `comparisons` list in place.
    - Judgment values and non-stimulus fields are not modified.
    - If a comparison contains a stimulus label not present in `stimuli_set`,
      a KeyError will be raised.
    """
    stimuli = sorted(list(stimuli_set))
    names_to_id = dict(zip(stimuli, range(1, len(stimuli) + 1)))
    stim_keys = ['s1', 's2', 's3', 's4']
    for i in range(len(comparisons)):
        c = comparisons[i]
        for k in stim_keys:
            c[k] = names_to_id[c[k]]
    return comparisons


# if __name__ == '__main__':
    # TODO
    # take in args, and return outputs and args
