from __future__ import annotations

import json

from dashboard.lib import loaders


def test_load_pipeline_manifest_missing(monkeypatch, tmp_path) -> None:
    missing_path = tmp_path / "pipeline_manifest.json"
    monkeypatch.setattr(loaders, "PIPELINE_MANIFEST", missing_path)
    assert loaders.load_pipeline_manifest() is None


def test_load_pipeline_manifest_present(monkeypatch, tmp_path) -> None:
    manifest_path = tmp_path / "pipeline_manifest.json"
    manifest_path.write_text(
        json.dumps({"generated_at": "2026-07-04T00:00:00", "git_sha": "abc123", "status": "ok"}),
        encoding="utf-8",
    )
    monkeypatch.setattr(loaders, "PIPELINE_MANIFEST", manifest_path)
    manifest = loaders.load_pipeline_manifest()
    assert manifest is not None
    assert manifest["status"] == "ok"


def test_load_pipeline_manifest_corrupt(monkeypatch, tmp_path) -> None:
    manifest_path = tmp_path / "pipeline_manifest.json"
    manifest_path.write_text("{not valid json", encoding="utf-8")
    monkeypatch.setattr(loaders, "PIPELINE_MANIFEST", manifest_path)
    assert loaders.load_pipeline_manifest() is None


# --- Wave 3 PHASE-03: data_freshness_badge() surfaces scenario_vintage --------

def test_data_freshness_badge_shows_scenario_vintage(monkeypatch, tmp_path) -> None:
    from streamlit.testing.v1 import AppTest

    manifest_path = tmp_path / "pipeline_manifest.json"
    manifest_path.write_text(
        json.dumps({
            "generated_at": "2026-08-27T00:00:00", "git_sha": "abc123def",
            "status": "ok", "scenario_vintage": "pdp8-2025-adjusted",
        }),
        encoding="utf-8",
    )

    script_path = tmp_path / "badge_script.py"
    script_path.write_text(
        "from pathlib import Path\n"
        "from dashboard.lib import loaders, branding\n"
        f"loaders.PIPELINE_MANIFEST = Path(r'{manifest_path}')\n"
        "branding.data_freshness_badge()\n",
        encoding="utf-8",
    )

    at = AppTest.from_file(str(script_path))
    at.run()
    assert not at.exception
    caption_text = " ".join(c.value for c in at.caption)
    assert "pdp8-2025-adjusted" in caption_text


def test_data_freshness_badge_omits_vintage_when_absent(tmp_path) -> None:
    from streamlit.testing.v1 import AppTest

    manifest_path = tmp_path / "pipeline_manifest.json"
    manifest_path.write_text(
        json.dumps({"generated_at": "2026-08-27T00:00:00", "git_sha": "abc123def", "status": "ok"}),
        encoding="utf-8",
    )

    script_path = tmp_path / "badge_script2.py"
    script_path.write_text(
        "from pathlib import Path\n"
        "from dashboard.lib import loaders, branding\n"
        f"loaders.PIPELINE_MANIFEST = Path(r'{manifest_path}')\n"
        "branding.data_freshness_badge()\n",
        encoding="utf-8",
    )

    at = AppTest.from_file(str(script_path))
    at.run()
    assert not at.exception
    caption_text = " ".join(c.value for c in at.caption)
    assert "scenario vintage" not in caption_text
