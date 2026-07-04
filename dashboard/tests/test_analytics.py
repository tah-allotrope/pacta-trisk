from __future__ import annotations

from dashboard.lib import analytics


def test_disabled_without_env(monkeypatch) -> None:
    monkeypatch.delenv("PILOT_ANALYTICS_ENDPOINT", raising=False)
    assert not analytics.is_analytics_enabled()
    # Should be a safe no-op: no thread started, no exception.
    analytics.track_page_view("home")


def test_enabled_with_env(monkeypatch) -> None:
    monkeypatch.setenv("PILOT_ANALYTICS_ENDPOINT", "https://example.goatcounter.com/count")
    assert analytics.is_analytics_enabled()


def test_track_page_view_no_network_error_when_disabled() -> None:
    # No endpoint configured in the default test environment; must not raise.
    analytics.track_page_view("pacta-alignment")
