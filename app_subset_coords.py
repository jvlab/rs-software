"""
app_subset_coords.py — entry point for the Subset Stimuli app.

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
    streamlit run app_subset_coords.py
"""

import streamlit as st

st.set_page_config(page_title="Subset Stimuli", layout="wide", initial_sidebar_state="expanded")

choice_page = st.Page("subset_pages/Choice_Subset.py", title="Filter a choice file by stimuli")
ooo_page = st.Page("subset_pages/OOO_Subset.py", title="Filter an odd-one-out choice file by stimuli")
coords_page = st.Page("subset_pages/Coords_Subset.py", title="Filter a coordinate file by stimuli", default=True)

pg = st.navigation([coords_page, choice_page, ooo_page], position="top")
pg.run()
