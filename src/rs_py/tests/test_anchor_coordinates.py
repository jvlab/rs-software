import unittest
import warnings

import numpy as np
from scipy.spatial.distance import pdist

from src.rs_py.utils.anchor_coordinates import choose_basis_vectors, anchor_points


class TestChooseBasisVectors(unittest.TestCase):

    def test_full_rank_is_returned_unchanged_without_warning(self):
        rng = np.random.default_rng(0)
        M = rng.normal(size=(4, 9))
        with warnings.catch_warnings():
            warnings.simplefilter("error")
            out = choose_basis_vectors(M)
        np.testing.assert_array_equal(out, M[:, 0:4])

    def test_rank_deficient_submatrix_warns_and_gets_full_rank(self):
        # first two columns are parallel, so the 2x2 submatrix has rank 1
        M = np.array([[1., 2., 0., 1.],
                      [1., 2., 1., 3.]])
        with self.assertWarns(RuntimeWarning):
            out = choose_basis_vectors(M)
        self.assertEqual(out.shape, (2, 2))
        self.assertEqual(np.linalg.matrix_rank(out), 2)

    def test_augmentation_is_the_smallest_power_of_two_multiple_of_identity(self):
        M = np.array([[1., 2., 0., 1.],
                      [1., 2., 1., 3.]])
        sub = M[:, 0:2]
        q = 1.0  # smallest nonzero absolute value in the submatrix
        with self.assertWarns(RuntimeWarning):
            out = choose_basis_vectors(M)
        added = out - sub
        h = int(round(np.log2(added[0, 0] / q)))
        np.testing.assert_allclose(added, q * 2 ** h * np.eye(2))
        self.assertGreaterEqual(h, 0)
        if h > 0:  # one step smaller would still have been rank-deficient
            self.assertLess(np.linalg.matrix_rank(sub + q * 2 ** (h - 1) * np.eye(2)), 2)

    def test_all_zero_submatrix_returns_identity_with_warning(self):
        M = np.zeros((3, 5))
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            out = choose_basis_vectors(M)
        np.testing.assert_array_equal(out, np.eye(3))
        self.assertTrue(any("all zero" in str(w.message) for w in caught))


class TestAnchorPointsRankDeficient(unittest.TestCase):

    def test_points_in_a_plane_asked_for_three_dims_now_run(self):
        # 3-D coordinates whose third column is exactly the sum of the first two:
        # the points span only a plane, which used to raise "Matrix is rank-deficient"
        rng = np.random.default_rng(1)
        xy = rng.normal(size=(8, 2))
        points = np.column_stack([xy, xy[:, 0] + xy[:, 1]])
        with self.assertWarns(RuntimeWarning):
            anchored = anchor_points(points)
        self.assertEqual(anchored.shape, points.shape)
        np.testing.assert_allclose(anchored[0], 0, atol=1e-9)          # first point at the origin
        np.testing.assert_allclose(pdist(anchored), pdist(points), atol=1e-6)  # distances preserved


if __name__ == "__main__":
    unittest.main()
