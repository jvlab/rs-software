""" Here I call the modules in the euclidean geometry folder and create a random data set,
with or without noise.

# Comparing models using likelihoods #####################################################
# create a set of stimuli from a Euclidean space
# use them to simulate a pairs of pairs experiment with some noise added to compare and dist
# take a 100 random trials from the experiment and get subject judgments
# using different geometry probabilities:
# - calculate the likelihood of observing these responses
# - plot the box plot of likelihood values for null geometry - 0.5 prob, Euclidean geometry (erf)
#   and 'best geometry'
##########################################################################################
"""

import logging
from numpy import mean, ones, sqrt
from scipy.spatial import procrustes
from scipy import optimize
from analysis.model_fitting import gram_schmidt as gs, mds, pairwise_likelihood_analysis as analysis
from analysis import util
from analysis.model_fitting.pairwise_likelihood_analysis import find_probabilities, calculate_ll
from analysis.geometry.hyperbolic import loid_map, hyperbolic_distances, sphere_map, spherical_distances
from analysis.model_fitting.minimization import gradient_descent

logging.basicConfig(level=logging.DEBUG)
LOG = logging.getLogger(__name__)
LOG.setLevel(logging.INFO)


def points_of_best_fit(judgments, number_repeats, args, start_points=None, minimization='gradient-descent'):
    """
    Given judgments, number of stimuli and dimensions of space,
    find the lowest likelihood points that give that fit
    :param judgments: {'i,j>k,l' : 4, ...}
    :param args: includes n_dim, num_stimuli, no_noise, sigmas
    :param start_points: optional arg, can use to start minimization at ground truth or other location
    :param minimization: gradient-descent (new improvement) or nelder-mead
    :return: optimal (points (x), minimum negative log-likelihood (y))
    @param minimization:
    @param start_points:
    @param args:
    @param judgments:
    @param number_repeats:
    """
    # for debugging
    fmin_costs = []

    def cost(stimulus_params, pair_a, pair_b, counts, repeats, parameters):
        vectors = analysis.params_to_points(stimulus_params, parameters['num_stimuli'], parameters['n_dim'])
        ll, is_bad = analysis.dist_model_ll_vectorized(pair_a, pair_b, counts, repeats, parameters, vectors)
        LOG.debug('geometry is good: {}'.format(not is_bad))
        # fmin_costs.append(-1 * ll)  # debugging fmin
        return -1 * ll

    # calculate noise before continuing
    total_st_dev = sqrt((args['sigmas']['dist'] ** 2) + args['sigmas']['compare'] ** 2)
    args['noise_st_dev'] = total_st_dev
    if start_points is None:
        # if not specified start minimization at coordiates returned by MDS after calculation of win-loss distances
        start_0 = mds.get_coordinates(args['n_dim'], judgments, number_repeats)[0]
    else:
        start_0 = start_points
    start = gs.anchor_points(start_0)
    LOG.info("########  Procrustes distance between start and anchored start: {}".format(
        procrustes(start, start_0)[2]))
    # turn points to params
    start_params = analysis.points_to_params(start)
    LOG.info('######## Run minimization on MDS start points (scipy minimize)')
    # make maxiter 60000 for 5D geometry
    options_min = {
        'disp': True,
        'fatol': args['fatol']}
    if args['n_dim'] < 4:
        options_min['maxiter'] = 85000
    elif args['n_dim'] >= 4:
        options_min['maxiter'] = 110000
    pairs_a, pairs_b, response_counts, comp_repeats = util.judgments_to_arrays(judgments, number_repeats)
    if minimization == 'nelder-mead':
        optimal = optimize.minimize(cost, start_params,
                                    args=(pairs_a, pairs_b, response_counts, comp_repeats, args),
                                    method='Nelder-Mead',
                                    options=options_min
                                    )
        LOG.info(
            '######## {} Iterations completed: {}. Model Dim: {}.'.format(optimal.message, optimal.nit,
                                                                          args['n_dim'])
        )
        solution = optimal.x
        solution_ll = optimal.fun
    else:
        solution = gradient_descent(cost, start_params, pairs_a, pairs_b, response_counts, comp_repeats, args)
        stim = analysis.params_to_points(solution, args['num_stimuli'], args['n_dim'])
        ll_final, is_model_bad = analysis.dist_model_ll_vectorized(pairs_a, pairs_b, response_counts, comp_repeats, args, stim)
        solution_ll = -1 * ll_final
        LOG.info("Final Model is good/ feasible: {}".format(not is_model_bad))

    coordinates = analysis.params_to_points(solution, args['num_stimuli'], args['n_dim'])

    try:
        procr_dist = procrustes(start, coordinates)[2]
    except ValueError:
        procr_dist = 'WARNING - problem with the coordinates. Nans or infs possible.'
    LOG.info('########  Procrustes distance between anchored start and final solution: {}'.format(
        procr_dist)
    )
    return coordinates, solution_ll  # , sum_residual_squares


