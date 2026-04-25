from __future__ import annotations

import streamlit as st

from dashboard.lib.branding import apply_page_frame, footer_note, public_demo_banner


apply_page_frame("Reports", "Phase 05 target page stub")
public_demo_banner()
st.info("This page is intentionally a stub in the current implementation. The next phase will add embedded HTML reports and download actions.")
footer_note()
