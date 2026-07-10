---
title: "Real-Data Readiness & Platform Hardening"
date: "2026-07-10"
type: "brainstorm"
depth: "thorough"
source_request: "Analyze current state and brainstorm what takes pacta-trisk to the next level"
slug: "real-data-readiness-and-hardening"
predecessor: "research/2026-07-04_bank-pilot-conversion-push-brainstorm.md"
---

# Brainstorm: Real-Data Readiness & Platform Hardening

## Where the project stands (2026-07-10)

The platform is **demo-complete and sales-packaged**. Since April: multisector TRISK (power/cement/steel), 243-cell scenario grid + Scenario Builder, engagement/disclosure output layer, BYOL Intake Wizard, BIDV advisory report, bank-prospect pitch deck, and — as of commit `e14cd84` (Jul 4) — the full pilot conversion pack (`pilot/`), self-explore dashboard tour, anonymous analytics, `scripts/pipeline_refresh.R` orchestrator, weekly GitHub Actions refresh, and bilingual VN documents. All three ideas from `research/future_planning_ideas.md` are implemented.

**The commercial artifacts now sell something the platform has never done.** `pilot/real_data_phase_proposal.md` promises a real-data phase: loanbook intake per spec, validation report returned to the bank, PACTA + TRISK on their book, private access-controlled dashboard instance, defined turnaround milestones. None of that path has been exercised end-to-end. Meanwhile the July 4 automation was committed **without ever being run** (no local R at the time), the analytics/freshness plumbing is dormant, and the engineering substrate (no R tests, no lockfile, ~3,100 lines of triplicated PACTA logic, 108 MB dashboard snapshot) is fine for a demo but a liability the day a signed engagement starts a clock.

**Thesis:** the next level is closing the gap between what the pilot pack promises and what the repo can actually deliver — verified automation, a rehearsed real-data delivery path, and an engineering base that survives a paying client's scrutiny. Analytics breadth stays third priority, pulled forward only where it defuses a predictable bank objection (automotive TRISK).

---

## Theme A — Activate & verify what's already built (P0, days)

The July 4 push shipped several implemented-but-dormant capabilities. Cheapest credibility wins available:

- **A1. Run the refresh pipeline once, for real.** `scripts/pipeline_refresh.R` and `.github/workflows/refresh.yml` have never executed (commit message admits it). Trigger `workflow_dispatch`, fix whatever breaks (likely candidates: the `R_LIBS_USER`/`trisk.model` load hack in `trisk_sector_demo.R:22-23` on Ubuntu, package install drift in `scripts/ci/install_deps.R`), and let it commit a real `dashboard/data/pipeline_manifest.json`.
- **A2. Fix the "Data as of: unknown" badge.** `data_freshness_badge()` reads `pipeline_manifest.json`, which doesn't exist until A1 succeeds. Right now the public pilot app displays an *anti*-credibility signal — the badge built to say "operated" says "unknown". Follows directly from A1; alternatively commit a manifest from a verified local run first.
- **A3. Stand up the analytics endpoint.** `dashboard/lib/analytics.py` is a no-op until `PILOT_ANALYTICS_ENDPOINT` is set. Register a GoatCounter (or similar) instance and set the secret in Streamlit Cloud — otherwise the "see engagement before the closing call" capability from DEC-010 silently doesn't exist.
- **A4. Orchestrator completeness.** `pipeline_refresh.R` covers only the TRISK chain + prioritization + snapshot. A cold rebuild still requires manually running `data/generate_vietnam_data.R`, `scripts/pacta_vietnam_scenario.R`, and the engagement/disclosure generators in the right order from memory. Add them as (optionally skipped) steps so one command rebuilds the world — this is also the prerequisite for regression testing (Theme C).
- **A5. Fail-loud snapshot.** `refresh_dashboard_data.R:79-94` logs `[MISS]` and continues when expected TRISK files are absent — a partial upstream failure can silently publish a half-populated public app via the auto-committing CI. Make missing expected files a hard error (or mark the manifest `degraded` and have the badge show it).

## Theme B — Repo & deployment diet (P0–P1, days)

A bank-visible public repo and a Community Cloud app both pay for every megabyte:

