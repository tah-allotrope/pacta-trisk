from __future__ import annotations

from pathlib import Path

import streamlit as st

from dashboard.lib.branding import apply_page_frame, footer_note, public_demo_banner
from dashboard.lib.loaders import load_markdown_text


ROOT = Path(__file__).resolve().parents[2]


apply_page_frame("Methodology", "PACTA + TRISK framing, assumptions, and source traceability.")
public_demo_banner()

pacta_note = load_markdown_text(ROOT / "research" / "PACTA for BANKS - TRISK overview.pptx.txt")
baer_note = load_markdown_text(ROOT / "research" / "Baer_TRISK_2022_extracted.txt")

st.markdown(
    "This dashboard is built around a simple sequence for bank clients: first identify transition misalignment in the portfolio, then show how that misalignment can translate into borrower-level transition stress."
)

st.subheader("PACTA for Banks")
st.markdown(
    "PACTA measures portfolio alignment across climate-relevant sectors using physical asset data, scenario pathways, and portfolio/company-level accounting views. "
    "The project research notes emphasize two accounting levels: a portfolio-weighted view to compare the bank with benchmarks, and a company-level unweighted view to identify leading emitters and engagement priorities."
)
with st.expander("PACTA source notes"):
    st.text(pacta_note[:3500])

st.subheader("TRISK")
st.markdown(
    "TRISK is a forward-looking transition stress test rooted in asset-level data and a firm-level financial model. "
    "In this repo the current pilot is limited to the power sector, where borrower value and PD changes are stressed under a synthetic Vietnam transition scenario."
)
with st.expander("TRISK source notes"):
    st.text(baer_note[:4000])

st.subheader("How the two fit together")
st.markdown(
    "PACTA answers **who is misaligned** and **by how much**. TRISK answers **what that could mean under a stress scenario** for firm value and credit deterioration. "
    "That is why the dashboard flow is PACTA Alignment -> TRISK Risk -> Reports."
)

st.subheader("Source files")
st.markdown(
    "- `research/PACTA for BANKS - TRISK overview.pptx.txt`  \n"
    "- `research/Baer_TRISK_2022_extracted.txt`  \n"
    "- `docs/Baer_TRISK_2022.pdf`"
)
pdf_path = ROOT / "docs" / "Baer_TRISK_2022.pdf"
if pdf_path.exists():
    st.download_button(
        "Download Baer TRISK 2022 PDF",
        pdf_path.read_bytes(),
        file_name=pdf_path.name,
        mime="application/pdf",
    )

footer_note()
