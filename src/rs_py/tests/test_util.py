import json

import numpy as np
import pytest

from src.rs_py.utils import util


def test_all_distance_pairs_has_correct_num_pairs():
    trial = 'ref:1.2.3.4.5.6.7.8'
    pairs = util.all_distance_pairs(trial)

    assert isinstance(pairs, list)
    assert len(pairs) == 28


def test_ranking_to_pairwise_comparisons_has_correct_length_and_count():
    distance_pairs = [
        'ref,1<ref,2',
        'ref,1<ref,3',
        'ref,1<ref,4',
        'ref,1<ref,5',
        'ref,4<ref,3',
    ]
    # The current function expects lists of stimulus names.
    ranked_stimuli = [
        ['1', '2', '3', '4', '5', '6', '7', '8'],
        ['1', '2', '3', '5', '4', '7', '6', '8'],
        ['8', '3', '7', '6', '2', '4', '1', '5'],
    ]

    counts, repeats = util.ranking_to_pairwise_comparisons(
        distance_pairs, ranked_stimuli
    )

    assert len(counts) == len(distance_pairs)
    assert counts['ref,1<ref,2'] == 2
    assert counts['ref,1<ref,3'] == 2
    assert counts['ref,1<ref,4'] == 2
    assert counts['ref,1<ref,5'] == 3
    assert counts['ref,4<ref,3'] == 0
    assert repeats == {pair: 3 for pair in distance_pairs}


def test_json_to_pairwise_choice_probs_has_correct_values(
    tmp_path, monkeypatch
):
    ranking_data = {
        'ref:1.2.3.4.5.6.8.7': [
            ['1', '2', '4', '5', '3', '6', '7', '8'],
            ['1', '2', '3', '4', '5', '6', '7', '8'],
            ['2', '1', '3', '4', '6', '5', '7', '8'],
            ['1', '2', '3', '5', '4', '6', '7', '8'],
            ['1', '2', '3', '4', '5', '6', '7', '8'],
        ],
        'ref:12.13.14.15.16.17.18.19': [
            ['12', '13', '14', '15', '16', '17', '18', '19'],
            ['13', '12', '15', '14', '17', '19', '18', '16'],
            ['19', '18', '17', '16', '15', '14', '13', '12'],
            ['16', '17', '12', '19', '13', '18', '15', '14'],
            ['12', '14', '18', '17', '15', '19', '13', '16'],
        ],
    }

    # Explicit test mapping for the synthetic numeric stimulus names.
    # monkeypatch restores the original function after this test.
    names_to_id = {'ref': 0}
    names_to_id.update({str(i): i for i in range(1, 20)})
    monkeypatch.setattr(
        util, 'stimulus_name_to_id', lambda: names_to_id
    )

    filepath = tmp_path / 'rankings.json'
    filepath.write_text(json.dumps(ranking_data), encoding='utf-8')

    counts, repeats = util.json_to_pairwise_choice_probs(filepath)

    assert len(counts) == 2 * 28

    # "ref,13 < ref,17" becomes D(ref,17) > D(ref,13).
    key = ((0, 17), (0, 13))
    assert counts[key] == 2
    assert repeats[key] == 5
    assert counts[key] / repeats[key] == 2 / 5

    # Stimulus 7 is always ranked before stimulus 8.
    key = ((0, 7), (0, 8))
    assert counts[key] == 0
    assert repeats[key] == 5
    assert counts[key] / repeats[key] == 0


def test_judgments_to_arrays_converts_dictionary_correctly():
    original_judgments = {
        ((0, 1), '>', (12, 13)): 3,
        ((27, 30), '>', (2, 3)): 2,
        ((4, 1), '>', (9, 10)): 5,
        ((5, 9), '>', (48, 3)): 0,
    }

    # Explicit fixture: each comparison was repeated five times.
    repeats = {key: 5 for key in original_judgments}

    correct_pairs1 = np.array([
        [0, 1],
        [27, 30],
        [4, 1],
        [5, 9],
    ])
    correct_pairs2 = np.array([
        [12, 13],
        [2, 3],
        [9, 10],
        [48, 3],
    ])
    correct_counts = np.array([3, 2, 5, 0])
    correct_repeats = np.array([5, 5, 5, 5])

    pairs1, pairs2, counts, repeats_array = util.judgments_to_arrays(
        original_judgments, repeats
    )

    assert len(pairs1) == len(original_judgments)
    assert len(pairs2) == len(original_judgments)

    np.testing.assert_array_equal(pairs1, correct_pairs1)
    np.testing.assert_array_equal(pairs2, correct_pairs2)
    np.testing.assert_array_equal(counts, correct_counts)
    np.testing.assert_array_equal(repeats_array, correct_repeats)