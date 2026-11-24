"""
Tests of rs_tools.subset_stimuli: the stimulus selection, and the choice-file, coordinate-file
and odd-one-out wrappers used by the apps.

Expected values are worked out by hand from small made-up stimulus lists and trial tables.
"""

import numpy as np
import pytest
import scipy.io as sio

from rs_tools.subset_stimuli import (
    _restore_empty_structs,
    detect_choice_format,
    load_ooo_file,
    save_choice_file,
    save_coords_file,
    save_ooo_file,
    subset_choice_file,
    subset_coords_file,
    subset_ooo_file,
    subset_stimuli,
    validate_choice_responses,
    validate_ooo_responses,
)

NAMES = ["bear", "apple", "bee", "cat"]

TRIADIC_COLNAMES = ["ref", "s1", "s2", "N(D(ref, s1) > D(ref, s2))", "N_Repeats(D(ref, s1) > D(ref, s2))"]
TETRADIC_COLNAMES = ["s1", "s2", "s3", "s4", "N(D(s1, s2) > D(s3, s4))", "N_Repeats(D(s1, s2) > D(s3, s4))"]
OOO_COLNAMES = ["s1", "s2", "s3", "N(s1 odd out)", "N(s2 odd out)", "N(s3 odd out)"]


def write_mat(path, **variables):
    sio.savemat(path, variables)
    return str(path)


# --- subset_stimuli: which stimuli are kept, and in which order ---------------------------------

def test_include_names_keeps_original_order():
    # the order of the include list does not matter: kept stimuli stay in file order
    assert subset_stimuli(NAMES, include=["cat", "bear"]) == (["bear", "cat"], [0, 3])


def test_include_positions_and_names_mixed():
    assert subset_stimuli(NAMES, include=[2, "apple"]) == (["apple", "bee"], [1, 2])


def test_exclude_names_keeps_the_rest():
    assert subset_stimuli(NAMES, exclude=["apple"]) == (["bear", "bee", "cat"], [0, 2, 3])


def test_exclude_nothing_keeps_everything():
    assert subset_stimuli(NAMES, exclude=[]) == (NAMES, [0, 1, 2, 3])


def test_regex_include_matches_anywhere_in_the_name():
    # "e" occurs in bear, apple and bee, not in cat
    assert subset_stimuli(NAMES, regex="e") == (["bear", "apple", "bee"], [0, 1, 2])


def test_regex_anchored():
    assert subset_stimuli(NAMES, regex="^b") == (["bear", "bee"], [0, 2])


def test_regex_exclude_drops_matches():
    assert subset_stimuli(NAMES, regex="^b", regex_mode="exclude") == (["apple", "cat"], [1, 3])


def test_alphabetize_sorts_names_and_indices_together():
    names, indices = subset_stimuli(NAMES, exclude=[], alphabetize=True)
    assert names == ["apple", "bear", "bee", "cat"]
    assert indices == [1, 0, 2, 3]
    assert [NAMES[i] for i in indices] == names


@pytest.mark.parametrize("kwargs", [{}, {"include": ["bear"], "exclude": ["cat"]}])
def test_exactly_one_selection_mode_is_required(kwargs):
    with pytest.raises(ValueError, match="exactly one"):
        subset_stimuli(NAMES, **kwargs)


def test_bad_regex_mode():
    with pytest.raises(ValueError, match="regex_mode"):
        subset_stimuli(NAMES, regex="b", regex_mode="keep")


def test_empty_stimulus_list():
    with pytest.raises(ValueError, match="empty"):
        subset_stimuli([], exclude=[])


def test_unknown_name():
    with pytest.raises(ValueError, match="not found: 'dog'"):
        subset_stimuli(NAMES, include=["dog"])


@pytest.mark.parametrize("position", [-1, 4])
def test_position_out_of_range(position):
    with pytest.raises(ValueError, match="out of range"):
        subset_stimuli(NAMES, include=[position])


