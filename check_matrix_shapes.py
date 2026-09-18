"""
check_matrix_shapes.py — prints the shape (and rank) of the matrices M and R that
anchor_points() builds during initialization.

    M = the (dimensions x stimuli) matrix that gets rank-checked
        (this is where "Matrix is rank-deficient" is raised)
    R = the rotated points, computed only if the rank check passes

Run from inside rs-software, with the choice file (CHOICE_FILE below) in the same
folder, or edit CHOICE_FILE to point at yours:
    python3 check_matrix_shapes.py 7          # one dimension
    python3 check_matrix_shapes.py 5 6 7      # several
"""

import sys
import numpy as np
from src.rs_py.utils.util import load_choices
import src.rs_py.utils.mds_embedding as mds
import src.rs_py.utils.anchor_coordinates as ac

CHOICE_FILE = "bc6pt_choices_DS_sess01.mat"


def matrix_shapes(choice_file, dim):
    """Mirror anchor_points() step by step and report shapes for M and R."""
    resp, rep, meta, stim_list = load_choices(choice_file)
    coords, _ = mds.get_coordinates(dim, resp, rep)

    points = (coords - coords[0, :]).T          # dimensions x stimuli
    M = points[:, 1:]                           # first stimulus is the origin, dropped

    print(f"\n===== dim = {dim} =====")
    print(f"coords from get_coordinates : {coords.shape}   (stimuli x dimensions)")
    print(f"points (transposed)         : {points.shape}   (dimensions x stimuli)")
    print(f"M = points[:, 1:]           : {M.shape}   rank = {np.linalg.matrix_rank(M)}  (needs {dim})")

    try:
        subset = ac.choose_basis_vectors(M)     # the rank check happens here
    except ValueError as e:
        print(f"R                           : never computed -> {e}")
        print(f"                              (it would be {points.shape} if the check passed)")
        return None

    Q = ac.gram_schmidt(subset)
    R = Q.T @ points
    print(f"subset of M                 : {subset.shape}")
    print(f"Q (gram-schmidt)            : {Q.shape}")
    print(f"R = Q.T @ points            : {R.shape}   (dimensions x stimuli)")
    print(f"R.T (what anchor_points returns): {R.T.shape}   (stimuli x dimensions)")
    return M, R


if __name__ == "__main__":
    dims = [int(a) for a in sys.argv[1:]] or [7]
    for d in dims:
        matrix_shapes(CHOICE_FILE, d)
