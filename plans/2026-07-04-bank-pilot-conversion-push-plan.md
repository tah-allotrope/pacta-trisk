---
title: "Bank Pilot Conversion Push"
date: "2026-07-04"
status: "completed"
request: "bank-pilot-conversion-push"
plan_type: "multi-phase"
research_inputs:
  - "research/2026-07-04_bank-pilot-conversion-push-brainstorm.md"
  - "research/future_planning_ideas.md"
---

# Plan: Bank Pilot Conversion Push

## Objective
Turn the demo-complete PACTA + TRISK Vietnam platform into a pilot-conversion package: a synthetic-data pilot (guided sessions plus ~2 weeks of unsupervised bank access to the public Streamlit app) that closes with a signed, paid real-data engagement. The work is four value-sequenced workstreams — conversion assets, self-explore readiness, refresh automation with CI, bilingual client documents — plus an upfront hygiene pass, over ~4–6 weeks with no fixed external deadline.

## Context Snapshot
- **Current state:** R pipeline (`scripts/*.R`) produces `synthesis_output/`, hand-copied to `dashboard/data/` via `scripts/refresh_dashboard_data.R`; 7-page public Streamlit app on Community Cloud (no auth, no data-freshness metadata); pitch deck done (`present/bank_prospect_deck.pptx`); loanbook intake templates exist (`intake/templates/loanbook_template.{csv,xlsx}`, `intake/templates/README_vi.md`); no `.github/` workflows; no evaluation guide, data-spec sheet, real-data proposal, VN client documents, or usage analytics; repo hygiene debt (stray root files `nul`, `Rplots.pdf`, root PNGs, committed cache dirs, dirty snapshot CSVs, redundant deck variants).
- **Desired state:** Clean public repo; a `pilot/` conversion pack (data-spec sheet, real-data phase proposal template, tailoring checklist, session scripts) with `{{BANK_NAME}}` slots; home page reworked into a guided evaluation tour with anonymous page-view analytics and visible methodology disclaimers; `scripts/pipeline_refresh.R` orchestrator writing `pipeline_manifest.json` surfaced as a "Data as of" badge in the app; a GitHub Actions workflow that reruns the pipeline and commits refreshed snapshots; VN reference translations ("bản dịch tham khảo") of the key client documents.
- **Key repo surfaces:** `dashboard/app.py`, `dashboard/lib/branding.py`, `dashboard/lib/loaders.py`, `dashboard/tests/`, `dashboard/pages/6_Intake_Wizard.py`, `scripts/refresh_dashboard_data.R`, the PACTA/TRISK script chain (`pacta_vietnam_scenario.R`, `trisk_prepare_inputs.R`, `trisk_power_demo.R`, `trisk_sector_demo.R`, `trisk_scenario_grid.R`, `sector_prioritization.R`, `engagement_scoring.R`), `intake/templates/`, `reports/`, `present/`, new `pilot/` and `.github/workflows/`.
- **Out of scope:** Real bank data ingestion, auth/login, per-bank isolation; dashboard i18n/VN toggle; new sectors or methodology upgrades (borrower-level SDA, VinFast sensitivity); pricing terms beyond placeholders; paid hosting or custom domain.

## Research Inputs
- `research/2026-07-04_bank-pilot-conversion-push-brainstorm.md` - Fixes goal (win pilot → signed real-data phase), pilot shape (guided sessions + open access, synthetic data, public app, no auth), the four workstreams and their sequencing, VN scope (documents only, AI-only translations), automation depth (orchestrator + manifest + badge + CI), and 14 recorded decisions this plan inherits.
- `research/future_planning_ideas.md` - Source of "idea 2" (refresh automation: orchestrator, manifest, badge, CI) implemented in PHASE-04; ideas 1 and 3 are already built and reused, not rebuilt.

