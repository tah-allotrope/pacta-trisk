---
title: "PACTA + TRISK Bank Showcase Dashboard"
date: "2026-04-25"
status: "draft"
request: "PACTA + TRISK dashboard/webapp for showcase with bank clients, deployed on a free tier of the best option among Firebase, Supabase, Oracle Cloud Free Tier, Streamlit Community Cloud, etc. Compare hosting options and pick a recommended stack. Use existing PACTA + TRISK outputs in this repo (reports/, research/) and synthetic Vietnam bank data."
plan_type: "multi-phase"
research_inputs:
  - "research/2026-04-08_integration-trisk-model-existing.md"
  - "research/PACTA for BANKS - TRISK overview.pptx.txt"
  - "research/Baer_TRISK_2022_extracted.txt"
---

# Plan: PACTA + TRISK Bank Showcase Dashboard

## Objective
Stand up a publicly reachable, free-tier-hosted web dashboard that lets a bank client click through the existing Vietnam PACTA alignment outputs and the TRISK power-pilot stress-test outputs from this repo as a single coherent narrative (portfolio → sector alignment → firm-level transition risk). The artifact must be demo-ready by the next bank client meeting, run at zero ongoing cost on a free tier, and be reproducible from the R/Python pipeline already in `scripts/` so updated runs roll forward without re-implementation.

## Context Snapshot
- **Current state:**
  - PACTA Vietnam pipeline produces alignment CSVs and PNGs in `synthesis_output/vietnam/` (e.g. `04_vn_ms_company.csv`, `06_vn_ms_alignment_2030.csv`, `12_vn_alignment_overview.png`).
  - TRISK power pilot produces NPV/VaR and PD-change artifacts in `synthesis_output/trisk/power_demo/` and inputs in `output/trisk_inputs/power_demo/`.
  - Static HTML reports already exist in `reports/` (e.g. `2026-04-16-final-vietnam-bank-trisk-demo.html`, `PACTA_Vietnam_Bank_Report.html`, `PACTA_Synthesis_Report.html`) but are unlinked, single-page, and not navigable as a portfolio walkthrough.
  - No web app, no interactive filtering, no client-friendly entry URL.
- **Desired state:** One hosted URL (custom subdomain optional) with: (1) landing page summarizing the methodology and the Vietnam bank case, (2) PACTA tab with sector/technology alignment views and downloadable CSVs, (3) TRISK tab with firm-level NPV change, VaR, and PD-change views plus shock-year sensitivity, (4) a "Reports" tab that hosts the existing HTML PDFs as deep-linked artifacts. Hosting must be free tier and require no card-on-file surprise.
- **Key repo surfaces:**
  - Data: `data/vietnam_*.csv`, `output/trisk_inputs/power_demo/`, `synthesis_output/vietnam/`, `synthesis_output/trisk/power_demo/`.
  - Pipelines: `scripts/pacta_vietnam_scenario.R`, `scripts/pacta_synthesis.R`, `scripts/trisk_prepare_inputs.R`, `scripts/trisk_power_demo.R`, `scripts/generate_report.py`/`generate_trisk_reports.py`.
  - Existing static reports in `reports/`.
  - Research: `research/2026-04-08_integration-trisk-model-existing.md`, `research/PACTA for BANKS - TRISK overview.pptx.txt`.
- **Out of scope:**
  - Running PACTA/TRISK math in the browser (the app reads precomputed artifacts only).
  - Multi-tenant auth / per-bank logins (single shared demo URL, optional shared password).
  - Real (non-synthetic) bank data; the showcase uses the synthetic Vietnam loanbook only.
  - CI/CD beyond a single `git push` deploy.

