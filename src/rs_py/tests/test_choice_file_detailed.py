import os
import csv
import copy
import numpy as np
import tempfile
import pytest
from scipy.io import savemat, loadmat
from collections import Counter

from src.rs_py.choices.choice_file_detailed import (generate_comparisons, process_subject_data,
                                                    standardize_comparison_keys, replace_stimuli_with_ids,
                                                    build_detailed_choice_mat)


def write_csv(path, rows, fieldnames):
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def test_process_subject_data_trial_counts():
    with tempfile.TemporaryDirectory() as tmpdir:
        csv_path = tmpdir + '/' + "test_responses.csv"

        rows = [
            {
                "ref": "A",
                "stim1": "B", "stim2": "C", "stim3": "D",
                "clicks": "['stim1','stim2','stim3']"
            },
            {
                "ref": "A",
                "stim1": "B", "stim2": "C", "stim3": "D",
                "clicks": "['stim3','stim2','stim1']"
            }
        ]

        write_csv(csv_path, rows, rows[0].keys())

        comps, stim_set = process_subject_data(str(tmpdir))

        trial_counts = Counter(c["trial"] for c in comps)
        assert trial_counts == {1: 3, 2: 3}


def test_process_subject_data_stimulus_set_is_complete():
    with tempfile.TemporaryDirectory() as tmpdir:
        csv_path = tmpdir + '/' + "test_responses.csv"

        rows = [
            {
                "ref": "X",
                "stim1": "P", "stim2": "Q", "stim3": "R",
                "clicks": "['stim1','stim2','stim3']"
            }
        ]

        write_csv(csv_path, rows, rows[0].keys())

        _, stim_set = process_subject_data(str(tmpdir))

        assert stim_set == {"X", "P", "Q", "R"}


def test_process_subject_data_reference_assignment():
    with tempfile.TemporaryDirectory() as tmpdir:
        csv_path = tmpdir + '/' + "test_responses.csv"

        rows = [
            {
                "ref": "REF",
                "stim1": "A", "stim2": "B",
                "clicks": "['stim2','stim1']"
            }
        ]

        write_csv(csv_path, rows, rows[0].keys())

        comps, _ = process_subject_data(str(tmpdir))

        for c in comps:
            assert c["s1"] == "REF"
            assert c["s3"] == "REF"


def test_generated_comparisons_from_clicks_have_correct_count():
    ref = "A"
    clicks = ["B", "C", "D", "E"]  # n = 4
    comps = generate_comparisons(ref, clicks, trial_num=1)

    # C(4, 2) = 6
    assert len(comps) == 6


def test_generated_comparisons_from_clicks_have_correct_fields():
    ref = "X"
    clicks = ["P", "Q", "R"]

    comps = generate_comparisons(ref, clicks, trial_num=7)

    for c in comps:
        assert c["trial"] == 7
        assert c["s1"] == ref
        assert c["s3"] == ref
        assert c["operator"] == ">"
        assert c["s2"] in clicks
        assert c["s4"] in clicks
        assert c["s2"] != c["s4"]


def test_generate_comparisons_unique_pairs():
    ref = "A"
    clicks = ["B", "C", "D", "E"]

    comps = generate_comparisons(ref, clicks, trial_num=1)

    seen_pairs = set()
    for c in comps:
        pair = tuple(sorted((c["s2"], c["s4"])))
        assert pair not in seen_pairs
        seen_pairs.add(pair)

    assert len(seen_pairs) == 6


def test_generate_comparisons_judgment_matches_click_order():
    ref = "A"
    clicks = ["B", "C", "D"]  # earlier click = closer

    comps = generate_comparisons(ref, clicks, trial_num=1)

    for c in comps:
        s2, s4 = c["s2"], c["s4"]
        judgment = c["judgment"]

        idx2 = clicks.index(s2)
        idx4 = clicks.index(s4)

        # judgment == 0 means s2 clicked before s4
        if idx2 < idx4:
            assert judgment == 0
        else:
            assert judgment == 1


