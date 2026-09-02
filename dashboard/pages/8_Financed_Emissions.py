from __future__ import annotations

import pandas as pd
import streamlit as st

from dashboard.lib.branding import apply_page_frame, footer_note, public_demo_banner
from dashboard.lib.loaders import load_analytics_tables


DISCLAIMER = (
    "Financed emissions here are a PCAF-style Scope 1+2 inventory computed on a synthetic "
    "portfolio. They are an illustrative screening layer, not an audited GHG inventory and "
    "not a regulatory disclosure."
)

SCOPE_3_NOTE = (
    "Automotive and coal mining are excluded from this inventory because Scope 3 dominates "
    "their financed-emissions profile. Every excluded borrower carries an explicit "
    "`exclusion_reason` rather than a silent zero."
)

# PCAF data-quality scores run 1 (best) to 5 (worst) -- the OPPOSITE direction
# from this repo's severity scores, where 1 is worst. Spell it out on screen so
# a reader never has to guess which convention a number follows.
QUALITY_LABELS = {
    1: "1 - audited / verified",
    2: "2 - reported by borrower",
    3: "3 - technology-average factor",
    4: "4 - derived activity data",
    5: "5 - sector-median capital",
}


def _fmt_tco2e(x: float) -> str:
    if pd.isna(x):
        return "n/a"
    return f"{x:,.0f} tCO2e"


apply_page_frame(
    "Financed Emissions",
    "PCAF-style Scope 1+2 financed emissions, sector decarbonization targets, and the "
    "sustainability-linked-loan readiness shortlist.",
)
public_demo_banner()

tables = load_analytics_tables()

if not tables:
    st.info(
        "No analytics tables are present in this snapshot. Run "
        "`Rscript scripts/pipeline_refresh.R` with `run_financed_emissions`, `run_targets` "
        "and `run_sll_readiness` enabled in the engagement config, which publishes them to "
        "`dashboard/data/analytics/`."
    )
    footer_note()
    st.stop()

st.warning(f"Synthetic data. {DISCLAIMER}")

# --- PCAF inventory -----------------------------------------------------------

fe = tables.get("financed_emissions")
dq = tables.get("data_quality_summary")

if fe is not None:
    st.markdown("## Financed emissions inventory")

    scored = fe[fe["financed_emissions_tco2e"].notna()]
    excluded = fe[fe["financed_emissions_tco2e"].isna()]

    col1, col2, col3 = st.columns(3)
    col1.metric("Total financed emissions", _fmt_tco2e(scored["financed_emissions_tco2e"].sum()))
    col2.metric("Borrowers in scope", f"{len(scored):,}")
    col3.metric("Excluded borrowers", f"{len(excluded):,}")

    # No total is ever shown without its data-quality composition beside it.
    if dq is not None and not dq.empty:
        st.markdown("### Data quality composition")
        st.caption(
            "PCAF data-quality scores run **1 (best) to 5 (worst)** - the opposite direction "
            "from this platform's severity scores, where 1 is worst. A total without this "
            "composition beside it is not a meaningful number."
        )
        shown = dq.copy()
        if "data_quality_score" in shown.columns:
            shown["quality"] = shown["data_quality_score"].map(
                lambda s: QUALITY_LABELS.get(int(s), str(s)) if pd.notna(s) else "unknown"
            )
        if "share_of_total" in shown.columns:
            shown["share_of_total"] = (shown["share_of_total"] * 100).round(1).astype(str) + "%"
        st.dataframe(shown, use_container_width=True, hide_index=True)

    st.caption(SCOPE_3_NOTE)

    with st.expander("Borrower-level inventory"):
        st.dataframe(fe, use_container_width=True, hide_index=True)

    if not excluded.empty and "exclusion_reason" in excluded.columns:
        with st.expander(f"Excluded borrowers ({len(excluded)}) and why"):
            st.dataframe(
                excluded[["name_abcd", "sector", "exclusion_reason"]],
                use_container_width=True,
                hide_index=True,
            )

# --- Sector target registry ---------------------------------------------------

targets = tables.get("target_registry")
if targets is not None and not targets.empty:
    st.markdown("## Sector decarbonization targets")
    st.caption(
        "A PACTA **alignment gap** measures distance from a scenario benchmark. A **target** "
        "here is computed by convergence from the portfolio's own baseline. The two share the "
        "name \"the PDP8 target\" but not the meaning - see "
        "`docs/bidv_sector_prioritization_methodology.md`. Nothing is ever marked *adopted*: "
        "that requires a board decision, not a pipeline."
    )
    st.dataframe(targets, use_container_width=True, hide_index=True)

# --- SLL readiness ------------------------------------------------------------

sll = tables.get("sll_readiness")
if sll is not None and not sll.empty:
    st.markdown("## Sustainability-linked-loan readiness")
    st.caption(
        "A screening shortlist for which borrowers could plausibly carry KPI/SPT-linked loan "
        "terms. Illustrative only - it is not a credit decision and not an offer."
    )
    st.dataframe(sll, use_container_width=True, hide_index=True)

footer_note()
