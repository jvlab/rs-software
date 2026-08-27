"""
convert_numpy_to_coords_mat.py — Convert a .npz archive (from
convert_coords_mat_to_numpy.py) back into a coordinate .mat file.

Usage:
    python3 convert_numpy_to_coords_mat.py input.npz output_coords.mat
"""

import sys
import numpy as np
from scipy.io import savemat


def numpy_to_coords_mat(npz_path, out_path=None):
    npz = np.load(npz_path)
    data = {}
    for key in npz.files:
        arr = npz[key]
        if arr.dtype.kind == 'U':
            if arr.ndim == 0:
                # single text field (e.g. 'metadata'/'readme' blob)
                data[key] = str(arr)
            else:
                # stimulus-name array: re-encode as fixed-width bytes so MATLAB
                # reads a proper char array, matching every other .mat writer
                # in this repo
                max_len = max(len(s) for s in arr)
                data[key] = np.array(list(arr), dtype=f'S{max_len}')
        else:
            data[key] = arr

    if out_path is not None:
        savemat(out_path, data)
        print(f"Saved: {out_path}")
        print(f"Fields: {list(data.keys())}")

    return data


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 convert_numpy_to_coords_mat.py <input.npz> <output_coords.mat>")
        sys.exit(1)
    numpy_to_coords_mat(sys.argv[1], sys.argv[2])
