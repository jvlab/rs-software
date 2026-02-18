"""
Use the Gram Schmidt procedure to reorient a set of points such that one point is at the origin, another point lies
on one axis (x1, 0, ..., 0) and the next point lies on a plane spanned by the two axes  (x2, x3, 0, ..., 0), and
so on. This constrains the minimization function that looks for the points of best fit, as rotations and
translations are made redundant.

This can also take into effect the noise parameter as we do not constrain where on the first axis, the second
point lies.
"""
import numpy as np


def choose_basis_vectors(M):
    """
    Given a matrix of points M (m by n), where m is the number of dimensions and n is the number of points,
    choose m vectors that are linearly independent from each other.

    Since the chosen submatrix would be m by m, a simple way to do this is by calculating the determinant.
    If the determinant is 0, the vectors are not linearly independent
    """
    # first check if M has full rank
    n_dim, n_points = M.shape
    if np.linalg.matrix_rank(M) < n_dim:
        raise ValueError("Matrix is rank-deficient. Points lie in a subspace of rank smaller than {} dim".format(n_dim))
    submatrix = M[:, 0:n_dim]
    if np.linalg.det(submatrix) == 0:
        return NotImplementedError("Edge case not handled. Points will need reordering if other vectors"
                                   "are selected.")
    return submatrix


def gram_schmidt(B):
    """
    Take in an m by m matrix A and return a matrix with orthonormal vectors that span the same space as A
    In this case, we assume that the input matrix A is square and has linearly independent vectors.
    """
    G = np.zeros(B.shape)
    n_row, n_col = B.shape
    for j in range(n_col):
        vector_j = B[:, j]
        for k in range(0, j):
            # subtract the projection of j onto the previous vector from vector j
            scalar = (np.dot(G[:, k], B[:, j]) / np.dot(G[:, k], G[:, k]))
            projection = G[:, k] * scalar
            vector_j = vector_j - projection
        G[:, j] = vector_j
    norms = np.linalg.norm(G, axis=0)
    G = G / norms
    return G


def anchor_points(points):
    """
    points: 37 by d matrix
    Given a set of 37 points, find the rotation needed using Gram Schmidt and then
    transform the  coordinates to the format needed - one point is zero and the rest are partly in a triangular form
    """
    # make the first point the origin (translate all by first vector)
    points = points - points[0, :]
    # transpose the matrix so that each point is a column
    points = points.T
    # choose d independent vectors
    subset_points = choose_basis_vectors(points[:, 1:])
    Q = gram_schmidt(subset_points)
    # transform the 37 points
    R = Q.T @ points
    # put rotated points in the correct format
    return R.T
