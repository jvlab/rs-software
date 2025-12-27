"""
To demo the script rs_detailed_choice_file.py
"""

import os
import numpy as np
from scipy.io import savemat

import rs_detailed_choice_file as rs_dcf


if __name__ == '__main__':
    print('Demo in creating a detailed mat file with triadic comparisons from raw ranking data.\n '
          'Enter 0 to use default values.\n')
    input_dir = input("Path to subject-data dir of experiment: ")
    output_dir = input("Output directory: ")
    subject = input('Subject ID: ')
    paradigm = input('Name of the experimental paradigm: ')
    num_trials = input('Total number of trials in experiment: ')
    num_sessions = input('Total number of sessions in experiment: ')
    stimulus_list = input('Stimulus list (optional): ')
    type_of_judgments = input('triadic or tetradic: ')

    if input_dir == '0':
        input_dir = '../samples/unprocessed_ranking_judgments/S4'
        subject = 'S4'
    if num_trials == '0':
        num_trials = 222
    if num_sessions == '0':
        num_sessions = 10

    pairwise_comparisons, stimulus_set = rs_dcf.process_subject_data(input_dir)
    comparisons_with_stim_ids = rs_dcf.replace_stimuli_with_ids(pairwise_comparisons, stimulus_set)
    standardized_comparisons = rs_dcf.standardize_comparison_keys(comparisons_with_stim_ids, type_of_judgments)

    total_comparisons = len(standardized_comparisons)
    responses_col_names = ['trial', 's1', 's2', 's3', 's4', 'N(D(s1, s2) > D(s3, s4))']
    # Column mapping for clarity
    COL_TRIAL = 0
    COL_S1 = 1
    COL_S2 = 2
    COL_S3 = 3
    COL_S4 = 4
    COL_JUDGMENT = 5

    responses = np.zeros((total_comparisons, len(responses_col_names)), dtype=int)
    stimulus_list_sorted = sorted(list(stimulus_set))
    stim_ids = list(range(1, len(stimulus_list_sorted) + 1))

    for i, comp in enumerate(standardized_comparisons):
        responses[i, COL_TRIAL] = comp['trial']
        responses[i, COL_S1] = comp['s1']
        responses[i, COL_S2] = comp['s2']
        responses[i, COL_S3] = comp['s3']
        responses[i, COL_S4] = comp['s4']
        responses[i, COL_JUDGMENT] = comp['judgment']

    results = {
        'metadata': {
            'stimulus_list': np.array(stimulus_list_sorted, dtype=object),
            'stim_ids': np.array(stim_ids, dtype=int),
            'paradigm': paradigm,
            'sessions': int(num_sessions),
            'subject': subject,
            'total_trials': int(num_trials),
            'total_comparisons': int(total_comparisons),
            'comparison_type': type_of_judgments
        },
        'response_colnames': responses_col_names,
        'responses': responses}

    output_path = os.path.join(output_dir, f"{subject}_{paradigm}_detailed_choice.mat")
    savemat(output_path, results)
    print(f"Saved results to {output_path}")
