import logging
from numpy import mean, ones
from scipy.spatial import procrustes
from scipy import optimize
from ..utils.minimize import gradient_descent
from ..geometry.hyperbolic import loid_map, hyperbolic_distances
from ..geometry.spherical import sphere_map, spherical_distances
from ..utils import anchor_coordinates as ac, mds_embedding as mds, util
from ..choices.choice_likelihoods import calculate_ll, dist_model_ll_vectorized, find_probabilities


LOG = logging.getLogger(__name__)


def points_of_best_fit(judgments, number_repeats, args, start_points=None):
    """
    Fit Euclidean coordinates to the observed judgments.

    Args:
        judgments (dict):
            Pairwise comparison judgments
        number_repeats (dict):
            Number of repeats for each comparison key in `judgments`.
        args (dict):
            Model settings. Must include:
            - `n_dim`: embedding dimension
            - `num_stimuli`: number of stimuli
            - `sigma`: noise scale
            - `tolerance`: stopping tolerance for optimization
            - `minimization`: optimization method, either `gradient-descent`
              or `nelder-mead`
        start_points (array-like, optional):
            Initial coordinates for optimization. If not provided, MDS-derived
            starting points are used.

    Returns:
        tuple:
            (coordinates, solution_ll)
            - coordinates: fitted Euclidean coordinates
            - solution_ll: negative log-likelihood of the fitted solution
    """

    def cost(stimulus_params, pair_a, pair_b, counts, repeats, parameters):
        vectors = ac.params_to_points(stimulus_params, parameters['num_stimuli'], parameters['n_dim'])
        ll, is_bad = dist_model_ll_vectorized(pair_a, pair_b, counts, repeats, parameters, vectors)
        LOG.debug('geometry is good: {}'.format(not is_bad))
        return -1 * ll

    # calculate noise before continuing
    args['noise_st_dev'] = args['sigma']
    if start_points is None:
        # if not specified start minimization at coordiates returned by MDS after calculation of win-loss distances
        start_0 = mds.get_coordinates(args['n_dim'], judgments, number_repeats)[0]
    else:
        start_0 = start_points
    start = ac.anchor_points(start_0)
    LOG.info("########  Procrustes distance between start and anchored start: {}".format(
        procrustes(start, start_0)[2]))
    # turn points to params
    start_params = ac.points_to_params(start)
    LOG.info('######## Run minimization on MDS start points (scipy minimize)')
    # make maxiter 60000 for 5D geometry
    options_min = {
        'disp': True,
        'fatol': args['tolerance']}
    if args['n_dim'] < 4:
        options_min['maxiter'] = 85000
    elif args['n_dim'] >= 4:
        options_min['maxiter'] = 110000
    pairs_a, pairs_b, response_counts, comp_repeats = util.judgments_to_arrays(judgments, number_repeats)
    if args['minimization'] == 'nelder-mead':
        optimal = optimize.minimize(cost, start_params,
                                    args=(pairs_a, pairs_b, response_counts, comp_repeats, args),
                                    method='Nelder-Mead',
                                    options=options_min
                                    )
        LOG.info(
            '######## {} Iterations completed: {}. Model Dim: {}.'.format(optimal.message, optimal.nit,
                                                                          args['n_dim'])
        )
        solution = optimal.model_coords
        solution_ll = optimal.fun
    else:
        solution = gradient_descent(cost, start_params, pairs_a, pairs_b, response_counts, comp_repeats, args)
        stim = ac.params_to_points(solution, args['num_stimuli'], args['n_dim'])
        ll_final, is_model_bad = dist_model_ll_vectorized(pairs_a, pairs_b, response_counts, comp_repeats, args, stim)
        solution_ll = -1 * ll_final
        LOG.debug("Final Model is good/ feasible: {}".format(not is_model_bad))

    coordinates = ac.params_to_points(solution, args['num_stimuli'], args['n_dim'])

    try:
        procr_dist = procrustes(start, coordinates)[2]
    except ValueError:
        procr_dist = 'WARNING - problem with the coordinates. Nans or infs possible.'
    LOG.debug('########  Procrustes distance between anchored start and final solution: {}'.format(
        procr_dist)
    )
    return coordinates, solution_ll  # , sum_residual_squares


