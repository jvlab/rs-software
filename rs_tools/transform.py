"""
transform -- run an rs_tools operation on a dataset, from Python, the command line,
or MATLAB (through src/rs_subset_coordsets.m and src/rs_subset_choicesets.m).

One option dictionary (`aux`, same field names as MATLAB's `aux` struct) drives all
three entry points, so a MATLAB call, a terminal call and a Python call that carry
the same options give the same result.

Supported operations (aux["operation"]):
    "subset"   keep or drop stimuli in a coordinates file
               aux["filter_type"]    "regex" | "include" | "exclude" | "keep_all"
               aux["filter_pattern"] regex string, or for include/exclude a list of
                                     stimulus names (or one comma-separated string)
               aux["regex_mode"]     "include" (default) or "exclude", for regex only
               aux["alphabetize"]    True to sort the kept stimuli by name
               aux["return_indices"] True to also write `kept_indices` (1-based positions of the
                                     kept stimuli in the original list, as a column), so that a
                                     caller can cut other per-stimulus data the same way
    "subset_choices"  keep or drop stimuli in choice data, as MATLAB's rs_read_choicedata returns it:
               the variable `data_comp` is a table with one row per comparison, 5 columns (triadic:
               ref, s1, s2, count, trials) or 6 (tetradic: s1, s2, s3, s4, count, trials), whose
               first columns number the stimuli from 1; the variable `typenames` (or `stim_list`)
               holds the stimulus names.  Trials that use a dropped stimulus are removed and the
               surviving stimuli are renumbered 1..N.  The count and trials columns are not changed.
               Uses the same filter_type, filter_pattern, regex_mode, alphabetize and
               return_indices options as "subset".

`dimensions` and `iterations` are accepted so the same aux works for future
operations (e.g. model fitting); "subset" does not use them.

Metadata rule: every variable that is not a coordinate table (dimN) or the stimulus
names (stim_labels / stim_list) is written back exactly as it was read -- pipeline,
setup, rawLLs, biasEstimate, ... -- including empty MATLAB structs.

Command line:
    python -m rs_tools.transform --input in.mat --output out.mat \\
        --operation subset --filter-type regex --filter-pattern "p\\d{4}$"
"""

import argparse
import json
import re
import sys
import warnings

import numpy as np
import scipy.io as sio

from .subset_stimuli import subset_stimuli, _restore_empty_structs

_DIM_KEY = re.compile(r"^dim(\d+)$")
_LABEL_KEYS = ("stim_labels", "stim_list")
_KNOWN_AUX = {
    "operation", "dimensions", "iterations", "filter_type", "filter_pattern",
    "regex_mode", "alphabetize", "return_indices",
}


def _label_to_str(label):
    if isinstance(label, np.ndarray):
        label = "".join(str(x) for x in label.ravel())
    return str(label).strip()


def _find_label_key(data):
    for key in _LABEL_KEYS:
        if key in data:
            return key
    raise ValueError(
        "No stimulus name variable ('stim_labels' or 'stim_list') found in this data.")


def _normalize_aux(aux):
    aux = dict(aux or {})
    aux.setdefault("operation", "subset")
    unknown = sorted(set(aux) - _KNOWN_AUX)
    if unknown:
        warnings.warn(f"Ignoring unknown aux field(s): {', '.join(unknown)}", stacklevel=3)
    return aux


def _names_from_pattern(pattern):
    if pattern is None:
        return []
    if isinstance(pattern, str):
        return [p.strip() for p in pattern.split(",") if p.strip()]
    return [str(p) for p in pattern]


