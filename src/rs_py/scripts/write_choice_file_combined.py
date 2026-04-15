"""Script wrapper for the combined-choice demo."""

from __future__ import annotations

import json
from copy import deepcopy


from src.rs_py.utils.config import CONFIG
from src.rs_py.choices import choice_file_combined as cfc

REQUIRED_KEYS = ["input_path", "output_dir"]



def options_default():
    opt_defaults = deepcopy(CONFIG["inputs"]["detailed_choice"])

    opt_defaults["metadata"] = {
        "exp_name": "unknown",
        "subject": "unknown",
        "stim_list": [],
        "num_sessions": None,
        "num_trials": None,
        "total_judgments": None,
        "judgment_type": "triadic"
    }
    return opt_defaults


def merge_with_defaults(user_params: dict | None) -> dict:
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


def validate_required(params: dict):
    missing = [k for k in REQUIRED_KEYS if k not in params or params[k] in (None, "", [])]
    if missing:
        raise ValueError(f"Missing required parameter(s): {', '.join(missing)}")


def normalize_params(user_params) -> dict:
    """
    Accept:
      - None
      - dict
      - JSON string
    """
    if user_params is None:
        return {}

    if isinstance(user_params, dict):
        return user_params

    if isinstance(user_params, str):
        user_params = user_params.strip()
        if not user_params:
            return {}
        return json.loads(user_params)

    raise TypeError("user_params must be a dict, JSON string, or None")
