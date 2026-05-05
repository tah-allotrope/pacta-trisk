# Streamlit Deployment Notes

## Target

- Host: Streamlit Community Cloud
- Repo: `https://github.com/tah-allotrope/pacta-trisk`
- Main file: `dashboard/app.py`
- Preferred subdomain: `pactavn`

## Repo prep

- Root `requirements.txt` now delegates to `dashboard/requirements.txt` so Streamlit Cloud can install dependencies without extra repo-path configuration.
- Dashboard data is bundled in-repo under `dashboard/data/`.
- TRISK snapshot data is now manifest-backed under `dashboard/data/trisk/manifest.csv` plus `power/`, `cement/`, and `steel/` sector folders.

## Manual deploy steps

1. Open `https://share.streamlit.io/` and sign in with GitHub.
2. Create a new app from repo `tah-allotrope/pacta-trisk`.
3. Set branch to `main`.
4. Set main file path to `dashboard/app.py`.
5. If the UI requests an app URL slug, try `pactavn`. If unavailable, choose the closest available variant.
6. Deploy.

## Post-deploy smoke checklist

1. Cold start completes in under 30 seconds.
2. Landing page renders with the public demo banner.
3. `PACTA Alignment` page renders and the sector selector changes content.
4. `TRISK Risk` page renders with `Power` as the default sector.
5. Switching `TRISK Risk` between `Power`, `Cement`, and `Steel` updates KPI cards, ranking labels, trajectory content, and sector-specific zip download labels.
6. `Cement` and `Steel` show the sector-level SDA-context caveat text.
7. The sensitivity selector updates the TRISK table/chart for the selected sector.
8. The full multisector TRISK zip download works.
9. `Reports` page opens at least one embedded HTML report.
10. `Methodology` page renders and the Baer PDF download button works.

## Local rerun before deploy

Run these commands from the repo root before pushing a refreshed dashboard snapshot:

```bash
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_prepare_inputs.R
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_power_demo.R
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_sector_demo.R cement
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_sector_demo.R steel
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/refresh_dashboard_data.R
python -m pytest dashboard/tests
python -m streamlit run dashboard/app.py --server.headless true
```

## Live-rerun operator setup (PHASE-04)

The Scenario Builder page supports an optional operator-only live-rerun mode that bypasses the precomputed grid and calls the R TRISK model directly.

### Prerequisites

- R (4.x) installed locally with the `trisk.model` package available in the user library.
- The R packages `dplyr`, `readr`, `tibble`, `tidyr`, `fs`, `ggplot2`, `purrr`, `scales` installed.

### Enabling live rerun

Set two environment variables before starting the Streamlit app:

```bash
set TRISK_LIVE_RERUN=1
set R_RSCRIPT=C:\Program Files\R\R-4.5.2\bin\Rscript.exe
streamlit run dashboard/app.py
```

On PowerShell:

```powershell
$env:TRISK_LIVE_RERUN = "1"
$env:R_RSCRIPT = "C:\Program Files\R\R-4.5.2\bin\Rscript.exe"
streamlit run dashboard/app.py
```

On Linux/macOS:

```bash
export TRISK_LIVE_RERUN=1
export R_RSCRIPT=/usr/bin/Rscript
streamlit run dashboard/app.py
```

If `R_RSCRIPT` is not set, the app defaults to `Rscript` on PATH.

### What the live-rerun path does

1. A "Live rerun (operator only)" expander appears in the Scenario Builder page.
2. The operator sets continuous (free-entry) values for all five levers.
3. Clicking "Run now" invokes `scripts/trisk_run_adhoc.R` via subprocess.
4. `trisk_run_adhoc.R` calls `trisk.model::run_trisk()` with the given parameters, writes borrower results to a temp CSV, and prints the path to stdout.
5. The Python adapter reads the CSV, displays the result as a side-by-side comparison with the nearest grid cell, and deletes the temp file.

### Safety

- **Never set `TRISK_LIVE_RERUN=1` on Streamlit Community Cloud.** The public deployment has no R runtime and the env var check will prevent the expander from appearing. Setting it would cause import errors at startup.
- The subprocess has a 30-second hard timeout. If the R call hangs, the UI shows a clear timeout error.
- A concurrency guard prevents multiple simultaneous reruns from the same session.

### Verifying the operator setup

```powershell
$env:TRISK_LIVE_RERUN = "1"
$env:R_RSCRIPT = "C:\Program Files\R\R-4.5.2\bin\Rscript.exe"
& "$env:R_RSCRIPT" scripts/trisk_run_adhoc.R --sector=power --shock_year=2028 --discount_rate=0.08 --risk_free_rate=0.03 --market_passthrough=0.25 --carbon_price_family=NGFS_NetZero2050
```

If R and trisk.model are installed correctly, a CSV path is printed to stdout.

## Constraints

- This environment can prepare the repo and verify locally, but Streamlit Community Cloud deployment still requires a browser-authenticated step unless a dedicated Streamlit API/CLI is available.
