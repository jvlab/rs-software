"""
Checks for rs_tools.results_export and rs_tools.run_comparison.

Run:  python -m pytest rs_tools/tests/test_results_export.py -q
"""

import os
import sys

import numpy as np
import pytest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, REPO)

from rs_tools.results_export import build_record, load_record, save_record, summarize  # noqa: E402


@pytest.fixture
def record():
    rng = np.random.default_rng(0)
    return build_record(
        source="test", dataset1="MC", dataset2="MC-br", dim=3, n_surrogates=20,
        real_disparity=0.0836, surrogate_disparities=rng.uniform(0.01, 0.04, 20),
        real_ll1=-0.7464, real_ll2=-0.7482,
        surrogate_ll1=rng.normal(-0.77, 0.005, 20), surrogate_ll2=rng.normal(-0.77, 0.005, 20),
        max_iterations_real=100, max_iterations_surrogate=100, learning_rate=0.05,
        resample_method="with_replacement", warm_start=False, n_shared_stimuli=25)


def test_p_values(record):
    assert record["n_surrogates_ge_real"] == 0
    assert record["p_value"] == 0.0
    assert "p_value_plus_one" not in record


def test_p_value_counts_ties_and_larger():
    rec = build_record(source="t", dataset1="a", dataset2="b", dim=2, n_surrogates=4,
                       real_disparity=0.5, surrogate_disparities=[0.1, 0.5, 0.6, 0.2])
    assert rec["n_surrogates_ge_real"] == 2
    assert rec["p_value"] == 0.5


@pytest.mark.parametrize("ext", ["json", "mat", "npz"])
def test_round_trip_every_format(record, tmp_path, ext):
    path = str(tmp_path / f"run.{ext}")
    save_record(record, path)
    back = load_record(path)
    assert back["dim"] == 3 and back["n_surrogates"] == 20
    assert back["dataset1"] == "MC" and back["resample_method"] == "with_replacement"
    assert back["real_disparity"] == pytest.approx(0.0836)
    assert back["p_value"] == pytest.approx(record["p_value"])
    for key in ("surrogate_disparities", "surrogate_ll1", "surrogate_ll2"):
        assert np.allclose(back[key], record[key])


def test_missing_surrogate_lls_are_allowed(tmp_path):
    rec = build_record(source="t", dataset1="a", dataset2="b", dim=2, n_surrogates=3,
                       real_disparity=0.2, surrogate_disparities=[0.1, 0.1, 0.1])
    for ext in ("json", "mat", "npz"):
        path = str(tmp_path / f"r.{ext}")
        save_record(rec, path)
        assert len(load_record(path)["surrogate_disparities"]) == 3


def test_summarize_collects_runs_into_a_csv(record, tmp_path):
    for i, d2 in enumerate(["MC-br", "MC-gm"]):
        r = dict(record, dataset2=d2)
        save_record(r, str(tmp_path / f"run{i}.json"))
    csv_path = str(tmp_path / "all.csv")
    rows = summarize([str(tmp_path / "run0.json"), str(tmp_path / "run1.json")], csv_path)
    assert [r["dataset2"] for r in rows] == ["MC-br", "MC-gm"]
    lines = open(csv_path).read().strip().splitlines()
    assert len(lines) == 3 and lines[0].startswith("file,dataset1,dataset2,dim")


def test_batch_script_writes_files_and_skips_finished_runs(tmp_path):
    from rs_tools.run_comparison import run_one
    f1 = os.path.join(REPO, "src/samples/bwtextures/bgca3pt_choices_MC_sess01_10.mat")
    f2 = os.path.join(REPO, "src/samples/bwtextures/bgca3pt_choices_MC-br_sess01_10.mat")
    if not (os.path.exists(f1) and os.path.exists(f2)):
        pytest.skip("sample choice files not present")
    paths = run_one(f1, f2, 2, "with_replacement", 3, 20, 20, 2, str(tmp_path), ["json"], verbose=False)
    rec = load_record(paths[0])
    assert rec["dim"] == 2 and rec["n_surrogates"] == 3 and rec["max_iterations_real"] == 20
    assert len(rec["surrogate_disparities"]) == 3
    mtime = os.path.getmtime(paths[0])
    run_one(f1, f2, 2, "with_replacement", 3, 20, 20, 2, str(tmp_path), ["json"], verbose=False)
    assert os.path.getmtime(paths[0]) == mtime, "a finished run should be skipped, not redone"


def _record_with_extras(n_stim=5, dim=2, n_conv=1):
    rng = np.random.default_rng(1)
    labels = [f"s{i}" for i in range(n_stim)]
    return build_record(
        source="t", dataset1="a", dataset2="b", dim=dim, n_surrogates=3, real_disparity=0.2,
        surrogate_disparities=[0.1, 0.1, 0.3],
        extras={"stim_labels1": labels, "stim_labels2": labels, "real_coords1": rng.normal(size=(n_stim, dim)),
                "real_coords2": rng.normal(size=(n_stim, dim)), "shared_stim_labels": labels,
                "aligned_coords1": rng.normal(size=(n_stim, dim)), "aligned_coords2": rng.normal(size=(n_stim, dim)),
                "convergence_dataset1": np.column_stack([np.arange(n_conv) * 50, -rng.random(n_conv)]),
                "convergence_dataset2": None})


@pytest.mark.parametrize("ext", ["json", "mat", "npz"])
@pytest.mark.parametrize("n_stim,dim,n_conv", [(5, 2, 1), (5, 1, 3), (1, 2, 1)])
def test_maps_labels_and_convergence_round_trip(tmp_path, ext, n_stim, dim, n_conv):
    rec = _record_with_extras(n_stim, dim, n_conv)
    path = str(tmp_path / f"r.{ext}")
    save_record(rec, path)
    back = load_record(path)
    assert list(back["stim_labels1"]) == list(rec["stim_labels1"])
    for key in ("real_coords1", "real_coords2", "aligned_coords1", "aligned_coords2", "convergence_dataset1"):
        assert back[key].shape == rec[key].shape, (key, back[key].shape, rec[key].shape)
        assert np.allclose(back[key], rec[key])


def test_unknown_extra_field_is_rejected():
    with pytest.raises(ValueError):
        build_record(source="t", dataset1="a", dataset2="b", dim=2, n_surrogates=1, real_disparity=0.1,
                     surrogate_disparities=[0.1], extras={"nonsense": [1]})


def test_bundle_zip_has_everything(tmp_path):
    import io
    import zipfile
    from rs_tools.results_export import bundle_zip, coords_csv, convergence_csv
    rec = _record_with_extras()
    data = bundle_zip(rec, {"coordinates_dataset1.csv": coords_csv(rec["stim_labels1"], rec["real_coords1"]),
                            "convergence.csv": convergence_csv({"a": rec["convergence_dataset1"], "pooled": None})})
    z = zipfile.ZipFile(io.BytesIO(data))
    assert {"README.txt", "results.json", "results.mat", "results.npz",
            "coordinates_dataset1.csv", "convergence.csv"} <= set(z.namelist())
    header = z.read("coordinates_dataset1.csv").decode().splitlines()[0]
    assert header == "stimulus,dim1,dim2"
    assert z.read("convergence.csv").decode().splitlines()[0] == "fit,iteration,log_likelihood_per_triad"


def test_summary_table_p_value_has_two_decimals(record):
    from rs_tools.results_export import summary_table_csv
    lines = summary_table_csv(record).decode().strip().splitlines()
    assert lines[1].split(",")[-1] == "0.00"
