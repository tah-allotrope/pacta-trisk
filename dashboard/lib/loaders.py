from __future__ import annotations

import json
from pathlib import Path

import pandas as pd
import streamlit as st


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
PACTA_DIR = DATA_DIR / "pacta"
TRISK_DIR = DATA_DIR / "trisk"
REPORTS_DIR = DATA_DIR / "reports"
TRISK_MANIFEST = TRISK_DIR / "manifest.csv"
PIPELINE_MANIFEST = DATA_DIR / "pipeline_manifest.json"


def load_pipeline_manifest() -> dict | None:
    """Read the pipeline refresh manifest, or None if it hasn't been generated yet."""
    if not PIPELINE_MANIFEST.exists():
        return None
    try:
        return json.loads(PIPELINE_MANIFEST.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


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


def trisk_sector_path(sector: str, name: str) -> Path:
    return TRISK_DIR / sector / name


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
    manifest = load_csv(TRISK_MANIFEST)
    default_sector = manifest.iloc[0]["sector"]
    return {
        "manifest": manifest,
        "default_sector": pd.DataFrame({"sector": [default_sector]}),
        **load_trisk_sector_tables(default_sector),
    }


def load_trisk_sector_tables(sector: str) -> dict[str, pd.DataFrame]:
    return {
        "assets": load_csv(trisk_sector_path(sector, "assets.csv")),
        "company_summary": load_csv(trisk_sector_path(sector, "company_summary.csv")),
        "company_trajectories_latest": load_csv(trisk_sector_path(sector, "company_trajectories_latest.csv")),
        "npv_results": load_csv(trisk_sector_path(sector, "npv_results_latest.csv")),
        "pd_results": load_csv(trisk_sector_path(sector, "pd_results_latest.csv")),
        "pd_summary": load_csv(trisk_sector_path(sector, "pd_summary.csv")),
        "financial_features": load_csv(trisk_sector_path(sector, "financial_features.csv")),
        "carbon_price": load_csv(trisk_sector_path(sector, "ngfs_carbon_price.csv")),
        "run_catalog": load_csv(trisk_sector_path(sector, "run_catalog.csv")),
        "scenarios": load_csv(trisk_sector_path(sector, "scenarios.csv")),
        "sensitivity_results": load_csv(trisk_sector_path(sector, "sensitivity_results.csv")),
        "sensitivity_summary": load_csv(trisk_sector_path(sector, "sensitivity_summary.csv")),
        "combined": load_csv(trisk_sector_path(sector, "top_borrowers_alignment_trisk.csv")),
    }


@st.cache_data(show_spinner=False)
def load_parquet(path: str | Path) -> pd.DataFrame:
    return pd.read_parquet(path)


def load_trisk_grid(sector: str) -> dict[str, pd.DataFrame]:
    grid_dir = TRISK_DIR / "grid" / sector
    return {
        "scenarios": load_csv(grid_dir / "scenarios.csv"),
        "borrower_results": load_parquet(grid_dir / "borrower_results.parquet"),
    }


def list_report_files() -> list[Path]:
    return sorted(REPORTS_DIR.glob("*.html"))


def _load_report_catalog_sidecar() -> dict[str, dict[str, str]]:
    """Read the report_catalog.json sidecar copied into the snapshot by
    scripts/refresh_dashboard_data.R (Wave 3 PHASE-02). Returns {} if the
    sidecar is absent (e.g. an old snapshot predating this phase) or
    unreadable -- report_catalog() below degrades every file to an
    uncatalogued entry rather than raising.
    """
    sidecar_path = REPORTS_DIR / "report_catalog.json"
    if not sidecar_path.exists():
        return {}
    try:
        import json

        return json.loads(sidecar_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def report_catalog() -> list[dict[str, str | Path]]:
    """Every HTML file actually present in the reports snapshot, with
    metadata from report_catalog.json when available. A published file with
    no catalog entry is never silently dropped (Wave 3 PHASE-02, N-008) --
    it gets a filename-derived title and an explicit "no summary" marker
    instead.
    """
    catalog = _load_report_catalog_sidecar()
    rows: list[dict[str, str | Path]] = []
    for path in list_report_files():
        meta = catalog.get(path.name)
        if meta:
            rows.append({
                "path": path,
                "title": meta.get("title", path.stem),
                "date": meta.get("date", ""),
                "summary": meta.get("summary", "No summary available."),
                "category": meta.get("category", "uncatalogued"),
            })
        else:
            rows.append({
                "path": path,
                "title": path.stem,
                "date": "",
                "summary": "No summary available.",
                "category": "uncatalogued",
            })
    return rows
