"""
Tests of rs_tools.transform: the "subset" and "subset_choices" operations, the file round trip,
the MATLAB entry point (run_files) and the command line.

The data are small made-up coordinate and choice files; the expected results (kept rows,
renumbered trials) are worked out by hand.
"""

import json

import numpy as np
import pytest
import scipy.io as sio

from rs_tools.transform import (
    aux_from_args,
    build_parser,
    load_data,
    main,
    run_files,
    save_data,
    transform,
    transform_file,
)

NAMES = ["bear", "apple", "bee", "cat"]
TRIADIC_COLNAMES = ["ref", "s1", "s2", "N(D(ref, s1) > D(ref, s2))", "N_Repeats(D(ref, s1) > D(ref, s2))"]
TETRADIC_COLNAMES = ["s1", "s2", "s3", "s4", "N(D(s1, s2) > D(s3, s4))", "N_Repeats(D(s1, s2) > D(s3, s4))"]
OOO_COLNAMES = ["s1", "s2", "s3", "N(s1 odd out)", "N(s2 odd out)", "N(s3 odd out)"]


def round_trip(tmp_path, name, **variables):
    """Write variables with scipy and read them back the way transform's callers do."""
    path = tmp_path / name
    sio.savemat(path, variables)
    return load_data(str(path))


@pytest.fixture
def coords(tmp_path):
    # row i of dim1 is i, row i of dim2 is (10 i, 10 i + 1): the rows show which stimuli are kept
    return round_trip(
        tmp_path, "coords.mat",
        dim1=np.arange(4.0).reshape(4, 1),
        dim2=np.array([[0.0, 1.0], [10.0, 11.0], [20.0, 21.0], [30.0, 31.0]]),
        stim_labels=NAMES,
        rawLLs=np.array([[-1.5, -1.2]]),
    )


def labels(value):
    return [str(x).strip() for x in np.atleast_1d(value).ravel()]


# --- operation "subset" (coordinate files) ---------------------------------------------------------

def test_keep_all_is_the_default_and_changes_nothing(coords):
    out = transform(coords)
    assert set(out) == set(coords)
    for key in coords:
        np.testing.assert_array_equal(out[key], coords[key])


def test_subset_regex_cuts_rows_and_keeps_other_variables(coords):
    out = transform(coords, {"filter_type": "regex", "filter_pattern": "^b", "return_indices": True})
    assert labels(out["stim_labels"]) == ["bear", "bee"]
    np.testing.assert_array_equal(out["dim1"], [[0.0], [2.0]])
    np.testing.assert_array_equal(out["dim2"], [[0.0, 1.0], [20.0, 21.0]])
    np.testing.assert_array_equal(out["rawLLs"], coords["rawLLs"])
    # kept_indices are 1-based, as a column, for MATLAB
    np.testing.assert_array_equal(out["kept_indices"], [[1.0], [3.0]])


def test_subset_regex_exclude(coords):
    out = transform(coords, {"filter_type": "regex", "filter_pattern": "^b", "regex_mode": "exclude"})
    assert labels(out["stim_labels"]) == ["apple", "cat"]
    assert "kept_indices" not in out


def test_subset_include_from_a_comma_separated_string(coords):
    out = transform(coords, {"filter_type": "include", "filter_pattern": "cat, apple"})
    assert labels(out["stim_labels"]) == ["apple", "cat"]
    np.testing.assert_array_equal(out["dim1"], [[1.0], [3.0]])


def test_subset_exclude_from_a_list_with_alphabetize(coords):
    out = transform(coords, {"filter_type": "exclude", "filter_pattern": ["apple"], "alphabetize": True})
    assert labels(out["stim_labels"]) == ["bear", "bee", "cat"]
    np.testing.assert_array_equal(out["dim1"], [[0.0], [2.0], [3.0]])


def test_subset_include_with_no_pattern_keeps_nothing(coords):
    with pytest.raises(ValueError, match="No stimuli left"):
        transform(coords, {"filter_type": "include"})


def test_subset_accepts_stim_list_as_the_name_variable(tmp_path):
    data = round_trip(tmp_path, "c.mat", dim1=np.arange(4.0).reshape(4, 1), stim_list=NAMES)
    out = transform(data, {"filter_type": "include", "filter_pattern": ["cat"]})
    assert labels(out["stim_list"]) == ["cat"]


def test_subset_needs_stimulus_names(tmp_path):
    data = round_trip(tmp_path, "c.mat", dim1=np.zeros((4, 1)))
    with pytest.raises(ValueError, match="No stimulus name variable"):
        transform(data)


def test_subset_needs_coordinates(tmp_path):
    data = round_trip(tmp_path, "c.mat", stim_labels=NAMES)
    with pytest.raises(ValueError, match="No 'dimN' coordinate variables"):
        transform(data)


def test_subset_needs_one_row_per_name(tmp_path):
    data = round_trip(tmp_path, "c.mat", dim1=np.zeros((3, 1)), stim_labels=NAMES)
    with pytest.raises(ValueError, match="'dim1' has 3 rows but there are 4 stimulus names"):
        transform(data)


