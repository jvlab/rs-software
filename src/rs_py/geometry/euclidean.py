"""
This file holds methods that can draw a given number of samples from a Euclidean space
of a given number of dimensions.

Sampling Strategy:
Points sampled will always lie on the surface of some n-dimensional 'sphere', equidistant
from the origin. Vectors are sampled from a surface of an n-dimensional Gaussian, to choose
a direction away from the origin, then are given a magnitude.

Parameters:
@ num_stimuli:  number of points/ stimuli
@ num_dim: dimension of the space from which to draw points
@ magnitude: magnitude of each of the points
"""
import numpy as np


class EuclideanSpace:
    """This class is a geometry of n-dimensional Euclidean Space."""

    def __init__(self, num_dim):
        # NOTE: "Sampling strategy fails for space with less than 2 dimensions."
        self.dimensions = num_dim

    def sample_space(self, magnitude, method="spherical_shell"):
        """ Sample a vector from the surface of a multidimensional
        standard normal distribution - approximate 'sphere' of a
        given radius (magnitude) UNLESS DIM = 1
        :param magnitude
        :param method - by  default  this is surface of a Gaussian
                        other methods added recently  (3/24/2021) include full Gaussian and uniform sampling
                        another change (4/22/2021) updated uniform to only sample from inside a sphere. otherwise
                        there tend to a lot more points in the corners as dimension increases.
        :return vector: 1d numpy array
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
        """ Returns a list of n dimensional points given by arrays
        :param num_stimuli: int
        :param method - to change sampling method
        :param magnitude: L2 norm of each vector
        :return vectors: list of 1d numpy arrays
        """
        return np.array([self.sample_space(magnitude, method) for _ in range(num_stimuli)])
