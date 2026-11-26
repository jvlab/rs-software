import numpy as np
import pytest
from scipy.spatial.distance import pdist, squareform
from matplotlib import pyplot as plt

import src.rs_py.geometry.euclidean as model
from src.rs_py.geometry.hyperbolic import loid_map, hyperbolic_distances
from src.rs_py.geometry.spherical import spherical_distances, sphere_map


def test_origin_correctly_mapped_to_hyperboloid_origin():
    X = np.array([[0], [0]])
    Y = loid_map(X, 1)

    assert len(Y) == len(X) + 1
    np.testing.assert_array_equal(Y[0], np.ones_like(Y[0]))
    np.testing.assert_array_equal(Y[1], np.zeros_like(Y[1]))
    np.testing.assert_array_equal(Y[2], np.zeros_like(Y[2]))


def test_visually_if_square_projected_correctly(show_plots):
    square_euclidean = np.array([
        [-1, -1, -1, -1, -1, -1, -1, -1,
         -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 1,
         1, 1, 1, 1, 1, 1, 1, 1,
         0.75, 0.5, 0.25, 0, -0.25, -0.5, -0.75],
        [1, 0.75, 0.5, 0, -0.25, -0.5, -0.75, -1,
         -1, -1, -1, -1, -1, -1, -1, -1,
         -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 1,
         1, 1, 1, 1, 1, 1, 1],
    ])

    for curvature in [0.2, 1, 2]:
        fig = None
        try:
            if show_plots:
                fig = plt.figure()
                ax = fig.add_subplot(projection="3d")
                ax.set_title(f"Hyperboloid: parameter {curvature}")

            for scale in [1, 1.5]:
                temp = scale * square_euclidean
                Y = loid_map(temp, curvature)

                print(
                    f"Parameter={curvature}, scale={scale}, "
                    f"mapped shape={Y.shape}"
                )

                if show_plots:
                    ax.plot(temp[0, :], temp[1, :], zs=0, marker="o",
                            linestyle="None", color="blue")
                    ax.scatter(
                        Y[1, :], Y[2, :], Y[0, :],
                        color=[0.5, 0.5, 0.7],
                    )

            if show_plots:
                plt.show()
        finally:
            if fig is not None:
                plt.close(fig)


def test_visually_if_random_points_projected_to_sphere_of_correct_radius(
        show_plots,
):
    rand_dots = np.array([
        np.random.standard_normal(100),
        np.random.standard_normal(100),
    ])
    radius = 0.5
    Y = sphere_map(rand_dots, radius)

    print(f"Radius={radius}, mapped shape={Y.shape}")

    if show_plots:
        fig = plt.figure()
        try:
            ax = fig.add_subplot(projection="3d")
            ax.plot(
                rand_dots[0, :], rand_dots[1, :], zs=0,
                marker="o", linestyle="None", color="blue",
            )
            ax.scatter(
                Y[1, :], Y[2, :], Y[0, :],
                color=[0.7, 0.5, 0.5],
            )
            ax.set_xlim(-1, 1)
            ax.set_ylim(-1, 1)
            ax.set_title(f"Sphere: radius {radius}")
            plt.show()
        finally:
            plt.close(fig)


def test_if_hyperbolic_distance_equals_euclidean_for_near_zero_curvature():
    square_euclidean = np.array([
        [-1, -1, -1, -1, -1, -0.5, 0, 0.5,
         1, 1, 1, 1, 1, 0.5, 0, -0.5],
        [1, 0.5, 0, -0.5, -1, -1, -1, -1,
         -1, -0.5, 0, 0.5, 1, 1, 1, 1],
    ])

    X = squareform(pdist(square_euclidean.T))
    Y = hyperbolic_distances(loid_map(square_euclidean, 0.01), 0.01)

    diffs = 0
    total = 0
    for i in range(Y.shape[0]):
        for j in range(i):
            diffs += np.abs(Y[i, j] - X[i, j])
            total += 1

    assert diffs / total <= 0.005