def test_triadic_same_comparison_different_order():
    comp1 = {
        "trial": 1,
        "s1": "A",
        "s2": "D",
        "operator": ">",
        "s3": "A",
        "s4": "B",
        "judgment": 1,
    }

    comp2 = {
        "trial": 1,
        "s1": "A",
        "s2": "B",
        "operator": ">",
        "s3": "A",
        "s4": "D",
        "judgment": 0,
    }

    out1 = standardize_comparison_keys([copy.deepcopy(comp1)], "triadic")[0]
    out2 = standardize_comparison_keys([copy.deepcopy(comp2)], "triadic")[0]
    assert out1 == out2


def test_triadic_standardizing_order_of_keys_correctly_reorders_stim_pairs():
    comp = {
        "trial": 1,
        "s1": "A",
        "s2": "Z",
        "operator": ">",
        "s3": "A",
        "s4": "C",
        "judgment": 1,
    }

    standardized = standardize_comparison_keys([copy.deepcopy(comp)], "triadic")[0]

    assert standardized["s2"] == "C"
    assert standardized["s4"] == "Z"
    assert standardized["judgment"] == 0


def test_in_triadic_comparison_ref_is_always_s1_s3():
    comp = {
        "trial": 5,
        "s1": "REF",
        "s2": "B",
        "operator": ">",
        "s3": "REF",
        "s4": "C",
        "judgment": 0,
    }

    standardized = standardize_comparison_keys([copy.deepcopy(comp)], "triadic")[0]

    assert standardized["s1"] == "REF"
    assert standardized["s3"] == "REF"


def test_two_comparisons_with_same_stimulus_pairs_standardized_to_common_format():
    comp1 = {
        "trial": 1,
        "s1": "k",
        "s2": "l",
        "operator": ">",
        "s3": "h",
        "s4": "w",
        "judgment": 1,
    }

    comp2 = {
        "trial": 1,
        "s1": "h",
        "s2": "w",
        "operator": ">",
        "s3": "k",
        "s4": "l",
        "judgment": 0,
    }

    out1 = standardize_comparison_keys([copy.deepcopy(comp1)], "tetradic")[0]
    out2 = standardize_comparison_keys([copy.deepcopy(comp2)], "tetradic")[0]
    assert out1 == out2


def test_standardizing_orders_keys_correctly_within_stim_pairs():
    comp = {
        "trial": 1,
        "s1": "l",
        "s2": "k",
        "operator": ">",
        "s3": "w",
        "s4": "h",
        "judgment": 1,
    }

    standardized = standardize_comparison_keys([copy.deepcopy(comp)], "tetradic")[0]

    assert standardized["s1"] == "h"
    assert standardized["s2"] == "w"
    assert standardized["s3"] == "k"
    assert standardized["s4"] == "l"


def test_standardizing_order_of_keys_correctly_does_not_flip_order_of_stim_pairs():
    comp = {
        "trial": 1,
        "s1": "z",
        "s2": "a",
        "operator": ">",
        "s3": "b",
        "s4": "c",
        "judgment": 1,
    }

    standardized = standardize_comparison_keys([copy.deepcopy(comp)], "tetradic")[0]

    assert standardized["s1"] == "a"
    assert standardized["s2"] == "z"
    assert standardized["s3"] == "b"
    assert standardized["s4"] == "c"
    assert standardized["judgment"] == 1


def test_standardizing_order_of_keys_correctly_reorders_stim_pairs():
    comp = {
        "trial": 1,
        "s1": "z",
        "s2": "k",
        "operator": ">",
        "s3": "b",
        "s4": "c",
        "judgment": 1,
    }

    standardized = standardize_comparison_keys([copy.deepcopy(comp)], "tetradic")[0]

    assert standardized["s1"] == "b"
    assert standardized["s2"] == "c"
    assert standardized["s3"] == "k"
    assert standardized["s4"] == "z"
    assert standardized["judgment"] == 0


