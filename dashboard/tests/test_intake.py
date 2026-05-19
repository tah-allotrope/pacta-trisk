from __future__ import annotations

import os
from pathlib import Path

import pandas as pd
import pytest

from dashboard.lib.intake import (
    convert_xlsx_to_csv,
    is_intake_enabled,
    parse_validation_summary,
)

TEMPLATE_XLSX = (
    Path(__file__).resolve().parents[2] / "intake" / "templates" / "loanbook_template.xlsx"
)


class TestIsIntakeEnabled:
    def test_returns_true_when_env_set(self) -> None:
        os.environ["BYOL_INTAKE"] = "1"
        assert is_intake_enabled() is True

    def test_returns_false_when_env_not_set(self) -> None:
        os.environ.pop("BYOL_INTAKE", None)
        assert is_intake_enabled() is False

    def test_returns_false_when_env_set_to_other(self) -> None:
        os.environ["BYOL_INTAKE"] = "0"
        assert is_intake_enabled() is False


class TestParseValidationSummary:
    def test_parses_full_summary(self) -> None:
        text = (
            "Total rows processed:     5\n"
            "Rows passing validation:  3\n"
            "Rows with errors:         2\n"
            "\n"
            "--- Match Preview ---\n"
            "  Total candidate matches:     10\n"
            "  Review needed (score < 1.0): 3\n"
        )
        tmp = Path("test_validation_summary.txt")
        try:
            tmp.write_text(text)
            result = parse_validation_summary(tmp)
            assert result["total_rows"] == 5
            assert result["passing_rows"] == 3
            assert result["error_rows"] == 2
            assert result["match_count"] == 10
            assert result["review_count"] == 3
            assert "raw_text" in result
        finally:
            tmp.unlink(missing_ok=True)

    def test_handles_missing_file(self) -> None:
        result = parse_validation_summary(Path("nonexistent.txt"))
        assert result["total_rows"] == 0
        assert result["raw_text"] == ""

    def test_handles_empty_fields(self) -> None:
        text = "Some unrelated text\n"
        tmp = Path("test_empty_summary.txt")
        try:
            tmp.write_text(text)
            result = parse_validation_summary(tmp)
            assert result["total_rows"] == 0
            assert result["raw_text"] == text
        finally:
            tmp.unlink(missing_ok=True)


class TestConvertXlsxToCsv:
    def test_converts_template_xlsx(self) -> None:
        if not TEMPLATE_XLSX.exists():
            pytest.skip("Template XLSX not found")
        csv_path = convert_xlsx_to_csv(TEMPLATE_XLSX)
        try:
            df = pd.read_csv(csv_path)
            assert "counterparty_name" in df.columns
            assert "exposure_vnd" in df.columns
            assert "sector_code" in df.columns
            assert "sector_code_system" in df.columns
            assert len(df) == 4  # 3 valid + 1 error example row
        finally:
            csv_path.unlink(missing_ok=True)

    def test_converts_to_valid_csv_format(self) -> None:
        if not TEMPLATE_XLSX.exists():
            pytest.skip("Template XLSX not found")
        csv_path = convert_xlsx_to_csv(TEMPLATE_XLSX)
        try:
            df = pd.read_csv(csv_path)
            # First example row should have valid data
            first_exposure = df.loc[0, "exposure_vnd"]
            assert pd.to_numeric(first_exposure, errors="coerce") >= 0
        finally:
            csv_path.unlink(missing_ok=True)