def test_if_hyperbolic_distance_equals_euclidean_for_points_near_origin(
        show_plots,
):
    random_euclidean = 0.02 * np.random.rand(2, 10)
    center = np.mean(random_euclidean, axis=1, keepdims=True)
    random_euclidean = random_euclidean - center

    X = squareform(pdist(random_euclidean.T))

    for val in [0.5, 1, 2]:
        Y = hyperbolic_distances(loid_map(random_euclidean, val), val)

        ratios = []
        for i in range(Y.shape[0]):
            for j in range(i):
                ratios.append(Y[i, j] / X[i, j])

        print(f"Parameter={val}, mean distance ratio={np.mean(ratios)}")
        assert np.mean(ratios) == pytest.approx(1, rel=0, abs=0.03)

    fig = None
    try:
        if show_plots:
            fig = plt.figure()
            ax = fig.add_subplot(projection="3d")
            ax.plot(
                random_euclidean[0, :], random_euclidean[1, :],
                zs=0, marker="o", linestyle="None",
            )

        for val in [0.5, 1, 2, 3]:
            Y = loid_map(random_euclidean, val)
            if show_plots and Y is not None:
                ax.scatter(Y[1, :], Y[2, :], Y[0, :])

        if show_plots:
            ax.set_xlim(-2, 1)
            ax.set_ylim(-2, 1)
            plt.show()
    finally:
        if fig is not None:
            plt.close(fig)


def test_if_spherical_distance_equals_euclidean_for_points_near_origin(
        show_plots,
):
    random_euclidean = 0.02 * np.random.rand(2, 50)
    center = np.mean(random_euclidean, axis=1, keepdims=True)
    random_euclidean = random_euclidean - center

    X = squareform(pdist(random_euclidean.T))

    for radius in [500]:
        Y = spherical_distances(
            sphere_map(random_euclidean, radius), radius
        )

        ratios = []
        for i in range(Y.shape[0]):
            for j in range(i):
                ratios.append(Y[i, j] / X[i, j])

        print(f"Radius={radius}, mean distance ratio={np.mean(ratios)}")
        assert np.mean(ratios) == pytest.approx(1, rel=0, abs=0.03)

    fig = None
    try:
        if show_plots:
            fig = plt.figure()
            ax = fig.add_subplot(projection="3d")
            ax.plot(
                random_euclidean[0, :], random_euclidean[1, :],
                zs=0, marker="o", linestyle="None",
            )

        for radius in [0.5, 1, 2, 3]:
            Y = sphere_map(random_euclidean, radius)
            if show_plots and Y is not None:
                ax.scatter(Y[1, :], Y[2, :], Y[0, :])

        if show_plots:
            ax.set_xlim(-2, 1)
            ax.set_ylim(-2, 1)
            plt.show()
    finally:
        if fig is not None:
            plt.close(fig)


def test_hyperbolic_inner_product_is_minus_1_for_points_on_hyperboloid():
    points2D = np.random.rand(10, 10)
    pointsH = loid_map(points2D.T, 1)

    H = np.eye(pointsH.shape[0])
    H[0, 0] = -1
    inner_product = np.round(pointsH.T @ H @ pointsH, 5)

    for i in range(len(inner_product)):
        assert inner_product[i, i] == -1

    assert np.all(inner_product <= -1)


def test_hyperbolic_map_and_dist_as_curvature_increases():
    space = model.EuclideanSpace(2)
    rand_dots = space.get_samples(1000, 10, "uniform").T

    for curv in [0.1, 0.25, 0.5, 0.75, 1, 2, 3, 4]:
        Y = loid_map(rand_dots, curv)
        D_new = hyperbolic_distances(Y, curv)

        print(
            f"Parameter={curv}, mean distance={np.mean(D_new)}, "
            f"max distance={np.max(D_new)}"
        )


def test_euclidean_create_space_has_correct_dim():
    space = model.EuclideanSpace(5)
    assert space.dimensions == 5


def test_euclidean_sample_space_sample_has_correct_magnitude():
    space = model.EuclideanSpace(5)
    sample = space.sample_space(8)
    assert 8 <= np.linalg.norm(sample)


def test_euclidean_sample_space_sample_has_correct_size():
    _n = 10
    space = model.EuclideanSpace(5)
    sample = space.get_samples(_n, 8)
    assert len(sample) == _n