def hyperbolic_points_of_best_fit(judgments, number_repeats, args, start_points=None):
    """
        Fit hyperbolic coordinates to the observed judgments.

        Args:
            judgments (dict):
                Pairwise comparison judgments.
            number_repeats (dict):
                Number of repeats for each comparison key in `judgments`.
            args (dict):
                Model settings. Must include:
                - `n_dim`: embedding dimension
                - `num_stimuli`: number of stimuli
                - `sigma`: noise scale
            start_points (array-like, optional):
                Initial coordinates for optimization. If not provided, MDS-derived
                starting points are used.

        Returns:
            tuple:
                (coordinates, solution_ll)
                - coordinates: fitted hyperbolic coordinates
                - solution_ll: negative log-likelihood of the fitted solution
    """
    def hyperbolic_cost(stimulus_params, pair_a, pair_b, counts, repeats, parameters):
        curvature = args['scripts']
        vectors = ac.params_to_points(stimulus_params, parameters['num_stimuli'], parameters['n_dim'])
        # mean center points
        vectors = vectors.T
        center = mean(vectors, 1)
        center = center.reshape((parameters['n_dim'], 1)) * ones((1, parameters['num_stimuli']))
        vectors = vectors - center
        # map Euclidean points to hyperboloid
        hyperboloid_points = loid_map(vectors, curvature)
        # compute distances
        distances = hyperbolic_distances(hyperboloid_points, curvature)
        probs = find_probabilities(distances, pair_a, pair_b, parameters['noise_st_dev'])
        # calculate log-likelihood, is_bad flag
        ll, is_bad = calculate_ll(counts, probs, repeats)
        LOG.debug('geometry is good: {}'.format(not is_bad))
        # fmin_costs.append(-1 * ll)  # debugging fmin
        return -1 * ll

    # calculate noise before continuing
    args['noise_st_dev'] = args['sigma']
    if start_points is None:
        # if not specified start minimization at coordiates returned by MDS after calculation of win-loss distances
        start_0 = mds.get_coordinates(args['n_dim'], judgments, number_repeats)[0]
    else:
        start_0 = start_points
    start = ac.anchor_points(start_0)

    LOG.debug("########  Procrustes distance between start and anchored start: {}".format(
        procrustes(start, start_0)[2]))
    # turn points to params
    start_params = ac.points_to_params(start)
    LOG.info('######## Run minimization on MDS start points (scipy minimize)')

    pairs_a, pairs_b, response_counts, comp_repeats = util.judgments_to_arrays(judgments, number_repeats)
    solution = gradient_descent(hyperbolic_cost, start_params, pairs_a, pairs_b, response_counts, comp_repeats, args)
    solution_ll = hyperbolic_cost(solution, pairs_a, pairs_b, response_counts, comp_repeats, args)

    coordinates = ac.params_to_points(solution, args['num_stimuli'], args['n_dim'])
    LOG.debug('########  Procrustes distance between anchored start and final solution: {}'.format(
        procrustes(start, coordinates)[2])
    )
    return coordinates, solution_ll  # , sum_residual_squares


def spherical_points_of_best_fit(judgments, number_repeats, args, start_points=None):
    """
    Fit spherical coordinates to the observed judgments.

    Args:
        judgments (dict):
            Pairwise comparison judgments
        number_repeats (dict):
            Number of repeats for each comparison key in `judgments`.
        args (dict):
            Model settings. Must include at least:
            - `n_dim`: embedding dimension
            - `num_stimuli`: number of stimuli
            - `sigma`: noise scale
        start_points (array-like, optional):
            Initial coordinates for optimization. If not provided, MDS-derived
            starting points are used.

    Returns:
        tuple:
            (coordinates, solution_ll)
            - coordinates: fitted spherical coordinates
            - solution_ll: negative log-likelihood of the fitted solution

    """
    # for debugging
    fmin_costs = []

    def spherical_cost(stimulus_params, pair_a, pair_b, counts, repeats, parameters):
        curvature = args['scripts']
        vectors = ac.params_to_points(stimulus_params, parameters['num_stimuli'], parameters['n_dim'])
        # mean center points
        vectors = vectors.T
        center = mean(vectors, 1)
        center = center.reshape((parameters['n_dim'], 1)) * ones((1, parameters['num_stimuli']))
        vectors = vectors - center
        # map Euclidean points to sphere
        sph_points = sphere_map(vectors, 1/curvature)
        # compute distances
        distances = spherical_distances(sph_points, 1/curvature)
        probs = find_probabilities(distances, pair_a, pair_b, parameters['noise_st_dev'])
        # calculate log-likelihood, is_bad flag
        ll, is_bad = calculate_ll(counts, probs, repeats)
        LOG.debug('geometry is good: {}'.format(not is_bad))
        # fmin_costs.append(-1 * ll)  # debugging fmin
        return -1 * ll

    # calculate noise before continuing
    args['noise_st_dev'] = args['sigma']
    if start_points is None:
        # if not specified start minimization at coordiates returned by MDS after calculation of win-loss distances
        start_0 = mds.get_coordinates(args['n_dim'], judgments, number_repeats)[0]
    else:
        start_0 = start_points
    start = ac.anchor_points(start_0)

    LOG.debug("########  Procrustes distance between start and anchored start: {}".format(
        procrustes(start, start_0)[2]))
    # turn points to params
    start_params = ac.points_to_params(start)
    LOG.info('######## Run minimization on MDS start points (scipy minimize)')

    pairs_a, pairs_b, response_counts, comp_repeats = util.judgments_to_arrays(judgments, number_repeats)
    solution = gradient_descent(spherical_cost, start_params, pairs_a, pairs_b, response_counts, comp_repeats, args)
    solution_ll = spherical_cost(solution, pairs_a, pairs_b, response_counts, comp_repeats, args)

    coordinates = ac.params_to_points(solution, args['num_stimuli'], args['n_dim'])
    try:
        procr_dist = procrustes(start, coordinates)[2]
    except ValueError:
        procr_dist = 'WARNING - problem with the coordinates. Nans or infs possible.'
    LOG.debug('########  Procrustes distance between anchored start and final solution: {}'.format(
        procr_dist)
    )
    return coordinates, solution_ll  # , sum_residual_squares