def test_invalid_comparison_type_raises_error():
    with pytest.raises(ValueError):
        standardize_comparison_keys([], comparison_type="invalid")


def test_stim_to_id_mapping_is_correct_for_a_single_trial():
    comparisons = [
        {
            "trial": 1,
            "s1": "A",
            "s2": "B",
            "s3": "A",
            "s4": "C",
            "judgment": 0,
        }
    ]

    stimuli_set = {"A", "B", "C"}

    out, id_to_name = replace_stimuli_with_ids(comparisons, stimuli_set)

    assert out[0]["s1"] == 1
    assert out[0]["s2"] == 2
    assert out[0]["s3"] == 1
    assert out[0]["s4"] == 3


def test_stim_id_assignment_is_alphabetical():
    comparisons = [
        {"s1": "Z", "s2": "A", "s3": "Z", "s4": "M", "judgment": 1}
    ]
    stimuli_set = {"Z", "A", "M"}

    out, id_to_stim = replace_stimuli_with_ids(comparisons, stimuli_set)

    # Alphabetical: A=1, M=2, Z=3
    assert out[0]["s1"] == 3
    assert out[0]["s3"] == 3
    assert out[0]["s2"] == 1
    assert out[0]["s4"] == 2


def test_judgment_unchanged_by_replacing_stim_by_ids():
    comparisons = [
        {
            "trial": 5,
            "s1": "A",
            "s2": "B",
            "s3": "A",
            "s4": "C",
            "judgment": 1,
        }
    ]

    stimuli_set = {"A", "B", "C"}

    out, id_to_stim = replace_stimuli_with_ids(comparisons, stimuli_set)
    assert out[0]["judgment"] == 1
    assert out[0]["trial"] == 5


def test_stimuli_in_multiple_comparisons_are_consistently_mapped_to_same_id():
    comparisons = [
        {"s1": "A", "s2": "B", "s3": "A", "s4": "C", "judgment": 0},
        {"s1": "C", "s2": "A", "s3": "C", "s4": "B", "judgment": 1},
    ]

    stimuli_set = {"A", "B", "C"}

    out, id_to_stim = replace_stimuli_with_ids(comparisons, stimuli_set)

    assert out[0]["s1"] == out[1]["s2"]  # A -> same ID everywhere
    assert out[0]["s4"] == out[1]["s1"]  # C -> same ID everywhere


def test_missing_stimulus_raises_keyerror_when_calling_replace_stim_with_ids():
    comparisons = [
        {"s1": "A", "s2": "B", "s3": "A", "s4": "D", "judgment": 0}
    ]
    stimuli_set = {"A", "B", "C"}  # D missing

    with pytest.raises(KeyError):
        replace_stimuli_with_ids(comparisons, stimuli_set)


def test_build_detailed_choice_mat_triadic():
    with tempfile.TemporaryDirectory() as input_dir, tempfile.TemporaryDirectory() as output_dir:
        rows = [{
            "ref": "A",
            "stim1": "B",
            "stim2": "C",
            "stim3": "D",
            "clicks": "['stim2', 'stim1', 'stim3']",
        }]
        write_csv(os.path.join(input_dir, "session_responses.csv"), rows, rows[0].keys())
        build_detailed_choice_mat(
            input_dir, output_dir, "texture", "AJ", {"judgment_type": "triadic"}
        )

        output_path = os.path.join(output_dir, "texture_detailed_choices_AJ.mat")
        result = loadmat(output_path, squeeze_me=True, struct_as_record=False)
        assert "metadata" in result
        assert "stim_list" in result
        assert "responses_colnames" in result
        assert "responses" in result
        assert list(result["stim_list"]) == ["A", "B", "C", "D"]
        assert not hasattr(result["metadata"], "stim_list")
        assert [name.strip() for name in result["responses_colnames"]] == [
            "trial", "ref", "s1", "s2", "N(D(ref, s1) > D(ref, s2))"
        ]

        responses = np.atleast_2d(result["responses"])
        observed_judgments = {
            (result["stim_list"][int(row[2]) - 1], result["stim_list"][int(row[3]) - 1]): int(row[4])
            for row in responses
        }
        assert observed_judgments == {("B", "C"): 1, ("B", "D"): 0, ("C", "D"): 0}


