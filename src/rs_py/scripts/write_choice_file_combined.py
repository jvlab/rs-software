"""Script wrapper for the combined-choice demo."""

from __future__ import annotations

from src.rs_py.demos.demo_combined_choices import get_defaults, run
from src.rs_py.scripts._demo_utils import collect_kwargs, finalize_kwargs, load_kwargs_from_cli


def run_combined_choice_demo(args=None, **kwargs):
    """Run the combined-choice script with an args dict or keyword arguments."""
    kwargs = collect_kwargs(args, **kwargs)
    args = finalize_kwargs(
        get_defaults(),
        kwargs,
        required=("input_path", "output_dir", "exp_name", "subject"),
    )
    return run(**args)


if __name__ == "__main__":
    run_combined_choice_demo(**load_kwargs_from_cli("Combine repeated detailed judgments into a single choice file."))