def _op_subset(data, aux):
    label_key = _find_label_key(data)
    labels_arr = np.asarray(data[label_key])
    stim_list = [_label_to_str(x) for x in np.atleast_1d(labels_arr).ravel()]

    dim_keys = [k for k in data if _DIM_KEY.match(k)]
    if not dim_keys:
        raise ValueError("No 'dimN' coordinate variables found -- is this a coordinates file?")
    for key in dim_keys:
        n_rows = np.asarray(data[key]).shape[0]
        if n_rows != len(stim_list):
            raise ValueError(
                f"'{key}' has {n_rows} rows but there are {len(stim_list)} stimulus names.")

    _, kept_indices = subset_stimuli(stim_list, **_selection_kwargs(aux))

    out = {}
    for key, value in data.items():
        if key in dim_keys or key == label_key:
            out[key] = np.asarray(value)[kept_indices]
        else:
            out[key] = value
    if aux.get("return_indices"):
        out["kept_indices"] = (np.asarray(kept_indices, dtype=float) + 1).reshape(-1, 1)
    return out


def _selection_kwargs(aux):
    """Turn the filter options in aux into the arguments of subset_stimuli (shared by every subset operation)."""
    ftype = aux.get("filter_type", "keep_all")
    pattern = aux.get("filter_pattern")
    kwargs = {"alphabetize": bool(aux.get("alphabetize", False))}
    if ftype == "regex":
        if not pattern:
            raise ValueError("filter_type 'regex' needs a filter_pattern.")
        kwargs.update(regex=str(pattern), regex_mode=aux.get("regex_mode", "include"))
    elif ftype == "include":
        kwargs["include"] = _names_from_pattern(pattern)
    elif ftype == "exclude":
        kwargs["exclude"] = _names_from_pattern(pattern)
    elif ftype == "keep_all":
        kwargs["exclude"] = []
    else:
        raise ValueError(
            f"Unknown filter_type {ftype!r}; use regex, include, exclude or keep_all.")
    return kwargs


_CHOICE_LABEL_KEYS = ("typenames", "stim_list")


def _op_subset_choices(data, aux):
    if "data_comp" not in data:
        raise ValueError("No 'data_comp' variable (the table of choices) found in this data.")
    label_key = next((k for k in _CHOICE_LABEL_KEYS if k in data), None)
    if label_key is None:
        raise ValueError("No stimulus name variable ('typenames' or 'stim_list') found in this data.")
    labels_arr = np.asarray(data[label_key])
    stim_list = [_label_to_str(x) for x in np.atleast_1d(labels_arr).ravel()]

    comp = np.asarray(data["data_comp"], dtype=float)
    if comp.ndim != 2 or comp.shape[0] == 0:
        raise ValueError("'data_comp' has no trials (it must be a table with one row per comparison).")
    n_cols = comp.shape[1]
    if n_cols not in (5, 6):
        raise ValueError(
            f"'data_comp' has {n_cols} columns; a choice table has 5 (triadic) or 6 (tetradic).")
    n_idx = n_cols - 2                      # columns that number the stimuli
    idx = comp[:, :n_idx]
    if not np.all(idx == np.round(idx)):
        raise ValueError("The stimulus numbers in the first columns of 'data_comp' must be whole numbers.")
    if idx.min() < 1 or idx.max() > len(stim_list):
        raise ValueError(
            f"'data_comp' uses stimulus numbers {int(idx.min())} to {int(idx.max())}, "
            f"but there are {len(stim_list)} stimulus names.")

    _, kept_indices = subset_stimuli(stim_list, **_selection_kwargs(aux))
    new_number = np.zeros(len(stim_list) + 1)       # new_number[old stimulus number] = new number, 0 if dropped
    for new, old in enumerate(kept_indices, start=1):
        new_number[old + 1] = new
    renumbered = new_number[idx.astype(int)]
    keep_rows = np.all(renumbered > 0, axis=1)      # a trial stays only if every stimulus in it is kept
    if not keep_rows.any():
        raise ValueError(
            f"No trials left after filtering -- none of the {comp.shape[0]} trials uses only the kept "
            f"stimuli. With tetradic data this happens when the kept stimuli never appear together in a trial.")
    new_comp = comp[keep_rows].copy()
    new_comp[:, :n_idx] = renumbered[keep_rows]

    out = {}
    for key, value in data.items():
        if key == "data_comp":
            out[key] = new_comp
        elif key == label_key:
            if np.asarray(value).dtype == object:       # a MATLAB cell array of names: stays a cell array
                out[key] = np.array([stim_list[i] for i in kept_indices], dtype=object).reshape(-1, 1)
            else:
                out[key] = np.asarray(value)[kept_indices]
        else:
            out[key] = value
    if aux.get("return_indices"):
        out["kept_indices"] = (np.asarray(kept_indices, dtype=float) + 1).reshape(-1, 1)
    return out