def test_repeated_or_missing_trials_tabulated_and_metadata_is_correct():
    with tempfile.TemporaryDirectory() as input_dir, tempfile.TemporaryDirectory() as output_dir:
        session_1_rows = [
            {"ref": "A", "stim1": "B", "stim2": "C", "clicks": "['stim1', 'stim2']"},
            {"ref": "A", "stim1": "B", "stim2": "C", "clicks": "['stim1', 'stim2']"},
        ]
        session_2_rows = [
            {"ref": "D", "stim1": "B", "stim2": "C", "clicks": "['stim2', 'stim1']"},
        ]
        write_csv(os.path.join(input_dir, "session_1_responses.csv"), session_1_rows, session_1_rows[0].keys())
        write_csv(os.path.join(input_dir, "session_2_responses.csv"), session_2_rows, session_2_rows[0].keys())

        build_detailed_choice_mat(
            input_dir, output_dir, "texture", "AJ",
            {"judgment_type": "triadic", "num_trials": 100, "num_sessions": 10},
        )
        output_path = os.path.join(output_dir, "texture_detailed_choices_AJ.mat")
        result = loadmat(output_path, squeeze_me=True, struct_as_record=False)
        responses = np.atleast_2d(result["responses"])
        assert list(responses[:, 0]) == [1, 2, 3]
        np.testing.assert_array_equal(responses[0, 1:], responses[1, 1:])
        assert result["metadata"].num_trials == 3
        assert result["metadata"].num_sessions == 2
        assert result["metadata"].total_judgments == responses.shape[0]


def test_tetradic_format_detailed_choice_mat_has_correct_fieldnames_and_size():
    with tempfile.TemporaryDirectory() as input_dir, tempfile.TemporaryDirectory() as output_dir:
        rows = [{
            "ref": "A",
            "stim1": "B",
            "stim2": "C",
            "stim3": "D",
            "clicks": "['stim2', 'stim1', 'stim3']",
        }]
        write_csv(os.path.join(input_dir, "session_responses.csv"), rows, rows[0].keys())
        build_detailed_choice_mat(
            input_dir, output_dir, "texture", "AJ", {"judgment_type": "tetradic"}
        )
        output_path = os.path.join(output_dir, "texture_detailed_choices_AJ.mat")
        result = loadmat(output_path, squeeze_me=True, struct_as_record=False)
        assert [name.strip() for name in result["responses_colnames"]] == [
            "trial", "s1", "s2", "s3", "s4", "N(D(s1, s2) > D(s3, s4))"
        ]
        assert np.atleast_2d(result["responses"]).shape == (3, 6)


def test_bad_input_files_raise_errors():
    with tempfile.TemporaryDirectory() as input_dir:
        with pytest.raises(ValueError):
            process_subject_data(input_dir)

    with tempfile.TemporaryDirectory() as input_dir:
        rows = [{"ref": "A", "stim1": "B", "stim2": "C", "clicks": "stim1,stim2"}]
        write_csv(os.path.join(input_dir, "bad_responses.csv"), rows, rows[0].keys())
        with pytest.raises(ValueError):
            process_subject_data(input_dir)

    with tempfile.TemporaryDirectory() as input_dir:
        rows = [{"stim1": "B", "stim2": "C", "clicks": "['stim1', 'stim2']"}]
        write_csv(os.path.join(input_dir, "bad_responses.csv"), rows, rows[0].keys())
        with pytest.raises(KeyError):
            process_subject_data(input_dir)


