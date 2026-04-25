from __future__ import annotations

from pathlib import Path
from typing import Iterable

import pandas as pd
import streamlit as st


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
PACTA_DIR = DATA_DIR / "pacta"
TRISK_DIR = DATA_DIR / "trisk"
REPORTS_DIR = DATA_DIR / "reports"


@st.cache_data(show_spinner=False)
def load_csv(path: str | Path) -> pd.DataFrame:
    return pd.read_csv(path)


@st.cache_data(show_spinner=False)
def load_markdown_text(path: str | Path) -> str:
    return Path(path).read_text(encoding="utf-8")


@st.cache_data(show_spinner=False)
def load_bytes(path: str | Path) -> bytes:
    return Path(path).read_bytes()


def pacta_path(name: str) -> Path:
    return PACTA_DIR / name


def trisk_path(name: str) -> Path:
    return TRISK_DIR / name


def reports_path(name: str) -> Path:
    return REPORTS_DIR / name


def load_pacta_alignment_tables() -> dict[str, pd.DataFrame]:
    return {
        "matches": load_csv(pacta_path("02_vn_matched_prioritized.csv")),
        "ms_company": load_csv(pacta_path("04_vn_ms_company.csv")),
        "ms_portfolio": load_csv(pacta_path("04_vn_ms_portfolio.csv")),
        "sda_portfolio": load_csv(pacta_path("05_vn_sda_portfolio.csv")),
        "ms_alignment": load_csv(pacta_path("06_vn_ms_alignment_2030.csv")),
        "sda_alignment": load_csv(pacta_path("06_vn_sda_alignment_2030.csv")),
    }


def load_trisk_tables() -> dict[str, pd.DataFrame]:
    return {
        "assets": load_csv(trisk_path("assets.csv")),
        "company_summary": load_csv(trisk_path("company_summary.csv")),
        "company_trajectories_latest": load_csv(trisk_path("company_trajectories_latest.csv")),
        "npv_results": load_csv(trisk_path("npv_results_latest.csv")),
        "pd_results": load_csv(trisk_path("pd_results_latest.csv")),
        "pd_summary": load_csv(trisk_path("pd_summary.csv")),
        "financial_features": load_csv(trisk_path("financial_features.csv")),
        "carbon_price": load_csv(trisk_path("ngfs_carbon_price.csv")),
        "run_catalog": load_csv(trisk_path("run_catalog.csv")),
        "scenarios": load_csv(trisk_path("scenarios.csv")),
        "sensitivity_results": load_csv(trisk_path("sensitivity_results.csv")),
        "sensitivity_summary": load_csv(trisk_path("sensitivity_summary.csv")),
        "combined": load_csv(trisk_path("top_borrowers_alignment_trisk.csv")),
    }


def list_report_files() -> list[Path]:
    return sorted(REPORTS_DIR.glob("*.html"))


def report_catalog() -> list[dict[str, str | Path]]:
    summaries = {
        "2026-04-16-final-vietnam-bank-trisk-demo.html": {
            "title": "Final Vietnam Bank TRISK Demo",
            "date": "2026-04-16",
            "summary": "Combined client-facing synthesis of the Vietnam PACTA baseline and TRISK power pilot.",
        },
        "PACTA_Vietnam_Bank_Report.html": {
            "title": "PACTA Vietnam Bank Report",
            "date": "2026-03-20",
            "summary": "Vietnam-specific PACTA alignment narrative for the synthetic Mekong Commercial Bank portfolio.",
        },
        "2026-04-16-trisk-power-pilot.html": {
            "title": "TRISK Power Pilot",
            "date": "2026-04-16",
            "summary": "Power-sector stress-test report with borrower-level NPV and PD changes plus sensitivity findings.",
        },
        "PACTA_Synthesis_Report.html": {
            "title": "PACTA Synthesis Report",
            "date": "2026-03-19",
            "summary": "Best-of-both alignment report combining the earlier AI and staff PACTA approaches.",
        },
    }
    rows: list[dict[str, str | Path]] = []
    for path in list_report_files():
        meta = summaries.get(path.name)
        if meta:
            rows.append({"path": path, **meta})
    return rows


def image_catalog(names: Iterable[str], base_dir: Path) -> list[dict[str, str | Path]]:
    return [{"name": name, "path": base_dir / name} for name in names]
