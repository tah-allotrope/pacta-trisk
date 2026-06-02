from __future__ import annotations

import subprocess
import os
from pathlib import Path

import pandas as pd

# Engagement & Disclosure Output Layer — PHASE-04 operator gating + R subprocess
# wrappers. Mirrors dashboard/lib/intake.py (env-flag gate, Rscript resolution,
# stderr surfaced on non-zero exit). Operator-only: never enabled on the public
# deployment.

ENV_FLAG = "OUTPUTS_LAYER"
ENV_RSCRIPT = "R_RSCRIPT"
DEFAULT_RSCRIPT = "Rscript"
SUBPROCESS_TIMEOUT = 180  # seconds

REPO_ROOT = Path(__file__).resolve().parents[2]
SCORING_SCRIPT = REPO_ROOT / "scripts" / "engagement_scoring.R"
LETTERS_SCRIPT = REPO_ROOT / "scripts" / "generate_engagement_letters.R"
DISCLOSURE_SCRIPT = REPO_ROOT / "scripts" / "generate_disclosure_pack.R"

PRIORITY_CSV = REPO_ROOT / "output" / "engagement" / "engagement_priority.csv"
LETTERS_DIR = REPO_ROOT / "output" / "engagement_letters"
LETTERS_MANIFEST = LETTERS_DIR / "manifest.csv"
DISCLOSURE_HTML = REPO_ROOT / "output" / "disclosure" / "disclosure_pack.html"


def is_outputs_enabled() -> bool:
    return os.environ.get(ENV_FLAG) == "1"


def get_rscript_path() -> str:
    return os.environ.get(ENV_RSCRIPT, DEFAULT_RSCRIPT)


def _run_r(script: Path, extra_args: list[str]) -> subprocess.CompletedProcess:
    """Run an R generator from the repo root; surface stderr on failure (RISK-04-01)."""
    if not script.exists():
        raise RuntimeError(f"R script not found at {script}.")
    rscript = get_rscript_path()
    cmd = [str(rscript), str(script), *extra_args]
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT,
            cwd=str(REPO_ROOT),  # generators resolve paths via getwd()
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(
            f"R subprocess timed out after {SUBPROCESS_TIMEOUT}s: {script.name}"
        )
    except FileNotFoundError:
        raise RuntimeError(
            f"Rscript not found at '{rscript}'. Set the {ENV_RSCRIPT} env var to "
            f"the full path of Rscript."
        )
    if proc.returncode != 0:
        stderr_msg = proc.stderr.strip() if proc.stderr.strip() else "(no stderr)"
        raise RuntimeError(
            f"{script.name} failed (exit code {proc.returncode}).\nStderr:\n{stderr_msg}"
        )
    return proc


def ensure_scoring() -> None:
    """Build the priority table if it is missing (both generators depend on it)."""
    if not PRIORITY_CSV.exists():
        _run_r(SCORING_SCRIPT, [])


def generate_engagement_letters(top_n: int = 10) -> dict:
    """Run engagement_scoring (if needed) then the letter generator. Returns manifest + logs."""
    if not is_outputs_enabled():
        raise RuntimeError(f"Outputs layer is not enabled. Set {ENV_FLAG}=1 to use this feature.")
    ensure_scoring()
    proc = _run_r(LETTERS_SCRIPT, ["--top_n", str(int(top_n))])
    result: dict = {"stdout": proc.stdout, "stderr": proc.stderr, "letters": []}
    if LETTERS_MANIFEST.exists():
        manifest = pd.read_csv(LETTERS_MANIFEST)
        result["manifest"] = manifest
        for _, row in manifest.iterrows():
            path = REPO_ROOT / str(row["file"])
            if path.exists():
                result["letters"].append(
                    {"borrower": row["borrower"], "sector": row["sector"], "path": path}
                )
    return result


def generate_disclosure_pack(top_n: int = 10, anonymize: bool = False) -> dict:
    """Run engagement_scoring (if needed) then the disclosure-pack generator. Returns HTML + logs."""
    if not is_outputs_enabled():
        raise RuntimeError(f"Outputs layer is not enabled. Set {ENV_FLAG}=1 to use this feature.")
    ensure_scoring()
    extra = ["--top_n", str(int(top_n))]
    if anonymize:
        extra += ["--anonymize", "TRUE"]
    proc = _run_r(DISCLOSURE_SCRIPT, extra)
    result: dict = {"stdout": proc.stdout, "stderr": proc.stderr, "anonymized": anonymize}
    if DISCLOSURE_HTML.exists():
        result["html_path"] = DISCLOSURE_HTML
        result["html"] = DISCLOSURE_HTML.read_text(encoding="utf-8")
    return result
