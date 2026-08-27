"""
convert_coords_mat_to_numpy.py — Convert a coordinate .mat file (dimN, rawLLs,
bestModelLL, etc.) to a NumPy .npz archive.

Unlike a choice file (one flat table), a coords file has several differently-
shaped arrays -- so this saves to .npz (a named bundle of arrays), not .npy.

Usage:
    python3 convert_coords_mat_to_numpy.py path/to/coords.mat output.npz
"""

import sys
import numpy as np
from scipy.io import loadmat


def coords_mat_to_numpy(mat_path, out_path=None):
    d = loadmat(mat_path)
    fields = {k: v for k, v in d.items() if not k.startswith('__')}

    arrays = {}
    for key, val in fields.items():
        if val.dtype.kind in ('U', 'S'):
            squeezed = val.squeeze()
            if squeezed.ndim == 0:
                # single text field (e.g. 'metadata'/'readme' blob), not a list of names
                arrays[key] = np.array(str(squeezed))
            else:
                # stimulus-name array: normalize to plain unicode strings for saving
                arrays[key] = np.array([str(s).strip() for s in squeezed])
        else:
            arrays[key] = val

    if out_path is not None:
        np.savez(out_path, **arrays)
        print(f"Saved: {out_path}")
        print(f"Fields: {list(arrays.keys())}")

    return arrays


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 convert_coords_mat_to_numpy.py <input_coords.mat> <output.npz>")
        sys.exit(1)
    coords_mat_to_numpy(sys.argv[1], sys.argv[2])
