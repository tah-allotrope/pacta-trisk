# Dashboard

## Run locally

```bash
streamlit run dashboard/app.py
```

## What is implemented

- Phase 02: Streamlit shell, loaders, chart helpers, theme, README
- Phase 03: `1_PACTA_Alignment.py` with KPI cards, sector drilldown, downloads, and static snapshot charts
- Phase 04: `2_TRISK_Risk.py` with borrower ranking, scatter, sensitivity filtering, assumptions panel, and TRISK zip download
- Phase 05: `3_Reports.py`, `4_Methodology.py`, landing-page polish, and shared branding/footer updates

## Current page status

- `1_PACTA_Alignment.py` — implemented
- `2_TRISK_Risk.py` — implemented
- `3_Reports.py` — implemented
- `4_Methodology.py` — implemented

## Public demo mode

The plan was updated to use a **fully public** URL, so the app currently does **not** require a password gate.

If a later phase reintroduces a gate, the intended secret is `DEMO_PASSWORD` via `st.secrets`.

## Data source

The app reads from `dashboard/data/`, which is refreshed from pipeline outputs via:

```bash
Rscript scripts/refresh_dashboard_data.R
```

## Demo artifacts

- Latest integrated report anchor: `dashboard/data/reports/2026-04-16-final-vietnam-bank-trisk-demo.html`
- Methodology source PDF: `docs/Baer_TRISK_2022.pdf`
