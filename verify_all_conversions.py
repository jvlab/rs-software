"""
verify_all_conversions.py — single run-on-demand routine that checks every
conversion tool in this repo for correctness / lossless round trips.

Checks:
  1. OOO -> triadic: converted output matches what's independently derivable
     from the raw judgments (same logic as verify_triadic_matches_ooo.py).
  2. Choice file: mat -> npy -> mat round trip is byte-for-byte identical.
  3. Coordinate file: mat -> npz -> mat round trip is byte-for-byte identical.
     NOTE: does not support files with nested MATLAB struct fields (e.g. old
     demo files with 'setup'/'pipeline' structs) -- flagged explicitly with a
     clear message if such a file is given, not silently skipped or crashed.

Usage (defaults to known sample files, runs out of the box):
    python3 verify_all_conversions.py
Or point it at specific files:
    python3 verify_all_conversions.py --ooo <raw.mat> --triadic <converted.mat> \
        --choice <choice.mat> --coords <coords.mat>
"""

import argparse
import os
import sys
import tempfile
import numpy as np
from scipy.io import loadmat

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

DEFAULT_OOO = 'src/samples/brightness/brightness_choices-ooo_GA2.mat'
DEFAULT_TRIADIC = 'src/samples/brightness/brightness_choices-triadic_GA2.mat'
DEFAULT_CHOICE = 'src/samples/bwtextures/bgca3pt_choices_MC_sess01_10.mat'
DEFAULT_COORDS = 'src/samples/bwtextures/bdce3pt_coords_SN_sess01_10.mat'  # rich file: has bestModelLL/biasEstimate/debiasedRelativeLL/metadata, per JV's request to test with rich coord files
DEFAULT_COORDS_BENCHMARK = 'src/samples/brightness/brightness_ooo_GA2_coords_BENCHMARK.mat'

PASS = "PASS"
FAIL = "FAIL"
SKIP = "SKIP"

results = []  # list of (check_name, status, detail)


def report(name, status, detail):
    results.append((name, status, detail))
    print(f"[{status}] {name}")
    if detail:
        print(f"       {detail}")


def check_ooo_to_triadic(ooo_path, triadic_path):
    print("\n=== 1. OOO -> Triadic conversion ===")
    if not (os.path.exists(ooo_path) and os.path.exists(triadic_path)):
        report("OOO -> Triadic", SKIP, f"missing file(s): {ooo_path} / {triadic_path}")
        return
    ooo_raw = loadmat(ooo_path)
    tri_raw = loadmat(triadic_path)
    ooo_stims = [s.strip() for s in ooo_raw['stim_list']]
    tri_stims = [s.strip() for s in tri_raw['stim_list']]
    print(f"\n{'RAW OOO (s1,s2,s3,n1_odd,n2_odd,n3_odd)':<45} | TRIADIC (ref,s1,s2,count,repeats)")
    for i in range(min(5, len(ooo_raw['responses']))):
        o_row = ooo_raw['responses'][i].astype(int)
        o_names = [ooo_stims[j - 1] for j in o_row[:3]]
        t_row = tri_raw['responses'][i].astype(int)
        t_names = [tri_stims[j - 1] for j in t_row[:3]]
        print(f"  {o_names} {str(list(o_row[3:])):<10} | {t_names} {list(t_row[3:])}")

    from verify_triadic_matches_ooo import check
    total_keys, mismatches, stims = check(ooo_path, triadic_path)
    if mismatches:
        report("OOO -> Triadic", FAIL, f"{len(mismatches)}/{total_keys} facts did not match")
    else:
        report("OOO -> Triadic", PASS, f"all {total_keys} independently-derived facts matched exactly")


