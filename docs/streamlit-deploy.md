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

## Constraints

- This environment can prepare the repo and verify locally, but Streamlit Community Cloud deployment still requires a browser-authenticated step unless a dedicated Streamlit API/CLI is available.
