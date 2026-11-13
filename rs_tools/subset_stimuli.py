"""
subset_stimuli — Select a subset of stimuli from a stimulus list, by index, name, or regex.

This is the format-agnostic core of the stimulus filtering feature (JV, meeting
2026-09-23). It only knows about a plain list of stimulus names -- it has no
idea whether those names came from a choice file (`stim_list`) or a
coordinate file (`stim_labels`). The choice-file and coordinate-file specific
logic (renumbering trials, selecting matching rows in dimN arrays, etc.) is
built on top of this as separate wrappers, so both file types share one
selection implementation instead of two.
"""

import re


def subset_stimuli(stim_list, include=None, exclude=None, regex=None,
                    regex_mode="include", alphabetize=False):
    """
    Decide which stimuli to keep from a stimulus list.

    Exactly one of `include`, `exclude`, or `regex` must be given.

    Args:
        stim_list: list of stimulus names, in their original index order (0-indexed)
        include: list of names and/or 0-indexed integer positions to keep
        exclude: list of names and/or 0-indexed integer positions to drop
        regex: a regex pattern string, matched against each stimulus name
        regex_mode: "include" to keep matches (default), "exclude" to drop matches
        alphabetize: if True, sort the kept names alphabetically;
                     if False (default), keep them in their original order

    Returns:
        kept_names: list of stimulus names that were kept, in the chosen order
        kept_indices: list of each kept name's position in the ORIGINAL stim_list
                       (0-indexed) -- callers use this to select the matching
                       rows/columns in whichever file format they're working with
    """
    modes_given = sum(x is not None for x in (include, exclude, regex))
    if modes_given != 1:
        raise ValueError(
            "Give exactly one of `include`, `exclude`, or `regex` (got {}).".format(modes_given))
    if regex_mode not in ("include", "exclude"):
        raise ValueError("regex_mode must be 'include' or 'exclude', got {!r}.".format(regex_mode))

    if len(stim_list) == 0:
        raise ValueError(
            "This file's stimulus list is empty (0 names), so there is nothing to filter. "
            "Check that the file has a 'stim_labels' (or 'stim_list') variable with the stimulus names.")

    name_to_index = {name: i for i, name in enumerate(stim_list)}

    def _resolve(items):
        resolved = set()
        for item in items:
            if isinstance(item, str):
                if item not in name_to_index:
                    raise ValueError(f"Stimulus name not found: {item!r}")
                resolved.add(name_to_index[item])
            else:
                if not (0 <= item < len(stim_list)):
                    raise ValueError(f"Stimulus index out of range: {item}")
                resolved.add(item)
        return resolved

    if include is not None:
        keep = _resolve(include)
    elif exclude is not None:
        keep = set(range(len(stim_list))) - _resolve(exclude)
    else:
        try:
            pattern = re.compile(regex)
        except re.error as e:
            hint = ""
            if regex.lstrip().startswith(("*", "+", "?")):
                hint = " A leading * needs something before it -- to match names ending in m use m$, or .*m to match anything followed by m."
            raise ValueError(f"'{regex}' isn't a valid pattern yet ({e}).{hint}") from None
        matched = {i for i, name in enumerate(stim_list) if pattern.search(name)}
        keep = matched if regex_mode == "include" else set(range(len(stim_list))) - matched

    kept_indices = sorted(keep)
    kept_names = [stim_list[i] for i in kept_indices]

    if alphabetize:
        order = sorted(range(len(kept_names)), key=lambda k: kept_names[k])
        kept_names = [kept_names[k] for k in order]
        kept_indices = [kept_indices[k] for k in order]

    if not kept_names:
        examples = ", ".join(repr(n) for n in stim_list[:3])
        raise ValueError(
            f"No stimuli left after filtering -- your selection removed all {len(stim_list)} "
            f"stimuli in this file (the names look like {examples}). "
            "Check the pattern or the stimuli you picked.")

    return kept_names, kept_indices


def _flatten_indices(key):
    """Recursively collect every stimulus index inside a triadic or tetradic trial key.
    Triadic keys look like ((ref, s1), (ref, s2)); tetradic like ((s1, s2), (s3, s4)).
    Both are just nested tuples of ints, so one recursive walk handles either shape."""
    if isinstance(key, tuple):
        indices = []
        for part in key:
            indices.extend(_flatten_indices(part))
        return indices
    return [key]


