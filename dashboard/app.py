from __future__ import annotations

import streamlit as st

from dashboard.lib.branding import apply_page_frame, footer_note, public_demo_banner
from dashboard.lib.loaders import load_pacta_alignment_tables, load_trisk_tables


apply_page_frame(
    "PACTA + TRISK Vietnam Bank Showcase",
    "Portfolio alignment first, transition-stress follow-through second.",
)
public_demo_banner()

st.markdown(
    """
This public demo packages a synthetic Vietnam commercial bank case into a bank-client walkthrough.
The first story is **PACTA alignment**: which sectors and technologies are already aligned with PDP8 / NDC / NZE-style pathways, and which ones are visibly misaligned.

The second story is **TRISK transition risk**: once misalignment exists, what might that mean for borrower value and credit stress under a scenario shock.
This first app slice implements the dashboard shell and the PACTA alignment experience against the frozen artifact snapshot in `dashboard/data/`.

Use the left sidebar to switch pages.
The PACTA page already supports sector filters, downloadable tables, and static snapshot charts side-by-side with interactive tables.
TRISK, Reports, and Methodology are scaffolded so later phases can add the deeper pages without changing the shell.
"""
)

st.markdown(
    """
<div class="what-new-card">
  <strong>What's new:</strong> the TRISK Risk, Reports, and Methodology pages are now live, so the dashboard tells the full portfolio -> sector alignment -> borrower stress -> evidence narrative.
  The latest anchor artifact is <code>2026-04-16-final-vietnam-bank-trisk-demo.html</code> in the Reports tab.
</div>
""",
    unsafe_allow_html=True,
)

pacta = load_pacta_alignment_tables()
trisk = load_trisk_tables()

col1, col2, col3, col4 = st.columns(4)
col1.metric("PACTA tables", len(pacta))
col2.metric("TRISK tables", len(trisk))
col3.metric("Available pages", 4)
col4.metric("Deployment target", "pactavn")

st.markdown("## How to read this demo")
guide_1, guide_2, guide_3 = st.columns(3)
guide_1.markdown(
    "**1. Start with PACTA**  \nSee where the portfolio is misaligned against Vietnam and global transition pathways."
)
guide_2.markdown(
    "**2. Move to TRISK**  \nCompare which power, cement, and steel borrowers absorb the largest value and credit deterioration under the stress scenario."
)
guide_3.markdown(
    "**3. Finish with evidence**  \nUse Reports and Methodology for the longer-form narrative, assumptions, and source traceability."
)

with st.expander("Current snapshot inventory", expanded=True):
    c1, c2 = st.columns(2)
    with c1:
        st.write("**PACTA**")
        st.write(", ".join(sorted(pacta.keys())))
    with c2:
        st.write("**TRISK**")
        sector_list = ", ".join(trisk["manifest"]["label"].tolist())
        st.write(f"Sectors: {sector_list}")
        st.write(", ".join(sorted(key for key in trisk.keys() if key not in {"manifest", "default_sector"})))

st.success("All planned dashboard pages are now implemented for the client-facing demo scope. Use the sidebar to move from alignment to stress to supporting artifacts.")

footer_note()
