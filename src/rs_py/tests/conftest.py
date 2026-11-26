import pytest


def pytest_addoption(parser):
    parser.addoption(
        "--no-plots",
        action="store_true",
        default=True,
        help="Run tests without creating or displaying plots.",
    )


@pytest.fixture
def show_plots(request):
    return not request.config.getoption("--no-plots")