## Assumptions and Constraints
- **ASM-001:** The existing pitch deck, report generators (`scripts/generate_report.R`, `scripts/generate_bidv_report.R`), and output layer are content-current; this push wraps them rather than rebuilding.
- **ASM-002:** Streamlit Community Cloud auto-deploys from `main` and remains adequate for pilot traffic during the open-access weeks.
- **ASM-003:** No VN-speaking reviewer is in the loop; the "bản dịch tham khảo" label carries the quality disclaimer (brainstorm DEC-012).
- **CON-001:** Every bank-visible artifact must carry synthetic/illustrative-data disclaimers; in-app copy must keep the README methodology caveats visible (TRISK NPV/PD are illustrative stress indicators; cement/steel are sector-level SDA; steel match coverage ~4%).
- **CON-002:** R package restore in GitHub Actions is slow; the workflow must use renv (or a rocker container) with aggressive caching to stay usable.
- **CON-003:** The app is public with no login, so analytics must be anonymous and PII-free.
- **DEC-001:** Hosting stays fully public on Streamlit Community Cloud, no auth gate.
- **DEC-002:** Conversion assets are bank-agnostic with `{{BANK_NAME}}`-style slots and a tailoring checklist (per-prospect customization in under an hour).
- **DEC-003:** Sequencing by value: conversion assets → self-explore readiness → automation → bilingual documents; hygiene first because the public repo is itself bank-visible.

## Phase Summary
| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Repo hygiene and clean baseline | None | Clean tree, reconciled snapshots, pruned artifacts, all work committed |
| PHASE-02 | Conversion asset pack | PHASE-01 | `pilot/` pack: data-spec sheet, real-data proposal template, tailoring checklist, Intake Wizard demo script |
| PHASE-03 | Self-explore readiness | PHASE-01 | Home-page evaluation tour, anonymous analytics, disclaimer copy pass, guided-session scripts |
| PHASE-04 | Pipeline automation (idea 2) | PHASE-01 | `scripts/pipeline_refresh.R`, `pipeline_manifest.json`, "Data as of" badge, `.github/workflows/refresh.yml` |
| PHASE-05 | Bilingual client documents | PHASE-02, PHASE-03 | VN reference translations of data-spec sheet, evaluation guide, and key report pack items |

## Detailed Phases

### PHASE-01 - Repo Hygiene and Clean Baseline
**Goal**
Make the public repo look tended before bank eyes land on it, and establish a committed, reproducible baseline for the later phases.