def test_multiple_trials_with_overlapping_triadic_comparison():
    """
    Two trials share the same triadic comparison (A,B vs A,C) but appear
    under different click orders. After standardization, both should map
    to the same canonical representation, differing only by trial index.
    """
    with tempfile.TemporaryDirectory() as tmpdir:
        # ---------- Create CSV with 2 trials, 3 stimuli ----------
        csv_path = os.path.join(tmpdir, "test_responses.csv")

        rows = [
            # Trial 1: B clicked before C
            {
                "ref": "A",
                "stim1": "B",
                "stim2": "C",
                "stim3": "D",
                "clicks": "['stim1','stim2','stim3']"
            },
            # Trial 2: same stimuli, different order
            {
                "ref": "A",
                "stim1": "B",
                "stim2": "C",
                "stim3": "D",
                "clicks": "['stim2','stim1','stim3']"
            }
        ]

        write_csv(csv_path, rows, rows[0].keys())

        # ---------- Run pipeline ----------
        pairwise, stim_set = process_subject_data(tmpdir)

        with_ids, _id = replace_stimuli_with_ids(pairwise, stim_set)

        standardized = standardize_comparison_keys(
            with_ids, comparison_type="triadic"
        )

        total = len(standardized)
        assert total == 6  # 2 trials × C(3,2)=3

        # ---------- Populate responses ----------
        responses_col_names = [
            'trial',
            's1',
            's2',
            's3',
            's4',
            'N(D(s1, s2) > D(s3, s4))'
        ]

        responses = np.zeros((total, len(responses_col_names)), dtype=int)

        for i, c in enumerate(standardized):
            responses[i, 0] = c['trial']
            responses[i, 1] = c['s1']
            responses[i, 2] = c['s2']
            responses[i, 3] = c['s3']
            responses[i, 4] = c['s4']
            responses[i, 5] = c['judgment']

        # ---------- Find overlapping triadic comparison ----------
        # Canonical triadic key: (s1, s2, s3, s4)
        keys = [
            (r[1], r[2], r[3], r[4])
            for r in responses
        ]

        # Count occurrences ignoring trial index
        from collections import Counter
        key_counts = Counter(keys)

        # There must be at least one triadic comparison shared across trials
        shared = [k for k, v in key_counts.items() if v == 2]
        assert len(shared) >= 1

        # That shared comparison should appear once per trial
        shared_key = shared[0]

        rows_for_key = [
            r for r in responses
            if (r[1], r[2], r[3], r[4]) == shared_key
        ]

        trials = {int(r[0]) for r in rows_for_key}
        assert trials == {1, 2}

        # ---------- Save to .mat ----------
        stimulus_list_sorted = sorted(list(stim_set))
        stim_ids = list(range(1, len(stimulus_list_sorted) + 1))

        results = {
            'metadata': {
                'stimulus_list': np.array(stimulus_list_sorted, dtype=object),
                'stim_ids': np.array(stim_ids, dtype=int),
                'paradigm': 'test',
                'sessions': 1,
                'subject': 'subj',
                'total_trials': 2,
                'total_comparisons': total,
                'comparison_type': 'triadic',
            },
            'response_colnames': np.array(responses_col_names, dtype=object),
            'responses': responses,
        }

        mat_path = os.path.join(tmpdir, "overlap_test.mat")
        savemat(mat_path, results)

        # ---------- Reload and sanity check ----------
        loaded = loadmat(mat_path, squeeze_me=True, struct_as_record=False)

        loaded_responses = loaded['responses']
        assert loaded_responses.shape == responses.shape

        # Confirm overlap survived serialization
        loaded_keys = [
            (int(r[1]), int(r[2]), int(r[3]), int(r[4]))
            for r in loaded_responses
        ]
        loaded_counts = Counter(loaded_keys)

        assert any(v == 2 for v in loaded_counts.values())


if __name__ == '__main__':
    pytest.main()