def _remap_key(key, old_to_new):
    """Rebuild a trial key with the same nested shape, replacing each index with its new number."""
    if isinstance(key, tuple):
        return tuple(_remap_key(part, old_to_new) for part in key)
    return old_to_new[key]


def subset_choice_file(stim_list, resp, rep, include=None, exclude=None, regex=None,
                        regex_mode="include", alphabetize=False):
    """
    Select a subset of stimuli from a choice file's data, dropping any trial that
    references an excluded stimulus and renumbering the survivors 1..N. Works on
    both triadic and tetradic choice files without needing to know which one it is.

    Args:
        stim_list: list of stimulus names, as returned by load_choices (0-indexed order)
        resp: dict {trial_key: n_chosen}, as returned by load_choices
        rep: dict {trial_key: n_repeats}, as returned by load_choices
        include, exclude, regex, regex_mode, alphabetize: selection options,
            passed straight through to subset_stimuli -- see that function for details

    Returns:
        new_resp: dict, same shape as `resp`, renumbered, with dropped trials removed
        new_rep: dict, same shape as `rep`, renumbered, with dropped trials removed
        kept_names: the surviving stimulus names, in their new index order
    """
    kept_names, kept_indices = subset_stimuli(
        stim_list, include=include, exclude=exclude, regex=regex,
        regex_mode=regex_mode, alphabetize=alphabetize)
    old_to_new = {old_index: new_index for new_index, old_index in enumerate(kept_indices)}

    new_resp, new_rep = {}, {}
    n_dropped = 0
    for key in resp:
        if all(i in old_to_new for i in _flatten_indices(key)):
            new_key = _remap_key(key, old_to_new)
            new_resp[new_key] = resp[key]
            new_rep[new_key] = rep[key]
        else:
            n_dropped += 1

    n_excluded_stim = len(stim_list) - len(kept_names)
    print(f"subset_choice_file: excluded {n_excluded_stim} of {len(stim_list)} stimuli; "
          f"dropped {n_dropped} of {len(resp)} trials that referenced an excluded stimulus "
          f"({len(new_resp)} trials remain)")

    return new_resp, new_rep, kept_names


def save_choice_file(out_path, resp, rep, stim_list, readme_note=""):
    """
    Save a resp/rep/stim_list triple (the format load_choices, subset_choice_file, etc.
    all use) to a .mat choice file. Auto-detects triadic vs tetradic from the shape of
    the trial keys and writes the matching column layout.
    """
    import numpy as np
    from scipy.io import savemat

    if not resp:
        raise ValueError(
            "Cannot save an empty choice file -- no trials remain after filtering. "
            "This can happen with tetradic files if the kept stimuli never appear "
            "together in the same trial.")

    # triadic key: ((ref, s1), (ref, s2)) -- the two halves share the same first element (ref)
    sample_key = next(iter(resp))
    is_triadic = sample_key[0][0] == sample_key[1][0]

    rows = []
    if is_triadic:
        for (ref, s1), (_, s2) in resp:
            key = ((ref, s1), (ref, s2))
            rows.append([ref + 1, s1 + 1, s2 + 1, resp[key], rep[key]])
        colnames = ['ref', 's1', 's2', 'N(D(ref, s1) > D(ref, s2))', 'N_Repeats(D(ref, s1) > D(ref, s2))']
    else:
        for (s1, s2), (s3, s4) in resp:
            key = ((s1, s2), (s3, s4))
            rows.append([s1 + 1, s2 + 1, s3 + 1, s4 + 1, resp[key], rep[key]])
        colnames = ['s1', 's2', 's3', 's4',
                    'N(D(s1, s2) > D(s3, s4))', 'N_Repeats(D(s1, s2) > D(s3, s4))']

    arr = np.array(rows, dtype=np.float64)
    max_len = max(len(s) for s in stim_list)
    savemat(out_path, {
        'responses': arr,
        'responses_colnames': colnames,
        'stim_list': np.array(stim_list, dtype=f'S{max_len}'),
        'readme': readme_note or "Subset of a choice file, produced by subset_choice_file.",
    })
    print(f"Saved: {out_path}  ({len(rows)} trials, {len(stim_list)} stimuli)")


