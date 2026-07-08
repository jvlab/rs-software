"""
Sample points from Euclidean spaces of configurable dimension.

This module provides utilities for drawing stimulus locations in an
n-dimensional Euclidean space. Points can be sampled from the surface of a
sphere, from a Gaussian distribution, or uniformly from inside a sphere.
"""
import numpy as np


class EuclideanSpace:
    """Represent an n-dimensional Euclidean space for sampling points."""

    def __init__(self, num_dim):
        """
            Set the dimensionality of the space.
            Args:
                num_dim (int): Number of dimensions in the Euclidean space. """
        # NOTE: "Sampling strategy fails for space with less than 2 dimensions."
        self.dimensions = num_dim

    def sample_space(self, magnitude, method="spherical_shell"):
        """
            Sample one point from the space.
            Args:
                magnitude (float): Target magnitude or scale of the sample.
                method (str): Sampling method. Options are `spherical_shell`, `gaussian`, and `uniform`.

            Returns:
                numpy.ndarray or float: A sampled point. For `spherical_shell`, returns a scalar when `dimensions == 1`.
        """
        if method == "spherical_shell":
            if self.dimensions == 1:
                return np.random.normal(0, 1)
            else:
                sample = np.random.normal(0, 1, self.dimensions)
                # get length of vector
                length = np.sqrt(sample.dot(sample))
                # normalize and scale vector so it has magnitude passed in as arg
                scaled_sample = np.array([(float(x) / length) * magnitude for x in sample])
                return scaled_sample
        # sample from inside a Gaussian, not limited to the surface
        elif method == "gaussian":
            sample = np.random.normal(0, magnitude, self.dimensions)
            return sample
        # sample each dimension from a uniform distribution on [0, magnitude]
        # but only take points that lie in a sphere of radius magnitude
        elif method == "uniform":
            sample = np.random.uniform(-magnitude, magnitude, self.dimensions)
            length = np.sqrt(sample.dot(sample))
            while length > magnitude:
                sample = np.random.uniform(-magnitude, magnitude, self.dimensions)
                length = np.sqrt(sample.dot(sample))
            return sample

    def get_samples(self, num_stimuli, magnitude=1, method="spherical_shell"):
        """
            Sample multiple points from the space.
            Args:
                num_stimuli (int): Number of points to sample.
                magnitude (float): Target magnitude or scale of each sample.
                method (str): Sampling method. Options are `spherical_shell`, `gaussian`, and `uniform`.

            Returns:
                numpy.ndarray: Array of sampled points, one per stimulus.
        """
        return np.array([self.sample_space(magnitude, method) for _ in range(num_stimuli)])
