from __future__ import annotations

import streamlit as st
import streamlit.components.v1 as components

from dashboard.lib.branding import apply_page_frame, footer_note
from dashboard.lib.outputs import (
    ENV_FLAG,
    generate_disclosure_pack,
    generate_engagement_letters,
    is_outputs_enabled,
)

# --- Operator gate (mirrors 6_Intake_Wizard.py / BYOL_INTAKE) ----------------
if not is_outputs_enabled():
    st.info(
        "Engagement & Disclosure Outputs is disabled. Set the environment "
        f"variable `{ENV_FLAG}=1` to enable this operator-only page. "
        "It never appears on the public deployment."
    )
    st.stop()

apply_page_frame(
    "Engagement & Disclosure Outputs",
    "Generate per-borrower engagement letters and the board/regulator disclosure pack.",
)

st.markdown(
    """
    <div style="padding:0.9rem 1rem;border:1px solid rgba(57,255,20,0.28);
    border-radius:14px;background:linear-gradient(135deg,rgba(57,255,20,0.09),
    rgba(0,229,255,0.05));margin-bottom:1rem;">
    <strong>Operator mode — synthetic data.</strong>
    These generators produce client-facing artifacts (letters, disclosure pack)
    from the synthetic demo portfolio. They are illustrative model outputs, not a
    credit decision or regulatory filing, and require human and legal review
    before any external use. Generated files are not committed to git.
    <span style="display:inline-block;padding:0.18rem 0.55rem;border-radius:999px;
    background:rgba(248,81,73,0.16);color:#ffd7d4;border:1px solid rgba(248,81,73,0.35);
    font-size:0.8rem;margin-left:0.5rem;">Operator only</span>
    </div>
    """,
    unsafe_allow_html=True,
)

# --- Mandatory confirmation before any generation ----------------------------
confirm = st.checkbox(
    "I confirm these are illustrative, synthetic-data artifacts requiring human "
    "review before any external use.",
    value=False,
)

st.divider()

# --- Controls (Q-004: fixed 50/50 weighting — no weight slider) --------------
col_a, col_b = st.columns(2)
with col_a:
    top_n = st.number_input(
        "Top-N borrowers", min_value=1, max_value=23, value=10, step=1,
        help="How many of the highest-priority borrowers to include.",
    )
with col_b:
    anonymize = st.checkbox(
        "Anonymise disclosure pack (Borrower A / B / C)",
        value=False,
        help="Replace real borrower names with stable pseudonyms for external sharing.",
    )

st.caption(
    "Composite engagement score is a fixed 50/50 blend of PACTA alignment gap and "
    "TRISK transition-stress priority (illustrative — calibrate to your institution's "
    "risk appetite in production)."
)

b_letters, b_disclosure = st.columns(2)
with b_letters:
    gen_letters = st.button(
        "Generate engagement letters", type="primary", disabled=not confirm,
        use_container_width=True,
    )
with b_disclosure:
    gen_disclosure = st.button(
        "Generate disclosure pack", type="primary", disabled=not confirm,
        use_container_width=True,
    )

if not confirm:
    st.warning("Tick the confirmation box above to enable generation.")

# --- Engagement letters ------------------------------------------------------
if gen_letters and confirm:
    with st.spinner("Generating engagement letters (running R generator) ..."):
        try:
            result = generate_engagement_letters(top_n=int(top_n))
        except RuntimeError as exc:
            st.error(f"Letter generation failed:\n\n{exc}")
            st.stop()

    letters = result.get("letters", [])
    st.success(f"Generated {len(letters)} engagement letter(s).")
    manifest = result.get("manifest")
    if manifest is not None:
        st.dataframe(manifest, use_container_width=True, hide_index=True)

    for item in letters:
        try:
            html_bytes = item["path"].read_bytes()
        except OSError:
            continue
        slug = item["path"].parent.name
        st.download_button(
            label=f"⬇ {item['borrower']} ({item['sector']})",
            data=html_bytes,
            file_name=f"engagement_letter_{slug}.html",
            mime="text/html",
            key=f"dl_letter_{slug}",
        )

# --- Disclosure pack ---------------------------------------------------------
if gen_disclosure and confirm:
    with st.spinner("Generating disclosure pack (running R generator) ..."):
        try:
            result = generate_disclosure_pack(top_n=int(top_n), anonymize=anonymize)
        except RuntimeError as exc:
            st.error(f"Disclosure pack generation failed:\n\n{exc}")
            st.stop()

    mode = "anonymised" if result.get("anonymized") else "named (internal board)"
    st.success(f"Generated disclosure pack — {mode}.")
    html = result.get("html")
    if html:
        st.download_button(
            label="⬇ Download disclosure_pack.html",
            data=html.encode("utf-8"),
            file_name="disclosure_pack.html",
            mime="text/html",
            key="dl_disclosure",
        )
        with st.expander("Preview disclosure pack", expanded=False):
            components.html(html, height=640, scrolling=True)

footer_note()
