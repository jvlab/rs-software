"""
subset_pages/Choice_Subset.py — the triadic/tetradic choice-file page of the Subset Stimuli app.

This is one page of a multi-page app; app_subset_choices.py is the entry point
(and top-nav router) that Streamlit Cloud actually runs.
"""

import sys
import os
import io
import tempfile
import streamlit as st

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from rs_tools.choice_loader import load_choices
from rs_tools.subset_stimuli import (
    subset_stimuli, subset_choice_file, save_choice_file, detect_choice_format,
    validate_choice_responses,
)

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
        <h1>Filter a choice file by stimuli</h1>
        <p>Keep or remove specific stimuli from a choice file before running analysis —
        works on both triadic and tetradic files.</p>
    </div>
    """,
    unsafe_allow_html=True,
)

with st.expander("New here? What does this do?", expanded=False):
    st.markdown(
        "Upload a choice file, pick which stimuli to keep or drop, and download a "
        "smaller version with just those stimuli.\n\n"
        "Any trial that mentions a removed stimulus gets dropped too, and the "
        "remaining stimuli are renumbered from 1, with no gaps."
    )

st.sidebar.title("Filter a choice file by stimuli")
st.sidebar.caption("Filter a choice file down to a chosen set of stimuli.")
st.sidebar.markdown("---")

choice_uploader_n = st.session_state.get("choice_uploader_n", 0)
uploaded = st.sidebar.file_uploader("Choice file (.mat)", type="mat", key=f"choice_uploader_{choice_uploader_n}")


def _filter_another_file():
    """Clear the uploaded file (a new uploader key gives a fresh, empty upload box) and any saved state."""
    st.session_state["choice_uploader_n"] = st.session_state.get("choice_uploader_n", 0) + 1
    for k in ['choice_file_id', 'choice_file_format', 'choice_original', 'choice_working', 'choice_chain_count', 'choice_result', 'choice_just_chained']:
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
        '<p class="subtitle">Upload a .mat choice file in the sidebar to begin.</p></div>',
        unsafe_allow_html=True,
    )
    st.stop()

# A fresh upload (new file_id) resets any chained filtering from a previous file.
# Re-running with the SAME uploaded file (e.g. after clicking "Filter this result
# again") must NOT re-load from disk, since that would wipe out the chained result
# and go back to the original data -- so this whole block only runs once per file.
if st.session_state.get("choice_file_id") != uploaded.file_id:
    with tempfile.NamedTemporaryFile(suffix=".mat", delete=False) as tmp:
        tmp.write(uploaded.read())
        tmp_path = tmp.name

    file_format = detect_choice_format(tmp_path)

    if file_format == "odd_one_out":
        os.unlink(tmp_path)
        st.markdown(
            '<div class="card"><h3>This is an odd-one-out file</h3>'
            '<p class="subtitle">It has the same number of columns as a tetradic file, but they '
            'mean something different — no <code>s4</code> column, three separate odd-count '
            'columns instead. Use the dedicated odd-one-out page instead.</p></div>',
            unsafe_allow_html=True,
        )
        st.page_link("subset_pages/OOO_Subset.py", label="Go to: Filter an odd-one-out choice file by stimuli")
        st.stop()

    try:
        resp, rep, metadata, stim_list = load_choices(tmp_path)
    except Exception as e:
        os.unlink(tmp_path)
        st.error(f"Could not load file: {e}\n\nMake sure this is a **choice** file, not a coordinates file.")
        st.stop()

    try:
        validate_choice_responses(tmp_path, file_format, len(stim_list))
    except ValueError as e:
        st.error(f"This doesn't look like a valid {file_format} file:\n\n{e}")
        st.stop()
    finally:
        os.unlink(tmp_path)

    st.session_state["choice_file_id"] = uploaded.file_id
    st.session_state["choice_file_format"] = file_format
    st.session_state["choice_original"] = {"resp": resp, "rep": rep, "stim_list": stim_list}
    st.session_state["choice_working"] = {"resp": resp, "rep": rep, "stim_list": stim_list}
    st.session_state["choice_chain_count"] = 0

working = st.session_state["choice_working"]
resp, rep, stim_list = working["resp"], working["rep"], working["stim_list"]
file_format = st.session_state["choice_file_format"]
chain_count = st.session_state["choice_chain_count"]

trial_word = {"triadic": "Triads", "tetradic": "Tetrads"}.get(file_format, "Trials")

st.sidebar.markdown("---")
st.sidebar.subheader("Selection")
if chain_count > 0:
    st.sidebar.caption(
        f"Filtering pass {chain_count + 1} — working from the previous result "
        f"({len(stim_list)} stimuli). Selections below start fresh each pass."
    )

# Widget keys are suffixed with chain_count so each new filtering pass starts with
# blank selections instead of inheriting stale picks from a stimulus list that may
# no longer contain those names.
mode = st.sidebar.radio(
    "How do you want to select stimuli?",
    ["Keep only these (include)", "Remove these (exclude)",
     "Match a pattern (regex)", "Keep all (just reorder)"],
    key=f"mode-{chain_count}",
)

include = exclude = regex = None
regex_mode = "include"

if mode == "Keep only these (include)":
    include = st.sidebar.multiselect("Stimuli to keep", options=stim_list, key=f"include-{chain_count}")
    selection_ready = bool(include)
elif mode == "Remove these (exclude)":
    exclude = st.sidebar.multiselect("Stimuli to remove", options=stim_list, key=f"exclude-{chain_count}")
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
        key=f"regex-{chain_count}",
    )
    regex_mode = st.sidebar.radio("Pattern matches should be...", ["include", "exclude"],
                                   horizontal=True, key=f"regex_mode-{chain_count}")
    selection_ready = bool(regex)
else:  # Keep all (just reorder)
    exclude = []
    selection_ready = True

alphabetize = st.sidebar.checkbox("Alphabetize the output stimulus list", value=False,
                                   key=f"alphabetize-{chain_count}")

st.sidebar.markdown("---")
run_btn = st.sidebar.button("Run", type="primary", use_container_width=True)

# Buttons use on_click callbacks, which run BEFORE the script reruns. A plain
# `if st.button(...)` placed after the Run check never fires: clicking it reruns
# the page with Run no longer pressed, and the script stops before reaching it.
def _chain_to(new_resp, new_rep, new_stims, new_count):
    st.session_state["choice_working"] = {"resp": new_resp, "rep": new_rep, "stim_list": new_stims}
    st.session_state["choice_chain_count"] = new_count
    st.session_state["choice_just_chained"] = True


def _reset_to_original():
    st.session_state["choice_working"] = dict(st.session_state["choice_original"])
    st.session_state["choice_chain_count"] = 0


if chain_count > 0:
    st.sidebar.button("↺ Reset to original file", use_container_width=True,
                      key="reset_sidebar", on_click=_reset_to_original)

if st.session_state.pop("choice_just_chained", False):
    st.toast(f"Ready for pass {chain_count + 1} -- pick what to keep or remove from this result.", icon="🔁")

if chain_count > 0:
    st.markdown(
        f'<div class="card"><h3>Pass {chain_count + 1}: filtering your last result</h3>'
        f'<p class="subtitle">You are now working from the result of pass {chain_count}, not your '
        f'original upload ({len(stim_list)} stimuli, {len(resp)} {trial_word.lower()} left). '
        f'Choose what to keep or remove in the sidebar, then click Run. '
        f'Use "Reset to original file" in the sidebar to start over.</p></div>',
        unsafe_allow_html=True,
    )

pass_note = (f" — pass {chain_count + 1}, working from the result of pass {chain_count}"
             if chain_count > 0 else "")
st.markdown(
    f'<div class="card"><h3>Loaded file</h3>'
    f'<p class="subtitle">{uploaded.name} — detected as <b>{file_format.replace("_", " ")}</b>{pass_note}</p>'
    f'<div class="metric-row">'
    f'<div class="metric-box"><div class="value">{len(stim_list)}</div><div class="label">Stimuli</div></div>'
    f'<div class="metric-box"><div class="value">{len(resp)}</div><div class="label">{trial_word.rstrip("s")} types</div></div>'
    f'</div></div>',
    unsafe_allow_html=True,
)

# Live preview -- cheap, uses only the lightweight name-selection step, not the full
# choice-file processing, so it can update instantly as the sidebar selection changes.
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

# The result is remembered for as long as the selection stays the same, so it
# survives reruns caused by the download button or the filter-again button.
selection_sig = (chain_count, mode, tuple(include or ()), tuple(exclude or ()),
                 regex, regex_mode, alphabetize)
stored = st.session_state.get("choice_result")

if run_btn:
    if not selection_ready:
        st.error("Set your selection in the sidebar before running.")
        st.stop()
    try:
        new_resp, new_rep, new_stims = subset_choice_file(
            stim_list, resp, rep, include=include, exclude=exclude,
            regex=regex, regex_mode=regex_mode, alphabetize=alphabetize)
    except ValueError as e:
        st.error(str(e))
        st.stop()
    st.session_state["choice_result"] = {"sig": selection_sig, "data": (new_resp, new_rep, new_stims)}
elif stored and stored["sig"] == selection_sig:
    new_resp, new_rep, new_stims = stored["data"]
else:
    step_badges(True, selection_ready, False)
    st.stop()

step_badges(True, True, True)

n_excluded_stim = len(stim_list) - len(new_stims)
n_dropped_trials = len(resp) - len(new_resp)

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
            <div class="metric-box kept">
                <div class="value">{len(new_resp)} / {len(resp)}</div>
                <div class="label">{trial_word} kept</div>
            </div>
            <div class="metric-box excluded">
                <div class="value">{n_dropped_trials}</div>
                <div class="label">{trial_word} excluded</div>
            </div>
        </div>
        <div class="pill-list">{pills}{more}</div>
    </div>
    """,
    unsafe_allow_html=True,
)

