from __future__ import annotations

import streamlit as st

from dashboard.lib.branding import apply_page_frame, data_freshness_badge, footer_note, public_demo_banner
from dashboard.lib.loaders import load_pacta_alignment_tables, load_trisk_tables


apply_page_frame(
    "PACTA + TRISK Vietnam Bank Showcase",
    "A guided evaluation tour: portfolio alignment, transition-risk stress, and the outputs a bank would take away.",
)
public_demo_banner()
data_freshness_badge()

st.markdown(
    """
This is a self-guided evaluation of a synthetic Vietnam commercial bank case
("Mekong Commercial Bank"). Work through the five steps below in order — each
links to the page that covers it. Expect about 20-30 minutes end to end.

All figures are illustrative transition-risk indicators for portfolio
screening, not production credit-risk or regulatory capital outputs. See the
**Methodology** page for full caveats (sector coverage, match-rate quality,
scenario assumptions).
"""
)

pacta = load_pacta_alignment_tables()
trisk = load_trisk_tables()

st.markdown("## Evaluation tour")

step1, step2 = st.columns(2)
with step1:
    st.markdown("### 1. PACTA Alignment")
    st.write(
        "Which sectors and technologies in the loan portfolio are already "
        "aligned with PDP8 / NDC 2022 / IEA NZE pathways, and which are "
        "visibly misaligned. Start here — everything downstream builds on this."
    )
    st.page_link("pages/1_PACTA_Alignment.py", label="Open PACTA Alignment", icon="1️⃣")

with step2:
    st.markdown("### 2. TRISK Risk")
    st.write(
        "Once misalignment exists, what does it mean for borrower value and "
        "credit stress under a scenario shock? Compare power, cement, and "
        "steel borrowers side by side."
    )
    st.page_link("pages/2_TRISK_Risk.py", label="Open TRISK Risk", icon="2️⃣")

step3, step4 = st.columns(2)
with step3:
    st.markdown("### 3. Scenario Builder")
    st.write(
        "Drive shock year, discount rate, risk-free rate, market passthrough, "
        "and carbon-price family yourself to see borrower rankings shift in "
        "real time. This is the best page for a hands-on evaluation."
    )
    st.page_link("pages/5_Scenario_Builder.py", label="Open Scenario Builder", icon="3️⃣")

with step4:
    st.markdown("### 4. Reports & Methodology")
    st.write(
        "The longer-form narrative, assumptions, and source traceability "
        "behind every number on the previous pages."
    )
    st.page_link("pages/3_Reports.py", label="Open Reports", icon="4️⃣")
    st.page_link("pages/4_Methodology.py", label="Open Methodology", icon="4️⃣")

st.markdown("### 5. Outputs")
st.write(
    "What a bank takes away at the end: engagement priority scoring, "
    "engagement letter drafts, and a disclosure pack aligned to Decision "
    "263 / TCFD-style reporting."
)
st.page_link("pages/7_Outputs.py", label="Open Outputs", icon="5️⃣")

with st.expander("Current snapshot inventory"):
    c1, c2 = st.columns(2)
    with c1:
        st.write("**PACTA**")
        st.write(", ".join(sorted(pacta.keys())))
    with c2:
        st.write("**TRISK**")
        sector_list = ", ".join(trisk["manifest"]["label"].tolist())
        st.write(f"Sectors: {sector_list}")
        st.write(", ".join(sorted(key for key in trisk.keys() if key not in {"manifest", "default_sector"})))

footer_note()