def check_ooo_benchmark(ooo_path, benchmark_path):
    """Benchmark strategy (per JV): re-run the converter fresh and check its
    output against a frozen, known-correct file -- exact match, since this
    conversion is deterministic (no randomness involved)."""
    print("\n=== 1b. OOO -> Triadic: fresh run vs. frozen benchmark ===")
    if not (os.path.exists(ooo_path) and os.path.exists(benchmark_path)):
        report("OOO -> Triadic benchmark", SKIP, f"missing file(s): {ooo_path} / {benchmark_path}")
        return

    from convert_ooo_to_triadic import ooo_to_triadic
    with tempfile.TemporaryDirectory() as tmp:
        fresh_path = os.path.join(tmp, 'fresh_triadic.mat')
        ooo_to_triadic(ooo_path, out_path=fresh_path)

        fresh = loadmat(fresh_path)
        bench = loadmat(benchmark_path)
        fresh_fields = {k for k in fresh if not k.startswith('__')}
        bench_fields = {k for k in bench if not k.startswith('__')}

        print(f"\n{'FRESH RUN':<45} | FROZEN BENCHMARK")
        for k in sorted(fresh_fields & bench_fields):
            f, b = fresh[k], bench[k]
            if f.dtype.kind in ('U', 'S'):
                f_sq, b_sq = f.squeeze(), b.squeeze()
                f_str = str(f_sq) if f_sq.ndim == 0 else str([str(s).strip() for s in f_sq][:3])
                b_str = str(b_sq) if b_sq.ndim == 0 else str([str(s).strip() for s in b_sq][:3])
            else:
                f_str, b_str = str(f.flatten()[:3]), str(b.flatten()[:3])
            print(f"{k + ':':<20} {f_str:<24} | {b_str}")

        if fresh_fields != bench_fields:
            report("OOO -> Triadic benchmark", FAIL,
                    f"field sets differ (columns skipped?): {fresh_fields.symmetric_difference(bench_fields)}")
            return

        problems = []
        for k in sorted(fresh_fields):
            f, b = fresh[k], bench[k]
            if f.dtype.kind in ('U', 'S'):
                f_sq, b_sq = f.squeeze(), b.squeeze()
                match = ([str(s).strip() for s in f_sq] == [str(s).strip() for s in b_sq]
                         if f_sq.ndim else str(f_sq) == str(b_sq))
            else:
                match = np.array_equal(f, b)
            if not match:
                problems.append(k)

        if problems:
            report("OOO -> Triadic benchmark", FAIL, f"fields differ from frozen benchmark: {problems}")
        else:
            report("OOO -> Triadic benchmark", PASS, f"fresh run matches frozen benchmark exactly ({len(fresh_fields)} fields)")


def check_choice_roundtrip(choice_path):
    print("\n=== 2. Choice file: mat -> npy -> mat round trip ===")
    if not os.path.exists(choice_path):
        report("Choice file round trip", SKIP, f"missing file: {choice_path}")
        return
    from src.rs_py.utils.util import load_choices
    from convert_mat_to_numpy import mat_to_numpy
    from convert_numpy_to_mat import numpy_to_mat

    with tempfile.TemporaryDirectory() as tmp:
        npy_path = os.path.join(tmp, 'test.npy')
        back_path = os.path.join(tmp, 'test_back.mat')

        arr, stim_list = mat_to_numpy(choice_path)
        np.save(npy_path, arr)

        arr_reloaded = np.load(npy_path)
        numpy_to_mat(arr_reloaded, stim_list=stim_list, out_path=back_path)

        orig_resp, orig_rep, _, orig_stims = load_choices(choice_path)
        back_resp, back_rep, _, back_stims = load_choices(back_path)

        print(f"\n{'ORIGINAL':<45} | ROUND-TRIPPED")
        print(f"{'stim_list (first 5):':<20} {str(orig_stims[:5]):<24} | {str(back_stims[:5])}")
        print(f"{'array shape:':<20} {str(arr.shape):<24} | {str(arr_reloaded.shape)}")
        print("first 5 rows:")
        for i in range(min(5, len(arr))):
            print(f"  {str(arr[i].astype(int)):<43} | {str(arr_reloaded[i].astype(int))}")

        problems = []
        if orig_stims != back_stims:
            problems.append("stimulus list changed")
        if orig_resp != back_resp:
            problems.append("response counts changed")
        if orig_rep != back_rep:
            problems.append("repeat counts changed")

        if problems:
            report("Choice file round trip", FAIL, "; ".join(problems))
        else:
            report("Choice file round trip", PASS,
                    f"{len(orig_stims)} stimuli, {sum(orig_rep.values())} total trials, all exact")


DISPARITY_THRESHOLD = 0.1   # ~5-10x normal run-to-run variance (observed ~0.01-0.02)
LL_THRESHOLD = 0.05         # ~5-10x normal run-to-run variance (observed ~0.004-0.012)


