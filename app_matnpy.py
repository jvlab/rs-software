"""
app_matnpy.py — Streamlit app for .mat → NumPy conversion.

Run locally:
    cd ~/Downloads/rs-software
    streamlit run app_matnpy.py
"""

import sys
import os
import tempfile
import numpy as np
import streamlit as st

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

st.set_page_config(page_title=".mat → NumPy", layout="centered")
st.title(".mat → NumPy Converter")
st.markdown(
    "Convert a `.mat` triadic choice file to a 5-column NumPy array."
)
st.info(
    "**Output columns:** `ref, s1, s2, N(s1 chosen), N_repeats` (1-indexed)"
)

conv_file = st.file_uploader("Upload .mat choices file", type=["mat"])

if conv_file is not None:
    with tempfile.NamedTemporaryFile(suffix=".mat", delete=False) as tmp:
        tmp.write(conv_file.read())
        tmp_path = tmp.name
    try:
        from convert_mat_to_numpy import mat_to_numpy
        arr, stim_list = mat_to_numpy(tmp_path)

        st.success(f"Loaded: **{arr.shape[0]} trials**, **{len(stim_list)} stimuli**")
        st.markdown(f"**Stimuli:** {', '.join(stim_list[:10])}{'...' if len(stim_list) > 10 else ''}")

        st.dataframe(
            {"ref": arr[:,0].astype(int), "s1": arr[:,1].astype(int),
             "s2": arr[:,2].astype(int), "n_s1_chosen": arr[:,3].astype(int),
             "n_repeats": arr[:,4].astype(int)},
            use_container_width=True, height=300
        )

        out_name = conv_file.name.replace(".mat", ".npy")
        st.download_button("Download .npy file", data=arr.tobytes(),
                           file_name=out_name, mime="application/octet-stream")

    except Exception as e:
        st.error(f"Conversion failed: {e}")
    finally:
        os.unlink(tmp_path)
else:
    st.info("Upload a .mat choices file above to get started.")
