"""Render pilot/*.md conversion documents to client-shareable HTML.

Usage: python pilot/render_docs.py
Requires the `markdown` package (pip install markdown).
"""
from __future__ import annotations

from pathlib import Path

import markdown

PILOT_DIR = Path(__file__).parent

DOCS = [
    (PILOT_DIR / "loanbook_data_spec.md", PILOT_DIR / "rendered" / "loanbook_data_spec.html"),
    (PILOT_DIR / "real_data_phase_proposal.md", PILOT_DIR / "rendered" / "real_data_phase_proposal.html"),
    (PILOT_DIR / "vn" / "loanbook_data_spec_vi.md", PILOT_DIR / "rendered" / "vn" / "loanbook_data_spec_vi.html"),
    (PILOT_DIR / "vn" / "evaluation_guide_vi.md", PILOT_DIR / "rendered" / "vn" / "evaluation_guide_vi.html"),
    (PILOT_DIR / "vn" / "real_data_phase_proposal_vi.md", PILOT_DIR / "rendered" / "vn" / "real_data_phase_proposal_vi.html"),
]

TEMPLATE = """<!DOCTYPE html>
<html lang="{lang}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title}</title>
<style>
  :root {{
    --primary: #1a365d; --accent: #2b6cb0; --bg: #f7fafc;
    --card-bg: #ffffff; --border: #e2e8f0; --text: #2d3748; --text-light: #718096;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
    background: var(--bg); color: var(--text); line-height: 1.7;
    max-width: 860px; margin: 0 auto; padding: 2.5rem 1.5rem;
  }}
  h1 {{ color: var(--primary); border-bottom: 3px solid var(--accent); padding-bottom: 0.5rem; }}
  h2 {{ color: var(--primary); margin-top: 2rem; }}
  h3 {{ color: var(--accent); }}
  table {{ width: 100%; border-collapse: collapse; margin: 1rem 0; background: var(--card-bg); }}
  th, td {{ border: 1px solid var(--border); padding: 0.5rem 0.75rem; text-align: left; font-size: 0.92rem; }}
  th {{ background: #edf2f7; }}
  blockquote {{
    border-left: 4px solid var(--accent); margin: 1rem 0; padding: 0.5rem 1rem;
    background: var(--card-bg); color: var(--text-light); font-style: italic;
  }}
  code {{ background: #edf2f7; padding: 0.1rem 0.35rem; border-radius: 4px; font-size: 0.9em; }}
  hr {{ border: none; border-top: 1px solid var(--border); margin: 2rem 0; }}
</style>
</head>
<body>
{body}
</body>
</html>
"""


def render(src: Path, dst: Path) -> None:
    if not src.exists():
        print(f"skip (missing): {src}")
        return
    text = src.read_text(encoding="utf-8")
    body = markdown.markdown(text, extensions=["tables", "fenced_code"])
    title = text.splitlines()[0].lstrip("# ").strip() if text else src.stem
    lang = "vi" if src.name.endswith("_vi.md") else "en"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(TEMPLATE.format(lang=lang, title=title, body=body), encoding="utf-8")
    print(f"rendered: {dst}")


if __name__ == "__main__":
    for src, dst in DOCS:
        render(src, dst)