@pytest.mark.parametrize("aux, message", [
    ({"filter_type": "regex"}, "needs a filter_pattern"),
    ({"filter_type": "regex", "filter_pattern": ["^b"]}, "single text string"),
    ({"filter_type": "nearest"}, "Unknown filter_type"),
    ({"operation": "fit"}, "Unknown operation"),
])
def test_option_errors(coords, aux, message):
    with pytest.raises(ValueError, match=message):
        transform(coords, aux)


def test_unknown_option_gives_a_warning(coords):
    with pytest.warns(UserWarning, match="Ignoring unknown aux field.*colour"):
        transform(coords, {"colour": "red"})


def test_dimensions_and_iterations_are_accepted_without_effect(coords):
    out = transform(coords, {"dimensions": 2, "iterations": 10})
    np.testing.assert_array_equal(out["dim2"], coords["dim2"])


# --- operation "subset_choices" (choice files) -----------------------------------------------------

def choice_data(tmp_path, responses, colnames, names=NAMES, colnames_key="responses_colnames", **extra):
    variables = {"responses": np.asarray(responses, dtype=float), colnames_key: colnames, "stim_list": names}
    variables.update(extra)
    return round_trip(tmp_path, "choices.mat", **variables)


# triadic: ref, s1, s2, count, trials (stimuli numbered from 1)
TRIADIC = [[1, 2, 3, 2, 4],
           [2, 3, 4, 1, 4],
           [3, 4, 2, 0, 3]]


def test_subset_choices_triadic(tmp_path):
    data = choice_data(tmp_path, TRIADIC, TRIADIC_COLNAMES, note="kept as it is")
    # drop stimulus 1 (bear): rows 2 and 3 stay; 2, 3, 4 become 1, 2, 3; counts unchanged
    out = transform(data, {"operation": "subset_choices", "filter_type": "exclude",
                           "filter_pattern": ["bear"], "return_indices": True})
    np.testing.assert_array_equal(out["responses"], [[1, 2, 3, 1, 4], [2, 3, 1, 0, 3]])
    assert labels(out["stim_list"]) == ["apple", "bee", "cat"]
    assert labels(out["responses_colnames"]) == TRIADIC_COLNAMES
    assert labels(out["note"]) == ["kept as it is"]
    np.testing.assert_array_equal(out["kept_indices"], [[2.0], [3.0], [4.0]])


def test_subset_choices_char_array_names_keep_their_padding(tmp_path):
    data = choice_data(tmp_path, TRIADIC, TRIADIC_COLNAMES)
    out = transform(data, {"operation": "subset_choices", "filter_type": "include",
                           "filter_pattern": ["apple", "bee", "cat"]})
    # a MATLAB char array: the kept rows, unchanged (same width)
    assert out["stim_list"].dtype == data["stim_list"].dtype
    np.testing.assert_array_equal(out["stim_list"], data["stim_list"][[1, 2, 3]])


def test_subset_choices_cell_array_names_stay_a_cell_array(tmp_path):
    cell = np.empty((4, 1), dtype=object)
    for i, name in enumerate(NAMES):
        cell[i, 0] = name
    data = choice_data(tmp_path, TRIADIC, TRIADIC_COLNAMES, names=cell)
    assert data["stim_list"].dtype == object
    out = transform(data, {"operation": "subset_choices", "filter_type": "exclude", "filter_pattern": ["bear"]})
    assert out["stim_list"].dtype == object and out["stim_list"].shape == (3, 1)
    assert labels(out["stim_list"]) == ["apple", "bee", "cat"]


def test_subset_choices_alphabetize_renumbers_in_the_new_order(tmp_path):
    data = choice_data(tmp_path, TRIADIC, TRIADIC_COLNAMES)
    # keep apple, bee, cat in alphabetical order: apple (2) --> 1, bee (3) --> 2, cat (4) --> 3
    out = transform(data, {"operation": "subset_choices", "filter_type": "exclude",
                           "filter_pattern": ["bear"], "alphabetize": True})
    np.testing.assert_array_equal(out["responses"], [[1, 2, 3, 1, 4], [2, 3, 1, 0, 3]])


def test_subset_choices_tetradic(tmp_path):
    tetradic = [[1, 2, 3, 4, 1, 5],
                [2, 3, 4, 2, 2, 5]]
    data = choice_data(tmp_path, tetradic, TETRADIC_COLNAMES)
    # keep 2, 3, 4 --> 1, 2, 3: only the second row has no stimulus 1
    out = transform(data, {"operation": "subset_choices", "filter_type": "regex",
                           "filter_pattern": "^bear$", "regex_mode": "exclude"})
    np.testing.assert_array_equal(out["responses"], [[1, 2, 3, 1, 2, 5]])


def test_subset_choices_odd_one_out_uses_three_stimulus_columns(tmp_path):
    ooo = [[1, 2, 3, 4, 1, 0],
           [2, 3, 4, 0, 3, 2]]
    data = choice_data(tmp_path, ooo, OOO_COLNAMES)
    out = transform(data, {"operation": "subset_choices", "filter_type": "exclude", "filter_pattern": ["bear"]})
    # columns 4 to 6 are counts, not stimulus numbers, and are not renumbered
    np.testing.assert_array_equal(out["responses"], [[1, 2, 3, 0, 3, 2]])


