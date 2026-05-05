# PACTA + TRISK Demo Script

## Goal

Walk a bank client through the dashboard in under 8 minutes.

## Pre-demo checklist

1. Open the live Streamlit URL 2 minutes before the meeting to avoid cold-start lag.
2. Keep `reports/2026-04-16-final-vietnam-bank-trisk-demo.html` open in a spare tab as backup.
3. If the cloud app is unavailable, run `streamlit run dashboard/app.py` locally and screen-share.
4. For a multisector demo refresh, rerun `scripts/trisk_prepare_inputs.R`, `scripts/trisk_power_demo.R`, `scripts/trisk_sector_demo.R cement`, `scripts/trisk_sector_demo.R steel`, and `scripts/refresh_dashboard_data.R` before the meeting.

## 8-minute walkthrough (with Scenario Builder)

### 0:00 to 1:00 — Landing page

- State that the dataset is synthetic and safe for demo use.
- Explain the sequence: portfolio alignment first, borrower stress second, longer-form evidence last.
- Point to the four pages in the sidebar.

### 1:00 to 3:00 — PACTA Alignment

- Open `PACTA Alignment`.
- Highlight the KPI cards and explain that the page answers: where is the portfolio aligned or misaligned against transition pathways?
- Use the sector selector to move from `Power` to `Automotive`.
- Show the interactive table and the static chart panel side-by-side.
- Close with the alignment overview and coal stranded-risk figure.

### 3:00 to 5:30 — TRISK Risk

- Open `TRISK Risk`.
- Start with the red disclaimer: PD changes are scenario-horizon stress summaries, not regulatory PDs.
- Start on `Power`, show the NPV ranking chart, and call out the top coal-heavy names.
- Show the NPV-vs-PD scatter and explain heterogeneity across borrowers.
- Change one sensitivity input, such as `market_passthrough`, and show that the results update instantly without recomputation.
- Switch the sector selector to `Cement` and `Steel` to show that the dashboard now reuses the same stress view across all three sectors.
- State explicitly that `Cement` and `Steel` currently use sector-level SDA context, not borrower-specific alignment scores.
- Point to the assumptions tables so the client sees what drives the synthetic stress setup.

### 5:30 to 6:30 — Scenario Builder

- Open `Scenario Builder` (sidebar item 5).
- Explain: "This page lets you drive the five TRISK levers yourself to see how borrower rankings shift."
- Change `Shock year` from 2028 to 2026 — show the top-10 ranking change and the delta table.
- Switch `Carbon price family` to `Delayed transition (mild)` — point out which borrowers drop in priority.
- Highlight the top NPV mover: "This borrower is most sensitive to the lever combination you chose."
- Click `Save current scenario`, then change a lever and reload from saved.
- Click `Download scenario CSV` to show export capability.
- (Operator only, local setup) Open the "Live rerun" expander, set a custom discount rate like 0.07, and click "Run now" to show the live comparison.

### 7:00 to 7:30 — Reports + Methodology

- Open `Reports`, expand the final integrated report.
- Open `Methodology`, explain the PACTA vs TRISK division of labor.
- Point to the source PDF and research notes.

### 7:30 to 8:00 — Close

- Summarize the client value:
  - portfolio-level transition story,
  - borrower-level stress ranking,
  - interactive scenario exploration (Scenario Builder),
  - downloadable evidence.
- Offer to drill further into a sector or borrower after the main walkthrough.

## Fallback path

If the live Streamlit app is unavailable during the demo:

1. Run `streamlit run dashboard/app.py` locally.
2. Screen-share the local app.
3. If local Streamlit also fails, open the latest integrated HTML report and continue the narrative from that static artifact.

## Known caveats to say out loud

- The full dashboard uses synthetic portfolio, borrower, and scenario data.
- TRISK outputs are demo stress indicators, not production credit-model outputs.
- `Power` has borrower-level market-share alignment context, while `Cement` and `Steel` currently show sector-level SDA context for orientation only.
