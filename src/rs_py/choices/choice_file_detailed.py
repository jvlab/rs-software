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
import numpy as np
from scipy.io import savemat

from src.rs_py.utils.helpers import stimulus_name_to_id, stimulus_id_to_name_for_mat


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
    """
    Parse the click order for a trial into a sequence of stimulus labels.

    Given a trial row, read the stored click-order indices from `row['clicks']`
    and return the corresponding stimuli in the order they were clicked.

    Args:
        row (dict):
            A single trial row containing a `clicks` field and a list of stimuli.
            The `clicks` field must encode the clicked stimulus indices in the
            order they were selected.

    Returns:
        - sequence (list[str]) - Ordered list of stimulus labels corresponding
          to the clicked stimuli for that trial.

    Notes:
        - Assumes data are being read in from csv files created by Waraich and Victor (2022) paradigm.
    """
    sequence = ast.literal_eval(row['clicks'])
    return [row[stim_num] for stim_num in sequence]


def generate_comparisons(reference, clicks, trial_num):
    """
    Generate all pairwise triadic distance comparisons for a single trial.

    Given a reference stimulus and an ordered list of non-reference stimuli,
    generate all pairwise triadic comparisons implied by the click order.

    Args:
        reference (str):
            Label of the reference stimulus.
        clicks (list[str]):
            Ordered list of non-reference stimuli in the order they were clicked.
        trial_num (int):
            Trial index assigned to all generated comparisons.

    Returns:
        - comparisons (list[dict]) - List of comparison dictionaries, one for each unordered stimulus pair.
        Each dictionary contains:
            - trial
            - s1
            - s2
            - s3
            - s4
            - operator
            - judgment

    Notes:
        The number of generated comparisons is $n# choose 2, where $n$ is the number of comparison stimuli.
        Each unordered stimulus pair appears exactly once per trial.
        Canonicalization of comparison keys and stimulus-ID remapping are
        performed by downstream processing steps.

        See also: standardize_comparison_keys
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
        Read response CSV files for a single subject and convert each trial’s click
        order into all implied pairwise triadic distance comparisons relative to the
        reference stimulus.

        For every row in every matching response CSV file, the function parses the
        observed click order, generates all (n choose 2) comparisons among the
        comparison stimuli, and assigns trial numbers sequentially across all files
        and rows.

        Args:
            input_directory (str):
                Path to a directory containing one or more response CSV files for a
                single subject. Subdirectories are searched recursively for files
                matching the response-file pattern defined by `get_response_files`.

        Returns:
            - all_comparisons (list[dict]) - Flat list of comparison dictionaries, one
              for each generated triadic comparison.
              Each dictionary contains:
                - trial
                - s1
                - s2
                - operator
                - s3
                - s4
                - judgment
            - stimuli (set) - Labels of all stimuli encountered across all processed
              trials, including both reference and non-reference stimuli.

        Notes:
            - Trial numbering starts at 1 and increases sequentially across all files
              and rows; no session boundaries are inferred.
            - CSV files are read using UTF-8 with BOM (`utf-8-sig`) encoding to match
              experimental data exports.
            - This function does not canonicalize comparison keys, remap stimulus IDs,
              or aggregate across trials; those steps are handled downstream.
            - The interpretation of click order and judgment semantics is handled by
              `generate_comparisons`.

            See also: generate_comparisons
        """
    all_comparisons = []
    stimuli = set()
    trial_num = 1

    resp_files = sorted(get_response_files(input_directory))
    # open response csv files and go through line by line
    if len(resp_files) == 0:
        raise ValueError(
            "No comparisons generated from input directory: {}.\n"
            "Check that files exist.".format(input_directory)
        )
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
    if len(all_comparisons) == 0:
        raise ValueError(
            f"No comparisons generated from input directory: {input_directory}\n"
            "Check CSV format and make sure files aren't empty."
        )
    return all_comparisons, stimuli


