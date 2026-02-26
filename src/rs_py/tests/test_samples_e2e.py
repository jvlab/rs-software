import os
import unittest
import tempfile
import numpy as np
from scipy.io import loadmat

# Update this import path to your module
from src.rs_py.choices.choice_file_combined import build_combine_choice_mat


def _repo_root():
    # Put this test file under tests/. This goes up to repo root.
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def _get_col_idx(colnames, target):
    colnames = [c.strip() for c in list(colnames)]
    return colnames.index(target)


class TestE2EUsingSamples(unittest.TestCase):

    def _assert_no_within_pair_swaps(self, responses, colnames):
        colnames = [c.strip() for c in colnames]
        COL_S1 = colnames.index("s1")
        COL_S2 = colnames.index("s2")
        COL_S3 = colnames.index("s3")
        COL_S4 = colnames.index("s4")

        seen = set()
        for row in responses:
            a = int(row[COL_S1]);
            b = int(row[COL_S2]);
            c = int(row[COL_S3]);
            d = int(row[COL_S4])

            forbidden = {
                (b, a, c, d),  # swap first pair
                (a, b, d, c),  # swap second pair
                (b, a, d, c),  # swap both pairs
            }
            conflict = forbidden.intersection(seen)
            if conflict:
                self.fail(
                    f"Found within-pair swap duplicate.\n"
                    f"Current: {(a, b, c, d)}\n"
                    f"Conflicts with: {sorted(conflict)}"
                )
            seen.add((a, b, c, d))

    def _test_detailed_and_combined_totals_match(self, detailed, combined):
        """
        Invariant:
          sum_judgments(detailed) == sum_judgments(combined)
          n_rows(detailed)        == sum_repeats(combined)
        """
        # --- Detailed totals ---
        det_responses = np.asarray(detailed["responses"])
        det_cols = detailed["response_colnames"]
        det_j_idx = _get_col_idx(det_cols, "N(D(s1, s2) > D(s3, s4))")

        sum_judgments_detailed = int(np.sum(det_responses[:, det_j_idx]))
        total_repeats_detailed = int(det_responses.shape[0])  # each row is one repeat/occurrence

        # --- Combined totals ---
        comb_responses = np.asarray(combined["responses"])
        comb_cols = combined["response_colnames"]
        comb_j_idx = _get_col_idx(comb_cols, "N(D(s1, s2) > D(s3, s4))")
        comb_r_idx = _get_col_idx(comb_cols, "N_Repeats(D(s1, s2) > D(s3, s4))")

        sum_judgments_combined = int(np.sum(comb_responses[:, comb_j_idx]))
        total_repeats_combined = int(np.sum(comb_responses[:, comb_r_idx]))

        self.assertEqual(
            sum_judgments_detailed, sum_judgments_combined,
            f"Judgment sums differ: detailed={sum_judgments_detailed}, combined={sum_judgments_combined}"
        )
        self.assertEqual(
            total_repeats_detailed, total_repeats_combined,
            f"Total repeats differ: detailed rows={total_repeats_detailed}, combined sum repeats={total_repeats_combined}"
        )
        self.assertEqual(total_repeats_detailed, 222*28*5)
        self.assertNotEqual(sum_judgments_combined, 0)

    def test_samples_detailed_to_combined_has_no_swaps(self):
        repo = _repo_root()

        input_mat_path = os.path.join(
            repo,
            "samples",
            "choice_files",
            "animals_detailed_choices_S4.mat",
        )
        self.assertTrue(os.path.isfile(input_mat_path), f"Missing sample file: {input_mat_path}")

        exp_name = "test_animals"
        subject = "S4"

        with tempfile.TemporaryDirectory() as out_dir:
            build_combine_choice_mat(
                input_mat_path=input_mat_path,
                output_dir=out_dir,
                exp_name=exp_name,
                subject=subject,
            )

            output_path = os.path.join(out_dir, f"{exp_name}_combined_choices_{subject}.mat")
            self.assertTrue(os.path.isfile(output_path), f"Expected output not found: {output_path}")

            out = loadmat(output_path, squeeze_me=True)
            responses = np.asarray(out["responses"])
            colnames = list(out["response_colnames"])

            # Combined file should contain only canonical rows (no within-pair swaps)
            self._assert_no_within_pair_swaps(responses, colnames)
            # Confirm num repeats and num judgments match between detailed and combined files
            detailed = loadmat(input_mat_path, squeeze_me=True)
            self._test_detailed_and_combined_totals_match(detailed, out)