def test_nothing_left():
    with pytest.raises(ValueError, match="No stimuli left after filtering"):
        subset_stimuli(NAMES, regex="^z")


def test_invalid_regex_with_leading_star_gives_a_hint():
    with pytest.raises(ValueError, match="valid pattern.*A leading \\*"):
        subset_stimuli(NAMES, regex="*e")


def test_invalid_regex_without_hint():
    with pytest.raises(ValueError, match="valid pattern") as err:
        subset_stimuli(NAMES, regex="(b")
    assert "leading" not in str(err.value)


# --- choice files as resp/rep dictionaries --------------------------------------------------------

def triadic_trials():
    # keys ((ref, s1), (ref, s2)), 0-based; values: count and repeats
    resp = {((0, 1), (0, 2)): 3, ((0, 1), (0, 3)): 1, ((1, 2), (1, 3)): 2}
    rep = {((0, 1), (0, 2)): 4, ((0, 1), (0, 3)): 5, ((1, 2), (1, 3)): 6}
    return resp, rep


def test_subset_choice_file_triadic_drops_and_renumbers():
    resp, rep = triadic_trials()
    # drop stimulus 0 (bear): only the trial without it stays, and 1, 2, 3 become 0, 1, 2
    new_resp, new_rep, kept = subset_choice_file(NAMES, resp, rep, exclude=["bear"])
    assert kept == ["apple", "bee", "cat"]
    assert new_resp == {((0, 1), (0, 2)): 2}
    assert new_rep == {((0, 1), (0, 2)): 6}


def test_subset_choice_file_tetradic():
    resp = {((0, 1), (2, 3)): 1, ((1, 2), (3, 0)): 2, ((1, 2), (2, 3)): 3}
    rep = {key: 10 for key in resp}
    # keep 1, 2, 3 --> new numbers 0, 1, 2; the trials with stimulus 0 are dropped
    new_resp, new_rep, kept = subset_choice_file(NAMES, resp, rep, include=[1, 2, 3])
    assert kept == ["apple", "bee", "cat"]
    assert new_resp == {((0, 1), (1, 2)): 3}
    assert new_rep == {((0, 1), (1, 2)): 10}


def test_save_choice_file_triadic(tmp_path):
    resp, rep = triadic_trials()
    out = tmp_path / "tri.mat"
    save_choice_file(str(out), resp, rep, NAMES)
    raw = sio.loadmat(out)
    # keys are written 1-based, one row per trial, in dictionary order
    expected = np.array([[1, 2, 3, 3, 4], [1, 2, 4, 1, 5], [2, 3, 4, 2, 6]], dtype=float)
    np.testing.assert_array_equal(raw["responses"], expected)
    assert [c.strip() for c in raw["responses_colnames"]] == TRIADIC_COLNAMES
    assert [s.strip() for s in raw["stim_list"]] == NAMES


def test_save_choice_file_tetradic(tmp_path):
    resp = {((0, 1), (2, 3)): 1, ((1, 2), (3, 0)): 2}
    rep = {((0, 1), (2, 3)): 7, ((1, 2), (3, 0)): 8}
    out = tmp_path / "tet.mat"
    save_choice_file(str(out), resp, rep, NAMES, readme_note="made in a test")
    raw = sio.loadmat(out)
    np.testing.assert_array_equal(raw["responses"], [[1, 2, 3, 4, 1, 7], [2, 3, 4, 1, 2, 8]])
    assert [c.strip() for c in raw["responses_colnames"]] == TETRADIC_COLNAMES
    assert raw["readme"][0] == "made in a test"


