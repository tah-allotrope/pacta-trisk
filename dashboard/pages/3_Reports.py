from __future__ import annotations

import streamlit.components.v1 as components
import streamlit as st

from dashboard.lib.branding import apply_page_frame, footer_note, public_demo_banner
from dashboard.lib.loaders import load_bytes, load_markdown_text, report_catalog


apply_page_frame("Reports", "Embedded long-form artifacts for the client-facing narrative.")
public_demo_banner()

reports = report_catalog()
st.markdown(
    "Use this page when the bank audience wants the longer-form write-up behind the dashboard snapshots. "
    "The cards below expose the most useful four HTML reports inline and as downloadable artifacts."
)

for report in reports:
    with st.container(border=True):
        c1, c2 = st.columns([1.2, 1])
        with c1:
            st.markdown(f"### {report['title']}")
            st.caption(report["date"])
            st.write(report["summary"])
        with c2:
            report_bytes = load_bytes(report["path"])
            st.download_button(
                f"Download {report['title']}",
                report_bytes,
                file_name=report["path"].name,
                mime="text/html",
                key=f"download_{report['path'].name}",
            )
        with st.expander(f"Open {report['title']}", expanded=False):
            components.html(report_bytes.decode("utf-8"), height=900, scrolling=True)

footer_note()