- **B1. Drop the 2,931 dead grid run CSVs from `dashboard/data/`.** The app reads only the consolidated `borrower_results.parquet` (17–71 KB/sector) + `scenarios.csv`; the per-run CSV trees under `dashboard/data/trisk/grid/*/runs/` are ~100 MB of never-read weight in every clone and Cloud image. Keep raw runs in `synthesis_output/` (or gitignore them entirely and let the grid meta/parquet be the artifact of record). Update `refresh_dashboard_data.R` + `pipeline_refresh.R` file lists accordingly.
- **B2. Defuse the full-ZIP footgun.** `2_TRISK_Risk.py` builds a zip via `TRISK_DIR.rglob("*")` — after B1 this shrinks naturally, but bound it explicitly to the manifest-listed files.
- **B3. Git history diet.** 81 MB of loose objects, never gc'd; four ~7 MB near-duplicate .pptx decks plus a 10.4 MB extensionless `present/ref/Allotrope` blob live in history. Minimum: `git gc`, stop committing new deck variants, and consider moving `present/` binaries to Git LFS or a release asset. (History rewrite is optional and disruptive; assume not worth it unless clone time becomes a real complaint — noted as an assumption.)
- **B4. Root README + LICENSE.** There is no root `README.md` — a prospect's technical diligence lands on a bare directory listing. Write a proper front door: what this is, architecture diagram (data gen → PACTA → TRISK → grid → snapshot → dashboard → outputs), synthetic-data posture, how to run, link map to `pilot/`, `docs/`, `dashboard/`. Add a LICENSE (or an explicit proprietary notice — for a commercial advisory asset, "all rights reserved" notice is the safe default; assumed here).
- **B5. Housekeeping.** Delete `scripts/debug_ms.R` (committed scratch code); flip stale plan frontmatter (`2026-07-04` conversion push and at least four other implemented plans still say `draft` — undermines the tidy-operator impression the hygiene phase paid for); remove dead dashboard code (`charts.pd_change_heatmap`, `image_catalog()`, `ALLotrope_COLORS` typo).

## Theme C — Engineering substrate for a paid engagement (P1, 1–2 weeks)

Everything a staff engineer would flag before trusting this pipeline with a client's loanbook:

- **C1. Pin the R environment with `renv`.** No lockfile exists anywhere; CI installs latest CRAN on every run, so a `dplyr`/`trisk.model` release can silently change published numbers or break the weekly refresh. The conversion-push plan itself assumed caching keyed on `renv.lock` — create it. This also retires the fragile `R_LIBS_USER` load hack.
- **C2. First R tests: golden-number regression.** Zero R tests exist while the pipeline is deterministic and synthetic — the ideal regression fixture. A small `testthat` suite asserting known invariants (177 prioritized matches; 23 engagement borrowers; Nghi Son top stress rank; alignment gaps ±tolerance; expected output file inventory) run in CI *before* the refresh workflow may auto-commit would catch exactly the silent-drift failure mode C1 worries about. This is the single highest-leverage quality investment in the repo.
- **C3. Add a test/lint CI workflow.** Only the refresh workflow exists — the 8-file, ~550-line Python dashboard suite (`48 passed` locally) never runs in CI. A `pytest + ruff` workflow on push is an afternoon of work.
- **C4. Extract the shared R core.** Three PACTA scripts (~3,100 lines) triplicate match→analyze→plot logic; six scripts copy-paste the HTML-report toolkit (`img_to_base64`, CSS, section builders); diacritic-normalize/matching appears four times; TRISK sector metadata is duplicated between `trisk_sector_demo.R` and `refresh_dashboard_data.R` (two tribbles to keep in sync by hand). Extract `R/` modules (report toolkit, matching helpers, sector/config registry) sourced by all scripts — or go one step further to an internal package with `testthat` folded in (C2). Recommended: modules first, package only if C2 grows.
- **C5. Centralize run configuration.** TRISK base params (shock year 2028, discount 0.08…), prioritization weights, sector metadata, snapshot file lists are scattered inline across four scripts. One `config/` YAML (or `config.R`) read by pipeline + refresh + dashboard manifest generation makes client-specific parameterization ({{SCENARIO_SELECTION}} in the proposal!) a config change instead of a code hunt.
- **C6. (Optional, later) `targets` pipeline.** Dependency-aware rebuilds would subsume A4/A5 elegantly, but it's a rewrite of working orchestration — defer until after a first real engagement forces re-run frequency up. Assumption: not now.