def hyperbolic_points_of_best_fit(judgments, number_repeats, args, start_points=None):
    """
    Given judgments, number of stimuli and dimensions of space,
    find the lowest likelihood points that give that fit
    :param judgments: {'i,j>k,l' : 4, ...}
    :param args: includes n_dim, num_stimuli, no_noise, sigmas
    :param start_points: optional arg, can use to start minimization at ground truth or other location
    :return: optimal (points (x), minimum negative log-likelihood (y))
    """
    # for debugging
    fmin_costs = []

    def hyperbolic_cost(stimulus_params, pair_a, pair_b, counts, repeats, parameters):
        curvature = args['curvature']
        vectors = analysis.params_to_points(stimulus_params, parameters['num_stimuli'], parameters['n_dim'])
        # mean center points
        vectors = vectors.T
        center = mean(vectors, 1)
        center = center.reshape((parameters['n_dim'], 1)) * ones((1, parameters['num_stimuli']))
        vectors = vectors - center
        # map Euclidean points to hyperboloid
        hyperboloid_points = loid_map(vectors, curvature)
        # compute distances
        distances = hyperbolic_distances(hyperboloid_points, curvature)
        probs = find_probabilities(distances, pair_a, pair_b, parameters['noise_st_dev'], parameters['no_noise'])
        # calculate log-likelihood, is_bad flag
        ll, is_bad = calculate_ll(counts, probs, repeats)
        LOG.debug('geometry is good: {}'.format(not is_bad))
        # fmin_costs.append(-1 * ll)  # debugging fmin
        return -1 * ll

    # calculate noise before continuing
    total_st_dev = sqrt((args['sigmas']['dist'] ** 2) + args['sigmas']['compare'] ** 2)
    args['noise_st_dev'] = total_st_dev
    if start_points is None:
        # if not specified start minimization at coordiates returned by MDS after calculation of win-loss distances
        start_0 = mds.get_coordinates(args['n_dim'], judgments, number_repeats)[0]
    else:
        start_0 = start_points
    start = gs.anchor_points(start_0)

    LOG.info("########  Procrustes distance between start and anchored start: {}".format(
        procrustes(start, start_0)[2]))
    # turn points to params
    start_params = analysis.points_to_params(start)
    LOG.info('######## Run minimization on MDS start points (scipy minimize)')
    # make maxiter 60000 for 5D geometry
    options_min = {
        'disp': True,
        'fatol': args['fatol']}
    if args['n_dim'] < 4:
        options_min['maxiter'] = 85000
    elif args['n_dim'] >= 4:
        options_min['maxiter'] = 110000

    pairs_a, pairs_b, response_counts, comp_repeats = util.judgments_to_arrays(judgments, number_repeats)
    solution = gradient_descent(hyperbolic_cost, start_params, pairs_a, pairs_b, response_counts, comp_repeats, args)
    solution_ll = hyperbolic_cost(solution, pairs_a, pairs_b, response_counts, comp_repeats, args)
    # plt.plot(fmin_costs, 'o-')
    # plt.show()
    coordinates = analysis.params_to_points(solution, args['num_stimuli'], args['n_dim'])
    LOG.info('########  Procrustes distance between anchored start and final solution: {}'.format(
        procrustes(start, coordinates)[2])
    )
    return coordinates, solution_ll  # , sum_residual_squares


