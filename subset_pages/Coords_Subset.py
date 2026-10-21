"""
subset_pages/Coords_Subset.py — the coordinates-file page of the Subset Stimuli app.

This is one page of a multi-page app; app_subset_choices.py and app_subset_coords.py
are the entry points (and top-nav routers) that Streamlit Cloud actually runs.
"""

import sys
import os
import re
import io
import tempfile
import streamlit as st
import scipy.io as sio

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from convert_mat_to_numpy import coords_to_numpy
from rs_tools.subset_stimuli import subset_stimuli, subset_coords_file, save_coords_file

CUSTOM_CSS = """
<style>
html, body { font-family: "Helvetica Neue", Inter, -apple-system, sans-serif; }

.block-container { padding-top: 2.2rem; max-width: 900px; }

.hero {
    background: linear-gradient(135deg, #6C5CE7 0%, #4834D4 100%);
    border-radius: 18px;
    padding: 2rem 2.2rem;
    color: white;
    margin-bottom: 1.6rem;
    box-shadow: 0 10px 30px rgba(108, 92, 231, 0.25);
}
.hero h1 { margin: 0 0 0.35rem 0; font-size: 1.9rem; font-weight: 700; color: white; }
.hero p { margin: 0; opacity: 0.92; font-size: 0.98rem; }

.steps { display: flex; gap: 0.6rem; margin-bottom: 1.4rem; flex-wrap: wrap; }
.step {
    flex: 1; min-width: 150px;
    background: #FFFFFF; border: 1px solid #E7E5F5;
    border-radius: 12px; padding: 0.75rem 1rem;
    display: flex; align-items: center; gap: 0.6rem;
}
.step .num {
    background: #EFECFD; color: #4834D4;
    width: 26px; height: 26px; border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    font-weight: 700; font-size: 0.85rem; flex-shrink: 0;
}
.step .label { font-size: 0.87rem; color: #1B1B2F; font-weight: 600; }
.step.done { border-color: #6C5CE7; }
.step.done .num { background: #6C5CE7; color: white; }
.step.pending { opacity: 0.5; }

.card {
    background: #FFFFFF; border: 1px solid #E7E5F5;
    border-radius: 16px; padding: 1.5rem 1.6rem; margin-bottom: 1.2rem;
    box-shadow: 0 2px 10px rgba(27, 27, 47, 0.04);
}
.card h3 { margin-top: 0; font-size: 1.08rem; color: #1B1B2F; }
.card p.subtitle { color: #6B7280; font-size: 0.9rem; margin-top: -0.5rem; }

.metric-row { display: flex; gap: 0.9rem; flex-wrap: wrap; }
.metric-box {
    flex: 1; min-width: 160px;
    background: #EFECFD; border-radius: 14px;
    padding: 1rem 1.1rem; text-align: left;
}
.metric-box .value { font-size: 1.65rem; font-weight: 800; color: #4834D4; line-height: 1.1; }
.metric-box .label { font-size: 0.82rem; color: #6B7280; margin-top: 0.25rem; }
.metric-box.excluded { background: #FDECEC; }
.metric-box.excluded .value { color: #C0392B; }
.metric-box.kept { background: #E9F9EE; }
.metric-box.kept .value { color: #1E8449; }

.pill-list { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: 0.6rem; }
.pill {
    background: #EFECFD; color: #4834D4;
    border-radius: 999px; padding: 0.25rem 0.75rem; font-size: 0.82rem; font-weight: 600;
}
.pill.more { background: transparent; color: #6B7280; font-weight: 500; }

div[data-testid="stSidebar"] { background: #FAFAFE; border-right: 1px solid #E7E5F5; }
div.stButton > button, div.stDownloadButton > button {
    border-radius: 10px; font-weight: 600; border: none;
}
div.stButton > button[kind="primary"], div.stDownloadButton > button {
    background: #6C5CE7; box-shadow: 0 4px 14px rgba(108, 92, 231, 0.35);
}
div.stButton > button[kind="primary"]:hover, div.stDownloadButton > button:hover {
    background: #4834D4;
}
</style>
"""
st.markdown(CUSTOM_CSS, unsafe_allow_html=True)

st.markdown(
    """
    <div class="hero">
        <h1>Filter a coordinate file by stimuli</h1>
        <p>Keep or remove specific stimuli from a coordinates file — works with any
        number of fitted dimensions at once.</p>
    </div>
    """,
    unsafe_allow_html=True,
)