@pytest.mark.xfail(strict=True, reason="save_choice_file guesses triadic or tetradic from the first trial key; a tetradic key whose first and third stimuli are the same is taken as triadic, so the file is written wrongly or the save fails")
def test_save_choice_file_tetradic_with_shared_first_stimulus(tmp_path):
    resp = {((0, 1), (0, 2)): 1, ((1, 2), (0, 3)): 2}
    rep = {((0, 1), (0, 2)): 5, ((1, 2), (0, 3)): 5}
    out = tmp_path / "tet.mat"
    save_choice_file(str(out), resp, rep, NAMES)
    assert sio.loadmat(out)["responses"].shape == (2, 6)


def test_save_choice_file_refuses_an_empty_file(tmp_path):
    with pytest.raises(ValueError, match="empty choice file"):
        save_choice_file(str(tmp_path / "x.mat"), {}, {}, NAMES)


# --- coordinate files -----------------------------------------------------------------------------

def test_subset_coords_file_cuts_every_dimension():
    coords = {1: np.arange(4.0).reshape(4, 1), 2: np.arange(8.0).reshape(4, 2)}
    new_coords, kept = subset_coords_file(NAMES, coords, regex="^b")
    assert kept == ["bear", "bee"]
    np.testing.assert_array_equal(new_coords[1], [[0.0], [2.0]])
    np.testing.assert_array_equal(new_coords[2], [[0.0, 1.0], [4.0, 5.0]])


def test_save_coords_file_round_trip(tmp_path):
    coords = {1: np.array([[1.0], [2.0]]), 2: np.array([[1.0, 2.0], [3.0, 4.0]])}
    out = tmp_path / "coords.mat"
    save_coords_file(str(out), coords, ["bear", "cat"],
                     extra_fields={"rawLLs": np.array([[-1.5, -1.2]]), "pipeline": None})
    raw = sio.loadmat(out)
    np.testing.assert_array_equal(raw["dim1"], coords[1])
    np.testing.assert_array_equal(raw["dim2"], coords[2])
    assert [s.strip() for s in raw["stim_labels"]] == ["bear", "cat"]
    np.testing.assert_array_equal(raw["rawLLs"], [[-1.5, -1.2]])
    # None (scipy's form of an empty MATLAB struct) is written as a 1x1 struct with no fields,
    # which scipy reads back as a 1x1 object array holding None (savemat cannot write None itself)
    assert raw["pipeline"].shape == (1, 1) and raw["pipeline"][0, 0] is None


def test_save_coords_file_refuses_no_dimensions(tmp_path):
    with pytest.raises(ValueError, match="no fitted dimensions"):
        save_coords_file(str(tmp_path / "x.mat"), {}, NAMES)


# --- _restore_empty_structs: metadata written back as MATLAB had it -------------------------------

def test_restore_none_becomes_empty_struct():
    assert _restore_empty_structs(None) == {}


def test_restore_one_by_zero_becomes_zero_by_zero():
    out = _restore_empty_structs(np.zeros((1, 0)))
    assert out.shape == (0, 0)


def test_restore_one_by_one_cell_holding_none():
    cell = np.empty((1, 1), dtype=object)
    assert _restore_empty_structs(cell) == {}


def test_restore_walks_cells_and_structs():
    cell = np.empty((1, 2), dtype=object)
    cell[0, 0] = None
    cell[0, 1] = np.zeros((1, 0))
    out = _restore_empty_structs(cell)
    assert out[0, 0] == {} and out[0, 1].shape == (0, 0)
    struct = np.zeros((1, 1), dtype=[("empty", object), ("value", object)])
    struct[0, 0]["empty"] = None
    struct[0, 0]["value"] = np.array([[3.0]])
    out = _restore_empty_structs(struct)
    assert out[0, 0]["empty"] == {}
    np.testing.assert_array_equal(out[0, 0]["value"], [[3.0]])


def test_restore_leaves_other_values_alone():
    value = np.array([[1.0, 2.0]])
    assert _restore_empty_structs(value) is value
    assert _restore_empty_structs("text") == "text"


# --- detect_choice_format -------------------------------------------------------------------------

