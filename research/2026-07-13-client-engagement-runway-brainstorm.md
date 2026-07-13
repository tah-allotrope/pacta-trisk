---
title: "Client Engagement Runway: From Rehearsed Intake to Deliverable Engagements"
date: "2026-07-13"
type: "brainstorm"
depth: "thorough"
source_request: "Analyze current state and brainstorm what takes pacta-trisk to the next level"
slug: "client-engagement-runway"
predecessor: "research/2026-07-10-real-data-readiness-and-hardening-brainstorm.md"
---

# Brainstorm: Client Engagement Runway

## Where the project stands (2026-07-13)

The 2026-07-10 hardening plan is **fully executed** (commits `1c7739a` → `ff6dec9`). Verified in the working tree today:

- Refresh automation is live and proven: `pipeline_refresh.R` runs green, `dashboard/data/pipeline_manifest.json` reports `status: ok` with 8 steps (incl. the audit step), weekly CI auto-commit is gated by tests.
- Snapshot diet done: `dashboard/data/` is **3.0 MB** (was ~108 MB); root `README.md` + `NOTICE.md` exist.
- Reproducibility rails exist: `renv.lock`, root `tests/testthat/` (golden numbers, snapshot contract, manifest, intake fixture), `.github/workflows/ci.yml` (pytest + testthat).
- The real-data path is rehearsed at the intake layer: dirty 40-row SDB fixture → 17 errors detected → validation report HTML → `--anonymize` pseudonym map (`pilot/rehearsal_log.md`).
- Private-instance delivery shipped: `dashboard/lib/auth.py` dormant password gate, `docs/private-instance-deploy.md`, per-refresh audit report (`scripts/generate_refresh_audit.R`).

**The one promise still not demonstrable:** the proposal's milestone "PACTA + TRISK results delivered" (`pilot/real_data_phase_proposal.md` §4). The rehearsal log's own verdict names it: *"The remaining gap is the full PACTA/TRISK downstream run on the normalized fixture loanbook, which requires parameterizing the pipeline scripts."* The platform has **never run analytics on any loanbook except the hand-built MCB CSVs**. `scripts/pacta_vietnam_scenario.R` is a 1,385-line monolith with hardcoded `data/vietnam_*.csv` inputs, hardcoded `synthesis_output/vietnam/` outputs, MCB-branded report text, and no `commandArgs` handling (verified: it is absent from the list of arg-parsing scripts). The TRISK chain inherits the same fixed paths.

**Thesis:** the next level is the *client engagement runway* — make "run the whole platform on a new bank's normalized loanbook, produce their private deliverables, in one command" a demonstrated capability, and close the two hard external dependencies (real ABCD data, automotive TRISK) that a signing bank will hit in week one. Everything else is polish behind that.

---

## Theme 1 — One-command client engagement run (P0, the centerpiece)

This subsumes the deferred C4 (shared R core), C5 (config centralization), and the rehearsal's deferred downstream leg in one coherent move. Doing them separately would touch the same 3,100 lines twice.

