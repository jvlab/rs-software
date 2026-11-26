from src.rs_py.utils import mds_embedding as mds


def test_heuristic_dist_returns_correct_distance_dict_for_seeding():
    responses = {
        ((0, 1), '>', (0, 2)): 0,  # points 0, 1, 2, 3 labelled clockwise
        ((0, 1), '>', (0, 3)): 0,  # ..... 0 x---x 1
        ((0, 1), '>', (1, 2)): 0,  # ...    /     \
        ((0, 1), '>', (1, 3)): 0,  # ...   /       \
        ((0, 1), '>', (2, 3)): 0,  # .. 3 x---------x2
        ((0, 2), '>', (0, 3)): 1,
        ((0, 2), '>', (1, 2)): 1,
        ((0, 2), '>', (1, 3)): 0,
        ((0, 2), '>', (2, 3)): 1,
        ((0, 3), '>', (1, 2)): 1,
        ((0, 3), '>', (1, 3)): 0,
        ((0, 3), '>', (2, 3)): 1,
        ((1, 2), '>', (1, 3)): 0,
        ((1, 2), '>', (2, 3)): 1,
        ((1, 3), '>', (2, 3)): 1
    }
    repeats = {key: 1 for key in responses}
    distances = mds.heuristic_distances(responses, repeats)

    assert len(distances) == 6
    assert distances[(0, 1)] == 1 / 7.0
    assert distances[(0, 2)] == 5 / 7.0
    assert distances[(0, 3)] == 4 / 7.0
    assert distances[(1, 2)] == 3 / 7.0
    assert distances[(1, 3)] == 6 / 7.0
    assert distances[(2, 3)] == 2 / 7.0


def test_heuristic_dist_returns_correct_distance_dict_even_with_repeats():
    responses = {
        ((0, 1), '>', (0, 2)): 0,  # points 0, 1, 2, 3 labelled clockwise
        ((0, 1), '>', (0, 3)): 0,  # ..... 0 x---x 1
        ((0, 1), '>', (1, 2)): 0,  # ...    /     \
        ((0, 1), '>', (1, 3)): 0,  # ...   /       \
        ((0, 1), '>', (2, 3)): 0,  # .. 3 x---------x2
        ((0, 2), '>', (0, 3)): 5,
        ((0, 2), '>', (1, 2)): 5,
        ((0, 2), '>', (1, 3)): 0,
        ((0, 2), '>', (2, 3)): 5,
        ((0, 3), '>', (1, 2)): 5,
        ((0, 3), '>', (1, 3)): 0,
        ((0, 3), '>', (2, 3)): 5,
        ((1, 2), '>', (1, 3)): 0,
        ((1, 2), '>', (2, 3)): 5,
        ((1, 3), '>', (2, 3)): 5
    }
    repeats = {key: 5 for key in responses}
    distances = mds.heuristic_distances(responses, repeats)

    assert len(distances) == 6
    assert distances[(0, 1)] == (5 * (1 - 1) + 1) / 27.0
    assert distances[(0, 2)] == (5 * (5 - 1) + 1) / 27.0
    assert distances[(0, 3)] == (5 * (4 - 1) + 1) / 27.0
    assert distances[(1, 2)] == (5 * (3 - 1) + 1) / 27.0
    assert distances[(1, 3)] == (5 * (6 - 1) + 1) / 27.0
    assert distances[(2, 3)] == (5 * (2 - 1) + 1) / 27.0


def test_format_dist_puts_distances_in_right_place_in_matrix():
    distance_dict = {
        (0, 2): 2,
        (5, 6): 1,
        (1, 6): 6,
        (4, 4): 7
    }
    d = mds.format_distances(distance_dict)

    assert d.shape == (7, 7)
    assert d[0, 0] == 0
    assert d[6, 6] == 0
    assert d[4, 4] == 7
    assert d[2, 0] == 2
    assert d[1, 6] == 6
    assert d[6, 1] == 6
    assert d[4, 6] == 0
    assert d[6, 5] == 1
