from __future__ import annotations

import os

import pytest
from streamlit.testing.v1 import AppTest

from dashboard.lib.outputs import (
    DISCLOSURE_SCRIPT,
    ENV_FLAG,
    LETTERS_SCRIPT,
    SCORING_SCRIPT,
    is_outputs_enabled,
)


@pytest.fixture(autouse=True)
def _clear_flag():
    """Keep the operator flag isolated between tests."""
    saved = os.environ.get(ENV_FLAG)
    os.environ.pop(ENV_FLAG, None)
    yield
    if saved is None:
        os.environ.pop(ENV_FLAG, None)
    else:
        os.environ[ENV_FLAG] = saved


class TestIsOutputsEnabled:
    def test_returns_true_when_env_set(self) -> None:
        os.environ[ENV_FLAG] = "1"
        assert is_outputs_enabled() is True

    def test_returns_false_when_env_not_set(self) -> None:
        os.environ.pop(ENV_FLAG, None)
        assert is_outputs_enabled() is False

    def test_returns_false_when_env_set_to_other(self) -> None:
        os.environ[ENV_FLAG] = "0"
        assert is_outputs_enabled() is False


class TestGeneratorScriptsExist:
    def test_scoring_script_present(self) -> None:
        assert SCORING_SCRIPT.exists()

    def test_letters_script_present(self) -> None:
        assert LETTERS_SCRIPT.exists()

    def test_disclosure_script_present(self) -> None:
        assert DISCLOSURE_SCRIPT.exists()


class TestGuardsWhenDisabled:
    def test_letters_raises_when_disabled(self) -> None:
        os.environ.pop(ENV_FLAG, None)
        from dashboard.lib.outputs import generate_engagement_letters

        with pytest.raises(RuntimeError):
            generate_engagement_letters(top_n=3)

    def test_disclosure_raises_when_disabled(self) -> None:
        os.environ.pop(ENV_FLAG, None)
        from dashboard.lib.outputs import generate_disclosure_pack

        with pytest.raises(RuntimeError):
            generate_disclosure_pack(top_n=3)


class TestOutputsPage:
    def test_page_disabled_without_flag(self) -> None:
        os.environ.pop(ENV_FLAG, None)
        at = AppTest.from_file("dashboard/pages/7_Outputs.py")
        at.run()
        assert not at.exception
        # Disabled page shows an info message and stops before any controls.
        assert any(ENV_FLAG in str(info.value) for info in at.info)
        assert len(at.button) == 0

    def test_page_enabled_shows_gated_controls(self) -> None:
        os.environ[ENV_FLAG] = "1"
        try:
            at = AppTest.from_file("dashboard/pages/7_Outputs.py")
            at.run()
            assert not at.exception
            # Generate buttons exist but are gated behind the confirmation checkbox.
            assert len(at.button) == 2
            assert all(btn.disabled for btn in at.button)
        finally:
            os.environ.pop(ENV_FLAG, None)
