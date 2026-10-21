"""
app_subset_choices.py — entry point for the Subset Stimuli app.

This is a thin router: it declares the app's three pages and shows them as a
top navigation bar, then hands off to whichever page is selected. The page
content lives in subset_pages/Choice_Subset.py, subset_pages/OOO_Subset.py and
subset_pages/Coords_Subset.py. Both entry points show the same pages; only the page
that opens first differs.

The pages live in subset_pages/, not pages/: Streamlit adds every file in a folder named
pages/ to the sidebar of EVERY app deployed from this repo (the Surrogate MDS app, the
converters, ...), so the filter pages would show up in all of them.

Run locally:
    cd ~/Downloads/rs-software
    streamlit run app_subset_choices.py
"""

import streamlit as st

st.set_page_config(page_title="Subset Stimuli", layout="wide", initial_sidebar_state="expanded")

choice_page = st.Page("subset_pages/Choice_Subset.py", title="Filter a choice file by stimuli", default=True)
ooo_page = st.Page("subset_pages/OOO_Subset.py", title="Filter an odd-one-out choice file by stimuli")
coords_page = st.Page("subset_pages/Coords_Subset.py", title="Filter a coordinate file by stimuli")

pg = st.navigation([choice_page, ooo_page, coords_page], position="top")
pg.run()