def test_subset_choices_reads_response_colnames_too(tmp_path):
    data = choice_data(tmp_path, [[1, 2, 3, 4, 1, 5]], TETRADIC_COLNAMES, colnames_key="response_colnames")
    out = transform(data, {"operation": "subset_choices"})
    np.testing.assert_array_equal(out["responses"], [[1, 2, 3, 4, 1, 5]])


@pytest.mark.parametrize("responses, colnames, aux, message", [
    (TRIADIC, TRIADIC_COLNAMES, {"filter_type": "include", "filter_pattern": ["bear", "cat"]}, "No trials left after filtering"),
    ([[1, 2, 3, 4, 5, 6, 7]], [f"c{i}" for i in range(7)], {}, "has 7 columns"),
    ([[1, 2, 3, 4, 5, 6]], ["a", "b", "c", "d", "e", "f"], {}, "tetradic or odd-one-out"),
    ([[1, 2, 3.5, 1, 4]], TRIADIC_COLNAMES, {}, "whole numbers"),
    ([[1, 2, 5, 1, 4]], TRIADIC_COLNAMES, {}, "uses stimulus numbers 1 to 5, but there are 4 stimulus names"),
])
def test_subset_choices_errors(tmp_path, responses, colnames, aux, message):
    data = choice_data(tmp_path, responses, colnames)
    with pytest.raises(ValueError, match=message):
        transform(data, dict(aux, operation="subset_choices"))


@pytest.mark.parametrize("missing", ["responses", "stim_list"])
def test_subset_choices_needs_responses_and_names(tmp_path, missing):
    data = choice_data(tmp_path, TRIADIC, TRIADIC_COLNAMES)
    del data[missing]
    with pytest.raises(ValueError, match=f"No '{missing}' variable"):
        transform(data, {"operation": "subset_choices"})


def test_subset_choices_needs_trials():
    data = {"responses": np.zeros((0, 5)), "stim_list": np.array(NAMES), "responses_colnames": TRIADIC_COLNAMES}
    with pytest.raises(ValueError, match="no trials"):
        transform(data, {"operation": "subset_choices"})


# --- files, the MATLAB entry point and the command line --------------------------------------------

def test_save_and_load_keep_whole_numbers_as_doubles(tmp_path):
    path = tmp_path / "w.mat"
    save_data(str(path), {"responses": np.array([[1.0, 2.0, 3.0]])})
    data = load_data(str(path))
    assert data["responses"].dtype == np.float64


def test_save_data_to_npz(tmp_path):
    path = tmp_path / "out.npz"
    save_data(str(path), {"dim1": np.array([[1.0], [2.0]])})
    with np.load(path) as saved:
        np.testing.assert_array_equal(saved["dim1"], [[1.0], [2.0]])


def write_coords_file(tmp_path):
    path = tmp_path / "in.mat"
    sio.savemat(path, {"dim1": np.arange(4.0).reshape(4, 1), "stim_labels": NAMES})
    return path


def test_transform_file(tmp_path):
    out = tmp_path / "out.mat"
    transform_file(str(write_coords_file(tmp_path)), str(out), {"filter_type": "include", "filter_pattern": ["bee"]})
    data = load_data(str(out))
    assert labels(data["stim_labels"]) == ["bee"]
    np.testing.assert_array_equal(data["dim1"], [[2.0]])


def test_run_files_takes_options_as_json(tmp_path):
    # this is how rs_subset_coordsets.m calls Python
    out = tmp_path / "out.mat"
    run_files(write_coords_file(tmp_path), out, json.dumps({"filter_type": "regex", "filter_pattern": "t$"}))
    assert labels(load_data(str(out))["stim_labels"]) == ["cat"]


def test_command_line(tmp_path, capsys):
    out = tmp_path / "out.mat"
    code = main(["--input", str(write_coords_file(tmp_path)), "--output", str(out),
                 "--filter-type", "regex", "--filter-pattern", "^b", "--alphabetize"])
    assert code == 0
    assert "Saved" in capsys.readouterr().out
    assert labels(load_data(str(out))["stim_labels"]) == ["bear", "bee"]


def test_command_line_reports_errors(tmp_path, capsys):
    code = main(["--input", str(write_coords_file(tmp_path)), "--output", str(tmp_path / "o.mat"),
                 "--filter-type", "regex", "--filter-pattern", "^z"])
    assert code == 2
    assert "error: No stimuli left" in capsys.readouterr().err


def test_command_line_options_override_an_aux_file(tmp_path):
    aux_file = tmp_path / "aux.json"
    aux_file.write_text(json.dumps({"filter_type": "include", "filter_pattern": "bear", "regex_mode": "exclude"}))
    args = build_parser().parse_args(["--input", "a.mat", "--output", "b.mat", "--aux-file", str(aux_file),
                                      "--filter-pattern", "cat", "--dimensions", "3"])
    assert aux_from_args(args) == {"filter_type": "include", "filter_pattern": "cat",
                                   "regex_mode": "exclude", "dimensions": 3}
