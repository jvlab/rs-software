"""
results_export -- save a surrogate MDS comparison as a machine-readable file.

One result record describes one comparison of two datasets: the settings used, the real
disparity and log-likelihoods, every surrogate disparity, and the p-value. The same record
is written by the Surrogate MDS app (Download results buttons) and by the batch script
(rs_tools/run_comparison.py), so results from either can be collected into one table.

A record can also carry the fitted maps and convergence curves (see EXTRA_FIELDS), and
bundle_zip() packs everything -- the record in all three formats, CSV tables, the plot,
and a README -- into one zip.

Formats (chosen by file extension):
    .json   readable anywhere; arrays are lists
    .mat    MATLAB / Octave; fields are variables
    .npz    NumPy; each field is an array (load with allow_pickle=False)

Collect many runs into one table:
    python -m rs_tools.results_export summarize results/*.json --csv all_runs.csv

p-values: `p_value` is the fraction of surrogates with disparity >= the real disparity, as
the app shows it. With n surrogates it can only take values k/n, so 0 means "none of the n
surrogates reached the real value", not "impossible". It is reported as is, including 0: an
estimate from the surrogates that were run, not a claim of the "true" p-value.
"""

import csv
import datetime
import io
import json
import math
import os
import subprocess
import sys

import numpy as np

SCALAR_FIELDS = [
    "source", "created_utc", "software_version", "git_commit",
    "dataset1", "dataset2", "file1", "file2",
    "dim", "n_surrogates", "max_iterations_real", "max_iterations_surrogate",
    "learning_rate", "resample_method", "warm_start", "seed_mode",
    "n_shared_stimuli", "n_triads1", "n_triads2",
    "real_disparity", "real_ll1", "real_ll2",
    "surrogate_mean", "surrogate_std", "surrogate_critical_5pct", "n_surrogates_ge_real",
    "p_value",
]
ARRAY_FIELDS = ["surrogate_disparities", "surrogate_ll1", "surrogate_ll2"]
# optional extras: fitted maps (rows = stimuli, columns = dimensions), the stimulus names for
# each, the maps after alignment on the shared stimuli, and convergence curves
# (rows = [iteration, log-likelihood per triad])
EXTRA_FIELDS = [
    "stim_labels1", "stim_labels2", "real_coords1", "real_coords2",
    "shared_stim_labels", "aligned_coords1", "aligned_coords2",
    "convergence_dataset1", "convergence_dataset2", "convergence_pooled",
]
SUMMARY_COLUMNS = [
    "dataset1", "dataset2", "dim", "n_surrogates", "max_iterations_real",
    "max_iterations_surrogate", "resample_method", "real_disparity", "surrogate_mean",
    "surrogate_std", "surrogate_critical_5pct", "p_value", "real_ll1", "real_ll2", "source",
    "created_utc",
]


def _git_commit():
    try:
        here = os.path.dirname(os.path.abspath(__file__))
        out = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=here,
                             capture_output=True, text=True, timeout=5)
        return out.stdout.strip() or None
    except Exception:
        return None


def _software_version():
    try:
        from . import __version__
        return __version__
    except Exception:
        return None


def build_record(*, source, dataset1, dataset2, dim, n_surrogates, real_disparity,
                 surrogate_disparities, real_ll1=None, real_ll2=None,
                 surrogate_ll1=None, surrogate_ll2=None, file1=None, file2=None,
                 max_iterations_real=None, max_iterations_surrogate=None,
                 learning_rate=None, resample_method=None, warm_start=None,
                 seed_mode=None, n_shared_stimuli=None, n_triads1=None, n_triads2=None,
                 extras=None):
    """Assemble one result record. Fields that do not apply may be left as None.
    extras: optional dict with any of EXTRA_FIELDS (maps, labels, convergence curves)."""
    disparities = np.asarray(surrogate_disparities, dtype=float).ravel()
    n_ge = int(np.sum(disparities >= real_disparity))
    n = len(disparities)
    record = {
        "source": source,
        "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "software_version": _software_version(),
        "git_commit": _git_commit(),
        "dataset1": dataset1, "dataset2": dataset2, "file1": file1, "file2": file2,
        "dim": int(dim), "n_surrogates": int(n_surrogates),
        "max_iterations_real": max_iterations_real,
        "max_iterations_surrogate": max_iterations_surrogate,
        "learning_rate": learning_rate, "resample_method": resample_method,
        "warm_start": None if warm_start is None else bool(warm_start),
        "seed_mode": seed_mode, "n_shared_stimuli": n_shared_stimuli,
        "n_triads1": n_triads1, "n_triads2": n_triads2,
        "real_disparity": float(real_disparity),
        "real_ll1": None if real_ll1 is None else float(real_ll1),
        "real_ll2": None if real_ll2 is None else float(real_ll2),
        "surrogate_mean": float(disparities.mean()) if n else None,
        "surrogate_std": float(disparities.std()) if n else None,
        "surrogate_critical_5pct": float(np.quantile(disparities, 0.95)) if n else None,
        "n_surrogates_ge_real": n_ge,
        "p_value": float(n_ge / n) if n else None,
        "surrogate_disparities": disparities,
        "surrogate_ll1": None if surrogate_ll1 is None else np.asarray(surrogate_ll1, dtype=float).ravel(),
        "surrogate_ll2": None if surrogate_ll2 is None else np.asarray(surrogate_ll2, dtype=float).ravel(),
    }
    for key, value in (extras or {}).items():
        if key not in EXTRA_FIELDS:
            raise ValueError(f"Unknown extra field {key!r}; allowed: {', '.join(EXTRA_FIELDS)}")
        if value is None:
            record[key] = None
        elif key.startswith(("stim_labels", "shared_stim_labels")):
            record[key] = np.array([str(v) for v in value])
        else:
            record[key] = np.asarray(value, dtype=float)
    return record