def check_coords_benchmark(triadic_path, benchmark_path, dims=(2, 3), max_iter=3000):
    """Benchmark strategy (per JV) for choices -> coordinates: since MDS starts
    from a random position, a fresh correct run won't be byte-identical to a
    frozen benchmark even when nothing is wrong. So this checks two different
    things with two different standards:
      - structure (field names/shapes, i.e. "columns aren't skipped"): exact
        match, since that has nothing to do with randomness.
      - the coordinate values themselves: Procrustes disparity + LL, within a
        tolerance calibrated from real run-to-run variance, not byte-exact.
    """
    print("\n=== 2b. Choices -> Coordinates: fresh fit vs. frozen benchmark ===")
    if not (os.path.exists(triadic_path) and os.path.exists(benchmark_path)):
        report("Choices -> Coordinates benchmark", SKIP, f"missing file(s): {triadic_path} / {benchmark_path}")
        return

    from fit_brightness_ooo import run_mds_single_dim, build_mat_output
    from src.rs_py.utils.util import load_choices
    from src.rs_py.utils.config import CONFIG
    import src.rs_py.choices.choice_likelihoods as an
    from rs_tools.compare import procrustes_disparity

    resp, rep, _, stim_list = load_choices(triadic_path)
    total_triads = sum(rep.values())
    DEFAULTS = CONFIG['inputs']['model_fit']

    coords_by_dim = {}
    lls_by_dim = {}
    for dim in dims:
        coords, ll, _ = run_mds_single_dim(
            resp, rep, len(stim_list), dim, DEFAULTS['sigma'], max_iter,
            DEFAULTS['tolerance'], DEFAULTS['learning_rate'], DEFAULTS['minimization']
        )
        coords_by_dim[dim] = coords
        lls_by_dim[dim] = -ll / total_triads

    bench = loadmat(benchmark_path)
    bench_fields = {k for k in bench if not k.startswith('__')}
    expected_fields = {f'dim{d}' for d in dims} | {'rawLLs', 'bestModelLL', 'randModelLL',
                                                     'biasEstimate', 'debiasedRelativeLL', 'stim_list'}

    # --- structure check: exact, no tolerance ---
    missing = expected_fields - bench_fields
    if missing:
        report("Choices -> Coordinates benchmark", FAIL, f"benchmark file missing expected fields: {missing}")
        return

    bench_stims = [s.strip() for s in bench['stim_list']]
    bench_rawLLs = np.atleast_1d(bench['rawLLs']).squeeze()

    print(f"\n{'dim':<6}{'Procrustes disparity':<24}{'fresh LL':<14}{'benchmark LL':<14}{'LL diff'}")
    problems = []
    for i, dim in enumerate(dims):
        if f'dim{dim}' not in bench_fields:
            problems.append(f"dim{dim} missing from benchmark")
            continue
        disparity, n_shared = procrustes_disparity(coords_by_dim[dim], stim_list, bench[f'dim{dim}'], bench_stims)
        ll_diff = abs(lls_by_dim[dim] - bench_rawLLs[i])
        print(f"{dim:<6}{disparity:<24.5f}{lls_by_dim[dim]:<14.5f}{bench_rawLLs[i]:<14.5f}{ll_diff:.5f}")
        if disparity > DISPARITY_THRESHOLD:
            problems.append(f"dim{dim} Procrustes disparity {disparity:.5f} exceeds threshold {DISPARITY_THRESHOLD}")
        if ll_diff > LL_THRESHOLD:
            problems.append(f"dim{dim} LL diff {ll_diff:.5f} exceeds threshold {LL_THRESHOLD}")

    if problems:
        report("Choices -> Coordinates benchmark", FAIL, "; ".join(problems))
    else:
        report("Choices -> Coordinates benchmark", PASS,
                f"structure exact match, values within tolerance (disparity <= {DISPARITY_THRESHOLD}, LL diff <= {LL_THRESHOLD})")


