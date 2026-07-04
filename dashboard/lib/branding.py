from __future__ import annotations

import re

import streamlit as st

from dashboard.lib.analytics import track_page_view
from dashboard.lib.loaders import load_pipeline_manifest


def apply_page_frame(title: str, subtitle: str | None = None) -> None:
    st.set_page_config(page_title=title, page_icon=":bar_chart:", layout="wide")
    page_slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    track_page_view(page_slug)
    st.markdown(
        """
        <style>
          .stApp [data-testid="stMetricValue"] {
            font-size: 1.35rem;
          }
          .app-banner {
            padding: 0.9rem 1rem;
            border: 1px solid rgba(0, 229, 255, 0.25);
            border-radius: 14px;
            background: linear-gradient(135deg, rgba(0, 229, 255, 0.08), rgba(57, 255, 20, 0.06));
            margin-bottom: 1rem;
          }
          .app-banner strong { color: #f5feff; }
          .brand-footer {
            padding: 0.75rem 0;
            color: rgba(244, 251, 255, 0.72);
            font-size: 0.88rem;
          }
          .what-new-card {
            padding: 0.9rem 1rem;
            border-radius: 14px;
            border: 1px solid rgba(57, 255, 20, 0.28);
            background: linear-gradient(135deg, rgba(57,255,20,0.09), rgba(0,229,255,0.05));
          }
          .synthetic-pill {
            display: inline-block;
            padding: 0.18rem 0.55rem;
            border-radius: 999px;
            background: rgba(248, 81, 73, 0.16);
            color: #ffd7d4;
            border: 1px solid rgba(248, 81, 73, 0.35);
            font-size: 0.8rem;
          }
        </style>
        """,
        unsafe_allow_html=True,
    )
    st.markdown(f"# {title}")
    if subtitle:
        st.caption(subtitle)


def public_demo_banner() -> None:
    st.markdown(
        """
        <div class="app-banner">
          <strong>Synthetic Vietnam bank showcase.</strong>
          This dashboard uses synthetic portfolio and company data to demonstrate how PACTA alignment outputs and TRISK transition-risk outputs can be presented to a bank audience.
          <span class="synthetic-pill">Demo only</span>
        </div>
        """,
        unsafe_allow_html=True,
    )


def data_freshness_badge() -> None:
    """Render a 'Data as of' badge from the pipeline refresh manifest, or a fallback note if absent."""
    manifest = load_pipeline_manifest()
    if manifest is None:
        st.caption("Data as of: unknown (no pipeline_manifest.json found — run scripts/pipeline_refresh.R).")
        return
    generated_at = manifest.get("generated_at", "unknown")
    status = manifest.get("status", "unknown")
    sha = manifest.get("git_sha") or "unknown"
    status_note = "" if status == "ok" else " — **last refresh failed, showing prior snapshot**"
    st.caption(f"Data as of: {generated_at} (pipeline `{sha[:7] if sha != 'unknown' else sha}`){status_note}")


def footer_note() -> None:
    st.markdown("---")
    st.markdown(
        "<div class='brand-footer'><strong>Allotrope VC demo build.</strong> Synthetic data only. Public showcase for methodology walkthrough, not production risk management.</div>",
        unsafe_allow_html=True,
    )
