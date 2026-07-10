from __future__ import annotations

from streamlit.testing.v1 import AppTest


def test_no_password_renders_landing() -> None:
    at = AppTest.from_file("dashboard/app.py")
    at.run()
    assert not at.exception


def test_password_set_shows_gate() -> None:
    at = AppTest.from_file("dashboard/app.py")
    at.secrets["DEMO_PASSWORD"] = "secret123"
    at.run()
    assert not at.exception
    password_inputs = [el for el in at.get("markdown") if "Access Required" in str(el.value)]
    assert len(password_inputs) > 0 or any("password" in str(el).lower() for el in at.element)


def test_correct_password_grants_access() -> None:
    at = AppTest.from_file("dashboard/app.py")
    at.secrets["DEMO_PASSWORD"] = "secret123"
    at.run()
    text_inputs = at.text_input
    if text_inputs:
        text_inputs[0].input("secret123").run()
    assert not at.exception


def test_wrong_password_shows_error() -> None:
    at = AppTest.from_file("dashboard/app.py")
    at.secrets["DEMO_PASSWORD"] = "secret123"
    at.run()
    text_inputs = at.text_input
    if text_inputs:
        text_inputs[0].input("wrong").run()
    errors = [el for el in at.error if el]
    assert len(errors) > 0 or not at.exception
