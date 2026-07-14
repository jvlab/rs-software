"""
rs_ui.py — Shared Streamlit UI components for the JV lab MDS pipeline.

Import in any app:
    from rs_ui import mat_file_sidebar, convergence_plot, run_button
"""

import os
import tempfile
import numpy as np
import plotly.graph_objects as go
import streamlit as st


def mat_file_sidebar(label="File", key_prefix="f", allow_two=False):
    """
    Renders file input widgets in the sidebar (upload or path).
    Returns (path1, name1) for single mode, or (path1, name1, path2, name2) for two-file mode.
    Writes temp files for uploads; returns direct path for path input.
    Returns None for paths not yet provided.
    """
    input_mode = st.sidebar.radio(
        "Input method",
        ["Upload file" if not allow_two else "Upload files",
         "Enter file path" if not allow_two else "Enter file paths"],
        horizontal=True,
        key=f"{key_prefix}_mode"
    )
    upload_mode = input_mode.startswith("Upload")

    def _resolve(uploaded_file, path_str):
        if upload_mode:
            if uploaded_file is None:
                return None, None
            with tempfile.NamedTemporaryFile(suffix='.mat', delete=False) as tmp:
                tmp.write(uploaded_file.read())
                path = tmp.name
            name = uploaded_file.name.replace('_suniyya.mat', '').replace('.mat', '')
            return path, name
        else:
            if not path_str:
                return None, None
            name = os.path.basename(path_str).replace('_suniyya.mat', '').replace('.mat', '')
            return path_str, name

    if allow_two:
        if upload_mode:
            f1 = st.sidebar.file_uploader(f"Dataset 1 (.mat)", type="mat", key=f"{key_prefix}1")
            f2 = st.sidebar.file_uploader(f"Dataset 2 (.mat)", type="mat", key=f"{key_prefix}2")
            p1, n1 = _resolve(f1, None)
            p2, n2 = _resolve(f2, None)
        else:
            raw1 = st.sidebar.text_input("Path to dataset 1", placeholder="/path/to/file1.mat", key=f"{key_prefix}p1")
            raw2 = st.sidebar.text_input("Path to dataset 2", placeholder="/path/to/file2.mat", key=f"{key_prefix}p2")
            p1, n1 = _resolve(None, raw1)
            p2, n2 = _resolve(None, raw2)
        return p1, n1, p2, n2
    else:
        if upload_mode:
            f = st.sidebar.file_uploader(f"{label} (.mat)", type="mat", key=f"{key_prefix}1")
            return _resolve(f, None)
        else:
            raw = st.sidebar.text_input(f"Path to {label.lower()}", placeholder="/path/to/file.mat", key=f"{key_prefix}p1")
            return _resolve(None, raw)


def check_paths_ready(paths, input_mode):
    """
    Given a list of paths (may be None), check if all are ready.
    Shows appropriate errors/info and calls st.stop() if not ready.
    """
    for p in paths:
        if p is None:
            st.info("Upload .mat choice file(s) or enter file path(s) to get started.")
            st.stop()
        if not p.startswith('/tmp') and not os.path.exists(p):
            st.error(f"File not found: {p}")
            st.stop()


def convergence_plot(residuals_dict, total_triads_dict, styles=None):
    """
    Renders a Plotly convergence plot.

    residuals_dict: {label: [(iter, ll), ...]}
    total_triads_dict: {label: int}
    styles: optional {label: dict} with keys 'color', 'dash', 'symbol'
    """
    fig = go.Figure()
    for label, residuals in residuals_dict.items():
        if not residuals:
            continue
        itrs, lls = zip(*residuals)
        total = total_triads_dict[label]
        style = (styles or {}).get(label, {})
        fig.add_trace(go.Scatter(
            x=list(itrs),
            y=[-l / total for l in lls],
            mode='lines+markers',
            name=label,
            marker=dict(size=4, symbol=style.get('symbol', 'circle')),
            line=dict(
                color=style.get('color', None),
                dash=style.get('dash', 'solid')
            )
        ))
    fig.update_layout(
        xaxis_title="Iteration",
        yaxis_title="LL per triad",
        height=350,
        margin=dict(l=40, r=20, t=40, b=40),
        legend=dict(
            orientation="h",
            yanchor="bottom",
            y=1.02,
            xanchor="left",
            x=0
        )
    )
    st.plotly_chart(fig, use_container_width=True)