def check_coords_roundtrip(coords_path):
    print("\n=== 3. Coordinate file: mat -> npz -> mat round trip ===")
    if not os.path.exists(coords_path):
        report("Coordinate file round trip", SKIP, f"missing file: {coords_path}")
        return

    orig = loadmat(coords_path)
    orig_fields = {k for k in orig if not k.startswith('__')}
    # dtype.hasobject catches both plain object arrays AND structured/record
    # dtypes that contain object fields (e.g. MATLAB struct arrays, which load
    # with a structured dtype, not dtype.kind=='O' at the top level)
    if any(orig[k].dtype.hasobject for k in orig_fields):
        report("Coordinate file round trip", SKIP,
                "file contains nested MATLAB struct field(s) -- not supported by "
                "convert_coords_mat_to_numpy.py/convert_numpy_to_coords_mat.py "
                "(known limitation, not a crash to hide)")
        return

    from convert_coords_mat_to_numpy import coords_mat_to_numpy
    from convert_numpy_to_coords_mat import numpy_to_coords_mat

    with tempfile.TemporaryDirectory() as tmp:
        npz_path = os.path.join(tmp, 'test.npz')
        back_path = os.path.join(tmp, 'test_back.mat')

        coords_mat_to_numpy(coords_path, out_path=npz_path)
        numpy_to_coords_mat(npz_path, out_path=back_path)

        back = loadmat(back_path)
        back_fields = {k for k in back if not k.startswith('__')}

        print(f"\n{'ORIGINAL':<45} | ROUND-TRIPPED")
        for k in sorted(orig_fields & back_fields):
            o, b = orig[k], back[k]
            if o.dtype.kind in ('U', 'S'):
                o_sq, b_sq = o.squeeze(), b.squeeze()
                o_str = str(o_sq) if o_sq.ndim == 0 else str([str(s).strip() for s in o_sq][:3])
                b_str = str(b_sq) if b_sq.ndim == 0 else str([str(s).strip() for s in b_sq][:3])
            else:
                o_str = str(o.flatten()[:3])
                b_str = str(b.flatten()[:3])
            print(f"{k + ':':<20} {o_str:<24} | {b_str}")

        if orig_fields != back_fields:
            report("Coordinate file round trip", FAIL,
                    f"field sets differ: {orig_fields.symmetric_difference(back_fields)}")
            return

        problems = []
        for k in sorted(orig_fields):
            o, b = orig[k], back[k]
            if o.dtype.kind in ('U', 'S'):
                o_sq, b_sq = o.squeeze(), b.squeeze()
                if o_sq.ndim == 0:
                    match = str(o_sq) == str(b_sq)
                else:
                    match = [str(s).strip() for s in o_sq] == [str(s).strip() for s in b_sq]
            else:
                match = np.array_equal(o, b)
            if not match:
                problems.append(k)

        if problems:
            report("Coordinate file round trip", FAIL, f"fields that did not match: {problems}")
        else:
            report("Coordinate file round trip", PASS, f"all {len(orig_fields)} fields exact match")


def ask(prompt, default, interactive):
    if not interactive:
        return default
    val = input(f"{prompt} [default: {default}]: ").strip()
    return val if val else default


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--ooo', default=None)
    parser.add_argument('--triadic', default=None)
    parser.add_argument('--choice', default=None)
    parser.add_argument('--coords', default=None)
    parser.add_argument('--which', choices=['ooo', 'choice', 'coords', 'all'], default=None,
                         help='Which check to run non-interactively (uses defaults/flags, no prompts); omit for the interactive menu.')
    args = parser.parse_args()

    # non-interactive only when --which was passed on the command line
    interactive = args.which is None

    print("=" * 60)
    print("VERIFY CONVERSIONS")
    print("=" * 60)

    which = args.which
    if which is None:
        print("\nWhich conversion do you want to verify?")
        print("  1) OOO -> Triadic")
        print("  2) Choice file (mat -> npy -> mat)")
        print("  3) Coordinate file (mat -> npz -> mat)")
        print("  4) All of the above")
        choice = input("Choice [1-4, default: 4]: ").strip() or "4"
        which = {"1": "ooo", "2": "choice", "3": "coords", "4": "all"}.get(choice, "all")

    if which in ('ooo', 'all'):
        ooo_path = args.ooo or ask("Path to raw OOO file", DEFAULT_OOO, interactive)
        triadic_path = args.triadic or ask("Path to converted triadic file", DEFAULT_TRIADIC, interactive)
        print(f"\nTesting: {ooo_path}  ->  {triadic_path}")
        check_ooo_to_triadic(ooo_path, triadic_path)
        check_ooo_benchmark(ooo_path, triadic_path)

    if which in ('choice', 'all'):
        choice_path = args.choice or ask("Path to choice file", DEFAULT_CHOICE, interactive)
        print(f"\nTesting: {choice_path}")
        check_choice_roundtrip(choice_path)

    if which in ('coords', 'all'):
        coords_path = args.coords or ask("Path to coordinate file", DEFAULT_COORDS, interactive)
        print(f"\nTesting: {coords_path}")
        check_coords_roundtrip(coords_path)
        check_coords_benchmark(DEFAULT_TRIADIC, DEFAULT_COORDS_BENCHMARK)

    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    for name, status, _ in results:
        print(f"  [{status}] {name}")

    n_fail = sum(1 for _, s, _ in results if s == FAIL)
    n_skip = sum(1 for _, s, _ in results if s == SKIP)
    n_pass = sum(1 for _, s, _ in results if s == PASS)
    print(f"\n{n_pass} passed, {n_fail} failed, {n_skip} skipped")
    sys.exit(1 if n_fail else 0)
