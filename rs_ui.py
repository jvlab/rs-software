"""
rs_ui.py — Shared Streamlit UI components for the JV lab MDS pipeline.

Import in any app:
    from rs_ui import mat_file_sidebar, convergence_plot, run_button
"""

import os
import tempfile
import contextlib
import numpy as np
import plotly.graph_objects as go
import streamlit as st


class _StreamlitStdout:
    """Captures print() output and streams it into a Streamlit placeholder,
    keeping only the last `max_lines` lines. See live_progress() below."""
    def __init__(self, placeholder, max_lines=15):
        self.placeholder = placeholder
        self.max_lines = max_lines
        self.lines = []
        self._buf = ""

    def write(self, text):
        self._buf += text
        while "\n" in self._buf:
            line, self._buf = self._buf.split("\n", 1)
            if line.strip():
                self.lines.append(line)
        self.lines = self.lines[-self.max_lines:]
        self.placeholder.code("\n".join(self.lines) or " ")

    def flush(self):
        pass


@contextlib.contextmanager
def live_progress(placeholder, max_lines=15):
    """Show live fitting progress in the actual browser UI, not just server logs.

    The underlying fit function (Suniyya's gradient_descent, in
    src/rs_py/utils/minimize.py) already print()s progress every `log_every`
    iterations -- but plain print() on Streamlit Cloud only reaches the server
    log, never the page the user is looking at. This captures that same
    output (without touching her code at all) and streams it into a
    placeholder on the page instead, so long/slow fits show visible progress
    rather than a frozen-looking screen -- especially important on Streamlit
    Cloud, which can be slow.

    Usage:
        progress_log = st.empty()
        with live_progress(progress_log):
            run_mds_single_dim(..., log_every=50)
    """
    stream = _StreamlitStdout(placeholder, max_lines=max_lines)
    with contextlib.redirect_stdout(stream):
        yield


def slider_with_number(label, min_value, max_value, default, step=1, help=None, key=None, container=None, disabled=False):
    """
    Renders a slider + a synced number box + a reset-to-default button, all in
    one row: dragging the slider updates the number, typing in the number
    moves the slider. Gives users both quick visual adjustment (slider) and
    exact value entry (number box, including low values sliders are fiddly
    for) -- per JV's request that iteration/dimension controls support both.
    """
    container = container or st.sidebar
    key = key or label.lower().replace(' ', '_').replace('(', '').replace(')', '')
    slider_key, num_key = f"{key}__slider", f"{key}__num"

    if slider_key not in st.session_state:
        st.session_state[slider_key] = default
        st.session_state[num_key] = default

    def _from_slider():
        st.session_state[num_key] = st.session_state[slider_key]

    def _from_num():
        st.session_state[slider_key] = st.session_state[num_key]

    col_slider, col_num, col_reset = container.columns([3, 1.3, 0.5])
    with col_slider:
        st.slider(label, min_value=min_value, max_value=max_value, step=step,
                  key=slider_key, help=help, on_change=_from_slider, disabled=disabled)
    with col_num:
        st.write("")  # spacer to align with the slider's label row
        st.number_input(" ", min_value=min_value, max_value=max_value, step=step,
                         key=num_key, on_change=_from_num, label_visibility="collapsed", disabled=disabled)
    with col_reset:
        st.write("")
        if st.button("↺", key=f"{key}__reset", help="Reset to default", disabled=disabled):
            st.session_state[slider_key] = default
            st.session_state[num_key] = default

    return st.session_state[slider_key]


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
    styles: optional {label: dict} with keys 'color', 'dash', 'symbol', and optionally
            'name' (legend text), 'legendgroup' and 'showlegend' to share one legend entry
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
            name=style.get('name', label),
            legendgroup=style.get('legendgroup'),
            showlegend=style.get('showlegend', True),
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