@pytest.mark.parametrize("colnames, expected", [
    (TRIADIC_COLNAMES, "triadic"),
    (TETRADIC_COLNAMES, "tetradic"),
    (OOO_COLNAMES, "odd_one_out"),
    (["a", "b", "c", "d", "e"], "unknown"),
])
def test_detect_choice_format(tmp_path, colnames, expected):
    path = write_mat(tmp_path / "c.mat", responses=np.ones((2, len(colnames))), responses_colnames=colnames)
    assert detect_choice_format(path) == expected


def test_detect_choice_format_accepts_response_colnames(tmp_path):
    path = write_mat(tmp_path / "c.mat", responses=np.ones((2, 6)), response_colnames=TETRADIC_COLNAMES)
    assert detect_choice_format(path) == "tetradic"


def test_detect_choice_format_without_column_names(tmp_path):
    path = write_mat(tmp_path / "c.mat", responses=np.ones((2, 5)))
    assert detect_choice_format(path) == "unknown"


# --- validate_choice_responses --------------------------------------------------------------------

def triadic_file(tmp_path, responses, colnames=TRIADIC_COLNAMES):
    return write_mat(tmp_path / "c.mat", responses=np.asarray(responses, dtype=float),
                     responses_colnames=colnames, stim_list=NAMES)


GOOD_TRIADIC = [[1, 2, 3, 2, 4], [2, 3, 4, 0, 4]]


def test_validate_good_triadic_file(tmp_path):
    assert validate_choice_responses(triadic_file(tmp_path, GOOD_TRIADIC), "triadic", 4) is None


def test_validate_good_tetradic_file(tmp_path):
    path = triadic_file(tmp_path, [[1, 2, 3, 4, 1, 3], [4, 3, 2, 1, 3, 3]], TETRADIC_COLNAMES)
    assert validate_choice_responses(path, "tetradic", 4) is None


@pytest.mark.parametrize("responses, message", [
    ([[1, 2, 3, 2.5, 4], [2, 3, 4, 0, 4]], "whole numbers"),
    ([[1, 2, 5, 2, 4], [2, 3, 4, 0, 4]], "aren't all valid"),
    ([[0, 2, 3, 2, 4], [2, 3, 4, 0, 4]], "aren't all valid"),
    ([[1, 2, 3, 2, 4], [2, 2, 4, 0, 4]], "compares a stimulus to itself"),
    ([[1, 2, 3, -1, 4], [2, 3, 4, 0, 4]], "count is negative"),
    ([[1, 2, 3, 0, -1], [2, 3, 4, 0, 4]], "repeat count is negative"),
    ([[1, 2, 3, 5, 4], [2, 3, 4, 0, 4]], "greater than its repeat total"),
])
def test_validate_rejects_bad_values(tmp_path, responses, message):
    with pytest.raises(ValueError, match=message):
        validate_choice_responses(triadic_file(tmp_path, responses), "triadic", 4)


def test_validate_rejects_wrong_column_count(tmp_path):
    with pytest.raises(ValueError, match="should have 6 columns"):
        validate_choice_responses(triadic_file(tmp_path, GOOD_TRIADIC), "tetradic", 4)


def test_validate_rejects_missing_index_columns(tmp_path):
    colnames = ["a", "s1", "s2", "N(x)", "N_Repeats(x)"]
    with pytest.raises(ValueError, match="missing the expected column"):
        validate_choice_responses(triadic_file(tmp_path, GOOD_TRIADIC, colnames), "triadic", 4)


def test_validate_rejects_missing_count_columns(tmp_path):
    colnames = ["ref", "s1", "s2", "count", "repeats"]
    with pytest.raises(ValueError, match="count/repeat columns"):
        validate_choice_responses(triadic_file(tmp_path, GOOD_TRIADIC, colnames), "triadic", 4)


def test_validate_rejects_other_formats(tmp_path):
    with pytest.raises(ValueError, match="only handles triadic/tetradic"):
        validate_choice_responses(triadic_file(tmp_path, GOOD_TRIADIC), "odd_one_out", 4)


