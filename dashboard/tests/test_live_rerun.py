from __future__ import annotations

import os
from unittest.mock import patch

import pandas as pd
import pytest

from dashboard.lib.live_rerun import is_live_rerun_enabled, run_adhoc_trisk


def test_live_rerun_disabled_by_default() -> None:
    with patch.dict(os.environ, {}, clear=True):
        assert is_live_rerun_enabled() is False


def test_live_rerun_enabled_with_flag() -> None:
    with patch.dict(os.environ, {"TRISK_LIVE_RERUN": "1"}, clear=True):
        assert is_live_rerun_enabled() is True


def test_live_rerun_disabled_with_wrong_value() -> None:
    with patch.dict(os.environ, {"TRISK_LIVE_RERUN": "0"}, clear=True):
        assert is_live_rerun_enabled() is False


def test_live_rerun_raises_when_not_enabled() -> None:
    with patch.dict(os.environ, {}, clear=True):
        with pytest.raises(RuntimeError, match="not enabled"):
            run_adhoc_trisk(
                sector="power",
                shock_year=2028,
                discount_rate=0.08,
                risk_free_rate=0.03,
                market_passthrough=0.25,
                carbon_price_family="NGFS_NetZero2050",
            )


def test_live_rerun_raises_on_rscript_not_found() -> None:
    with patch.dict(os.environ, {"TRISK_LIVE_RERUN": "1"}, clear=True):
        with pytest.raises(RuntimeError, match="Rscript not found"):
            run_adhoc_trisk(
                sector="power",
                shock_year=2028,
                discount_rate=0.08,
                risk_free_rate=0.03,
                market_passthrough=0.25,
                carbon_price_family="NGFS_NetZero2050",
                script_path="/nonexistent/script.R",
            )


def test_rscript_env_var_overrides_default() -> None:
    with patch.dict(os.environ, {"TRISK_LIVE_RERUN": "1", "R_RSCRIPT": "/custom/Rscript"}, clear=True):
        from dashboard.lib.live_rerun import get_rscript_path
        assert get_rscript_path() == "/custom/Rscript"


def test_rscript_env_var_default_fallback() -> None:
    with patch.dict(os.environ, {"TRISK_LIVE_RERUN": "1"}, clear=True):
        from dashboard.lib.live_rerun import get_rscript_path
        assert get_rscript_path() == "Rscript"
