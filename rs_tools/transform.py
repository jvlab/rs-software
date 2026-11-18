"""
transform -- run an rs_tools operation on a dataset, from Python, the command line,
or MATLAB (through src/rs_transform.m).

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

    ftype = aux.get("filter_type", "keep_all")
    pattern = aux.get("filter_pattern")
    kwargs = {"alphabetize": bool(aux.get("alphabetize", False))}
    if ftype == "regex":
        if not pattern:
            raise ValueError("filter_type 'regex' needs a filter_pattern.")
        if not isinstance(pattern, str):
            raise ValueError("filter_type 'regex' needs filter_pattern to be a single text string, "
                             f"but it is {type(pattern).__name__} (a MATLAB cell array?). "
                             "Give one regular expression, for example '^b'.")
        kwargs.update(regex=pattern, regex_mode=aux.get("regex_mode", "include"))
    elif ftype == "include":
        kwargs["include"] = _names_from_pattern(pattern)
    elif ftype == "exclude":
        kwargs["exclude"] = _names_from_pattern(pattern)
    elif ftype == "keep_all":
        kwargs["exclude"] = []
    else:
        raise ValueError(
            f"Unknown filter_type {ftype!r}; use regex, include, exclude or keep_all.")

    _, kept_indices = subset_stimuli(stim_list, **kwargs)

    out = {}
    for key, value in data.items():
        if key in dim_keys or key == label_key:
            out[key] = np.asarray(value)[kept_indices]
        else:
            out[key] = value
    if aux.get("return_indices"):
        out["kept_indices"] = (np.asarray(kept_indices, dtype=float) + 1).reshape(-1, 1)
    return out


OPERATIONS = {"subset": _op_subset}


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