def _json_safe(value):
    if isinstance(value, np.ndarray):
        return [_json_safe(v) for v in value.tolist()]
    if isinstance(value, (np.floating, float)):
        return None if (math.isnan(value) or math.isinf(value)) else float(value)
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, list):
        return [_json_safe(v) for v in value]
    return value


def record_bytes(record, fmt):
    """Serialize a record to bytes for fmt in {'json', 'mat', 'npz'}."""
    fmt = fmt.lower().lstrip(".")
    present = {k: v for k, v in record.items() if v is not None}
    if fmt == "json":
        text = json.dumps({k: _json_safe(v) for k, v in record.items()}, indent=2)
        return text.encode("utf-8")
    buf = io.BytesIO()
    if fmt == "npz":
        np.savez(buf, **{k: np.asarray(v) for k, v in present.items()})
    elif fmt == "mat":
        from scipy.io import savemat
        data = {}
        for k, v in present.items():
            if k in ARRAY_FIELDS:
                data[k] = np.asarray(v, dtype=float).reshape(-1, 1)
            elif isinstance(v, np.ndarray) and v.dtype.kind == "U":
                data[k] = np.array(list(v), dtype=object).reshape(-1, 1)   # MATLAB cell array of text
            else:
                data[k] = int(v) if isinstance(v, bool) else v
        savemat(buf, data, do_compression=True)
    else:
        raise ValueError(f"Unknown format {fmt!r}; use json, mat or npz.")
    return buf.getvalue()


def table_csv(header, rows):
    """A list of rows (lists) as CSV bytes."""
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(header)
    writer.writerows(rows)
    return buf.getvalue().encode("utf-8")


def summary_table_csv(record):
    """The one-row table for the lab's comparison spreadsheet: real Procrustes D, the surrogate mean, sd
    and 5% critical value, and the p-value."""
    header = ["dataset_1", "dataset_2", "dim", "n_surrogates", "real_procrustes_D", "surrogate_mean_D",
              "surrogate_sd_D", "surrogate_5pct_quantile_D", "p_value"]
    row = [record["dataset1"], record["dataset2"], record["dim"], record["n_surrogates"],
           record["real_disparity"], record["surrogate_mean"], record["surrogate_std"],
           record["surrogate_critical_5pct"], record["p_value"]]
    return table_csv(header, [row])


def coords_csv(labels, coords):
    """A map as CSV bytes: one row per stimulus, columns stimulus, dim1, dim2, ..."""
    coords = np.asarray(coords, dtype=float)
    header = ["stimulus"] + [f"dim{i + 1}" for i in range(coords.shape[1])]
    return table_csv(header, [[str(n)] + [repr(float(x)) for x in row] for n, row in zip(labels, coords)])


def convergence_csv(curves):
    """curves: {name: array with rows [iteration, log-likelihood per triad]} as CSV bytes."""
    rows = [[name, int(it), repr(float(ll))] for name, arr in curves.items() if arr is not None
            for it, ll in np.asarray(arr)]
    return table_csv(["fit", "iteration", "log_likelihood_per_triad"], rows)