def subset_coords_file(stim_list, coords_by_dim, include=None, exclude=None, regex=None,
                        regex_mode="include", alphabetize=False):
    """
    Select a subset of stimuli from a coordinates file's data -- keeps the matching
    row in every dimN array, for every fitted dimensionality at once.

    Args:
        stim_list: list of stimulus names (as returned by coords_to_numpy)
        coords_by_dim: dict {dim: array of shape (n_stimuli, dim)}, as returned by
            coords_to_numpy -- one array per fitted dimensionality
        include, exclude, regex, regex_mode, alphabetize: selection options,
            passed straight through to subset_stimuli

    Returns:
        new_coords_by_dim: dict, same dims, each array's rows filtered/reordered to match kept_names
        kept_names: the surviving stimulus names, in their new index order
    """
    kept_names, kept_indices = subset_stimuli(
        stim_list, include=include, exclude=exclude, regex=regex,
        regex_mode=regex_mode, alphabetize=alphabetize)

    new_coords_by_dim = {dim: arr[kept_indices, :] for dim, arr in coords_by_dim.items()}

    n_excluded_stim = len(stim_list) - len(kept_names)
    print(f"subset_coords_file: excluded {n_excluded_stim} of {len(stim_list)} stimuli "
          f"({len(kept_names)} remain), across {len(coords_by_dim)} fitted dimension(s)")

    return new_coords_by_dim, kept_names


def _restore_empty_structs(value):
    """
    Prepare a variable carried over from the original file so MATLAB sees it unchanged.

    scipy loads a MATLAB struct with no fields (and empty structs nested inside other
    structs/cells) as None, which savemat cannot write back. Replace each None with an
    empty dict, which savemat writes as the same 1x1 empty struct.

    scipy also reads a MATLAB [] (0x0) inside a nested struct as 1x0, and would write it
    back as 1x0. Restore those to 0x0. (A genuine 1x0 inside a struct would be turned into
    0x0 too; the metadata in the lab's files only contains [], never 1x0.)
    """
    import numpy as np

    if value is None:
        return {}
    if (isinstance(value, np.ndarray) and value.shape == (1, 0) and value.dtype.names is None
            and value.dtype != object):
        return np.zeros((0, 0), dtype=value.dtype)
    if isinstance(value, np.ndarray) and value.dtype.names:
        out = value.copy()
        for name in value.dtype.names:
            for idx in np.ndindex(value.shape):
                out[name][idx] = _restore_empty_structs(value[name][idx])
        return out
    if isinstance(value, np.ndarray) and value.dtype == object:
        if value.shape == (1, 1) and value[0, 0] is None:
            return {}  # scipy's form of a 1x1 struct with no fields
        out = np.empty(value.shape, dtype=object)
        for idx in np.ndindex(value.shape):
            out[idx] = _restore_empty_structs(value[idx])
        return out
    return value


def save_coords_file(out_path, coords_by_dim, stim_list, extra_fields=None):
    """
    Save a coords_by_dim/stim_list pair (the format coords_to_numpy, subset_coords_file,
    etc. all use) to a .mat coordinates file.

    Args:
        out_path: where to save the .mat file
        coords_by_dim: dict {dim: array of shape (n_stimuli, dim)}
        stim_list: list of stimulus names, in the same row order as coords_by_dim
        extra_fields: optional dict of additional fields to carry over from the
            original file (e.g. rawLLs, bestModelLL, biasEstimate, pipeline, setup).
            They are written back unchanged. Empty MATLAB structs, which scipy loads
            as None, are restored as empty structs so they can be written.
    """
    import numpy as np
    from scipy.io import savemat

    if not coords_by_dim:
        raise ValueError("Cannot save an empty coordinates file -- no fitted dimensions given.")

    data = {}
    for dim, arr in coords_by_dim.items():
        data[f"dim{dim}"] = arr

    max_len = max(len(s) for s in stim_list)
    data['stim_labels'] = np.array(stim_list, dtype=f'S{max_len}')

    for key, value in (extra_fields or {}).items():
        data[key] = _restore_empty_structs(value)

    savemat(out_path, data)
    print(f"Saved: {out_path}  ({len(stim_list)} stimuli, dims {sorted(coords_by_dim)})")


