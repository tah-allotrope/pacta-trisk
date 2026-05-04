from __future__ import annotations

from pathlib import Path

import pandas as pd

from dashboard.lib.loaders import (
    TRISK_DIR,
    load_pacta_alignment_tables,
    load_trisk_grid,
    load_trisk_sector_tables,
    load_trisk_tables,
)


def test_pacta_loaders_return_dataframes() -> None:
    tables = load_pacta_alignment_tables()
    assert tables["ms_portfolio"].empty is False
    assert tables["ms_alignment"].empty is False


def test_trisk_loaders_return_dataframes() -> None:
    tables = load_trisk_tables()
    assert tables["manifest"].empty is False
    assert tables["company_summary"].empty is False
    assert tables["company_trajectories_latest"].empty is False
    assert tables["sensitivity_results"].empty is False


def test_trisk_sector_loader_returns_dataframes() -> None:
    tables = load_trisk_sector_tables("cement")
    assert tables["company_summary"].empty is False
    assert tables["company_trajectories_latest"].empty is False
    assert tables["combined"].empty is False


def test_trisk_grid_sectors_have_required_files() -> None:
    manifest = load_trisk_tables()["manifest"]
    for sector in manifest[manifest["grid_available"] == True]["sector"]:
        grid_dir = TRISK_DIR / "grid" / sector
        assert (grid_dir / "scenarios.csv").exists(), f"Missing scenarios.csv for {sector}"
        assert (grid_dir / "borrower_results.parquet").exists(), f"Missing borrower_results.parquet for {sector}"
        assert (grid_dir / "grid_meta.json").exists(), f"Missing grid_meta.json for {sector}"


def test_trisk_grid_loader_returns_correct_schema() -> None:
    grid = load_trisk_grid("power")
    assert "scenarios" in grid
    assert "borrower_results" in grid
    assert isinstance(grid["scenarios"], pd.DataFrame)
    assert isinstance(grid["borrower_results"], pd.DataFrame)

    expected_scenario_cols = {"scenario_id", "sector", "shock_year", "discount_rate", "risk_free_rate", "market_passthrough", "carbon_price_family"}
    assert expected_scenario_cols.issubset(set(grid["scenarios"].columns)), f"Missing columns: {expected_scenario_cols - set(grid['scenarios'].columns)}"

    expected_result_cols = {"scenario_id", "company_id", "company_name", "npv_change_pct", "pd_change_pct", "stress_priority_score"}
    assert expected_result_cols.issubset(set(grid["borrower_results"].columns)), f"Missing columns: {expected_result_cols - set(grid['borrower_results'].columns)}"

    assert grid["scenarios"]["scenario_id"].nunique() > 0
    assert grid["borrower_results"]["scenario_id"].nunique() > 0


def test_trisk_grid_scenario_count() -> None:
    grid = load_trisk_grid("power")
    n_scenarios = len(grid["scenarios"])
    assert n_scenarios == 243, f"Expected 243 scenarios, got {n_scenarios}"
