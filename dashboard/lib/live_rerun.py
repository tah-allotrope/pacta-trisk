from __future__ import annotations

import os
import subprocess
from pathlib import Path
from typing import Any

import pandas as pd

ENV_FLAG = "TRISK_LIVE_RERUN"
ENV_RSCRIPT = "R_RSCRIPT"
DEFAULT_RSCRIPT = "Rscript"
SUBPROCESS_TIMEOUT = 30  # seconds


def is_live_rerun_enabled() -> bool:
    return os.environ.get(ENV_FLAG) == "1"


def get_rscript_path() -> str:
    return os.environ.get(ENV_RSCRIPT, DEFAULT_RSCRIPT)


def run_adhoc_trisk(
    sector: str,
    shock_year: int,
    discount_rate: float,
    risk_free_rate: float,
    market_passthrough: float,
    carbon_price_family: str,
    script_path: str | Path | None = None,
) -> dict[str, Any]:
    if not is_live_rerun_enabled():
        raise RuntimeError(
            f"Live rerun is not enabled. Set {ENV_FLAG}=1 to use this feature."
        )

    if script_path is None:
        script_path = Path(__file__).resolve().parents[2] / "scripts" / "trisk_run_adhoc.R"

    rscript = get_rscript_path()
    cmd = [
        rscript,
        str(script_path),
        f"--sector={sector}",
        f"--shock_year={shock_year}",
        f"--discount_rate={discount_rate}",
        f"--risk_free_rate={risk_free_rate}",
        f"--market_passthrough={market_passthrough}",
        f"--carbon_price_family={carbon_price_family}",
    ]

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(
            f"TRISK R subprocess timed out after {SUBPROCESS_TIMEOUT}s. "
            f"Check that trisk.model is installed and the inputs are valid."
        )
    except FileNotFoundError:
        raise RuntimeError(
            f"Rscript not found at '{rscript}'. "
            f"Set the {ENV_RSCRIPT} env var to the full path of Rscript, "
            f"or ensure R is on your PATH."
        )

    if proc.returncode != 0:
        stderr_msg = proc.stderr.strip() if proc.stderr.strip() else "(no stderr output)"
        raise RuntimeError(
            f"TRISK R subprocess failed (exit code {proc.returncode}).\n"
            f"Stderr:\n{stderr_msg}"
        )

    stdout_lines = [line for line in proc.stdout.splitlines() if line.strip()]
    if not stdout_lines:
        raise RuntimeError(
            "TRISK R subprocess produced no output.\n"
            f"Stderr:\n{proc.stderr.strip()}"
        )

    output_path = stdout_lines[-1].strip()
    if not os.path.isfile(output_path):
        raise RuntimeError(
            f"TRISK R subprocess did not produce a valid output file.\n"
            f"Expected path: {output_path}\n"
            f"Stdout:\n{proc.stdout.strip()}\n"
            f"Stderr:\n{proc.stderr.strip()}"
        )

    df = pd.read_csv(output_path)
    os.unlink(output_path)

    return {"success": True, "data": df, "stderr": proc.stderr.strip()}
