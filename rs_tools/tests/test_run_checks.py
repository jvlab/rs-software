import pytest

from rs_tools.run_checks import cost_plateau, estimate_seconds, format_duration


def test_estimate_scales_with_surrogates_and_workers():
    # 0.01 s per iteration per dataset, 2 datasets
    base = estimate_seconds(0.01, 0.01, 100, 0, 100, warm_start=False)
    assert base == pytest.approx(2.0)                      # two real fits of 100 iterations
    with_warm = estimate_seconds(0.01, 0.01, 100, 0, 100, warm_start=True)
    assert with_warm == pytest.approx(4.0)                 # plus the pooled fit
    one_worker = estimate_seconds(0.01, 0.01, 100, 10, 100, warm_start=False, speedup=1)
    two_workers = estimate_seconds(0.01, 0.01, 100, 10, 100, warm_start=False, speedup=2)
    assert one_worker == pytest.approx(2.0 + 0.02 * 10 * 100)
    assert two_workers == pytest.approx(2.0 + 0.02 * 10 * 100 / 2)


def test_format_duration():
    assert format_duration(30) == "about 30 seconds"
    assert format_duration(600) == "about 10 min"
    assert format_duration(7200) == "about 2.0 hours"


def test_plateau_flat_curve_is_levelled_off():
    residuals = [(i, 0.72 * 100) for i in range(50, 501, 50)]
    levelled, change = cost_plateau(residuals, total_triads=100)
    assert levelled and change == 0.0


def test_plateau_falling_curve_is_still_improving():
    residuals = [(i, (0.9 - 0.0004 * i) * 100) for i in range(50, 501, 50)]
    levelled, change = cost_plateau(residuals, total_triads=100)
    assert not levelled and change > 0.001


def test_plateau_needs_enough_points():
    assert cost_plateau([], 100) is None
    assert cost_plateau([(50, 70.0), (100, 69.0)], 100) is None
