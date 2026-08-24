"""
rng_control.py — if_frozen randomization control, kept entirely separate from
Suniyya's src/rs_py package so her files stay untouched.

Convention (mirrors MATLAB behavior):
  if_frozen = 1  -> seed(0) -- same sequence every run
  if_frozen = 0  -> seed(None) -- fully random each run
  if_frozen < 0  -> seed(0), then advance by abs(if_frozen) steps

Usage: call initialize_random_state(if_frozen) yourself, immediately before
calling get_coordinates() / points_of_best_fit() (whenever start_points is not
given) -- those functions no longer manage seeding internally.
"""

import numpy as np


def initialize_random_state(if_frozen):
    if if_frozen == 0:
        np.random.seed(None)
    elif if_frozen == 1:
        np.random.seed(0)
    elif if_frozen < 0:
        np.random.seed(0)
        np.random.rand(abs(if_frozen))
