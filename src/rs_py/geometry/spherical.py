"""
Sample points on a sphere and compute pairwise spherical distances.

This module provides helpers for mapping Euclidean points onto a spherical
surface and measuring pairwise spherical distances. It includes legacy
(deprecated) versions of the mapping and distance functions, plus the current
implementations used in the codebase.
"""

import logging
import numpy as np


LOG = logging.getLogger(__name__)


# def sphere_map_deprecated(X, radius):
#     """ Map points in Euclidean space to points on a spherical surface using stereographic projection
#     adapted from https://en.wikipedia.org/wiki/Stereographic_projection to work for projection from a disk of
#     @param radius: R to a sphere of radius R.
#     @param X: d by n matrix with n points of dimension d in Rd (real numbers, d dim)
#     @return Y: d+1 by n matrix with n points projected onto the sphere of dimension d, which is embedded in
#     d+1-dimensional space
#     """
#     # retain coordinates of X but add a 0-th coordinate which is a function of the d-dimensional coordinate values
#     d, n = X.shape
#     Y = np.zeros((d + 1, n))
#     # squared norms of all vectors = dot products
#     dot_prods = np.einsum('ij,ij->j', X, X)  # https://stackoverflow.com/questions/6229519/numpy-column-wise-dot-product
#     denom_xi = 1/(dot_prods + radius**2)
#     D = np.diag(2*(radius**2)*denom_xi)
#     Y[1:, :] = X @ D
#     Y[0, :] = radius * (-radius ** 2 + dot_prods)/(radius ** 2 + dot_prods)
#     return Y


def sphere_map(X, radius):
    """
    Map Euclidean points to the surface of a sphere.

    This function rescales the input by the sphere radius and applies the
    current spherical mapping used for visualization and analysis.

    Args:
        X (numpy.ndarray): Array of shape (d, n), with n points in d Euclidean
            dimensions.
        radius (float): Radius of the sphere.

    Returns:
        numpy.ndarray: Array of shape (d + 1, n) containing points projected onto the sphere.

    Notes:
        mu (curvature) is 1/ radius.
    """
    X = X/radius
    # retain coordinates of X but add a 0-th coordinate which is a function of the d-dimensional coordinate values
    d, n = X.shape
    Y = np.zeros((d + 1, n))
    # squared norms of all vectors = dot products
    dot_prods = np.einsum('ij,ij->j', X, X)  # https://stackoverflow.com/questions/6229519/numpy-column-wise-dot-product
    for k in range(1, d+1):
        for p in range(n):
            Y[k, p] = 2 * X[k-1, p]/(1 + dot_prods[p])
    for p in range(n):
        Y[0, p] = (1 - dot_prods[p])/(1 + dot_prods[p])
    return Y


# def spherical_distances_deprecated(X, radius):
#     """
#     Computes the spherical distance between points ON the sphere.
#     Assumes the points passed in are not off the surface - already projected!
#     @param radius: radius of the sphere
#     @param X: d-by-n matrix of coordinates for points on a sphere
#     @return: cos-1(-[X, X]) = an n-by-n matrix of pairwise distance matrix for all points X
#     """
#     # standard inner product
#     inner_product = X.T @ X  # do not make it negative
#     interstimulus_distances = (radius/2) * np.arccos(round((inner_product / (radius**2)), 6))
#     return interstimulus_distances


def spherical_distances(X, radius):
    """
    Compute pairwise spherical distances between points on the sphere.

    Args:
        X (numpy.ndarray): Array of shape (d, n) containing points already
            projected onto the sphere.
        radius (float): Radius of the sphere.

    Returns:
        numpy.ndarray: Pairwise spherical distance matrix.

    Notes:
        Assumes the points passed in are not off the surface - already projected!
        Distance is $arccos(-[X, X])$ for all points X
    """
    # standard inner product
    inner_product = X.T @ X  # do not make it negative
    interstimulus_distances = (radius/2) * np.arccos(round(inner_product, 6))
    return interstimulus_distances