## Research Inputs
- `research/2026-04-08_integration-trisk-model-existing.md` — Confirms the layered narrative the dashboard should tell (PACTA = "who is misaligned", TRISK = "how much value/credit risk under scenario shock"), pins the power sector as the right pilot, and lists the exact firm-level outputs (NPV change, VaR, PD-change, sensitivity over `shock_year`/`discount_rate`/`risk_free_rate`/`market_passthrough`) that drive the TRISK tab's required charts and filters.
- `research/PACTA for BANKS - TRISK overview.pptx.txt` — Establishes audience-facing framing for bank clients (alignment vs. risk, sector pilot first), informs the landing-page copy and tab order.
- `research/Baer_TRISK_2022_extracted.txt` — Source of methodology footnote text and the cautionary language around interpreting PD changes (must surface as an inline disclaimer in the TRISK tab so bank clients don't read PD changes as 1-year regulatory PDs).

## Assumptions and Constraints
- **ASM-001:** All charts are precomputed by the existing R/Python pipeline; the web app only loads CSV/PNG/Parquet artifacts. No live R kernel, no on-request stress-test re-runs.
- **ASM-002:** Synthetic Vietnam dataset is safe to expose publicly; no NDA-restricted data lands in the deployed bundle.
- **ASM-003:** Total artifact bundle (CSVs + PNGs + HTML reports) fits under 100 MB so any free-tier static host accepts it without paid add-ons.
- **ASM-004:** A single demo password is acceptable in lieu of full auth; if the user wants no auth, that toggle is a one-line change in the chosen framework.
- **CON-001:** Free tier only. No credit card requirement at deploy time. No service that auto-bills after a trial.
- **CON-002:** Solo developer, Windows + R + Python toolchain already installed; avoid stacks that need Docker-on-Windows or a separate Postgres install just for the demo.
- **CON-003:** Demo must survive ~1 month of light click traffic (≤200 concurrent sessions across pilots) without exceeding free-tier quotas.
- **DEC-001:** **Recommended hosting stack is Streamlit Community Cloud** (Python, free, GitHub-linked, no card, ~1 GB RAM/app, sleeps when idle, custom subdomain `pacta-trisk-vn.streamlit.app`). Rationale and alternative comparison in `## Risks and Alternatives`.
- **DEC-002:** Frontend is a Streamlit multi-page app reading artifacts from the repo (or a `dashboard/data/` snapshot copy) — no separate API server, no database for v1.
- **DEC-003:** Existing static `reports/*.html` are served as-is via Streamlit `components.html` or as downloadable links; they are not rewritten.

## Phase Summary
| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Pick host, lock data contract, snapshot artifacts | None | Hosting decision doc, `dashboard/data/` snapshot, schema README |
| PHASE-02 | Scaffold Streamlit multi-page app and shared components | PHASE-01 | `dashboard/app.py`, `dashboard/pages/`, `dashboard/lib/`, local run works |
| PHASE-03 | Build PACTA alignment views | PHASE-02 | Portfolio overview, sector/tech filters, downloadable CSVs |
| PHASE-04 | Build TRISK risk views | PHASE-02 | NPV/VaR, PD-change, sensitivity sliders, methodology disclaimer |
| PHASE-05 | Reports hub + landing page + branding | PHASE-03, PHASE-04 | Landing page, embedded HTML reports, screenshots, demo password |
| PHASE-06 | Deploy to Streamlit Community Cloud and rehearse demo | PHASE-05 | Public URL, smoke-test checklist, fallback plan |

## Detailed Phases

### PHASE-01 - Host Selection and Data Contract
**Goal**
Lock the hosting choice, define the precise on-disk data contract the app will read, and snapshot the relevant outputs into a single `dashboard/data/` folder so the app does not depend on the full pipeline being rerun.

**Tasks**
- [ ] TASK-01-01: Author `docs/hosting-decision.md` with a one-page comparison of Streamlit Community Cloud, Supabase (Postgres + Edge Functions), Firebase Hosting + Cloud Run, Oracle Cloud Free Tier (Always Free VM), Hugging Face Spaces, Vercel/Netlify (static + Next.js), and Render free web service. Score on: card-required, sleep behavior, RAM/CPU, file-size limits, custom domain, ease of CSV/PNG hosting, secret/password support.
- [ ] TASK-01-02: Record the recommendation (DEC-001 = Streamlit Community Cloud) with explicit reasons and a documented fallback (Hugging Face Spaces with Streamlit SDK).
- [ ] TASK-01-03: Create `dashboard/data/pacta/` and copy the curated subset from `synthesis_output/vietnam/` (`02_vn_matched_prioritized.csv`, `04_vn_ms_company.csv`, `04_vn_ms_portfolio.csv`, `05_vn_sda_portfolio.csv`, `06_vn_ms_alignment_2030.csv`, `06_vn_sda_alignment_2030.csv`, all `*.png`).
- [ ] TASK-01-04: Create `dashboard/data/trisk/` and copy the curated subset from `synthesis_output/trisk/power_demo/` (NPV/VaR results, PD-change results, sensitivity results) and from `output/trisk_inputs/power_demo/` (the financial features and scenarios actually used).
- [ ] TASK-01-05: Create `dashboard/data/reports/` with symlinks or copies of the four `reports/2026-04-16-*.html` and `reports/PACTA_*Report.html` files used in the showcase.
- [ ] TASK-01-06: Write `dashboard/data/README.md` describing every file's columns, units, and provenance script (e.g. "produced by `scripts/pacta_synthesis.R` step 04").
- [ ] TASK-01-07: Add `scripts/refresh_dashboard_data.R` (or `.py`) — a one-shot copy/rename script so future pipeline runs republish the snapshot deterministically.

**Files / Surfaces**
- `docs/hosting-decision.md` - new comparison doc.
- `dashboard/data/` - new snapshot tree consumed by the app.
- `scripts/refresh_dashboard_data.R` - new helper.
- `synthesis_output/vietnam/`, `synthesis_output/trisk/power_demo/`, `output/trisk_inputs/power_demo/`, `reports/` - read-only sources.

**Dependencies**
- None.

**Exit Criteria**
- [ ] `docs/hosting-decision.md` exists with a clear winner and a fallback.
- [ ] `dashboard/data/` is self-contained: deleting `output/` and `synthesis_output/` would not break the app.
- [ ] `scripts/refresh_dashboard_data.R` regenerates `dashboard/data/` from current pipeline outputs in one command.
- [ ] Total `dashboard/data/` size ≤100 MB.

**Phase Risks**
- **RISK-01-01:** Streamlit Cloud free tier limits change (e.g. always-on, RAM). Mitigation: keep app stateless and ≤500 MB working set; document Hugging Face Spaces fallback in `docs/hosting-decision.md`.

### PHASE-02 - Streamlit App Scaffold
**Goal**
Stand up the Streamlit multi-page skeleton, shared loaders, and theme so subsequent phases only add page-level content.

**Tasks**
- [ ] TASK-02-01: Create `dashboard/app.py` as the landing page (overview + nav).
- [ ] TASK-02-02: Create `dashboard/pages/1_PACTA_Alignment.py`, `dashboard/pages/2_TRISK_Risk.py`, `dashboard/pages/3_Reports.py`, `dashboard/pages/4_Methodology.py` as empty stubs.
- [ ] TASK-02-03: Create `dashboard/lib/loaders.py` with `@st.cache_data`-wrapped CSV/PNG loaders pointed at `dashboard/data/`.
- [ ] TASK-02-04: Create `dashboard/lib/charts.py` with thin Plotly wrappers (`alignment_bar`, `trajectory_line`, `npv_var_scatter`, `pd_change_heatmap`).
- [ ] TASK-02-05: Add `dashboard/requirements.txt` pinning `streamlit`, `pandas`, `plotly`, `pyarrow`. No R dependency.
- [ ] TASK-02-06: Add `dashboard/.streamlit/config.toml` with theme (Allotrope-friendly palette) and `client.toolbarMode = "minimal"`.
- [ ] TASK-02-07: Add `dashboard/README.md` with `streamlit run dashboard/app.py` instructions and the `STREAMLIT_PASSWORD` env-var explanation.
- [ ] TASK-02-08: Implement optional shared-secret gate in `dashboard/app.py` using `st.secrets["DEMO_PASSWORD"]` (no-op if unset).

**Files / Surfaces**
- `dashboard/app.py`, `dashboard/pages/*`, `dashboard/lib/*`, `dashboard/requirements.txt`, `dashboard/.streamlit/config.toml`, `dashboard/README.md` - all new.

**Dependencies**
- PHASE-01 (`dashboard/data/` exists).

**Exit Criteria**
- [ ] `streamlit run dashboard/app.py` opens locally with all four tabs visible.
- [ ] Loaders return non-empty DataFrames for at least one PACTA file and one TRISK file.
- [ ] Demo password gate works locally when `DEMO_PASSWORD` is set.

**Phase Risks**
- **RISK-02-01:** Plotly bundle inflates cold-start. Mitigation: lazy-import inside page modules, cache loaders.

### PHASE-03 - PACTA Alignment Views
**Goal**
Turn `synthesis_output/vietnam/` into an interactive alignment story a bank client can navigate.

**Tasks**
- [ ] TASK-03-01: Implement portfolio overview section reading `04_vn_ms_portfolio.csv` and `05_vn_sda_portfolio.csv` (header KPIs: % aligned by sector, weighted exposure).
- [ ] TASK-03-02: Implement sector/technology filter (Power, Automotive, Cement, Steel) wired to `04_vn_ms_company.csv` and `06_vn_ms_alignment_2030.csv` / `06_vn_sda_alignment_2030.csv`.
- [ ] TASK-03-03: Render technology-mix and trajectory charts (`05_vn_power_techmix.png`, `06_vn_coal_trajectory.png`, `07_vn_renewables_trajectory.png`, `08_vn_auto_techmix.png`, `09_vn_ev_trajectory.png`, `10_vn_cement_sda.png`, `11_vn_steel_sda.png`) through `st.image` with captions sourced from `dashboard/data/README.md`.
- [ ] TASK-03-04: Render `12_vn_alignment_overview.png` and `13_vn_coal_stranded_risk.png` as the closing "so what" figures on the page.
- [ ] TASK-03-05: Add per-table "Download CSV" buttons via `st.download_button`.
- [ ] TASK-03-06: Add a "Methodology footnote" expander citing PACTA for Banks docs and `research/PACTA for BANKS - TRISK overview.pptx.txt`.

**Files / Surfaces**
- `dashboard/pages/1_PACTA_Alignment.py` - implements all of the above.
- `dashboard/lib/loaders.py`, `dashboard/lib/charts.py` - extended as needed.

**Dependencies**
- PHASE-02.

**Exit Criteria**
- [ ] Sector filter changes both the table and the trajectory image without page reload error.
- [ ] All five sectors render at least one chart and one table.
- [ ] Downloads succeed for at least three CSVs.

**Phase Risks**
- **RISK-03-01:** Source PNGs are static and don't respond to filter; that's expected for v1, but must be visually framed as "snapshot view" with the interactive table living next to it.

### PHASE-04 - TRISK Risk Views
**Goal**
Make the firm-level transition-risk story navigable: which Vietnam power borrowers lose the most NPV, which see the largest PD shifts, and how that shifts under shock-year and discount-rate sensitivity.

**Tasks**
- [ ] TASK-04-01: Inventory the actual columns in `synthesis_output/trisk/power_demo/` outputs and document them in `dashboard/data/README.md` (NPV baseline, NPV stress, NPV change, VaR, PD-change term structure 1y–5y, sensitivity dimensions).
- [ ] TASK-04-02: Implement company-level NPV change ranking table + bar chart.
- [ ] TASK-04-03: Implement scatter of `npv_change_pct` vs `pd_change` colored by technology (coal/gas/hydro/solar/wind).
- [ ] TASK-04-04: Implement sensitivity panel with sliders/selects for `shock_year`, `discount_rate`, `risk_free_rate`, `market_passthrough` that filter the precomputed sensitivity grid (no live recomputation).
- [ ] TASK-04-05: Render the inputs-used panel (financial features and scenario excerpts from `output/trisk_inputs/power_demo/`) so bank clients can see the synthetic assumptions.
- [ ] TASK-04-06: Add a prominent disclaimer ("PD changes are scenario-horizon shock summaries, not 1-year regulatory PDs") sourced from `research/Baer_TRISK_2022_extracted.txt`.
- [ ] TASK-04-07: Add a "Download all TRISK results" zip button.

**Files / Surfaces**
- `dashboard/pages/2_TRISK_Risk.py` - implements all of the above.
- `dashboard/lib/loaders.py`, `dashboard/lib/charts.py` - extended for risk-specific helpers.
- `synthesis_output/trisk/power_demo/`, `output/trisk_inputs/power_demo/` - read-only.

**Dependencies**
- PHASE-02. PHASE-01 must have copied TRISK results into `dashboard/data/trisk/`.

**Exit Criteria**
- [ ] At least one company-level NPV table and one PD-change visual render with real numbers.
- [ ] Sensitivity sliders change visible values within ≤500 ms (no recompute).
- [ ] Disclaimer is visible on first paint, not hidden inside an expander.

**Phase Risks**
- **RISK-04-01:** Sensitivity grid not pre-materialized at all combinations — discover during TASK-04-01. Mitigation: if missing, regenerate via `scripts/trisk_power_demo.R` over a small parameter grid before deploy and bake results into `dashboard/data/trisk/`.

### PHASE-05 - Reports Hub, Landing Page, Branding
**Goal**
Polish for client-facing demo: a strong landing page, the existing PDF/HTML reports as first-class artifacts, and minimal branding.

**Tasks**
- [ ] TASK-05-01: Write landing copy in `dashboard/app.py`: 3-paragraph framing (synthetic Vietnam case, why PACTA + TRISK together, how to read the tabs).
- [ ] TASK-05-02: Add a "What's new" callout linking the latest report (`reports/2026-04-16-final-vietnam-bank-trisk-demo.html`).
- [ ] TASK-05-03: Implement `dashboard/pages/3_Reports.py` listing the four reports with title, date, one-line summary, and an "Open" button using `components.html(open(file).read(), height=900, scrolling=True)` for inline view; also a "Download HTML" button.
- [ ] TASK-05-04: Implement `dashboard/pages/4_Methodology.py` summarizing PACTA for Banks and TRISK with citations to the research notes and inline links to source PDFs.
- [ ] TASK-05-05: Add a small Allotrope logo / footer ("Synthetic data; for demo only") on every page via `dashboard/lib/branding.py`.
- [ ] TASK-05-06: Capture three screenshots of the live local app for the README and for sharing in pre-demo emails.

**Files / Surfaces**
- `dashboard/app.py`, `dashboard/pages/3_Reports.py`, `dashboard/pages/4_Methodology.py`, `dashboard/lib/branding.py`, `dashboard/README.md`.
- `reports/*.html` - read-only embed sources.

**Dependencies**
- PHASE-03, PHASE-04.

**Exit Criteria**
- [ ] Landing page passes a "10-second test" — a non-PACTA reader understands what they're looking at.
- [ ] All four HTML reports open inline and download cleanly.
- [ ] Footer disclaimer visible on every page.

**Phase Risks**
- **RISK-05-01:** Embedding large HTML reports inflates memory. Mitigation: load on tab open, not on app start, and prefer download links if any report exceeds 5 MB.

### PHASE-06 - Deploy and Rehearse
**Goal**
Ship the public URL on Streamlit Community Cloud, gate it with a demo password, and run a full rehearsal against the demo script.

**Tasks**
- [ ] TASK-06-01: Push the `dashboard/` tree to a public GitHub repo (or this one if already public) and confirm `dashboard/requirements.txt` is at repo root or referenced via `requirements_file` in Streamlit settings.
- [ ] TASK-06-02: Connect Streamlit Community Cloud to the repo, set main file to `dashboard/app.py`, set Python version, and set `DEMO_PASSWORD` in app secrets.
- [ ] TASK-06-03: Configure the custom subdomain `pacta-trisk-vn.streamlit.app` (or close variant if taken).
- [ ] TASK-06-04: Run the smoke-test checklist on the deployed URL: cold-start <30 s, all four tabs render, sensitivity sliders responsive, downloads succeed, password gate works in incognito.
- [ ] TASK-06-05: Write a one-page demo script in `docs/demo-script.md` walking the bank-client narrative tab-by-tab (≤8 minutes).
- [ ] TASK-06-06: Document the fallback path: if Streamlit Cloud is unreachable mid-demo, run `streamlit run dashboard/app.py` locally and screen-share; pre-record a 2-min Loom as last-resort backup.

**Files / Surfaces**
- Streamlit Community Cloud project (external).
- `docs/demo-script.md` - new.
- `dashboard/README.md` - update with public URL.

**Dependencies**
- PHASE-05 complete and merged.

**Exit Criteria**
- [ ] Public URL loads in incognito, password gate accepts the configured secret.
- [ ] Smoke-test checklist passes end-to-end.
- [ ] Demo script rehearsed once with a stopwatch and timed under 8 minutes.

**Phase Risks**
- **RISK-06-01:** Free tier sleep on idle adds ~10 s warm-up before a live demo. Mitigation: hit the URL ~2 min before the meeting; document this in `docs/demo-script.md`.

## Verification Strategy
- **TEST-001:** Add `dashboard/tests/test_loaders.py` (pytest) asserting each loader returns the expected non-empty schema for every file in `dashboard/data/`. Run via `pytest dashboard/tests/`.
- **TEST-002:** Add `dashboard/tests/test_smoke.py` using Streamlit's `AppTest` to render each page headlessly and assert no exception.
- **MANUAL-001:** Smoke-test checklist on the deployed URL (PHASE-06, TASK-06-04): cold-start, every tab, every download, sensitivity sliders, password gate, mobile-width Chrome devtools layout.
- **MANUAL-002:** Subject-matter sanity check — confirm the Vietnam coal stranded-risk number on the dashboard matches `synthesis_output/vietnam/13_vn_coal_stranded_risk.png` and the TRISK NPV change ranking matches the latest `reports/2026-04-16-trisk-power-pilot.html`.
- **OBS-001:** Enable Streamlit Cloud's built-in app analytics; check after first week that no quota is approaching limits.

## Risks and Alternatives
- **RISK-001:** Free-tier vendor lock-in / sleep behavior surprises a live client meeting. Mitigation: document Hugging Face Spaces fallback in `docs/hosting-decision.md`; pre-warm the URL before each demo.
- **RISK-002:** Synthetic data is mistaken for real bank data. Mitigation: footer disclaimer on every page (PHASE-05) and a prominent banner on the landing page.
- **RISK-003:** Methodology misreading by clients (PD change as 1-year regulatory PD). Mitigation: persistent disclaimer on TRISK page (TASK-04-06) sourced verbatim from Baer 2022 caveat.
- **ALT-001:** **Supabase + a Next.js frontend on Vercel.** Cleaner production path (Postgres-backed, real REST/GraphQL, SSO-ready) but ~2–3× the build effort, requires schema migration of CSVs into Postgres, and needs separate hosting for the React app. Rejected for v1 because the showcase is read-only and the cost/benefit doesn't justify a database.
- **ALT-002:** **Firebase Hosting + Cloud Run.** Strong free tier and CDN but requires containerizing a Python/R service, a credit card on file, and IAM setup. Rejected: card requirement and operational overhead too high for a single demo.
- **ALT-003:** **Oracle Cloud Always Free VM.** Generous resources (4 ARM cores, 24 GB RAM) and no sleep, but it's a self-managed Linux VM (TLS, reverse proxy, systemd), card-on-file at signup, and historically frequent free-tier reclamations. Rejected for the showcase; reasonable if we later need an always-on backend.
- **ALT-004:** **Hugging Face Spaces (Streamlit SDK).** Near-equivalent to Streamlit Cloud, also free, no card. Kept as the documented fallback in `docs/hosting-decision.md`.
- **ALT-005:** **Pure static site (GitHub Pages / Netlify) of the existing HTML reports.** Cheapest and simplest, but loses interactivity (filters, sensitivity sliders, downloadable subsets). Rejected because the bank-client showcase is materially better with interaction.

## Grill Me — Resolved 2026-04-26
1. **Q-001: Public or password-gated?** **Fully public.** Drop password gate; add prominent synthetic-data disclaimer on every page.
2. **Q-002: Sensitivity grid materialized?** **Batch run needed.** Budget time in PHASE-04 to run a small grid via `scripts/trisk_power_demo.R` and snapshot into `dashboard/data/trisk/sensitivity.csv`.
3. **Q-003: Deadline?** **Full scope, no fixed deadline.** Execute all 6 phases with full polish.
4. **Q-004: Custom domain?** **Yes — `pactavn`** (target `pactavn.streamlit.app` or equivalent available subdomain). Add CNAME task to PHASE-06.
5. **Q-005: Raw loanbook rows?** **Aggregated only.** No raw loanbook exposure; keep inputs in Methodology expander as downloadable CSV with "synthetic" stamp.

## Suggested Next Step
Execute PHASE-01 starting with `docs/hosting-decision.md` and the `dashboard/data/` snapshot.