- **T1.1 Engagement workspace convention.** Introduce `engagements/<bank-slug>/` containing `engagement_config.yml` (bank name, loanbook path, ABCD path, scenario selection, sectors in scope, anonymization on/off, output root) plus per-engagement `output/` and `reports/`. The synthetic MCB demo becomes just the default engagement (`engagements/mcb-demo/` or config defaults preserving today's paths byte-for-byte), keeping the golden-number tests and public snapshot untouched.
- **T1.2 Extract the shared R core into `R/`.** The three PACTA scripts (`pacta_demo.R` 532 ln, `pacta_synthesis.R` 1,196 ln, `pacta_vietnam_scenario.R` 1,385 ln) triplicate load→match→prioritize→target→plot→report logic; the HTML toolkit (`img_to_base64`, CSS, section builders) is copy-pasted across six generators; TRISK sector metadata lives in two hand-synced tribbles (`trisk_sector_demo.R`, `refresh_dashboard_data.R`). Extract: `R/pacta_core.R`, `R/report_toolkit.R`, `R/matching.R`, `R/sector_registry.R`, sourced by thin per-stage scripts. Retire `pacta_demo.R` and `pacta_synthesis.R` to an `attic/` (or delete — they exist only as methodology references; the r2dii demo reports in `reports/` already capture that).
- **T1.3 Parameterize the pipeline end-to-end.** `pacta_vietnam_scenario.R` (renamed `run_pacta.R`), `trisk_prepare_inputs.R`, `trisk_sector_demo.R`, `trisk_scenario_grid.R`, `sector_prioritization.R`, `engagement_scoring.R`, and the letter/disclosure generators all read the engagement config instead of literals. Bank name flows into report headers via one variable (today "Mekong Commercial Bank" is baked into chart titles and HTML copy).
- **T1.4 `scripts/run_engagement.R` orchestrator.** One command: intake validate+map (+ optional anonymize) → validation report → PACTA → TRISK per in-scope sector → prioritization → engagement scoring → letters + disclosure pack → private snapshot directory ready for `docs/private-instance-deploy.md`. Writes an engagement-scoped manifest (mirroring `pipeline_manifest.json`) so the private instance's freshness badge works. Reuse `pipeline_refresh.R`'s step-runner pattern rather than inventing a second one.
- **T1.5 Complete the deferred rehearsal leg.** Run the SDB fixture's `normalized_loanbook.csv` through T1.4 for real (no disposable clone — the parameterization makes ASM-007 obsolete). Append results + timings to `pilot/rehearsal_log.md` and fill the proposal's milestone table with measured turnaround numbers. Expected friction (record, then fix): SDB counterparties matching against the *MCB-designed* ABCD, sectors with zero matched loans crashing plot code, grid runtime per sector on a second book.
- **T1.6 Second-book regression fixture.** Freeze the SDB run's key outputs as a second golden-number test set so the parameterization can never silently regress into "works only for MCB" again. Keep MCB goldens as-is.

Risk: this is the largest refactor the repo has attempted, touching every published number. Mitigation is already in place — the golden-number suite plus snapshot-contract tests were built for exactly this; refactor under green tests, byte-identical MCB outputs as the acceptance bar (chart PNGs may differ in metadata; compare CSVs numerically).

## Theme 2 — Close the hard external dependencies (P1, decision-critical)

Two things a signed engagement hits in week one that no amount of code fixes:

- **T2.1 Real ABCD sourcing decision brief** (deferred D5, still unwritten — verified no doc mentions Asset Impact licensing terms). A real loanbook must match against *real* asset-based company data; `data/vietnam_abcd.csv` is synthetic and MCB-shaped. Write `docs/abcd_sourcing_decision.md`: Asset Impact (AI) license — cost, Vietnam coverage by sector, lead time — vs. self-collected (EVN/GENCO annual reports, Global Energy Monitor coal/gas/steel trackers, VNSTEEL/VICEM disclosures) vs. hybrid (AI for power, self-built for cement/steel). Include a per-sector coverage estimate and a recommendation. This is research, not code, and it unblocks the commercial conversation *before* a bank asks.
- **T2.2 ABCD intake contract.** `intake/SCHEMA.md` covers only the loanbook. Define the minimum ABCD columns + validation for the case where the bank or a data partner supplies company data, mirroring the loanbook contract (template, validator extension in `intake_validate_and_map.R` or a sibling script, Vietnamese README).
- **T2.3 Scenario/benchmark versioning.** PDP8 anchors, NDC targets, and NZE pathways are frozen 2023-vintage interpolations inside `data/generate_vietnam_data.R`. Real engagements will span scenario updates (PDP8 revision is expected). Move scenario anchor points into versioned CSVs under `data/scenarios/<version>/` referenced by the engagement config, so "which scenario vintage produced this number" is answerable — the audit report can then record it.

## Theme 3 — Methodology objection-closers (P1, scoped to known holes)

All four were explicitly deferred by the hardening plan's out-of-scope list and remain open (verified: `engagement_scoring.R:149` still emits `"N/A - sector not in TRISK pilot"` for automotive):

- **T3.1 Automotive TRISK.** VinFast/THACO carry the demo's best alignment story yet show "Not assessed" in TRISK, letters, and composite scores (`composite_partial = TRUE`). The sector-aware runner + grid infra make this mostly data prep (market-share shock analogous to power, per `docs/trisk_multisector_contract.md`). Closes the last visible sector hole; removes the `composite_partial` caveat from the engagement page.
- **T3.2 Dung Quat LNG zero-baseline fix.** Known-open since April; the pre-commissioning asset produces NA sensitivity rows in shipped outputs. Backfill first-operating-year baseline in `trisk_prepare_inputs.R` or exclude with an explicit modeled-limitation note — NAs in client-visible tables are the worst of the three options.
- **T3.3 Power 2025-NA backfill.** Generator-level fix in `data/generate_vietnam_data.R` so the techmix panel stops rendering empty 2025 bars.
- **T3.4 Steel coverage honesty pass.** ~4% synthetic match coverage makes steel outputs decorative. Enrich the synthetic steel book (the demo should model what a *good* engagement looks like) and promote the coverage threshold into the steel views as a reusable pattern — real books will have low-coverage sectors too, and "below reporting threshold" handling becomes an engagement feature, not a demo apology.

## Theme 4 — Pilot-facing product polish (P2)

- **T4.1 Vietnamese dashboard toggle.** DEC-007 kept the app English with bilingual docs. For a *Vietnamese bank's* private instance this is the single most visible polish item. Scope it honestly: a `lang=vi` string table for page titles, nav, KPI labels, and disclaimers (not chart internals) covers the walkthrough-meeting need at ~10% of full i18n cost.
- **T4.2 Scenario Builder persistence.** Saved scenarios die with `st.session_state`; deep-link query params already exist — add "copy shareable link" + optional file-based save. Cheap, and it converts workshop sessions into artifacts.
- **T4.3 PDF export.** Banks circulate PDFs internally; the validation report, disclosure pack, and audit report are HTML-only. A print-CSS pass + documented browser print recipe (or `pagedown`) is the low-tech answer; avoid heavyweight deps.
- **T4.4 Test the untested dashboard surface.** Pages 6/7 smoke tests, chart helpers, zip builders; derive the grid-size assertion from `grid_meta.json` instead of the hardcoded 243 in `test_loaders.py`; import Scenario Builder helpers instead of reimplementing them in `test_scenario_builder.py`.
- **T4.5 Reports page lazy-load.** Four ~350 KB inline iframes; gate behind expanders/buttons.

## Theme 5 — Commercial completeness (P2–P3)

- **T5.1 Pricing scaffold.** `{{PRICING_AND_TERMS_PLACEHOLDER}}` remains blank. Even without final numbers, draft the *structure* (fixed-fee intake+validation, per-sector analysis modules, private-instance hosting, workshop add-on) so proposals can be tailored in minutes. Content decision belongs to the owner; the scaffold doesn't.
- **T5.2 Recorded walkthrough.** A 5-minute screen recording of the public app following `docs/demo-script.md` — an async sales asset that survives scheduling failures with bank contacts.
- **T5.3 Engagement-level executive summary generator.** One page: coverage, top-3 gaps, top-5 stress borrowers, recommended next steps — the artifact a risk head forwards to a CRO. Trivial once T1.4 exists (it's a report over the engagement manifest + outputs).

## Theme 6 — Deferred-and-stays-deferred

- `targets` pipeline migration (still not worth a rewrite of a working 8-step runner at this scale).
- Multi-tenant SaaS / real auth (per-client stamped private instances cover the first engagements; ALT-002 reasoning holds).
- Git history rewrite / LFS (clone size not a complaint; forward-looking ignores are in place).
- New sectors beyond the existing four (oil & gas, aviation) — no Vietnamese-bank pull yet.
- Borrower-level SDA for cement/steel — real methodology work; do it inside a paid engagement.

---

## Recommended sequencing

| Sprint | Contents | Outcome |
|---|---|---|
| 1 (1–2 wks) | T1.1–T1.4 | Config-driven engagement pipeline; shared `R/` core; ~2,000 duplicated lines retired; MCB outputs proven byte-identical under green golden tests |
| 2 (days) | T1.5–T1.6, T3.2–T3.3 | SDB fixture runs end-to-end; measured turnaround timings in the proposal; second regression fixture frozen; NA edge cases gone |
| 3 (week) | T2.1–T2.3, T3.1 | ABCD sourcing decision written; ABCD intake contract; scenario versioning; automotive TRISK closes the sector gap |
| 4 (week) | T3.4, T4.1–T4.3, T5.1, T5.3 | Steel coverage pattern; VN toggle; shareable scenarios; PDF path; pricing scaffold; exec summary |
| Opportunistic | T4.4–T4.5, T5.2 | Test coverage, page weight, recorded demo |

**Rationale:** Sprint 1 is the only item that converts the pilot pack from "rehearsed at the intake layer" to "deliverable end-to-end" — and it must come first because Themes 3–5 would otherwise be built against code slated for refactor. Sprint 2 cashes the rehearsal cheque and hardens against regression. Sprint 3 removes the two dependencies (data sourcing, automotive) that a signed bank hits in week one. Sprint 4 is what makes the private instance feel finished in a Vietnamese boardroom.

## Assumptions adopted (orchestrator unavailable)

- **ASM-A:** The business objective stands (convert a Vietnamese bank prospect into a paid real-data pilot); delivery capability outranks analytics breadth.
- **ASM-B:** Refactor-under-golden-tests with byte-identical MCB CSV outputs is the acceptance bar for Theme 1; chart PNGs compared visually, not byte-wise.
- **ASM-C:** `pacta_demo.R` / `pacta_synthesis.R` are retired in Theme 1 (superseded methodology references; their reports remain in `reports/`). If a reason to keep them emerges, they move to `attic/` untouched rather than being parameterized.
- **ASM-D:** Engagement configs are YAML read via `yaml::read_yaml` (already a transitive dep through the R stack; verify before adding).
- **ASM-E:** VN toggle scope is chrome-only (titles/nav/KPI labels/disclaimers), not chart internals or generated reports (DEC-007's docs-only compromise extends to generated artifacts).
- **ASM-F:** Pricing *numbers* remain the owner's call; only the structure ships (T5.1).

## Out of scope

- Real bank data execution (still requires a signed engagement; fixtures only).
- Any change to the public app's synthetic-data disclaimers (CON-001 posture unchanged).
- Upstream package changes (r2dii.*, trisk.model pinned via `renv.lock`).
- Kubernetes/VM hosting builds — `docs/private-instance-deploy.md`'s Streamlit Cloud recipe stands until a client's infosec rejects it.

## Suggested next step

Run `/plan client-engagement-runway` scoped to Sprints 1–2 (engagement-config refactor + SDB end-to-end run), with Sprint 3 as a follow-on plan once the parameterized pipeline is proven on the second book.
