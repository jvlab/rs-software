"""
To demo the script choice_file_detailed.py
"""
from __future__ import annotations

import os
from copy import deepcopy


from src.rs_py.utils.config import CONFIG
from src.rs_py.choices import choice_file_detailed as cfd

REQUIRED_KEYS = ["input_path", "output_dir"]


def options_default():
    opt_defaults = deepcopy(CONFIG["inputs"]["detailed_choice"])
    return opt_defaults


def merge_with_defaults(user_params):
    defaults = options_default()
    params = deepcopy(defaults)

    if not user_params:
        return params

    # Merge top-level keys first
    for key, value in user_params.items():
        if key != "metadata":
            params[key] = value

    # Merge metadata separately, if provided
    user_metadata = user_params.get("metadata")
    if isinstance(user_metadata, dict):
        params["metadata"].update(user_metadata)
    elif user_metadata is not None:
        raise TypeError("metadata must be a dict if provided")

    return params


def validate_required(params):
    missing = [k for k in REQUIRED_KEYS if k not in params or params[k] in (None, "", [])]
    if missing:
        raise ValueError(f"Missing required parameter(s): {', '.join(missing)}")


def run(user_params):
    """
    Run the detailed choice-file builder on a set of user parameters.

    Args:
        user_params: Dictionary of parameters used to build the detailed choice
        file.
            Required keys:
                - input_path: Path to the input directory containing raw data.
                - output_dir: Path to the directory where outputs should be saved.
            Optional key:
                - metadata: Dictionary with optional fields such as:
                - exp_name: Experiment name.
                - subject: Subject identifier.
                - stim_list: List of stimuli.
                - num_sessions: Number of sessions.
                - num_trials: Number of trials.
                - total_judgments: Total number of judgments.
                - judgment_type: Type of judgment task, default is "triadic".

    Returns:
        None

    Raises:
    - ValueError: If a required parameter is missing or empty.
    - TypeError: If metadata is provided but is not a dictionary.
    - FileNotFoundError: If input_path does not exist.
    """
    params = merge_with_defaults(user_params)
    validate_required(params)

    input_path = params["input_path"]
    output_dir = params["output_dir"]

    metadata = params["metadata"]
    exp_name = metadata["exp_name"]
    subject = metadata["subject"]

    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Input directory not found: {input_path}")

    os.makedirs(output_dir, exist_ok=True)

    print("\nProcessing raw data...")
    print(f"  Input directory: {input_path}")
    print(f"  Output directory: {output_dir}")
    print(f"  Subject: {subject}")
    print(f"  Experiment: {exp_name}")
    print(f"  Types of judgments: {metadata['judgment_type']}\n")

    cfd.build_detailed_choice_mat(
        input_dir=input_path,
        output_dir=output_dir,
        exp_name=exp_name,
        subject=subject,
        metadata=metadata,
    )

    print("\nDone.")