pass_no = chain_count + 1


if not new_resp:
    st.warning(
        f"No {trial_word.lower()} remain after filtering, so there's nothing to download. "
        "This can happen with tetradic files if the stimuli you kept never "
        "appear together in the same trial -- try keeping a larger set."
    )
    if chain_count > 0:
        st.button("↺ Reset to original file", use_container_width=True,
                  key="reset_result_empty", on_click=_reset_to_original)
    st.stop()

buf = io.BytesIO()
with tempfile.NamedTemporaryFile(suffix=".mat", delete=False) as tmp_out:
    save_choice_file(tmp_out.name, new_resp, new_rep, new_stims)
    with open(tmp_out.name, "rb") as f:
        buf.write(f.read())
os.unlink(tmp_out.name)

suffix = "_subset.mat" if pass_no == 1 else f"_subset{pass_no}.mat"
out_name = uploaded.name.replace(".mat", suffix)
st.download_button(
    "Download subset .mat" if pass_no == 1 else f"Download pass {pass_no} result (.mat)",
    data=buf.getvalue(), file_name=out_name, mime="application/octet-stream")
st.caption(f"This file has {len(new_stims)} stimuli and {len(new_resp)} {trial_word.lower()}.")

st.markdown("---")
st.markdown("**Want to narrow it down further?**")
st.caption(
    "\"Filter this result again\" makes the result above your new starting point, so you don't have to "
    "re-upload. The result above is then replaced, so download it first if you need it."
)
chain_col, reset_col = st.columns(2)
with chain_col:
    st.button("🔁 Filter this result again", use_container_width=True, key="filter_again",
              on_click=_chain_to, args=(new_resp, new_rep, new_stims, chain_count + 1))
with reset_col:
    if chain_count > 0:
        st.button("↺ Reset to original file", use_container_width=True,
                  key="reset_result", on_click=_reset_to_original)

st.button("📂 Filter another file", key="filter_another_result", on_click=_filter_another_file,
          help="Clear this file and go back to a fresh upload.")