def detect_choice_format(mat_path):
    """
    Inspect a choice file's raw column names to tell triadic, tetradic, and
    odd-one-out formats apart. Tetradic and odd-one-out files both have 6
    columns, so column count alone can't tell them apart -- this looks at
    the actual column names instead:
        triadic:     ref, s1, s2, N(D(ref, s1) > D(ref, s2)), N_Repeats(...)
        tetradic:    s1, s2, s3, s4, N(D(s1, s2) > D(s3, s4)), N_Repeats(...)
        odd-one-out: s1, s2, s3, N(s1 odd out), N(s2 odd out), N(s3 odd out)
    Tetradic always has an 's4' column; odd-one-out never does.

    Returns: 'triadic', 'tetradic', 'odd_one_out', or 'unknown'
    """
    import scipy.io as sio

    raw = sio.loadmat(mat_path, squeeze_me=True)
    colnames_key = 'responses_colnames' if 'responses_colnames' in raw else 'response_colnames'
    if colnames_key not in raw:
        return 'unknown'

    names = [str(c).strip() for c in raw[colnames_key]]
    if any(n.startswith('ref') for n in names):
        return 'triadic'
    if any(n == 's4' for n in names):
        return 'tetradic'
    if any('odd' in n.lower() for n in names):
        return 'odd_one_out'
    return 'unknown'


def validate_choice_responses(mat_path, file_format, n_stimuli):
    """
    Sanity-check a triadic or tetradic choice file's raw `responses` array
    against what that format is actually supposed to contain, so a
    wrong-format or corrupted upload gets caught with a clear error right
    away instead of failing obscurely downstream (or silently producing
    nonsense, e.g. via int() truncating a stray float).

    Checks, for the relevant column group:
        - right number of columns for the format (5 for triadic, 6 for tetradic)
        - every value is a whole number (no fractional values anywhere)
        - the stimulus-index columns (ref/s1/s2, or s1/s2/s3/s4) are all
          valid 1-based indices into stim_list (1..n_stimuli)
        - within a row, the stimulus-index columns are pairwise distinct
          (a trial can't compare a stimulus to itself)
        - the count column is >= 0
        - the repeat column is >= 0, and count <= repeat for every row
          (a stimulus can't be "chosen" more times than the trial was shown)

    Raises ValueError with a specific, actionable message if anything is
    wrong. Returns None (nothing to report) if the file checks out.
    """
    import numpy as np
    import scipy.io as sio

    raw = sio.loadmat(mat_path, squeeze_me=True)
    if 'responses' not in raw:
        raise ValueError("This file has no 'responses' variable -- it doesn't look like a choice file at all.")
    responses = raw['responses']

    colnames_key = 'responses_colnames' if 'responses_colnames' in raw else 'response_colnames'
    names = [str(c).strip() for c in raw[colnames_key]]
    col_idx = {name: i for i, name in enumerate(names)}

    if file_format == "triadic":
        index_cols = ["ref", "s1", "s2"]
        expected_ncols = 5
    elif file_format == "tetradic":
        index_cols = ["s1", "s2", "s3", "s4"]
        expected_ncols = 6
    else:
        raise ValueError(f"validate_choice_responses only handles triadic/tetradic, got {file_format!r}")

    if responses.ndim != 2:
        raise ValueError(f"'responses' should be a 2-D table, but this file's is {responses.ndim}-D.")
    if responses.shape[1] != expected_ncols:
        raise ValueError(
            f"A {file_format} choice file should have {expected_ncols} columns, "
            f"but this file has {responses.shape[1]}. Make sure this is really a "
            f"{file_format} file, not a different comparison type."
        )
    if any(name not in col_idx for name in index_cols):
        missing = [name for name in index_cols if name not in col_idx]
        raise ValueError(
            f"This file is missing the expected column(s) {missing} for a {file_format} file "
            f"-- its columns are named {names}."
        )

    count_col = next((i for n, i in col_idx.items() if n.startswith("N(")), None)
    repeat_col = next((i for n, i in col_idx.items() if n.startswith("N_Repeats")), None)
    if count_col is None or repeat_col is None:
        raise ValueError(f"Couldn't find the count/repeat columns in {names} -- is this really a choice file?")

    not_whole = responses != np.round(responses)
    if not_whole.any():
        row, col = np.argwhere(not_whole)[0]
        raise ValueError(
            f"All values in a choice file should be whole numbers, but row {row} column "
            f"'{names[col]}' is {responses[row, col]!r}. This usually means the file isn't "
            f"actually a choice file (or is the wrong comparison type)."
        )

    idx_positions = [col_idx[name] for name in index_cols]
    idx_values = responses[:, idx_positions]
    if idx_values.min() < 1 or idx_values.max() > n_stimuli:
        bad_row = np.argmax((idx_values < 1).any(axis=1) | (idx_values > n_stimuli).any(axis=1))
        raise ValueError(
            f"Row {bad_row}'s stimulus indices {list(idx_values[bad_row])} aren't all valid "
            f"1-based positions into a {n_stimuli}-stimulus list. Make sure this file's stim_list "
            f"matches its responses, and that it's really a {file_format} file."
        )

    dup_row = np.argmax([len(set(row)) != len(row) for row in idx_values])
    if len(set(idx_values[dup_row])) != len(idx_values[dup_row]):
        raise ValueError(
            f"Row {dup_row} compares a stimulus to itself (indices {list(idx_values[dup_row])}) "
            f"-- that shouldn't be possible in a real choice file."
        )

    counts = responses[:, count_col]
    repeats = responses[:, repeat_col]
    if (counts < 0).any():
        raise ValueError(f"Row {int(np.argmax(counts < 0))}'s count is negative ({counts.min()}), which isn't valid.")
    if (repeats < 0).any():
        raise ValueError(f"Row {int(np.argmax(repeats < 0))}'s repeat count is negative ({repeats.min()}), which isn't valid.")
    if (counts > repeats).any():
        bad_row = int(np.argmax(counts > repeats))
        raise ValueError(
            f"Row {bad_row} has a count ({counts[bad_row]}) greater than its repeat total "
            f"({repeats[bad_row]}) -- a trial can't be chosen more times than it was shown."
        )