OPERATIONS = {"subset": _op_subset, "subset_choices": _op_subset_choices}


def transform(data_original, aux=None):
    """
    Apply aux["operation"] to a dataset and return the transformed dataset.

    data_original: dict of variables as returned by load_data (scipy loadmat, not squeezed)
    aux: option dict, see the module docstring
    """
    aux = _normalize_aux(aux)
    operation = aux["operation"]
    if operation not in OPERATIONS:
        raise ValueError(
            f"Unknown operation {operation!r}; available: {', '.join(sorted(OPERATIONS))}.")
    return OPERATIONS[operation](data_original, aux)


def load_data(path):
    """
    Read a .mat file with shapes, nested structures and number types as MATLAB sees them.
    mat_dtype=True matters: MATLAB stores whole-number doubles in a compact integer form,
    and without it they would come back (and be written back) as uint8/uint16.
    """
    raw = sio.loadmat(path, mat_dtype=True)
    return {k: v for k, v in raw.items() if not k.startswith("__")}


def save_data(path, data):
    """Write a dataset to .mat (default) or .npz, keeping nested metadata intact."""
    if str(path).lower().endswith(".npz"):
        np.savez(path, **data)  # nested structs become pickled object arrays
        return
    sio.savemat(path, {k: _restore_empty_structs(v) for k, v in data.items()},
                do_compression=True)


def transform_file(input_path, output_path, aux=None):
    save_data(output_path, transform(load_data(input_path), aux))


def run_files(input_path, output_path, aux_json="{}"):
    """Entry point used from MATLAB: paths are strings, aux arrives as a JSON string."""
    transform_file(str(input_path), str(output_path), json.loads(str(aux_json)))


def aux_from_args(args):
    """Build the same option dict MATLAB's aux struct becomes, from CLI flags."""
    aux = {}
    if args.aux_file:
        with open(args.aux_file) as f:
            aux.update(json.load(f))
    flag_values = {
        "operation": args.operation, "dimensions": args.dimensions,
        "iterations": args.iterations, "filter_type": args.filter_type,
        "filter_pattern": args.filter_pattern, "regex_mode": args.regex_mode,
        "alphabetize": True if args.alphabetize else None,
    }
    aux.update({k: v for k, v in flag_values.items() if v is not None})
    return aux


def build_parser():
    p = argparse.ArgumentParser(
        prog="python -m rs_tools.transform",
        description="Run an rs_tools operation on a .mat dataset (same options as "
                    "MATLAB's rs_transform aux struct).")
    p.add_argument("--input", required=True, help="input .mat file")
    p.add_argument("--output", required=True, help="output .mat (or .npz) file")
    p.add_argument("--operation", help="operation to run (default: subset)")
    p.add_argument("--dimensions", type=int, help="model dimensionality (unused by subset)")
    p.add_argument("--iterations", type=int, help="optimizer iterations (unused by subset)")
    p.add_argument("--filter-type", choices=["regex", "include", "exclude", "keep_all"])
    p.add_argument("--filter-pattern", help="regex, or comma-separated names for include/exclude")
    p.add_argument("--regex-mode", choices=["include", "exclude"])
    p.add_argument("--alphabetize", action="store_true")
    p.add_argument("--aux-file", help="JSON file of aux options; flags override it")
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        transform_file(args.input, args.output, aux_from_args(args))
    except (ValueError, OSError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    print(f"Saved {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