with st.expander("New here? What does this do?", expanded=False):
    st.markdown(
        "Upload a coordinates file, pick which stimuli to keep or drop, and "
        "download a smaller version with just those stimuli.\n\n"
        "If the file has more than one fitted dimensionality (e.g. both a 2D and "
        "a 3D fit), all of them are filtered together, so they stay in sync. "
        "Any other fields in the file (like fit-quality statistics) are carried "
        "over as-is, with a note that they describe the original file, not this "
        "smaller version."
    )

st.sidebar.title("Filter a coordinate file by stimuli")
st.sidebar.caption("Filter a coordinates file down to a chosen set of stimuli.")
st.sidebar.markdown("---")

coords_uploader_n = st.session_state.get("coords_uploader_n", 0)
uploaded = st.sidebar.file_uploader("Coordinates file (.mat)", type="mat", key=f"coords_uploader_{coords_uploader_n}")


def _filter_another_file():
    """Clear the uploaded file (a new uploader key gives a fresh, empty upload box) and any saved state."""
    st.session_state["coords_uploader_n"] = st.session_state.get("coords_uploader_n", 0) + 1
    for k in []:
        st.session_state.pop(k, None)


if uploaded is not None:
    st.sidebar.button("📂 Filter another file", use_container_width=True,
                      key="filter_another_sidebar", on_click=_filter_another_file,
                      help="Clear this file and go back to a fresh upload.")



def step_badges(uploaded_done, selected_done, run_done):
    def cls(done, active):
        if done:
            return "step done"
        return "step pending" if not active else "step"
    st.markdown(
        f"""
        <div class="steps">
            <div class="{cls(uploaded_done, True)}"><div class="num">1</div><div class="label">Upload file</div></div>
            <div class="{cls(selected_done, uploaded_done)}"><div class="num">2</div><div class="label">Choose stimuli</div></div>
            <div class="{cls(run_done, selected_done)}"><div class="num">3</div><div class="label">Run &amp; download</div></div>
        </div>
        """,
        unsafe_allow_html=True,
    )


if uploaded is None:
    step_badges(False, False, False)
    st.markdown(
        '<div class="card"><h3>Get started</h3>'
        '<p class="subtitle">Upload a .mat coordinates file in the sidebar to begin.</p></div>',
        unsafe_allow_html=True,
    )
    st.stop()

with tempfile.NamedTemporaryFile(suffix=".mat", delete=False) as tmp:
    tmp.write(uploaded.read())
    tmp_path = tmp.name

try:
    coords_by_dim, stim_list = coords_to_numpy(tmp_path)
except Exception as e:
    st.error(f"Could not load file: {e}\n\nMake sure this is a **coordinates** file, not a choice file.")
    os.unlink(tmp_path)
    st.stop()

# Carry over any field beyond the structural ones (dimN, stim_labels/stim_list, readme) --
# generic on purpose, so this keeps working if a future file format has different extra
# fields than the ones this codebase currently writes (rawLLs, bestModelLL, etc.)
# Not squeezed, so extra fields keep their exact MATLAB shapes. mat_dtype=True reads each
# number as the type MATLAB gives it: MATLAB stores whole-number doubles in a compact
# integer form, and without this they would be written back as uint8/uint16.
raw = sio.loadmat(tmp_path, mat_dtype=True)
os.unlink(tmp_path)
structural_keys = {k for k in raw if re.match(r"^dim\d+$", k)} | {"stim_labels", "stim_list"}
extra_fields = {k: v for k, v in raw.items() if not k.startswith("__") and k not in structural_keys}

st.sidebar.markdown("---")
st.sidebar.subheader("Selection")
mode = st.sidebar.radio(
    "How do you want to select stimuli?",
    ["Keep only these (include)", "Remove these (exclude)",
     "Match a pattern (regex)", "Keep all (just reorder)"],
)

include = exclude = regex = None
regex_mode = "include"

if mode == "Keep only these (include)":
    include = st.sidebar.multiselect("Stimuli to keep", options=stim_list)
    selection_ready = bool(include)
elif mode == "Remove these (exclude)":
    exclude = st.sidebar.multiselect("Stimuli to remove", options=stim_list)
    selection_ready = bool(exclude)
elif mode == "Match a pattern (regex)":
    regex = st.sidebar.text_input(
        "Regex pattern", placeholder="e.g. ^b",
        help=(
            "Examples:\n"
            "- `^b` — starts with b\n"
            "- `0600$` — ends with 0600\n"
            "- `p\\d{4}$` — ends in \"p\" + 4 digits (e.g. bp0400, cp0200) — picks out positives\n"
            "- `m\\d{4}$` — ends in \"m\" + 4 digits (e.g. bm0400, cm0200) — picks out negatives\n"
            "- `rand` — contains \"rand\" anywhere"
        ),
    )
    regex_mode = st.sidebar.radio("Pattern matches should be...", ["include", "exclude"], horizontal=True)
    selection_ready = bool(regex)