def spherical_points_of_best_fit(judgments, number_repeats, args, start_points=None):
    """
    Given judgments, number of stimuli and dimensions of space,
    find the lowest likelihood points that give that fit
    :param judgments: {'i,j>k,l' : 4, ...}
    :param args: includes n_dim, num_stimuli, no_noise, sigmas
    :param start_points: optional arg, can use to start minimization at ground truth or other location
    :return: optimal (points (x), minimum negative log-likelihood (y))
    @param start_points:
    @param args:
    @param judgments:
    @param number_repeats:
    """
    # for debugging
    fmin_costs = []

    def spherical_cost(stimulus_params, pair_a, pair_b, counts, repeats, parameters):
        curvature = args['curvature']
        vectors = analysis.params_to_points(stimulus_params, parameters['num_stimuli'], parameters['n_dim'])
        # mean center points
        vectors = vectors.T
        center = mean(vectors, 1)
        center = center.reshape((parameters['n_dim'], 1)) * ones((1, parameters['num_stimuli']))
        vectors = vectors - center
        # map Euclidean points to sphere
        sph_points = sphere_map(vectors, 1/curvature)
        # compute distances
        distances = spherical_distances(sph_points, 1/curvature)
        probs = find_probabilities(distances, pair_a, pair_b, parameters['noise_st_dev'], parameters['no_noise'])
        # calculate log-likelihood, is_bad flag
        ll, is_bad = calculate_ll(counts, probs, repeats)
        LOG.debug('geometry is good: {}'.format(not is_bad))
        # fmin_costs.append(-1 * ll)  # debugging fmin
        return -1 * ll

    # calculate noise before continuing
    total_st_dev = sqrt((args['sigmas']['dist'] ** 2) + args['sigmas']['compare'] ** 2)
    args['noise_st_dev'] = total_st_dev
    if start_points is None:
        # if not specified start minimization at coordiates returned by MDS after calculation of win-loss distances
        start_0 = mds.get_coordinates(args['n_dim'], judgments, number_repeats)[0]
    else:
        start_0 = start_points
    start = gs.anchor_points(start_0)

    LOG.info("########  Procrustes distance between start and anchored start: {}".format(
        procrustes(start, start_0)[2]))
    # turn points to params
    start_params = analysis.points_to_params(start)
    LOG.info('######## Run minimization on MDS start points (scipy minimize)')
    # make maxiter 60000 for 5D geometry
    options_min = {
        'disp': True,
        'fatol': args['fatol']}
    if args['n_dim'] < 4:
        options_min['maxiter'] = 85000
    elif args['n_dim'] >= 4:
        options_min['maxiter'] = 110000

    pairs_a, pairs_b, response_counts, comp_repeats = util.judgments_to_arrays(judgments, number_repeats)
    solution = gradient_descent(spherical_cost, start_params, pairs_a, pairs_b, response_counts, comp_repeats, args)
    solution_ll = spherical_cost(solution, pairs_a, pairs_b, response_counts, comp_repeats, args)
    # plt.plot(fmin_costs, 'o-')
    # plt.show()
    coordinates = analysis.params_to_points(solution, args['num_stimuli'], args['n_dim'])
    try:
        procr_dist = procrustes(start, coordinates)[2]
    except ValueError:
        procr_dist = 'WARNING - problem with the coordinates. Nans or infs possible.'
    LOG.info('########  Procrustes distance between anchored start and final solution: {}'.format(
        procr_dist)
    )
    return coordinates, solution_ll  # , sum_residual_squares
