# Workshop Facilitation Kit — PACTA + TRISK Vietnam

> **Synthetic data — illustrative only.** Every exercise uses the synthetic MCB demo portfolio. No real client data is required or shown.

This kit sequences a **half-day (3.5-hour) client workshop** for the first bank that onboards. It reuses existing repo assets; it writes no new analytical content.

## Agenda (220 minutes)

| # | Segment | Duration | Assets | Facilitator notes |
|---|---------|----------|--------|-------------------|
| 0 | Welcome & synthetic-data disclaimer | 15 min | This README's disclaimer + `docs/outputs_layer.md` privacy posture | State explicitly: every number is synthetic and illustrative; BIP? No real data leaves the bank. |
| 1 | **Data readiness exercise** | 45 min | `intake/templates/loanbook_template.csv` + `intake/templates/loanbook_template.xlsx` + `intake/SCHEMA.md` (§ Units, § Submission size) | Hands-on: each table maps its own anonymized 10-row extract onto the template. Emphasize the whole-VND unit contract — exposures are whole Dong (1e5–5e12), never millions, never rescaled; formatting for display goes through `R/format_money.R` only. Check that participants can produce `normalized_loanbook.csv` locally via `Rscript scripts/intake_validate_and_map.R` and read `validation_warnings.csv` / `coverage_metrics.json`. Timing: 20 min mapping, 15 min validator run, 10 min Q&A. |
| 2 | **Methodology walkthrough** | 40 min | `docs/scoring_anchors.md` (Tables A1/A2/B/C + SLL-1, composite formulas, worked example) | Walk the four anchor tables and the borrower composite `severity_alignment` / `severity_trisk` blend. Use the worked example (Power 14.39pp → 0.60975, Cement 2.1% → 0.2583) so participants can recompute a score with a calculator. Stress that SLL readiness is a *different question* from transition-risk severity — see `R/sll_readiness.R`. |
| 3 | **Live surface: Scenario Builder** | 30 min | Streamlit dashboard → **Scenario Builder** page (`dashboard/pages/`) | Live demo: move `shock_year`, `carbon_price_family`, `market_passthrough` and show TRISK NPV/PD move in real time. Point out which levers were historically inert (now fixed per `docs/` Wave 1 report). No data leaves the browser. |
| 4 | **Worked example: anonymized disclosure pack** | 50 min | `output/disclosure/disclosure_pack.html` rendered with `--anonymize` (Borrower A/B/C) + `templates/disclosure/disclosure_sections.md` + `docs/financed_emissions_methodology.md` § Two benchmarks note | Walk the TCFD four pillars, then focus on Metrics & Targets: show financed-emissions total *with* its data-quality composition (scores 1–5) adjacent, and call out the Scope 3 exclusion (automotive, coal mining). Then open the Sector Target Registry (`Sector_Target_Registry.html`): state the duality sentence explicitly — *PACTA alignment gaps are measured against the scenario benchmark, while targets are computed by convergence from the portfolio's own baseline.* Financed emissions is a third, independent inventory — not a gap or a target. |
| 5 | **Roadmap & next steps** | 20 min | `docs/bidv_implementation_roadmap.md` (adapted to the engaging bank's name via `{{bank_name}}`) + `docs/hosting-decision.md` | Align on data-extraction owner, 6-month phased pathway, quarterly re-run cadence, and that private instance hosting is operator-hosted, access-controlled per-engagement (not one cloned repo per client). Collect `paths.report_overlay_md` content if the bank wants a custom narrative section. |
| 6 | Wrap & actions log | 20 min | `workshop/actions_log_template.csv` (in this directory) | Capture owners/dates for loanbook extract, ABCD supplement, overlay sign-off, and go/no-go for first real run. |

## Materials checklist (print / pre-load)

- `intake/templates/loanbook_template.csv` (and .xlsx) — one per table, plus a filled example row.
- `docs/scoring_anchors.md` — printed, one per participant (the calculator-reproducible proof).
- Live dashboard URL + fallback screenshots under `dashboard/data/` if offline.
- Anonymized disclosure pack + `Financed_Emissions.html` + `Sector_Target_Registry.html` — pre-generated with `--anonymize` (no real names, no unredacted VND beyond the anonymized band).
- `workshop/actions_log_template.csv` — for capture.

## Whole-VND contract (repeat at the start of segment 1)

> **Money is whole Vietnamese Dong (VND) and is never rescaled.** Loan exposures (`loan_size_outstanding`, `exposure_vnd`) span raw magnitudes 1e5 to 5e12. Never divide or multiply except where existing code already does so for display. Formatting for display goes through `R/format_money.R`. The intake validator and `INV-006` both fail a book whose median VND exposure is implausibly small — the same defect a millions-of-VND rescale would produce.

## Facilitator timings (strict)

- Start 09:00, hard stop 12:30. Buffer 10 min for Segment 1 overrun; cut Segment 3 live demo to 20 min if needed — never cut Segment 4's duality note or Segment 5's next-step owners.
- Each hand-off ends with a one-sentence takeaway written on the shared board.

## What this kit does NOT do

- No new analytical content is computed for the workshop. Every table and chart shown is a pre-generated pipeline output on the synthetic portfolio.
- No real loanbook is ingested during the workshop. The BYOL intake page (`BYOL_INTAKE=1`) is demoed conceptually; a real intake is a follow-up offline step.

## Prerequisites (operator, before the day)

- `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json` green, plus `Rscript scripts/generate_disclosure_pack.R --anonymize --config engagements/mcb-demo/engagement_config.json` to refresh the anonymized pack.
- `python -m streamlit run dashboard/app.py` reachable on the workshop network, with Scenario Builder page verified.
- `workshop/actions_log_template.csv` printed.

## Follow-up

Within 48h, send the anonymized pack + `Coverage_Reconciliation_Report.html` + this README to the participant list, and open a tracking issue for the first real `intake/` submission.
