from __future__ import annotations

import os

import streamlit as st


def require_password() -> None:
    expected = None
    try:
        expected = st.secrets.get("DEMO_PASSWORD")
    except Exception:
        pass
    if not expected:
        expected = os.environ.get("DEMO_PASSWORD")
    if not expected:
        return

    if st.session_state.get("auth_ok") is True:
        return

    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        st.markdown("### Access Required")
        pw = st.text_input("Access password", type="password")
        if pw:
            if pw == expected:
                st.session_state["auth_ok"] = True
                st.rerun()
            else:
                st.error("Incorrect password.")
                st.stop()
        else:
            st.stop()