def standardize_comparison_keys(comparisons, comparison_type='triadic'):
    """
    Standardize comparison field order and canonicalize comparison keys.

    Takes in a list of comparisons, edits their fields (`s1`, `s2`, `s3`, `s4`,
    `judgment`), and returns the same list with comparison keys ordered
    consistently. Equivalent comparisons are therefore represented identically,
    which supports downstream tallying and aggregation.

    Args:
        comparisons (list[dict]):
            A list of comparisons and judgments with the keys `s1`, `s2`, `s3`,
            `s4`, and `judgment`.
        comparison_type (str):
            Comparison type to standardize. `'triadic'` by default, and the only
            type implemented as of 02/17/2026.

    Returns:
        - comparisons (list[dict]) - The same list of comparisons with field
          names and comparison order standardized.
          Each dictionary contains:
            - s1
            - s2
            - s3
            - s4
            - judgment

    Notes:
        - If `(s2, s4)` appears in reverse order, the elements are swapped and
          the judgment is flipped.
        - For triadic comparisons, the reference appears in both pairs of stimuli
          and is always assigned as `s1 = s3 = ref`.
        - The ordering of the two stimulus pairs is determined by alphabetical
          order of the non-reference elements.
        - Example: for pairs `(k, l)` and `(c, k)`, the standardized form is
          `s1 = k, s2 = c, s3 = k, s4 = l`.
        - Tetradic comparisons are not yet implemented.
        - Within each pair, stimulus order is also determined alphabetically.
        - Example: for pairs `(k, l)` and `(h, w)`, the standardized form is
          `s1 = h, s2 = w, s3 = k, s4 = l`.

        See also: generate_comparisons
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

        Constructs a deterministic mapping from stimulus labels to integer IDs
        based on the sorted order of `stimuli_set`, then replaces the values of the
        stimulus fields (`s1`, `s2`, `s3`, `s4`) in each comparison dictionary with
        their corresponding integer IDs.

        Args:
            comparisons (list[dict]):
                List of comparison dictionaries. Each dictionary must contain the
                keys `s1`, `s2`, `s3`, and `s4`, whose values are stimulus labels
                present in `stimuli_set`. The list is modified in place.
            stimuli_set (set):
                Set of all stimulus labels to be mapped to integer IDs. IDs are
                assigned starting from 1, in alphabetical order of the labels.

        Returns:
            - comparisons (list[dict]) - The input list of comparison dictionaries
              with stimulus labels replaced by integer stimulus IDs.
              The mapping of IDs to stimuli is also returned or stored separately,
              depending on downstream use.

        Notes:
            - The function mutates the input `comparisons` list in place.
            - Judgment values and non-stimulus fields are not modified.
            - If a comparison contains a stimulus label not present in `stimuli_set`,
              a `KeyError` will be raised.
            - The function does not perform canonicalization, reordering of stimulus
              keys, or judgment flipping.

            See also: standardize_comparison_keys
        """
    stimuli = sorted(list(stimuli_set))
    names_to_id = stimulus_name_to_id(stimuli, one_indexed=True)
    id_to_name = stimulus_id_to_name_for_mat(stimuli)
    stim_keys = ['s1', 's2', 's3', 's4']
    for i in range(len(comparisons)):
        c = comparisons[i]
        for k in stim_keys:
            c[k] = names_to_id[c[k]]
    return comparisons, id_to_name


def build_detailed_choice_mat(input_dir, output_dir, exp_name, subject, metadata):
    # Process rank orderings to pairwise comparisons between a reference and two stimuli
    pairwise_comparisons, stimulus_set = process_subject_data(input_dir)
    # Swap stimulus names with numeric stimulus ids
    comparisons_with_stim_ids, stim_id_to_name = replace_stimuli_with_ids(pairwise_comparisons, stimulus_set)
    # Standardize the orders in which stimuli will appear, such that if two pairs are compared across different
    # trials, they are referenced with the same identifier (s1,s2,s3,s4). This imposes a standard way of ordering
    # two pairs and the stimuli within each pair. Judgments reflect whether D(s1,s2) > D(s3,s4).
    standardized_comparisons = standardize_comparison_keys(comparisons_with_stim_ids, metadata['judgment_type'])

    # Build output structure and write to a mat file in the output_dir
    total_comparisons = len(standardized_comparisons)
    responses_col_names = []
    responses = []

    if metadata['judgment_type'] == 'triadic':
        responses_col_names = ['trial', 'ref', 's1', 's2', 'N(D(ref, s1) > D(ref, s2))']
        # Column mapping for clarity
        COL_TRIAL = 0
        COL_REF = 1
        COL_S1 = 2
        COL_S2 = 3
        COL_JUDGMENT = 4

        responses = np.zeros((total_comparisons, len(responses_col_names)), dtype=int)
        for i, comp in enumerate(standardized_comparisons):
            responses[i, COL_TRIAL] = comp['trial']
            responses[i, COL_REF] = comp['s1']
            responses[i, COL_S1] = comp['s2']
            responses[i, COL_S2] = comp['s4']
            responses[i, COL_JUDGMENT] = comp['judgment']
    elif metadata['judgment_type'] == 'tetradic':
        responses_col_names = ['trial', 's1', 's2', 's3', 's4', 'N(D(s1, s2) > D(s3, s4))']
        # Column mapping for clarity
        COL_TRIAL = 0
        COL_S1 = 1
        COL_S2 = 2
        COL_S3 = 3
        COL_S4 = 4
        COL_JUDGMENT = 5

        responses = np.zeros((total_comparisons, len(responses_col_names)), dtype=int)
        for i, comp in enumerate(standardized_comparisons):
            responses[i, COL_TRIAL] = comp['trial']
            responses[i, COL_S1] = comp['s1']
            responses[i, COL_S2] = comp['s2']
            responses[i, COL_S3] = comp['s3']
            responses[i, COL_S4] = comp['s4']
            responses[i, COL_JUDGMENT] = comp['judgment']

    results = {
        'metadata': metadata,
        'responses_colnames': responses_col_names,
        'responses': responses
    }

    results['metadata']['stim_list'] = [stim_id_to_name[k] for k in stim_id_to_name.keys()]
    results['metadata']['total_judgments'] = total_comparisons

    output_path = os.path.join(output_dir, f"{exp_name}_detailed_choices_{subject}.mat")
    savemat(output_path, results)
    print(f"Saved results to {output_path}")
    return


# if __name__ == '__main__':
    # TODO
    # take in args, and return outputs and args