## Theme D — Rehearse the real-data delivery path (P1, the strategic centerpiece)

The proposal template commits to a concrete delivery flow. Rehearse it before a bank signs:

- **D1. Full dress rehearsal with an "unseen bank" fixture.** Generate a second synthetic loanbook (different bank, different names, deliberate dirt: bad VSIC codes, missing credit limits, USD rows, un-matchable borrowers) and run the *entire promised flow*: intake spec → Intake Wizard validation → normalized loanbook → PACTA (PDP8/NDC/NZE) → TRISK → engagement scoring → letters + disclosure pack → private report. Time each stage against the proposal's milestone table. Every friction point found here is one not found during a paid engagement. This is the highest-value single exercise available to the project.
- **D2. Client-grade validation report.** The proposal promises "a validation report returned to {{BANK_NAME}} before analysis proceeds." The intake layer emits `validation_errors.csv` + a summary txt — operator artifacts, not a client deliverable. Build a small generator (reuse the HTML toolkit from C4) that renders coverage stats, sector mapping results, match-rate preview, and remediation asks as a branded, shareable HTML/PDF.
- **D3. Private-instance deployment recipe.** The proposal promises "a private, access-controlled dashboard instance." Nothing implements this. Minimum viable: a documented recipe for a password-gated (`st.secrets` + login widget) duplicate Streamlit Cloud app fed from a private repo/branch with the client's snapshot; or a small VM/container deploy. Write `docs/private-instance-deploy.md` and test it once with the D1 fixture. Multi-tenant SaaS remains out of scope (still premature) — this is a per-client stamped copy.
- **D4. Anonymization/pseudonymization module.** `{{ANONYMIZATION_APPROACH}}` is a blank in the proposal with no supporting tooling beyond the disclosure pack's `--anonymize`. Add a documented intake-side option (hash/pseudonymize `counterparty_name` with an operator-held mapping table, per `docs/intake_privacy.md` posture) so the anonymization conversation in the data-spec walkthrough has a concrete default answer.
- **D5. Real ABCD sourcing decision brief.** A real engagement analyzes a real loanbook against *real* asset-based company data — the synthetic `vietnam_abcd.csv` cannot serve. Write a short decision brief on Asset Impact licensing vs. self-collected Vietnam ABCD (EVN/GENCO reports, GEM coal/gas plant trackers) with cost/coverage/timeline, so the commercial conversation doesn't stall on a data dependency discovered late. (Research task, not code.)
- **D6. Reproducibility/audit report.** The one unbuilt piece of `future_planning_ideas.md` Idea 2: a per-run rendered report (input checksums, match coverage, key gaps, top-5 TRISK borrowers, changed-since-last-run diff). For a paid engagement this becomes the audit artifact behind every number a client questions. Fold into the refresh pipeline after A1/C2.

## Theme E — Targeted methodology depth (P2, only what defuses objections)

Repeatedly deferred; pull forward only the items a bank evaluator will predictably raise:

- **E1. Automotive TRISK.** VinFast/THACO show the demo's cleanest alignment story but render "Not assessed" in TRISK, engagement letters, and the composite score (flagged `composite_partial`). It's the visible hole in an otherwise complete four-sector narrative. The sector-aware runner + grid infrastructure make this mostly a data-prep task (market-share shock analogous to power, per the multisector contract).
- **E2. Fix the Dung Quat LNG zero-baseline edge case.** Known-open since April; produces NA sensitivity rows in shipped outputs. Either handle pre-commissioning years in input prep (backfill first-operating-year baseline) or exclude the asset with an explicit modeled-limitation note in the outputs rather than NAs.
- **E3. Steel coverage honesty pass.** ~4% match coverage makes steel outputs decoration; the caveat exists but is easy to miss. Either enrich the synthetic steel book so the demo demonstrates *good* coverage, or promote the caveat into the steel views themselves ("illustrative only — below reporting threshold"). Recommended: enrich — the demo should model what a good engagement looks like.
- **E4. Power 2025-NA cleanup.** Backfill 2025 projected values in the synthetic ABCD so the power techmix panel stops shipping NA bars — pure data-generator fix, removes a recurring "why is this empty?" demo distraction.
- **E5. (Defer) Borrower-level SDA for cement/steel.** Real methodology work with real-data dependencies; keep sector-level with clear disclaimers until a client pays for depth.

