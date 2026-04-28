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


def test_trisk_page_renders() -> None:
    at = AppTest.from_file("dashboard/pages/2_TRISK_Risk.py")
    at.run()
    assert not at.exception


def test_trisk_page_allows_sector_switch() -> None:
    at = AppTest.from_file("dashboard/pages/2_TRISK_Risk.py")
    at.run()
    at.selectbox(key="trisk_sector").select("cement").run()
    assert not at.exception


def test_reports_page_renders() -> None:
    at = AppTest.from_file("dashboard/pages/3_Reports.py")
    at.run()
    assert not at.exception


def test_methodology_page_renders() -> None:
    at = AppTest.from_file("dashboard/pages/4_Methodology.py")
    at.run()
    assert not at.exception
