"""
Some utilities to help with processing psychophysical data files
"""

import json
import numpy as np
from itertools import combinations

from scipy.io import loadmat

from src.rs_py.utils.helpers import stimulus_name_to_id


def all_distance_pairs(trial_key):
    trial = trial_key.split(':')
    ref = trial[0]
    pairs = list(combinations(trial[1].split('.'), 2))

    def helper(x):
        return '{},{}<{},{}'.format(ref, x[0], ref, x[1])

    return list(map(helper, pairs))


def ranking_to_pairwise_comparisons(distance_pairs, ranked_stimuli):
    # TODO
    # may need to refactor or delete entirely
    """ Convert ranking data to comparisons of pairs of pairs of stimuli

    @param distance_pairs:
    :type distance_pairs: list
    :param ranked_stimuli:
    :type ranked_stimuli: list
    """
    # ranked_stimuli is a list of lists. each list is a 'repeat'
    rank = {}
    comparisons = {}
    num_repeats = {}
    for stimulus_list in ranked_stimuli:
        for index in range(len(stimulus_list)):
            rank[stimulus_list[index]] = index
        for pair in distance_pairs:
            dists = pair.split('<')
            stim1 = dists[0].split(',')[1]
            stim2 = dists[1].split(',')[1]
            if pair not in comparisons:
                comparisons[pair] = 1 if rank[stim1] < rank[stim2] else 0
                num_repeats[pair] = 1
            else:
                num_repeats[pair] += 1
                if rank[stim1] < rank[stim2]:
                    comparisons[pair] += 1
    return comparisons, num_repeats


def judgments_to_arrays(judgments_dict, repeats):
    """Instead of having trials be a dictionary with keys made of tuples,
    convert judgment keys and values into numpy arrays for faster operations """
    # the indices of the stimuli for each trial's "first" pair of stimuli
    first_pair = np.array([np.array(trial[0]) for trial in judgments_dict.keys()])
    # the indices of the stimuli for each trial's "second" pair of stimuli
    second_pair = np.array([np.array(trial[-1]) for trial in judgments_dict.keys()])
    comparison_counts = np.array([v for k, v in judgments_dict.items()], dtype='float')
    comparison_repeats = np.array([repeats[k] for k, v in judgments_dict.items()], dtype='float')
    return first_pair, second_pair, comparison_counts, comparison_repeats


def read_combined_choices(filepath):
    # input path to combined choice file
    matfile = loadmat(filepath)
    responses = matfile["responses"]
    metadata = matfile["metadata"]

    pairwise_responses = {}
    pairwise_num_repeats = {}

    for row in responses:
        s1, s2, s3, s4 = int(row[0]), int(row[1]), int(row[2]), int(row[3])
        count = int(row[4])
        repeats = int(row[5])

        # subtract 1 as MATLAB 1-based indices
        key = ((s1-1, s2-1), (s3-1, s4-1))
        if key not in pairwise_responses:
            pairwise_responses[key] = count
            pairwise_num_repeats[key] = repeats
        else:
            pairwise_responses[key] += count
            pairwise_num_repeats[key] += repeats

    return pairwise_responses, pairwise_num_repeats, metadata


def json_to_pairwise_choice_probs(filepath):
    names_to_id = stimulus_name_to_id()
    with open(filepath) as file:
        ranking_responses_by_trial = json.load(file)

    # break up ranking responses into pairwise judgments
    pairwise_comparison_responses = {}
    pairwise_comparison_num_repeats = {}
    for config in ranking_responses_by_trial:
        comparisons, num_repeats = ranking_to_pairwise_comparisons(all_distance_pairs(config),
                                                                   ranking_responses_by_trial[config]
                                                                   )
        for key, count in comparisons.items():
            pairs = key.split('<')
            stim1, stim2 = pairs[1].split(',')
            stim3, stim4 = pairs[0].split(',')
            new_key = ((names_to_id[stim1], names_to_id[stim2]), (names_to_id[stim3], names_to_id[stim4]))
            if new_key not in pairwise_comparison_responses:
                pairwise_comparison_responses[new_key] = count
                pairwise_comparison_num_repeats[new_key] = num_repeats[key]
            else:
                # if the comparison is repeated in two trials (context design side-effect)
                pairwise_comparison_responses[new_key] += count
                pairwise_comparison_num_repeats[new_key] += num_repeats[key]
    return pairwise_comparison_responses, pairwise_comparison_num_repeats


#         write_choice_probs_to_mat(
#         #     '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/experiments/experiments'
#         #     '/{}_exp/subject-data/preprocessed/{}_{}_exp.json'.format(domain, subject, domain),
#         #     '/Users/suniyya/Desktop', '{}_{}_choices'.format(subject, domain), include_names=False)
