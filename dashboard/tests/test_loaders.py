from __future__ import annotations

from dashboard.lib.loaders import load_pacta_alignment_tables, load_trisk_tables


def test_pacta_loaders_return_dataframes() -> None:
    tables = load_pacta_alignment_tables()
    assert tables["ms_portfolio"].empty is False
    assert tables["ms_alignment"].empty is False


def test_trisk_loaders_return_dataframes() -> None:
    tables = load_trisk_tables()
    assert tables["company_summary"].empty is False
    assert tables["company_trajectories_latest"].empty is False
    assert tables["sensitivity_results"].empty is False