def load_ooo_file(mat_path):
    """
    Load an odd-one-out choice file as a plain row table, rather than the
    trial-key dictionary used for triadic/tetradic files -- an OOO trial
    carries 3 separate counts (one per stimulus, for how often it was
    picked as the odd one out), which doesn't fit the single-count-per-trial
    shape that dictionary was built for.

    Returns:
        rows: (n_triplets, 6) array, 1-indexed columns
              [s1, s2, s3, N(s1 odd out), N(s2 odd out), N(s3 odd out)]
        stim_list: list of stimulus names, in index order
    """
    import scipy.io as sio

    raw = sio.loadmat(mat_path, squeeze_me=True)
    if 'stim_list' not in raw or 'responses' not in raw:
        raise ValueError("This doesn't look like a choice file -- missing 'stim_list' or 'responses'.")
    stim_list = [str(s).strip() for s in raw['stim_list']]
    rows = raw['responses']
    if rows.ndim != 2 or rows.shape[1] != 6:
        raise ValueError(
            "This doesn't look like an odd-one-out file -- expected 6 columns "
            f"(s1, s2, s3, N(s1 odd out), N(s2 odd out), N(s3 odd out)), got shape {rows.shape}. "
            "Make sure this is an odd-one-out file, not a triadic or tetradic choice file.")
    return rows, stim_list