## Theme F — Dashboard product polish (P3, opportunistic)

- **F1. Scenario Builder persistence** — saved scenarios die with `st.session_state`; the deep-link query params already exist, so add a "copy shareable link" affordance and/or file-based save.
- **F2. Dashboard VN toggle** — deferred by DEC-007; revisit only if a pilot bank's working language demands it (the docs-only compromise likely holds through the first pilot).
- **F3. Reports page weight** — four ~350 KB inline iframes; lazy-load behind buttons.
- **F4. Test the gaps** — pages 6/7 smoke tests, chart helpers, zip builders; import Scenario Builder helpers into tests instead of reimplementing them (`test_scenario_builder.py` currently duplicates the logic it tests).
- **F5. Un-hardcode the 243** — `test_loaders.py` asserts exactly 243 scenarios; derive from `grid_meta.json` so a lever-range change doesn't break tests spuriously.

---

## Recommended sequencing

| Sprint | Contents | Outcome |
|---|---|---|
| 1 (days) | A1–A3, A5, B1–B2, B5 | Automation proven live; badge + analytics real; snapshot 108 MB → <10 MB |
| 2 (week) | C1–C3, B4, A4 | renv lockfile; golden-number R tests + pytest gating the auto-commit CI; root README |
| 3 (1–2 wks) | D1–D4 | Real-data path rehearsed end-to-end; validation report + private-instance recipe + anonymization default exist |
| 4 (week) | E1–E4, D5–D6, C4–C5 | Automotive TRISK closes the sector gap; audit report; shared R core + config |
| Opportunistic | F1–F5, C6, B3 | Polish as demo feedback dictates |

**Rationale:** Sprint 1 is pure activation of already-paid-for work. Sprint 2 is insurance — the auto-committing weekly CI is currently capable of publishing silently wrong numbers to the public pilot app, and C1+C2 are the cheapest guard. Sprint 3 is the strategic move: the pilot pack's promises become demonstrated capability before any bank tests them. Sprint 4 spends effort only where a bank evaluator will predictably push.

## Assumptions adopted (orchestrator unavailable)

- **ASM-A:** The business objective from the 2026-07-04 brainstorm stands (win a real bank pilot; synthetic pilot → paid real-data phase). This brainstorm therefore optimizes for *delivery readiness* over analytics breadth.
- **ASM-B:** No git history rewrite (B3) — disruptive, and clone size isn't yet a complaint; gc + LFS-for-new-binaries suffices.
- **ASM-C:** Proprietary "all rights reserved" notice rather than an OSS license (commercial advisory asset; note upstream r2dii/trisk packages are themselves open-source and unaffected).
- **ASM-D:** `targets` migration (C6) and multi-tenant SaaS remain deferred; per-client stamped private instances (D3) cover the first engagements.
- **ASM-E:** Grid raw run CSVs are safe to drop from `dashboard/data/` because the app provably reads only the consolidated parquet + scenarios.csv (verified in exploration); raw runs remain reproducible via the grid script.
- **ASM-F:** Dashboard stays English through the first pilot (DEC-007 upheld).

## Out of scope

- Real bank data ingestion *execution* (rehearsal with synthetic fixtures only — real data enters with a signed engagement).
- New sectors beyond the existing four; oil & gas / aviation.
- Methodology changes beyond E1–E4 (no borrower-level SDA, no new scenario sources).
- Pricing/commercial terms content.
- Full i18n of the dashboard.

## Suggested next step

Run `/plan real-data-readiness-and-hardening` scoped to Sprints 1–2 first (activation + safety rails), with Sprint 3 (dress rehearsal) as the follow-on plan once CI is proven green.
