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
