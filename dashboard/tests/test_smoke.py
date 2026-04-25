from __future__ import annotations

from streamlit.testing.v1 import AppTest


def test_app_shell_renders() -> None:
    at = AppTest.from_file("dashboard/app.py")
    at.run()
    assert not at.exception


def test_pacta_page_renders() -> None:
    at = AppTest.from_file("dashboard/pages/1_PACTA_Alignment.py")
    at.run()
    assert not at.exception
