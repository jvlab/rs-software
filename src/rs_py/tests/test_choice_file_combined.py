import csv
import os
import tempfile
import pytest

import numpy as np
from scipy.io import loadmat, savemat

from src.rs_py.choices.choice_file_combined import build_combine_choice_mat
from src.rs_py.choices.choice_file_detailed import build_detailed_choice_mat


# ----------------- Set-up functions/ fixtures-------------------------------#
def write_csv(path, rows, fieldnames):
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def get_col_idx(colnames, target):
    colnames = [name.strip() for name in colnames]
    return colnames.index(target)


def get_detailed_choices():
    return {
        "metadata": {"exp_name": "texture", "subject": "AJ"},
        "stim_list": np.array(["A", "B", "C", "D"], dtype=object),
        "responses_colnames": [
            "trial", "ref", "s1", "s2", "N(D(ref, s1) > D(ref, s2))"
        ],
        "responses": np.array([
            [1, 1, 2, 3, 1],
            [2, 1, 2, 3, 0],
            [3, 1, 2, 4, 1],
        ]),
    }


def get_detailed_tetradic_choices():
    return {
        "metadata": {"exp_name": "texture", "subject": "AJ"},
        "stim_list": np.array(["A", "B", "C", "D"], dtype=object),
        "responses_colnames": [
            "trial", "s1", "s2", "s3", "s4", "N(D(s1, s2) > D(s3, s4))"
        ],
        "responses": np.array([
            [1, 1, 2, 3, 4, 1],
            [2, 1, 2, 3, 4, 0],
            [3, 1, 3, 2, 4, 1],
        ]),
    }


# ----------------- Tests --------------------------------------------------#
def test_combine_triadic_choices_from_detailed_retains_stimlist():
    with tempfile.TemporaryDirectory() as tmpdir:
        detailed_path = os.path.join(tmpdir, "detailed.mat")
        output_dir = os.path.join(tmpdir, "output")
        os.mkdir(output_dir)

        detailed = get_detailed_choices()
        savemat(detailed_path, detailed)

        build_combine_choice_mat(detailed_path, output_dir, "texture", "AJ")
        output_path = os.path.join(output_dir, "texture_choices_AJ.mat")
        combined = loadmat(output_path, squeeze_me=True, struct_as_record=False)
        assert [name.strip() for name in combined["responses_colnames"]] == [
            "ref", "s1", "s2", "N(D(ref, s1) > D(ref, s2))",
            "N_Repeats(D(ref, s1) > D(ref, s2))",
        ]
        np.testing.assert_array_equal(combined["stim_list"], detailed["stim_list"])


def test_detailed_choices_tabulated_correctly_in_combined_choices():
    with tempfile.TemporaryDirectory() as tmpdir:
        detailed_path = os.path.join(tmpdir, "detailed.mat")
        output_dir = os.path.join(tmpdir, "output")
        os.mkdir(output_dir)

        detailed = get_detailed_choices()
        savemat(detailed_path, detailed)

        build_combine_choice_mat(detailed_path, output_dir, "texture", "AJ")
        output_path = os.path.join(output_dir, "texture_choices_AJ.mat")
        combined = loadmat(output_path, squeeze_me=True, struct_as_record=False)

        responses = np.atleast_2d(combined["responses"])
        combined_rows = {
            tuple(row[:3]): tuple(row[3:])
            for row in responses
        }
        assert combined_rows == {
            (1, 2, 3): (1, 2),  # judgment = 1, repeated twice
            (1, 2, 4): (1, 1),  # judgment = 1, repeated once
        }


def test_tetradic_choices_tabulated_correctly_and_stimlist_retained():
    with tempfile.TemporaryDirectory() as tmpdir:
        detailed_path = os.path.join(tmpdir, "detailed.mat")
        output_dir = os.path.join(tmpdir, "output")
        os.mkdir(output_dir)

        detailed = get_detailed_tetradic_choices()
        savemat(detailed_path, detailed)

        build_combine_choice_mat(detailed_path, output_dir, "texture", "AJ")

        output_path = os.path.join(output_dir, "texture_choices_AJ.mat")
        combined = loadmat(output_path, squeeze_me=True, struct_as_record=False)
        assert [name.strip() for name in combined["responses_colnames"]] == [
            "s1", "s2", "s3", "s4", "N(D(s1, s2) > D(s3, s4))",
            "N_Repeats(D(s1, s2) > D(s3, s4))"]
        np.testing.assert_array_equal(combined["stim_list"], detailed["stim_list"])

        responses = np.atleast_2d(combined["responses"])
        combined_rows = {
            tuple(row[:4]): tuple(row[4:])
            for row in responses
        }
        assert combined_rows == {
            (1, 2, 3, 4): (1, 2),
            (1, 3, 2, 4): (1, 1)
        }


def test_num_trials_in_detailed_choices_equals_num_triads_in_combined_choices():
    with tempfile.TemporaryDirectory() as input_dir, tempfile.TemporaryDirectory() as output_dir:
        session_1_rows = [
            {"ref": "A", "stim1": "B", "stim2": "C", "clicks": "['stim1', 'stim2']"},
            {"ref": "A", "stim1": "B", "stim2": "C", "clicks": "['stim1', 'stim2']"},
        ]
        session_2_rows = [
            {"ref": "D", "stim1": "B", "stim2": "C", "clicks": "['stim2', 'stim1']"},
        ]
        write_csv(
            os.path.join(input_dir, "session_1_responses.csv"),
            session_1_rows, session_1_rows[0].keys()
        )
        write_csv(
            os.path.join(input_dir, "session_2_responses.csv"),
            session_2_rows, session_2_rows[0].keys()
        )

        build_detailed_choice_mat(
            input_dir, output_dir, "texture", "AJ", {"judgment_type": "triadic"}
        )
        detailed_path = os.path.join(output_dir, "texture_detailed_choices_AJ.mat")
        build_combine_choice_mat(detailed_path, output_dir, "texture", "AJ")

        detailed = loadmat(detailed_path, squeeze_me=True, struct_as_record=False)
        combined_path = os.path.join(output_dir, "texture_choices_AJ.mat")
        combined = loadmat(combined_path, squeeze_me=True, struct_as_record=False)

        detailed_responses = np.atleast_2d(detailed["responses"])
        combined_responses = np.atleast_2d(combined["responses"])
        detailed_colnames = detailed["responses_colnames"]
        combined_colnames = combined["responses_colnames"]
        detailed_judgments = detailed_responses[:, get_col_idx(
            detailed_colnames, "N(D(ref, s1) > D(ref, s2))"
        )]
        combined_judgments = combined_responses[:, get_col_idx(
            combined_colnames, "N(D(ref, s1) > D(ref, s2))"
        )]
        combined_repeats = combined_responses[:, get_col_idx(
            combined_colnames, "N_Repeats(D(ref, s1) > D(ref, s2))"
        )]

        assert np.sum(detailed_judgments) == np.sum(combined_judgments)
        assert detailed_responses.shape[0] == np.sum(combined_repeats)


if __name__ == "__main__":
    pytest.main()