def validate_ooo_responses(rows, n_stimuli):
    """
    Sanity-check an odd-one-out file's row table beyond just its column
    count (already checked by load_ooo_file), so a wrong-format or
    corrupted upload is caught with a clear error up front.

    Checks:
        - every value is a whole number
        - the s1/s2/s3 columns are all valid 1-based indices into stim_list
        - within a row, s1/s2/s3 are pairwise distinct
        - the three "odd one out" count columns are all >= 0

    Raises ValueError with a specific message if anything is wrong.
    Returns None if the file checks out.
    """
    import numpy as np

    not_whole = rows != np.round(rows)
    if not_whole.any():
        row, col = np.argwhere(not_whole)[0]
        raise ValueError(
            f"All values in an odd-one-out file should be whole numbers, but row {row} "
            f"column {col} is {rows[row, col]!r}. This usually means the file isn't "
            f"actually an odd-one-out file."
        )

    idx_values = rows[:, :3]
    if idx_values.min() < 1 or idx_values.max() > n_stimuli:
        bad_row = np.argmax((idx_values < 1).any(axis=1) | (idx_values > n_stimuli).any(axis=1))
        raise ValueError(
            f"Row {bad_row}'s stimulus indices {list(idx_values[bad_row])} aren't all valid "
            f"1-based positions into a {n_stimuli}-stimulus list. Make sure this file's stim_list "
            f"matches its responses."
        )

    dup_row = np.argmax([len(set(row)) != len(row) for row in idx_values])
    if len(set(idx_values[dup_row])) != len(idx_values[dup_row]):
        raise ValueError(
            f"Row {dup_row} repeats a stimulus within the same triplet (indices "
            f"{list(idx_values[dup_row])}) -- that shouldn't be possible in a real file."
        )

    counts = rows[:, 3:6]
    if (counts < 0).any():
        bad_row = np.argmax((counts < 0).any(axis=1))
        raise ValueError(
            f"Row {bad_row}'s odd-one-out counts ({list(counts[bad_row])}) include a negative "
            f"value, which isn't valid."
        )


def subset_ooo_file(stim_list, rows, include=None, exclude=None, regex=None,
                     regex_mode="include", alphabetize=False):
    """
    Select a subset of stimuli from an odd-one-out file's data, dropping any
    triplet that references an excluded stimulus and renumbering the
    survivors 1..N.

    Args:
        stim_list: list of stimulus names, as returned by load_ooo_file
        rows: (n_triplets, 6) array, as returned by load_ooo_file
        include, exclude, regex, regex_mode, alphabetize: selection options,
            passed straight through to subset_stimuli

    Returns:
        new_rows: (n_kept, 6) array, renumbered, with dropped triplets removed
        kept_names: the surviving stimulus names, in their new index order
    """
    import numpy as np

    kept_names, kept_indices = subset_stimuli(
        stim_list, include=include, exclude=exclude, regex=regex,
        regex_mode=regex_mode, alphabetize=alphabetize)
    old_to_new = {old_index: new_index for new_index, old_index in enumerate(kept_indices)}
    kept_set = set(kept_indices)

    new_rows = []
    n_dropped = 0
    for row in rows:
        s1, s2, s3 = int(row[0]) - 1, int(row[1]) - 1, int(row[2]) - 1  # to 0-indexed
        if s1 in kept_set and s2 in kept_set and s3 in kept_set:
            new_rows.append([old_to_new[s1] + 1, old_to_new[s2] + 1, old_to_new[s3] + 1,
                             row[3], row[4], row[5]])
        else:
            n_dropped += 1

    n_excluded_stim = len(stim_list) - len(kept_names)
    print(f"subset_ooo_file: excluded {n_excluded_stim} of {len(stim_list)} stimuli; "
          f"dropped {n_dropped} of {len(rows)} triplets that referenced an excluded stimulus "
          f"({len(new_rows)} triplets remain)")

    new_rows_arr = np.array(new_rows, dtype=np.float64) if new_rows else np.zeros((0, 6))
    return new_rows_arr, kept_names


def save_ooo_file(out_path, rows, stim_list):
    """
    Save a rows/stim_list pair (the format load_ooo_file, subset_ooo_file, etc.
    all use) to a .mat odd-one-out choice file.
    """
    import numpy as np
    from scipy.io import savemat

    if len(rows) == 0:
        raise ValueError(
            "Cannot save an empty odd-one-out file -- no triplets remain after filtering. "
            "This can happen if the stimuli you kept never appear together in the same triplet.")

    max_len = max(len(s) for s in stim_list)
    savemat(out_path, {
        'responses': rows,
        'responses_colnames': ['s1', 's2', 's3', 'N(s1 odd out)', 'N(s2 odd out)', 'N(s3 odd out)'],
        'stim_list': np.array(stim_list, dtype=f'S{max_len}'),
        'readme': "Subset of an odd-one-out choice file, produced by subset_ooo_file.",
    })
    print(f"Saved: {out_path}  ({len(rows)} triplets, {len(stim_list)} stimuli)")
