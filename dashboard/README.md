# Dashboard

## Run locally

```bash
streamlit run dashboard/app.py
```

## What is implemented

- Phase 02: Streamlit shell, loaders, chart helpers, theme, README
- Phase 03: `1_PACTA_Alignment.py` with KPI cards, sector drilldown, downloads, and static snapshot charts
- Phase 04: `2_TRISK_Risk.py` with borrower ranking, scatter, sensitivity filtering, assumptions panel, and TRISK zip downloads
- Phase 05: `3_Reports.py`, `4_Methodology.py`, landing-page polish, and shared branding/footer updates
- TRISK multisector follow-on: manifest-backed `power`, `cement`, and `steel` snapshot support with a sector selector on the TRISK page

## Current page status

- `1_PACTA_Alignment.py` — implemented
- `2_TRISK_Risk.py` — implemented with sector switching across `power`, `cement`, and `steel`
- `3_Reports.py` — implemented
- `4_Methodology.py` — implemented

## Public demo mode

The plan was updated to use a **fully public** URL, so the app currently does **not** require a password gate.

If a later phase reintroduces a gate, the intended secret is `DEMO_PASSWORD` via `st.secrets`.

## Data source

The app reads from `dashboard/data/`, which is a frozen snapshot republished from the pipeline outputs.

### PACTA snapshot refresh

```bash
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/refresh_dashboard_data.R
```

### Full TRISK multisector rerun flow

Run these commands from the repo root in order:

```bash
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_prepare_inputs.R
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_power_demo.R
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_sector_demo.R cement
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_sector_demo.R steel
& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/refresh_dashboard_data.R
python -m pytest dashboard/tests
python -m streamlit run dashboard/app.py --server.headless true
```

### TRISK snapshot layout

- `dashboard/data/trisk/manifest.csv` — sector catalog for the loader and page selector
- `dashboard/data/trisk/power/` — power-sector snapshot
- `dashboard/data/trisk/cement/` — cement-sector snapshot
- `dashboard/data/trisk/steel/` — steel-sector snapshot

## Sector caveats

- `power` uses borrower-level PACTA market-share alignment context.
- `cement` and `steel` currently use **sector-level SDA context**, not borrower-specific SDA alignment.
- TRISK NPV and PD outputs remain synthetic demo stress indicators, not production credit-model outputs.

## Demo artifacts

- Latest integrated report anchor: `dashboard/data/reports/2026-04-16-final-vietnam-bank-trisk-demo.html`
- Multisector phase artifact: `dashboard/data/reports/2026-04-28-trisk-multisector-phases-1-2.html`
- Methodology source PDF: `docs/Baer_TRISK_2022.pdf`
