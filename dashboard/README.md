# Dashboard

## Run locally

```bash
streamlit run dashboard/app.py
```

## What is implemented

- Phase 02: Streamlit shell, loaders, chart helpers, theme, README
- Phase 03: `1_PACTA_Alignment.py` with KPI cards, sector drilldown, downloads, and static snapshot charts

## Current page status

- `1_PACTA_Alignment.py` — implemented
- `2_TRISK_Risk.py` — stub
- `3_Reports.py` — stub
- `4_Methodology.py` — stub

## Public demo mode

The plan was updated to use a **fully public** URL, so the app currently does **not** require a password gate.

If a later phase reintroduces a gate, the intended secret is `DEMO_PASSWORD` via `st.secrets`.

## Data source

The app reads from `dashboard/data/`, which is refreshed from pipeline outputs via:

```bash
Rscript scripts/refresh_dashboard_data.R
```
