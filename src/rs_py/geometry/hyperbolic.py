"""
Add curvature to a Euclidean fit and test whether the fit improves.

This module takes a Euclidean embedding that already explains psychophysical
judgments, maps the points onto the top sheet of a two-sheet hyperboloid using
Loid geometry, and then computes pairwise hyperbolic distances. The resulting
distances can be used to evaluate whether adding negative curvature improves
log-likelihood relative to the Euclidean model.

The mapping is controlled by a curvature parameter, which determines how close
the projected points lie to the hyperboloid center. When the curvature
parameter approaches 0, the geometry approaches Euclidean space, so improved
fit at positive curvature provides evidence for curvature in the space, after
accounting for the extra parameter.
"""

import logging
import numpy as np


LOG = logging.getLogger(__name__)


def loid_map(X, degree_curvature):
    """
        Map Euclidean points onto the top sheet of a two-sheet hyperboloid.

        Args:
            X (numpy.ndarray): Array of shape (d, n), with n points in d Euclidean
                dimensions.
            degree_curvature (float): Curvature parameter controlling how strongly
                the points are projected toward hyperbolic geometry.

        Returns:
            numpy.ndarray: Array of shape (d + 1, n) containing the projected points on the hyperboloid.
    """
    # retain coordinates of X but add a 0-th coordinate which is a function of the d-dimensional coordinate values
    d, n = X.shape
    Y = np.zeros((d + 1, n))
    Y[1:, :] = degree_curvature * X
    dot_prods = np.einsum('ij,ij->j', X, X)
    Y[0, :] = np.sqrt(1 + (degree_curvature ** 2) * dot_prods)
    return Y


# def loid_to_poincare_map(X):
#     # NEED TO TEST
#     """
#         Map points from the Loid hyperboloid to the Poincaré disk.
#
#         Args:
#             X (numpy.ndarray): Array of shape (d + 1, n), with n points on the
#                 hyperboloid.
#
#         Returns:
#             numpy.ndarray: Array of shape (d, n) containing the corresponding
#             Poincaré disk coordinates.
#     """
#     # retain coordinates of X but add a 0-th coordinate which is a function of the d-dimensional coordinate values
#     d, n = X.shape
#     Y = np.zeros((d-1, n))
#     for p in range(n):
#         Y[:, p] = (1/(1+X[0, p])) * X[1:, p]
#     return Y


def hyperbolic_distances(X, curvature):
    """
    Compute pairwise hyperbolic distances between points on the hyperboloid.

    Args:
        X (numpy.ndarray): Array of shape (d + 1, n) containing points already
            projected onto the hyperboloid.
        curvature (float): Positive curvature parameter used to scale the
            resulting distances.

    Returns:
        numpy.ndarray: Pairwise hyperbolic distance matrix for the points in X.

    Notes:
        Distances are computed as $arccosh(-[X, X])$.
    """
    # test entries along the diagonal should equal 1
    # test all entries should be less than or equal to -1 or what notes say
    H = np.eye(X.shape[0])
    H[0, 0] = -1
    inner_product = X.T @ H @ X
    # return interstimulus_distances
    return np.arccosh(-round(inner_product, 6)) / curvature
