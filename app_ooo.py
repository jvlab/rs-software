"""
app_ooo.py — Streamlit app for OOO → Triadic conversion.

Run locally:
    cd ~/Downloads/rs-software
    streamlit run app_ooo.py
"""

import sys
import os
import tempfile
import numpy as np
import streamlit as st
from scipy.io import loadmat

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

st.set_page_config(page_title="OOO → Triadic", layout="centered")
st.title("OOO → Triadic Converter")
st.markdown(
    "Convert an **odd-one-out** `.mat` file to standard triadic choice format. "
    "Each OOO judgment generates exactly 2 triadic entries using JV's conversion rule."
)
st.info(
    "**Input format:** columns `s1, s2, s3, N(s1 odd), N(s2 odd), N(s3 odd)` (1-indexed)\n\n"
    "**Output format:** columns `ref, s1, s2, N(s1 chosen), N_repeats` (1-indexed)"
)

ooo_file = st.file_uploader("Upload OOO .mat file", type=["mat"])

if ooo_file is not None:
    with tempfile.NamedTemporaryFile(suffix=".mat", delete=False) as tmp:
        tmp.write(ooo_file.read())
        ooo_tmp = tmp.name
    try:
        from convert_ooo_to_triadic import ooo_to_triadic
        resp_ooo, rep_ooo, stims_ooo = ooo_to_triadic(ooo_tmp, out_path=None)

        _d = loadmat(ooo_tmp)
        n_input_triplets = _d['responses'].shape[0] if 'responses' in _d else None

        st.success(
            f"Converted: **{n_input_triplets} input triplets** → **{len(resp_ooo)} triadic trials** · **{len(stims_ooo)} stimuli**"
        )
        st.markdown(f"**Stimuli:** {', '.join(stims_ooo[:10])}{'...' if len(stims_ooo) > 10 else ''}")

        import pandas as pd
        rows = []
        for (ref_s1, s1), (_, s2) in list(resp_ooo.keys())[:200]:
            key = ((ref_s1, s1), (ref_s1, s2))
            rows.append({
                "ref": ref_s1 + 1, "s1": s1 + 1, "s2": s2 + 1,
                "n_s1_chosen": resp_ooo[key], "n_repeats": rep_ooo[key],
                "ref_name": stims_ooo[ref_s1], "s1_name": stims_ooo[s1], "s2_name": stims_ooo[s2],
            })
        st.dataframe(pd.DataFrame(rows), use_container_width=True, height=300)

        with tempfile.NamedTemporaryFile(suffix=".mat", delete=False) as out_tmp:
            out_ooo_path = out_tmp.name
        ooo_to_triadic(ooo_tmp, out_path=out_ooo_path)
        with open(out_ooo_path, "rb") as f:
            ooo_bytes = f.read()
        os.unlink(out_ooo_path)

        out_name = ooo_file.name.replace("ooo", "triadic").replace(".mat", "_triadic.mat")
        if "triadic" not in out_name:
            out_name = ooo_file.name.replace(".mat", "_triadic.mat")
        st.download_button("Download triadic .mat", data=ooo_bytes,
                           file_name=out_name, mime="application/octet-stream")

    except Exception as e:
        st.error(f"Conversion failed: {e}")
    finally:
        os.unlink(ooo_tmp)
else:
    st.info("Upload an OOO .mat file above to get started.")
