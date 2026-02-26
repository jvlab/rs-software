"""
Given a Euclidean fit, obtained from ordinary gradient descent that explains the psychophysical judgments, add curvature
(negative curvature to make the space more hyperbolic) and see if the fit improves.
This entails projecting Euclidean points onto the top sheet of a two sheet hyperboloid, using the Loid geometry as the
geometry of the space. Distances between points on the hyperbolid are then taken in a way inspired by/ adapted from Tabaghi
et al's paper, "Hyperbolic Distance Matrices." Once distances are obtained, LL can be calculated.
A parameter, lambda controls how close to the hyperboloid center, the points are projected. When lambda approaches 0,
the distances approach Euclidean distances, so a positive lambda yielding a better LL is evidence for curvature in the
space - IF you can account for the added benefit provided simply by adding 1 more parameter.
"""

import logging
import numpy as np


LOG = logging.getLogger(__name__)


def loid_map(X, degree_curvature):
    """ Map points in Euclidean space to points on the hyperboloid using a mapping to the Loid space.
    @param degree_curvature: the aforementioned lambda parameter, 0 if distances are Euclidean.
    @param X: d by n matrix with n points of dimension d in Rd (real numbers, d dim)
    @return Y: d+1 by n matrix with n points projected onto the hyperboloid of dimension d, which is embedded in
    d+1-dimensional space
    apply L(lambda.x)
    """
    # retain coordinates of X but add a 0-th coordinate which is a function of the d-dimensional coordinate values
    d, n = X.shape
    Y = np.zeros((d + 1, n))
    Y[1:, :] = degree_curvature * X
    dot_prods = np.einsum('ij,ij->j', X, X)
    Y[0, :] = np.sqrt(1 + (degree_curvature ** 2) * dot_prods)
    return Y


def loid_to_poincare_map(X):
    # NEED TO TEST
    """ Map points in Loid hyperboiloid to points on the Poincare disk.
    @param X: d+1 by n matrix with n points of dimension d in Rd (real numbers, d dim)
    @return Y: d by n matrix with n points projected onto the hyperboloid of dimension d, which is embedded in
    d+1-dimensional space
    """
    # retain coordinates of X but add a 0-th coordinate which is a function of the d-dimensional coordinate values
    d, n = X.shape
    Y = np.zeros((d-1, n))
    for p in range(n):
        Y[:, p] = (1/(1+X[0, p])) * X[1:, p]
    return Y


def hyperbolic_distances(X, curvature):
    """
    Computes the hyperblic distance between points ON the hyperboloid.
    Assumes the points passed in are not off the hyperboloid - already projected!
    @param curvature: 0 when distances supposedly like Euclidean, hyperbolic when > 0
    @param X: d-by-n matrix of coordinates for points on a hyperboloid Ld
    @return: cosh-1(-[X, X]) = an n-by-n matrix of pairwise distance matrix for all points X
    """
    # test entries along the diagonal should equal 1
    # test all entries should be less than or equal to -1 or what notes say
    H = np.eye(X.shape[0])
    H[0, 0] = -1
    inner_product = X.T @ H @ X
    # return interstimulus_distances
    return np.arccosh(-round(inner_product, 6)) / curvature