README_TEXT = """Surrogate MDS comparison -- everything from one run
====================================================

results.json / results.mat / results.npz
    The same record in three formats: settings, real disparity and log-likelihoods, every
    surrogate disparity and log-likelihood, the p-value, and the fitted maps and
    convergence curves. MATLAB: r = load('results.mat'). Python: np.load('results.npz').
    p_value is the fraction of surrogates at or above the real disparity (k/n, so it can be
    exactly 0: none of the n surrogates reached the real disparity).
surrogate_table.csv         one row per surrogate: log-likelihood of each dataset, disparity
coordinates_dataset1.csv    fitted map of dataset 1 (one row per stimulus)
coordinates_dataset2.csv    fitted map of dataset 2
aligned_dataset1.csv        both maps restricted to the shared stimuli, centered, with
aligned_dataset2.csv        dataset 2 rotated onto dataset 1 (the alignment behind the disparity)
convergence.csv             log-likelihood per triad against iteration for each real fit
disparity_histogram.html    the surrogate distribution and the real disparity (open in a browser)
"""


def bundle_zip(record, extra_files=None, stem="results"):
    """Everything from one run in one zip: the record in json/mat/npz, a README, and the
    extra files (name -> bytes) such as CSV tables and the plot."""
    import zipfile
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("README.txt", README_TEXT)
        for fmt in ("json", "mat", "npz"):
            z.writestr(f"{stem}.{fmt}", record_bytes(record, fmt))
        for name, data in (extra_files or {}).items():
            z.writestr(name, data)
    return buf.getvalue()


def save_record(record, path):
    """Write a record to path; the extension (.json, .mat, .npz) picks the format."""
    fmt = os.path.splitext(str(path))[1]
    with open(path, "wb") as f:
        f.write(record_bytes(record, fmt))


def load_record(path):
    """Read a record written by save_record back into a dict (arrays as numpy arrays)."""
    ext = os.path.splitext(str(path))[1].lower()
    if ext == ".json":
        with open(path) as f:
            raw = json.load(f)
        out = {}
        for k, v in raw.items():
            if v is not None and (k in ARRAY_FIELDS or k in EXTRA_FIELDS):
                out[k] = np.array(v) if k.startswith(("stim_labels", "shared_stim")) else np.array(v, dtype=float)
            else:
                out[k] = v
        return out
    if ext == ".npz":
        with np.load(path, allow_pickle=False) as z:
            return {k: (z[k] if (k in ARRAY_FIELDS or k in EXTRA_FIELDS) else z[k].item()) for k in z.files}
    if ext == ".mat":
        from scipy.io import loadmat
        raw = loadmat(path, squeeze_me=True)
        out = {}
        for k, v in raw.items():
            if k.startswith("__"):
                continue
            if k in ARRAY_FIELDS:
                out[k] = np.atleast_1d(v)
            elif k.startswith(("stim_labels", "shared_stim")):
                out[k] = np.array([str(x).strip() for x in np.atleast_1d(v)])
            elif k in EXTRA_FIELDS:
                out[k] = np.asarray(v)
            else:
                out[k] = v.item() if hasattr(v, "item") else v
        # squeeze_me flattens one-row / one-column tables: put them back
        for key in ("convergence_dataset1", "convergence_dataset2", "convergence_pooled"):
            if key in out:
                out[key] = np.asarray(out[key]).reshape(-1, 2)
        for key, labels in (("real_coords1", "stim_labels1"), ("real_coords2", "stim_labels2"),
                            ("aligned_coords1", "shared_stim_labels"), ("aligned_coords2", "shared_stim_labels")):
            if key in out and labels in out:
                out[key] = np.asarray(out[key]).reshape(len(out[labels]), -1)
        return out
    raise ValueError(f"Unknown file type {ext!r}; use .json, .mat or .npz.")


def summarize(paths, csv_path=None):
    """One row per result file, with the columns in SUMMARY_COLUMNS. Optionally write a CSV."""
    rows = []
    for p in paths:
        rec = load_record(p)
        row = {c: rec.get(c) for c in SUMMARY_COLUMNS}
        row["file"] = os.path.basename(p)
        rows.append(row)
    if csv_path:
        with open(csv_path, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=["file"] + SUMMARY_COLUMNS)
            writer.writeheader()
            writer.writerows(rows)
    return rows


def main(argv=None):
    import argparse
    parser = argparse.ArgumentParser(prog="python -m rs_tools.results_export")
    sub = parser.add_subparsers(dest="command", required=True)
    s = sub.add_parser("summarize", help="collect result files into one table")
    s.add_argument("files", nargs="+")
    s.add_argument("--csv", help="write the table to this CSV file")
    args = parser.parse_args(argv)
    rows = summarize(args.files, args.csv)
    for r in rows:
        print(f"{r['file']}: {r['dataset1']} vs {r['dataset2']}  {r['dim']}D  "
              f"disparity {r['real_disparity']:.4f}  p={r['p_value']:.4f}  "
              f"({r['n_surrogates']} surrogates)")
    if args.csv:
        print(f"Wrote {args.csv}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
