"""Helpers for demo script wrappers."""

from __future__ import annotations

import argparse
import json
from collections.abc import Mapping
from copy import deepcopy


def merge_defaults(defaults, overrides):
    """Recursively merge user overrides into a defaults dictionary."""
    merged = deepcopy(defaults)
    for key, value in overrides.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = merge_defaults(merged[key], value)
        else:
            merged[key] = value
    return merged


def finalize_kwargs(defaults, kwargs, *, required=None):
    """Apply defaults and verify required keyword arguments are present."""
    required = required or ()
    resolved = merge_defaults(defaults, kwargs)
    missing = [key for key in required if resolved.get(key) in (None, "")]
    if missing:
        raise ValueError("Missing required keyword arguments: {}".format(", ".join(sorted(missing))))
    return resolved


def collect_kwargs(args=None, **kwargs):
    """Accept either a single args-dict or ordinary keyword arguments."""
    if args is None:
        return dict(kwargs)
    if isinstance(args, Mapping):
        merged = dict(args)
    elif hasattr(args, "items"):
        merged = dict(args.items())
    else:
        raise TypeError("args must be a mapping/dict when provided.")
    merged.update(kwargs)
    return merged


def load_kwargs_from_cli(description):
    """Allow scripts to accept keyword args as a JSON object."""
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument(
        "--kwargs",
        default="{}",
        help="JSON object of keyword arguments to pass to the script.",
    )
    args = parser.parse_args()
    loaded = json.loads(args.kwargs)
    if not isinstance(loaded, dict):
        raise ValueError("--kwargs must decode to a JSON object.")
    return loaded
