import os
import csv
import copy
import numpy as np
import tempfile
import unittest
from scipy.io import savemat, loadmat
from collections import Counter

from src.rs_py.choices.choice_file_detailed import (generate_comparisons, process_subject_data,
                                                    standardize_comparison_keys, replace_stimuli_with_ids)


def write_csv(path, rows, fieldnames):
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


class TestParseRawJudgmentFiles(unittest.TestCase):
    def test_process_subject_data_trial_counts(self):
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
            self.assertDictEqual(trial_counts, {1: 3, 2: 3})

    def test_process_subject_data_stimulus_set(self):
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

            self.assertSetEqual(stim_set, {"X", "P", "Q", "R"})

    def test_process_subject_data_reference_assignment(self):
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
                self.assertEqual(c["s1"], "REF")
                self.assertEqual(c["s3"], "REF")


class TestGenerateComparisonsFromClicks(unittest.TestCase):
    def test_comparisons_count(self):
        ref = "A"
        clicks = ["B", "C", "D", "E"]  # n = 4
        comps = generate_comparisons(ref, clicks, trial_num=1)

        # C(4, 2) = 6
        self.assertEqual(len(comps), 6)

    def test_comparisons_structure(self):
        ref = "X"
        clicks = ["P", "Q", "R"]

        comps = generate_comparisons(ref, clicks, trial_num=7)

        for c in comps:
            self.assertEqual(c["trial"], 7)
            self.assertEqual(c["s1"], ref)
            self.assertEqual(c["s3"], ref)
            self.assertEqual(c["operator"], ">")
            self.assertTrue(c["s2"] in clicks)
            self.assertTrue(c["s4"] in clicks)
            self.assertIsNot(c["s2"], c["s4"])

    def test_generate_comparisons_unique_pairs(self):
        ref = "A"
        clicks = ["B", "C", "D", "E"]

        comps = generate_comparisons(ref, clicks, trial_num=1)

        seen_pairs = set()
        for c in comps:
            pair = tuple(sorted((c["s2"], c["s4"])))
            assert pair not in seen_pairs
            seen_pairs.add(pair)

        self.assertEqual(len(seen_pairs), 6)

    def test_generate_comparisons_judgment_matches_click_order(self):
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
                self.assertEqual(judgment, 0)
            else:
                self.assertEqual(judgment, 1)


class TestStandardizeComparisonKeys(unittest.TestCase):
    def test_triadic_same_comparison_different_order(self):
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

        self.assertEqual(out1, out2)

    def test_triadic_judgment_flip_on_swap(self):
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

        self.assertEqual(standardized["s2"], "C")
        self.assertEqual(standardized["s4"], "Z")
        self.assertEqual(standardized["judgment"], 0)

    def test_triadic_reference_preserved(self):
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

        self.assertEqual(standardized["s1"], "REF")
        self.assertEqual(standardized["s3"], "REF")

    def test_tetradic_same_comparison_pairs_swapped(self):
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

        self.assertEqual(out1, out2)

    def test_tetradic_within_pair_sorting(self):
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

        self.assertEqual(standardized["s1"], "h")
        self.assertEqual(standardized["s2"], "w")
        self.assertEqual(standardized["s3"], "k")
        self.assertEqual(standardized["s4"], "l")

    def test_tetradic_judgment_no_flip_on_pair_swap(self):
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

        self.assertEqual(standardized["s1"], "a")
        self.assertEqual(standardized["s2"], "z")
        self.assertEqual(standardized["s3"], "b")
        self.assertEqual(standardized["s4"], "c")
        self.assertEqual(standardized["judgment"], 1)

    def test_tetradic_judgment_flip_on_pair_swap(self):
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

        self.assertEqual(standardized["s1"], "b")
        self.assertEqual(standardized["s2"], "c")
        self.assertEqual(standardized["s3"], "k")
        self.assertEqual(standardized["s4"], "z")
        self.assertEqual(standardized["judgment"], 0)

    def test_invalid_comparison_type_raises(self):
        with self.assertRaises(ValueError):
            standardize_comparison_keys([], comparison_type="invalid")


class TestReplaceStimuliWithIds(unittest.TestCase):
    def test_basic_replacement(self):
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

        self.assertEqual(out[0]["s1"], 1)
        self.assertEqual(out[0]["s2"], 2)
        self.assertEqual(out[0]["s3"], 1)
        self.assertEqual(out[0]["s4"], 3)

    def test_alphabetical_id_assignment(self):
        comparisons = [
            {"s1": "Z", "s2": "A", "s3": "Z", "s4": "M", "judgment": 1}
        ]

        stimuli_set = {"Z", "A", "M"}

        out, id_to_stim = replace_stimuli_with_ids(comparisons, stimuli_set)

        # Alphabetical: A=1, M=2, Z=3
        self.assertEqual(out[0]["s1"], 3)
        self.assertEqual(out[0]["s2"], 1)
        self.assertEqual(out[0]["s4"], 2)

    def test_judgment_unchanged(self):
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

        self.assertEqual(out[0]["judgment"], 1)
        self.assertEqual(out[0]["trial"], 5)

    def test_in_place_mutation(self):
        comparisons = [
            {"s1": "A", "s2": "B", "s3": "A", "s4": "C", "judgment": 0}
        ]

        original = comparisons
        stimuli_set = {"A", "B", "C"}

        out, id_to_stim = replace_stimuli_with_ids(comparisons, stimuli_set)

        self.assertIs(out, original)

    def test_multiple_comparisons_consistent_mapping(self):
        comparisons = [
            {"s1": "A", "s2": "B", "s3": "A", "s4": "C", "judgment": 0},
            {"s1": "C", "s2": "A", "s3": "C", "s4": "B", "judgment": 1},
        ]

        stimuli_set = {"A", "B", "C"}

        out, id_to_stim = replace_stimuli_with_ids(comparisons, stimuli_set)

        self.assertEqual(out[0]["s1"], out[1]["s2"])  # A → same ID everywhere
        self.assertEqual(out[0]["s4"], out[1]["s1"])  # C → same ID everywhere

    def test_missing_stimulus_raises_keyerror(self):
        comparisons = [
            {"s1": "A", "s2": "B", "s3": "A", "s4": "D", "judgment": 0}
        ]

        stimuli_set = {"A", "B", "C"}  # D missing

        with self.assertRaises(KeyError):
            replace_stimuli_with_ids(comparisons, stimuli_set)

    def test_empty_comparisons(self):
        comparisons = []
        stimuli_set = {"A", "B"}

        out, id_to_stim = replace_stimuli_with_ids(comparisons, stimuli_set)

        self.assertEqual(out, [])


class TestFullMatPipelineWithOverlappingTriad(unittest.TestCase):
    def test_multiple_trials_with_overlapping_triadic_comparison(self):
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
            self.assertEqual(total, 6)  # 2 trials × C(3,2)=3

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
            self.assertTrue(len(shared) >= 1)

            # That shared comparison should appear once per trial
            shared_key = shared[0]

            rows_for_key = [
                r for r in responses
                if (r[1], r[2], r[3], r[4]) == shared_key
            ]

            trials = {int(r[0]) for r in rows_for_key}
            self.assertEqual(trials, {1, 2})

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
            self.assertEqual(loaded_responses.shape, responses.shape)

            # Confirm overlap survived serialization
            loaded_keys = [
                (int(r[1]), int(r[2]), int(r[3]), int(r[4]))
                for r in loaded_responses
            ]
            loaded_counts = Counter(loaded_keys)

            self.assertTrue(any(v == 2 for v in loaded_counts.values()))


if __name__ == '__main__':
    unittest.main()