else:  # Keep all (just reorder)
    exclude = []
    selection_ready = True

alphabetize = st.sidebar.checkbox("Alphabetize the output stimulus list", value=False)

st.sidebar.markdown("---")
run_btn = st.sidebar.button("Run", type="primary", use_container_width=True)

dims_str = ", ".join(f"{d}D" for d in sorted(coords_by_dim))

st.markdown(
    f'<div class="card"><h3>Loaded file</h3>'
    f'<p class="subtitle">{uploaded.name}</p>'
    f'<div class="metric-row">'
    f'<div class="metric-box"><div class="value">{len(stim_list)}</div><div class="label">Stimuli</div></div>'
    f'<div class="metric-box"><div class="value">{dims_str}</div><div class="label">Fitted dimensions</div></div>'
    f'</div></div>',
    unsafe_allow_html=True,
)

# Live preview -- cheap, uses only the lightweight name-selection step, not the full
# coords-file processing, so it can update instantly as the sidebar selection changes.
if selection_ready:
    try:
        preview_names, _ = subset_stimuli(
            stim_list, include=include, exclude=exclude, regex=regex,
            regex_mode=regex_mode, alphabetize=alphabetize)
        preview_error = None
    except ValueError as e:
        preview_names = None
        preview_error = str(e)

    if preview_error:
        st.markdown(
            f'<div class="card"><h3>Preview</h3>'
            f'<p class="subtitle">{preview_error}</p></div>',
            unsafe_allow_html=True,
        )
    else:
        preview_pills = "".join(f'<span class="pill">{name}</span>' for name in preview_names[:24])
        preview_more = (f'<span class="pill more">+{len(preview_names) - 24} more</span>'
                        if len(preview_names) > 24 else "")
        st.markdown(
            f'<div class="card"><h3>Preview</h3>'
            f'<p class="subtitle">Will keep {len(preview_names)} of {len(stim_list)} stimuli. '
            f'Click Run to actually process the file.</p>'
            f'<div class="pill-list">{preview_pills}{preview_more}</div></div>',
            unsafe_allow_html=True,
        )
else:
    st.markdown(
        '<div class="card"><h3>Preview</h3>'
        '<p class="subtitle">Choose stimuli in the sidebar to see a preview here.</p></div>',
        unsafe_allow_html=True,
    )

if not run_btn:
    step_badges(True, selection_ready, False)
    st.stop()

if not selection_ready:
    st.error("Set your selection in the sidebar before running.")
    st.stop()

try:
    new_coords, new_stims = subset_coords_file(
        stim_list, coords_by_dim, include=include, exclude=exclude,
        regex=regex, regex_mode=regex_mode, alphabetize=alphabetize)
except ValueError as e:
    st.error(str(e))
    st.stop()

step_badges(True, True, True)

n_excluded_stim = len(stim_list) - len(new_stims)

pills = "".join(f'<span class="pill">{name}</span>' for name in new_stims[:24])
more = f'<span class="pill more">+{len(new_stims) - 24} more</span>' if len(new_stims) > 24 else ""

st.markdown(
    f"""
    <div class="card">
        <h3>Result</h3>
        <div class="metric-row">
            <div class="metric-box kept">
                <div class="value">{len(new_stims)} / {len(stim_list)}</div>
                <div class="label">Stimuli kept</div>
            </div>
            <div class="metric-box excluded">
                <div class="value">{n_excluded_stim}</div>
                <div class="label">Stimuli excluded</div>
            </div>
        </div>
        <div class="pill-list">{pills}{more}</div>
    </div>
    """,
    unsafe_allow_html=True,
)

if extra_fields:
    st.caption(
        f"Carrying over {len(extra_fields)} other field(s) from the original file "
        f"({', '.join(sorted(extra_fields))}) -- they are saved unchanged, so they "
        "still describe the original file, not this subset."
    )

buf = io.BytesIO()
with tempfile.NamedTemporaryFile(suffix=".mat", delete=False) as tmp_out:
    save_coords_file(tmp_out.name, new_coords, new_stims, extra_fields=extra_fields)
    with open(tmp_out.name, "rb") as f:
        buf.write(f.read())
os.unlink(tmp_out.name)

out_name = uploaded.name.replace(".mat", "_subset.mat")
st.download_button("Download subset .mat", data=buf.getvalue(),
                   file_name=out_name, mime="application/octet-stream")

st.button("📂 Filter another file", key="filter_another_result", on_click=_filter_another_file,
          help="Clear this file and go back to a fresh upload.")