def test_validate_rejects_a_file_without_responses(tmp_path):
    path = write_mat(tmp_path / "c.mat", stim_list=NAMES)
    with pytest.raises(ValueError, match="no 'responses'"):
        validate_choice_responses(path, "triadic", 4)


def test_validate_rejects_a_table_that_is_not_two_dimensional(tmp_path):
    path = write_mat(tmp_path / "c.mat", responses=np.ones((2, 5, 2)), responses_colnames=TRIADIC_COLNAMES)
    with pytest.raises(ValueError, match="2-D table"):
        validate_choice_responses(path, "triadic", 4)


# --- odd-one-out files ----------------------------------------------------------------------------

GOOD_OOO = np.array([[1, 2, 3, 5, 1, 0], [2, 3, 4, 0, 2, 4], [1, 3, 4, 1, 1, 1]], dtype=float)


def ooo_file(tmp_path, rows=GOOD_OOO, **extra):
    variables = {"responses": rows, "responses_colnames": OOO_COLNAMES, "stim_list": NAMES}
    variables.update(extra)
    return write_mat(tmp_path / "ooo.mat", **variables)


def test_load_ooo_file(tmp_path):
    rows, names = load_ooo_file(ooo_file(tmp_path))
    np.testing.assert_array_equal(rows, GOOD_OOO)
    assert names == NAMES


def test_load_ooo_file_needs_stim_list_and_responses(tmp_path):
    path = write_mat(tmp_path / "x.mat", responses=GOOD_OOO)
    with pytest.raises(ValueError, match="missing 'stim_list' or 'responses'"):
        load_ooo_file(path)


def test_load_ooo_file_needs_six_columns(tmp_path):
    with pytest.raises(ValueError, match="expected 6 columns"):
        load_ooo_file(ooo_file(tmp_path, rows=GOOD_OOO[:, :5]))


def test_validate_good_ooo_rows():
    assert validate_ooo_responses(GOOD_OOO, 4) is None


@pytest.mark.parametrize("row, message", [
    ([1, 2, 3, 0.5, 0, 0], "whole numbers"),
    ([1, 2, 5, 0, 0, 0], "aren't all valid"),
    ([1, 1, 3, 0, 0, 0], "repeats a stimulus"),
    ([1, 2, 3, 0, -2, 0], "negative"),
])
def test_validate_ooo_rejects_bad_rows(row, message):
    rows = np.vstack([GOOD_OOO, np.array(row, dtype=float)])
    with pytest.raises(ValueError, match=message):
        validate_ooo_responses(rows, 4)


def test_subset_ooo_file_drops_and_renumbers():
    # drop stimulus 1 (bear): only the triplet 2, 3, 4 stays, renumbered 1, 2, 3; counts unchanged
    new_rows, kept = subset_ooo_file(NAMES, GOOD_OOO, exclude=["bear"])
    assert kept == ["apple", "bee", "cat"]
    np.testing.assert_array_equal(new_rows, [[1, 2, 3, 0, 2, 4]])


def test_subset_ooo_file_with_no_triplet_left():
    new_rows, kept = subset_ooo_file(NAMES, GOOD_OOO, include=["bear", "apple"])
    assert kept == ["bear", "apple"]
    assert new_rows.shape == (0, 6)


def test_save_ooo_file_round_trip(tmp_path):
    out = tmp_path / "ooo_out.mat"
    save_ooo_file(str(out), GOOD_OOO, NAMES)
    rows, names = load_ooo_file(str(out))
    np.testing.assert_array_equal(rows, GOOD_OOO)
    assert names == NAMES


def test_save_ooo_file_refuses_an_empty_file(tmp_path):
    with pytest.raises(ValueError, match="empty odd-one-out file"):
        save_ooo_file(str(tmp_path / "x.mat"), np.zeros((0, 6)), NAMES)