**Tasks**
- [ ] TASK-01-01: Reconcile the dirty snapshot CSVs (`dashboard/data/trisk/{power,cement,steel}/*_latest.csv`, `synthesis_output/trisk/*_demo/*_latest.csv`, `scripts/sector_prioritization.R`): inspect the diffs, decide keep-or-revert, and commit the resolution with a message explaining which pipeline run produced them.
- [ ] TASK-01-02: Delete stray files from the repo root: `nul`, `Rplots.pdf`, `github-signin-streamlit-oauth.png`, `streamlit-signin.png`, root-level `phase6-*.png`, `localhostrun-tunnel.*.log`.
- [ ] TASK-01-03: Add/extend `.gitignore` for `__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `.playwright-mcp/`, `Rplots.pdf`, tunnel logs, and `.claude/worktrees/`; remove any of these already tracked with `git rm -r --cached`.
- [ ] TASK-01-04: Prune redundant deck variants in `present/` — keep `bank_prospect_deck.pptx` as canonical (or `_v2` if newer content), move the rest to an `archive/` subfolder with a one-line README note.
- [ ] TASK-01-05: Sweep `plans/PROGRESS.md` open items: mark superseded items as closed-with-reason; carry any genuinely live item into this plan's phases or explicitly defer it.
- [ ] TASK-01-06: Run `python -m pytest dashboard/tests` and the app locally (`streamlit run dashboard/app.py`) to confirm the cleaned tree still works; commit everything so `git status` is clean.

**Files / Surfaces**
- `dashboard/data/trisk/**`, `synthesis_output/trisk/**` - dirty snapshot reconciliation
- `.gitignore`, repo root - stray file removal
- `present/` - deck variant pruning
- `plans/PROGRESS.md` - open-item sweep

**Dependencies**
- None

**Exit Criteria**
- [ ] `git status` is clean; no cache dirs or stray artifacts tracked.
- [ ] `python -m pytest dashboard/tests` passes on the cleaned tree.
- [ ] `plans/PROGRESS.md` has no ambiguous open items.

**Phase Risks**
- **RISK-01-01:** The dirty snapshot CSVs may reflect an unrecorded pipeline rerun with changed parameters. Mitigation: diff against HEAD before deciding; if provenance is unclear, regenerate deterministically via `scripts/refresh_dashboard_data.R` and commit that output instead.

### PHASE-02 - Conversion Asset Pack
**Goal**
Give the pilot's closing conversation concrete next-step artifacts: the bank must be able to picture its own loanbook flowing in, and sign a scoped real-data phase.

**Tasks**
- [ ] TASK-02-01: Create `pilot/` directory with a README explaining the pack's purpose and the tailoring workflow.
- [ ] TASK-02-02: Write `pilot/loanbook_data_spec.md` — the "your data here" sheet: required/optional columns (derived from `intake/templates/loanbook_template.csv` and `scripts/intake_validate_and_map.R`'s validation rules), accepted formats, anonymization/coding guidance, sector coverage notes, and what PACTA/TRISK each column feeds.
- [ ] TASK-02-03: Write `pilot/real_data_phase_proposal.md` — scope, workflow (intake → validation → PACTA run → TRISK stress → engagement outputs), timeline placeholders, deliverables list, and `{{BANK_NAME}}`/`{{CONTACT}}`/`{{DATE}}` slots; no pricing beyond placeholders.
- [ ] TASK-02-04: Write `pilot/tailoring_checklist.md` — the under-an-hour per-prospect customization steps (slots to fill, deck slide swaps, sector-mix emphasis choices).
- [ ] TASK-02-05: Script and verify the Intake Wizard demo path: a documented click-path through `dashboard/pages/6_Intake_Wizard.py` using `intake/templates/loanbook_template.csv` as the demo upload, captured in `pilot/intake_demo_script.md`; fix any rough edges the walkthrough exposes (empty states, validation messages).
- [ ] TASK-02-06: Render the data-spec sheet and proposal to client-shareable HTML (reuse the styling conventions of the existing `reports/` generators) into `pilot/rendered/`.

**Files / Surfaces**
- `pilot/` (new) - all conversion documents
- `intake/templates/loanbook_template.csv`, `scripts/intake_validate_and_map.R` - source of truth for the data spec
- `dashboard/pages/6_Intake_Wizard.py`, `dashboard/lib/intake.py` - demo-path polish
- `scripts/generate_report.R` - styling reference for rendered HTML

**Dependencies**
- PHASE-01 (clean baseline)

**Exit Criteria**
- [ ] All four documents exist with tailoring slots; a dry-run tailoring for a fictional bank takes under an hour.
- [ ] The Intake Wizard demo path runs end-to-end with the template CSV without errors; `python -m pytest dashboard/tests/test_intake.py` passes.
- [ ] Every document carries the synthetic/illustrative-data disclaimer (CON-001).

**Phase Risks**
- **RISK-02-01:** The data spec drifting from what `intake_validate_and_map.R` actually validates. Mitigation: derive the spec table directly from the script's rules and add a comment in the doc pointing at the source script and version.

### PHASE-03 - Self-Explore Readiness
**Goal**
Make the dashboard survive two unsupervised weeks of bank-team exploration, and give you engagement visibility before the closing conversation.

**Tasks**
- [ ] TASK-03-01: Rework `dashboard/app.py` home into a guided evaluation tour: ordered steps ("1. PACTA alignment → 2. TRISK stress → 3. Scenario Builder → 4. Reports/Methodology → 5. Intake preview"), each with a one-line "what to look for" and `st.page_link` into the page; remove the developer-facing copy (e.g., "This first app slice implements the dashboard shell", scaffolding notes, "Deployment target: pactavn" metric).
- [ ] TASK-03-02: Add anonymous page-view analytics: a helper in `dashboard/lib/` called from `apply_page_frame` in `branding.py` so every page pings on load; PII-free (CON-003); mechanism per Grill Me Q-002 (default: hosted GoatCounter-style pixel/endpoint, configurable via env var and silently disabled when unset).
- [ ] TASK-03-03: Disclaimer/copy pass across all seven pages: methodology caveats visible in-app (TRISK NPV/PD illustrative, cement/steel sector-level SDA, steel coverage ~4%), consistent synthetic-data banner via `public_demo_banner()`, and empty-state/error message polish found by walking every page with and without operator env flags.
- [ ] TASK-03-04: Write `pilot/session_scripts.md` — talk tracks for the 2–3 guided sessions (Session 1: PACTA story; Session 2: TRISK + Scenario Builder; Session 3: outputs, intake preview, real-data proposal handoff), each mapped to dashboard pages and deck slides.
- [ ] TASK-03-05: Add/extend tests: analytics helper is a no-op without its env var (unit test), home page renders (extend `dashboard/tests/test_smoke.py`).

**Files / Surfaces**
- `dashboard/app.py` - home-page tour rework
- `dashboard/lib/branding.py`, new `dashboard/lib/analytics.py` - page-frame hook + analytics
- `dashboard/pages/*.py` - disclaimer/copy pass
- `dashboard/tests/test_smoke.py`, new `dashboard/tests/test_analytics.py` - coverage
- `pilot/session_scripts.md` - guided-session talk tracks

**Dependencies**
- PHASE-01; TASK-03-04 references PHASE-02 documents (write it after TASK-02-03 exists or stub the reference).

**Exit Criteria**
- [ ] Home page presents the ordered evaluation tour with working page links; no developer-facing copy remains.
- [ ] Analytics pings fire on page load when configured and are provably absent when not; no PII in payloads.
- [ ] All pages show correct disclaimers; full pytest suite passes.

**Phase Risks**
- **RISK-03-01:** Third-party analytics domain in a bank user's network tab looks like tracking. Mitigation: keep the payload to page-slug + timestamp only, document it in the Methodology page's transparency note, and keep the env-var kill switch.

### PHASE-04 - Pipeline Automation (Idea 2)
**Goal**
Replace the hand-cranked snapshot copy with a one-command orchestrator plus CI, and surface data freshness in the app — the "operated, not hand-cranked" impression.

**Tasks**
- [ ] TASK-04-01: Write `scripts/pipeline_refresh.R`: runs the chain in order (`trisk_prepare_inputs.R` → `trisk_power_demo.R` → `trisk_sector_demo.R` for cement and steel → `trisk_scenario_grid.R` → `sector_prioritization.R` → `refresh_dashboard_data.R`), fails fast on any step, and logs per-step timing. (Confirm during implementation whether `pacta_vietnam_scenario.R` outputs also need regeneration or are static inputs.)
- [ ] TASK-04-02: Emit `dashboard/data/pipeline_manifest.json` from the orchestrator: run timestamp, git SHA, per-step status, output row counts per snapshot file.
- [ ] TASK-04-03: Add a "Data as of" badge: loader in `dashboard/lib/loaders.py` reads the manifest; `branding.py` renders the badge on every page via `apply_page_frame`; graceful fallback when the manifest is missing.
- [ ] TASK-04-04: Set up renv for the R pipeline (`renv.lock` at repo root) if not already present, so CI restores are deterministic and cacheable.
- [ ] TASK-04-05: Create `.github/workflows/refresh.yml`: manual `workflow_dispatch` + weekly `schedule`; restores R deps with renv caching (or a rocker container — decide by CI runtime), runs `Rscript scripts/pipeline_refresh.R`, and commits refreshed `dashboard/data/` + manifest per Grill Me Q-001 (default: direct commit to `main`).
- [ ] TASK-04-06: Add `dashboard/tests/test_manifest.py`: manifest schema validation and badge fallback behavior.

**Files / Surfaces**
- `scripts/pipeline_refresh.R` (new) - orchestrator
- `dashboard/data/pipeline_manifest.json` (new, generated) - freshness metadata
- `dashboard/lib/loaders.py`, `dashboard/lib/branding.py` - badge
- `renv.lock` (new if absent), `.github/workflows/refresh.yml` (new) - CI
- `dashboard/tests/test_manifest.py` (new) - coverage

**Dependencies**
- PHASE-01 (snapshot provenance settled first, so the orchestrator's first run is the new canonical baseline)

**Exit Criteria**
- [ ] `Rscript scripts/pipeline_refresh.R` reproduces the committed snapshots end-to-end locally (byte-identical or explained diffs).
- [ ] Badge shows the manifest date on every dashboard page; app still boots if the manifest is absent.
- [ ] The GitHub Actions workflow completes green on manual dispatch and lands a snapshot commit; cached run finishes in acceptable time (<~20 min).

**Phase Risks**
- **RISK-04-01:** Nondeterministic pipeline output (RNG in synthetic data generation) makes every CI run a spurious diff. Mitigation: audit for `set.seed()` in every stochastic step before enabling the schedule; if outputs still churn, make CI skip the commit when only noise-level diffs exist.
- **RISK-04-02:** renv restore exceeding CI limits. Mitigation: `actions/cache` on the renv library keyed to `renv.lock`; fall back to a prebuilt rocker image if restore stays >30 min.

### PHASE-05 - Bilingual Client Documents
**Goal**
Ship Vietnamese reference translations of the key client-facing documents — a strong signal for VN bank stakeholders at near-zero cost.

**Tasks**
- [ ] TASK-05-01: Build a VN financial-terminology glossary (`pilot/vn_glossary.md`) covering PACTA/TRISK/credit-risk terms, seeded from `intake/templates/README_vi.md` (existing VN text) and Decision 263 terminology in `docs/bidv_decision263_mapping.md`.
- [ ] TASK-05-02: Translate `pilot/loanbook_data_spec.md` → `pilot/vn/loanbook_data_spec_vi.md` using the glossary; label prominently "bản dịch tham khảo — bản tiếng Anh là bản chính" (reference translation — English prevails).
- [ ] TASK-05-03: Translate the evaluation guide content (home-page tour narrative + `pilot/session_scripts.md` participant-facing parts) → `pilot/vn/evaluation_guide_vi.md`, same labeling.
- [ ] TASK-05-04: Translate the real-data phase proposal → `pilot/vn/real_data_phase_proposal_vi.md`, preserving all `{{...}}` tailoring slots untranslated.
- [ ] TASK-05-05: Render VN documents to HTML in `pilot/rendered/vn/` matching the EN styling; verify Vietnamese diacritics render correctly in the HTML output (font/charset check).

**Files / Surfaces**
- `pilot/vn/` (new), `pilot/vn_glossary.md` (new) - translations
- `intake/templates/README_vi.md`, `docs/bidv_decision263_mapping.md` - terminology sources
- `pilot/rendered/vn/` - client-shareable HTML

**Dependencies**
- PHASE-02 (source documents), PHASE-03 (evaluation-guide content)

**Exit Criteria**
- [ ] All three VN documents exist, carry the reference-translation label, keep tailoring slots intact, and render with correct diacritics.
- [ ] Glossary terms are used consistently across all three documents (spot-check pass).

**Phase Risks**
- **RISK-05-01:** AI-only financial Vietnamese contains an embarrassing term error in front of bank risk staff. Mitigation: the glossary anchors the risky vocabulary to existing human-written VN sources (`README_vi.md`, Decision 263 terms); the reference-translation label sets expectations.

## Verification Strategy
- **TEST-001:** `python -m pytest dashboard/tests` green after every phase (PHASE-01 baseline; extended by test_analytics, test_manifest, test_smoke changes).
- **TEST-002:** `Rscript scripts/pipeline_refresh.R` runs clean locally and reproduces committed snapshots (PHASE-04 exit gate).
- **MANUAL-001:** Full unsupervised-user walkthrough: open the deployed public app cold, follow the home tour end-to-end on every page with operator flags off, confirming no developer copy, broken states, or missing disclaimers (closes PHASE-03).
- **MANUAL-002:** Dry-run prospect tailoring: fill all slots for a fictional bank using `pilot/tailoring_checklist.md`, timing the exercise (<1 hour target, closes PHASE-02).
- **OBS-001:** After deploy, confirm analytics events arrive for each page and contain no PII; confirm the CI workflow's scheduled run lands a snapshot commit and the live badge date updates.

## Risks and Alternatives
- **RISK-001:** Streamlit Community Cloud outage or cold-start sluggishness during the bank's open-access window undermines the "operated" impression. Mitigation: keep-warm ping (the analytics endpoint check or an uptime monitor), and a fallback plan to demo from a local run in guided sessions.
- **RISK-002:** Scope creep from PROGRESS.md's old open items (bilingual full report, borrower heatmap, three-scenario side-by-side) leaking into this push. Mitigation: PHASE-01's sweep explicitly closes or defers each; anything live must displace something in this plan, not extend it.
- **ALT-001:** Auth-gated pilot access (shared password or OAuth) — rejected per brainstorm DEC-005: synthetic data isn't sensitive and friction suppresses exploration.
- **ALT-002:** Full dashboard VN i18n — rejected per DEC-007; documents deliver better credibility-per-effort for risk staff who read documents more than dashboards.
- **ALT-003:** Skipping CI and keeping a local-only orchestrator — rejected by user choice (brainstorm DEC-008); CI is wanted despite the R-caching cost, mitigated via renv caching/rocker.

## Grill Me
1. **Q-001:** Should the GitHub Actions refresh workflow commit regenerated snapshots directly to `main` (auto-deploying the public app) or open a PR for review?
   - **Recommended default:** Direct commit to `main` on manual dispatch + weekly schedule — data is synthetic and deterministic, and auto-deploy reinforces the "operated" impression.
   - **Why this matters:** Determines TASK-04-05's final step and whether a bad run can reach the live pilot app unreviewed.
   - **If answered differently:** PR mode adds a review gate: the workflow opens a PR, the badge lags until merge, and PHASE-04's exit criteria gain a "merge the refresh PR" step.
2. **Q-002:** Which mechanism for anonymous page-view analytics — a hosted counter (GoatCounter-style pixel/endpoint) or in-app logging to Streamlit Cloud logs?
   - **Recommended default:** Hosted counter behind an env var (silently disabled when unset) — Streamlit Cloud logs are ephemeral and unaggregatable.
   - **Why this matters:** Shapes TASK-03-02's implementation and whether a third-party domain appears in bank users' network traffic (RISK-03-01).
   - **If answered differently:** In-app logging removes the third-party domain but forfeits reliable engagement numbers before the closing conversation; TASK-03-02 becomes a structured-log write plus a manual log-scrape step.
3. **Q-003:** For PHASE-01's deck pruning, is `present/bank_prospect_deck.pptx` or `bank_prospect_deck_v2.pptx` the canonical version to keep front-and-center?
   - **Recommended default:** Inspect both and keep whichever the final QA phase (commit 16f8c50 "FINAL") actually blessed; archive the others.
   - **Why this matters:** The session scripts (TASK-03-04) and tailoring checklist (TASK-02-04) must reference one canonical deck.
   - **If answered differently:** Only the archive step's file list changes.

## Suggested Next Step
Answer the three Grill Me questions (defaults are safe), then begin PHASE-01; each phase ends with a green `pytest` run and a commit, per the repo's verification-before-done standard.
