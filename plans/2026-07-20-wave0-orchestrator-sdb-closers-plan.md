---
title: "Wave 0 Completion: Verify Tool, Engagement Orchestrator, SDB Rehearsal + CI/Scaffolding, Data Closers with Deterministic Run IDs"
date: "2026-07-20"
status: "draft"
request: "Wave 0 execution from research/2026-07-20-runway-final-phases-and-beyond-brainstorm.md: N1 verification tool, runway PHASE-03 orchestrator, PHASE-04 SDB rehearsal (+N3 CI, N4 scaffolding), PHASE-05 data closers with N2 deterministic run IDs folded into the golden refreeze"
plan_type: "multi-phase"
research_inputs:
  - "research/2026-07-20-runway-final-phases-and-beyond-brainstorm.md"
  - "research/2026-07-18-runway-completion-and-credibility-brainstorm.md"
  - "plans/2026-07-18-engagement-runway-completion-plan.md"
---

# Plan: Wave 0 Completion — Verify Tool, Engagement Orchestrator, SDB Rehearsal + CI/Scaffolding, Data Closers with Deterministic Run IDs

## Objective

Finish the client-engagement runway so that "run the whole PACTA + TRISK platform on a
new bank's loanbook and produce their private deliverables, in one command" is a
demonstrated, CI-guarded capability. The TRISK core and all downstream generators are
already config-driven (commits `d299496`, `408e95c`); what remains is the
`scripts/run_engagement.R` orchestrator, the synthetic Saigon Delta Bank (SDB)
end-to-end rehearsal with a second frozen golden-test set, and the data closers (ABCD
sourcing brief, ABCD intake schema, scenario versioning, two NA-producing bug fixes).
This plan additionally front-loads a reusable byte-identity verification tool, retires
the known run_id/run_path CSV volatility at the wrapper level, adds an
engagement-scaffolding command, and puts the SDB run into weekly CI.

## Context Snapshot

- **Current state:** A synthetic-data demo platform for a fictional Vietnamese bank
  ("Mekong Commercial Bank", MCB; **all data is synthetic**). R pipeline
  (`scripts/*.R`) → frozen snapshot (`dashboard/data/`) → public Streamlit app.
  `R/trisk_core.R` holds the TRISK prepare/run/grid functions
  (`trisk_prepare_sector_inputs`, `trisk_run_sector`, `trisk_run_grid` + helpers,
  including an already-written, unit-tested but **not yet wired**
  `backfill_zero_baseline()`); `R/prioritization_core.R` holds `prioritize_sectors()`;
  `R/pacta_core.R` holds the PACTA functions. All pipeline scripts are thin CLI
  wrappers that call `cfg <- load_engagement_config(get_config_arg())`
  (`R/engagement_config.R`); no `--config` flag reproduces today's MCB paths exactly.
  The four downstream generators (`scripts/refresh_dashboard_data.R`,
  `scripts/engagement_scoring.R`, `scripts/generate_engagement_letters.R`,
  `scripts/generate_disclosure_pack.R`) are config-driven. The package `pactatrisk`
  0.1.0 loads via `devtools::load_all('.')`. Test state verified 2026-07-20: R suite
  171 passed / 0 failed; Python dashboard suite 58/58 passed.
  **Missing:** `R/step_runner.R`, `scripts/run_engagement.R`,
  `engagements/sdb-rehearsal/` (only `engagements/mcb-demo/` exists),
  `tests/testthat/test_step_runner.R`, `tests/testthat/test_sdb_engagement.R`,
  `docs/abcd_sourcing_decision.md`, `data/scenarios/`, an ABCD section in
  `intake/SCHEMA.md`, `NEWS.md`; package version still 0.1.0. A dirty 40-row SDB
  fixture (`data/fixtures/unseen_bank_loanbook.csv`) has passed intake
  validation/anonymization only — never PACTA/TRISK.
- **Desired state:** `Rscript tools/verify_refactor.R` mechanically enforces the
  byte-identity acceptance bar; `Rscript scripts/run_engagement.R --config
  engagements/<slug>/engagement_config.json --raw-loanbook <csv>` executes intake →
  validation report → PACTA → TRISK → prioritization → snapshot → scoring → letters →
  disclosure into an engagement-scoped tree with its own `pipeline_manifest.json`;
  the SDB fixture runs end-to-end with a second golden-test set and a weekly CI guard;
  `scripts/new_engagement.R` stamps out safe per-engagement configs; the five volatile
  TRISK CSVs are deterministic; scenario inputs are versioned under
  `data/scenarios/pdp8-2023/`; the Dung Quat zero-baseline and power-2025 NA bugs are
  fixed; `docs/abcd_sourcing_decision.md` and an ABCD intake contract exist; the
  package is 0.2.0 with `NEWS.md`.
- **Key repo surfaces:** `R/trisk_core.R` (esp. `execute_trisk_run` ≈ line 721 and
  `write_trisk_demo_outputs` ≈ lines 770–841), `R/prioritization_core.R`,
  `R/pacta_core.R`, `R/engagement_config.R`, `scripts/pipeline_refresh.R` (runner
  logic ≈ lines 62–108), `scripts/intake_validate_and_map.R`,
  `scripts/generate_validation_report.R`, `scripts/generate_vietnam_data.R`,
  `scripts/generate_refresh_audit.R`, `engagements/mcb-demo/engagement_config.json`,
  `data/fixtures/unseen_bank_loanbook.csv`, `intake/SCHEMA.md`,
  `pilot/rehearsal_log.md`, `tests/testthat/`, `.github/workflows/ci.yml`,
  `.github/workflows/refresh.yml`, `DESCRIPTION`, `NAMESPACE`.
  The prior in-repo plan `plans/2026-07-18-engagement-runway-completion-plan.md`
  contains extended rationale for the orchestrator/SDB/closers scope; this plan is
  self-contained but that file is available in the checkout for background.
- **Out of scope:** Automotive TRISK; steel synthetic-book enrichment; multi-scenario
  traffic-light view; executive summary generator; Vietnamese i18n; PDF export;
  `targets`/caching migration; real bank data execution (synthetic fixtures only);
  changes to synthetic-data disclaimers; renaming existing script files; changes to
  engagement-scoring math; changes to the 243-cell grid lever ranges; multi-tenant
  auth; upstream package changes (`r2dii.*`, `trisk.model` stay pinned).

## Environment & Conventions

- **Stack:** R 4.5.2 drives the analytics pipeline via `Rscript`; dependencies pinned
  in `renv.lock` (analysis: arrow, dplyr, fs, ggplot2, ggrepel, jsonlite,
  pacta.loanbook, purrr, r2dii.analysis/data/match/plot, readr, rlang, scales,
  stringi, tibble, tidyr, trisk.model; dev-only: testthat, roxygen2, devtools).
  **`yaml` is deliberately NOT a dependency** — configs are JSON via `jsonlite`.
  Python 3.11+ with Streamlit/pandas/plotly/pytest runs the dashboard.
- **Setup:** R: `Rscript -e "renv::restore()"` (no-renv fallback:
  `Rscript scripts/ci/install_deps.R`). Python:
  `python -m pip install -r dashboard/requirements.txt`. Note `.Rprofile` renv
  auto-activation is commented out for local development.
- **Build / Run:** full MCB pipeline: `Rscript scripts/pipeline_refresh.R` (7 TRISK
  steps + audit; `--full` prepends data generation + PACTA and appends engagement
  scoring + audit, 10 steps + audit). **Always run from the repo root** — every
  script resolves paths via `getwd()`. Windows: prepend
  `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe"` or
  `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"` for the session; Linux/CI: plain
  `Rscript`.
- **Test:** full R suite: `Rscript -e "testthat::test_dir('tests/testthat')"` —
  single file: `Rscript -e "testthat::test_file('tests/testthat/test_trisk_core.R')"`.
  Package harness: `Rscript -e "devtools::test()"`. Python:
  `python -m pytest dashboard/tests` — single:
  `python -m pytest dashboard/tests/test_loaders.py -v`.
- **Conventions & traps:** Loanbook money is raw VND (`loan_size_outstanding`,
  currency literal `VND`, magnitudes 1e5–5e12) — **never rescale**. Vietnamese names
  match after ASCII normalization via `normalize_vn_name()` (`R/matching_helpers.R`);
  CSVs are UTF-8 without BOM. Config convention: scripts source
  `R/engagement_config.R` and call `cfg <- load_engagement_config(get_config_arg())`;
  no `--config` → MCB defaults byte-identical to today. Refactor acceptance bar:
  byte-identical MCB CSV outputs, checked with **autocrlf-aware `git diff`, not raw
  md5sum** (Windows line-ending churn breaks md5 comparison of unchanged files). PNGs
  compare visually only; HTML reports may differ only in generated-timestamp text.
  R files in `R/` must work both `source()`d and package-loaded: keep top-of-file
  `library()` guards, use roxygen `#' @export` tags only, never `@import`/
  `@importFrom`. PowerShell 5.1 has no `&&` — use `;` or the portable
  `Rscript -e "..."` one-liners. `attic/` is retired code — do not touch.
  `dashboard/data/` is written only by `scripts/refresh_dashboard_data.R`.
- **Repo map:**
  - `scripts/` — pipeline stage CLI entrypoints + `pipeline_refresh.R` orchestrator.
  - `R/` — package modules; this plan ADDS `step_runner.R`.
  - `tools/` — (does not exist yet) dev-side verification tooling; ADDED here.
  - `data/` — synthetic MCB inputs + `data/fixtures/unseen_bank_loanbook.csv` (SDB);
    this plan ADDS `data/scenarios/pdp8-2023/`.
  - `output/`, `synthesis_output/` — MCB pipeline outputs (TRISK inputs, PACTA,
    TRISK results, prioritization, engagement outputs).
  - `dashboard/` — Streamlit app + frozen snapshot `dashboard/data/`.
  - `engagements/` — per-engagement configs; this plan ADDS `sdb-rehearsal/`.
  - `intake/` — BYOL schema + templates; `pilot/` — pilot pack incl.
    `rehearsal_log.md`; `tests/testthat/` — R suite (`helper-root.R` walks up to a
    directory containing `dashboard/`).

## Research Inputs

- From `research/2026-07-20-runway-final-phases-and-beyond-brainstorm.md`:
  - Runway PHASE-01/02 are done and byte-identity-verified; PHASE-03..05 remain and
    need no re-planning — only execution intelligence updates.
  - **N1:** both completed phases hand-rolled the same verification (full refresh →
    autocrlf-aware `git diff` → classify drift); codify it as `tools/verify_refactor.R`
    BEFORE the orchestrator phase so every later acceptance check is one command.
  - **N2:** five TRISK CSVs (`company_trajectories_latest.csv`,
    `npv_results_latest.csv`, `params_latest.csv`, `pd_results_latest.csv`,
    `run_catalog.csv`) differ between identical runs only in a `run_id`/`run_path`
    UUID regenerated by `trisk.model::run_trisk()` per invocation (established
    empirically via two back-to-back unmodified baseline runs). Rewrite those columns
    deterministically at write time in `write_trisk_demo_outputs()` (our code), and
    fold the resulting one-time CSV churn into the final phase's already-planned
    golden refreeze so goldens are refrozen exactly once.
  - **N3:** once the SDB rehearsal lands, run the SDB engagement weekly in CI so the
    "works only for MCB" regression guard is continuous.
  - **N4:** add `scripts/new_engagement.R` scaffolding — a hand-typo in
    `snapshot_dir` is exactly the cross-contamination class the orchestrator's guard
    rail exists for.
  - `backfill_zero_baseline()` already exists unit-tested in `R/trisk_core.R`; the
    Dung Quat fix is wiring + rerun + refreeze, not new code.
- From `research/2026-07-18-runway-completion-and-credibility-brainstorm.md` (via the
  in-repo plan `plans/2026-07-18-engagement-runway-completion-plan.md`):
  - The orchestrator chains per-step `Rscript` subprocesses via a shared step runner
    (process isolation preserves failure semantics and bounds memory across TRISK
    runs); package functions remain the substrate the scripts call.
  - The SDB fixture was designed so ~28 clean rows reuse company names present in
    `data/vietnam_abcd.csv` (EVN subsidiaries, VinFast, THACO, VICEM, Hoa Phat,
    Vinacomin), so PACTA matching demonstrably succeeds; 3 rows are deliberately
    unmatchable. Friction found during the SDB run is itself the deliverable — fix
    with inline guards and log them, do not redesign.
  - The intake validator's `normalized_loanbook.csv` has exactly the same 13 columns
    as `data/vietnam_loanbook.csv` — downstream compatibility is by construction.
  - The ABCD sourcing brief is research-only, gates the commercial conversation, and
    has zero code dependencies — start it in parallel, not serially at the end.

## Assumptions and Constraints

- **ASM-001:** Verification tool location — **BINDING DEFAULT:** `tools/verify_refactor.R`
  in a new top-level `tools/` directory (`scripts/` is reserved for pipeline stages).
  Dev-side tooling only: base R + `jsonlite` + `system2("git", ...)`; no new
  `renv.lock` dependency; not exported from the package; not sourced by any pipeline
  script.
- **ASM-002:** Drift classification in the verify tool — **BINDING DEFAULT:** classify
  changed tracked paths by rule, in order: (1) extension `.png` → `png-noise`
  (ignored); (2) extension `.html`, or basename `pipeline_manifest.json`,
  `refresh_audit_metrics.json`, `manifest.csv` → `timestamp-class` (ignored, but
  listed); (3) basename in the volatile list (`company_trajectories_latest.csv`,
  `npv_results_latest.csv`, `params_latest.csv`, `pd_results_latest.csv`,
  `run_catalog.csv`) → `volatile` (ignored, but listed; this list is emptied by
  PHASE-04's N2 fix); (4) anything else → `DRIFT` (fails). Untracked files are
  reported but never fail the check.
- **ASM-003:** Deterministic run-ID scheme (N2) — **BINDING DEFAULT:** in
  `write_trisk_demo_outputs()` (`R/trisk_core.R`), immediately before each
  `readr::write_csv()` of the four `*_latest.csv` files, overwrite the `run_id`
  column with `sprintf("%s_%s", sector, run_label)` (e.g. `"power_base"`,
  `"power_shock_year_2028"`), where `run_label` is the label already used to key
  `run_results` / build `run_catalog`; in `run_catalog.csv`, overwrite `run_path`
  with the same `sprintf("%s_%s", sector, run_label)` string. Apply the identical
  rewrite to any other CSV written by the same function that carries a `run_id`
  column (verify with a grep at execution time — `sensitivity_results.csv` and
  per-run copies are candidates). Never modify `trisk.model` itself, and never
  rewrite `run_id` before the in-memory joins that use it — only at write time.
- **ASM-004:** N2 lands in PHASE-04 (the final phase), in the same commit as the
  golden refreeze — **BINDING DEFAULT:** committed default-mode CSVs and both golden
  sets are refrozen exactly once, covering the NA fixes, scenario-path change, and
  run-ID determinism together. After that commit, remove the volatile list from
  `tools/verify_refactor.R` (set it to `character(0)`).
- **ASM-005:** CI placement for the SDB guard (N3) — **BINDING DEFAULT:** a second
  job `sdb-engagement` in `.github/workflows/refresh.yml` (weekly cadence +
  `workflow_dispatch`), independent of the `refresh` job, that runs the SDB
  engagement from scratch and the SDB golden test, and **commits nothing**. Do not
  add it to `ci.yml` (TRISK runs are minutes-long and would tax every push/PR).
- **ASM-006:** Scaffolder scope (N4) — **BINDING DEFAULT:**
  `scripts/new_engagement.R` writes exactly one file,
  `engagements/<slug>/engagement_config.json`, mirroring the key set of
  `engagements/mcb-demo/engagement_config.json` with all nine `paths` values rooted
  under `engagements/<slug>/`, `inputs` left at MCB defaults (the orchestrator
  overrides the loanbook from intake), `run_grid` `false` unless `--grid` given,
  `anonymize` `false` unless `--anonymize` given. Slug must match `^[a-z0-9-]+$`;
  refuse (non-zero exit) if `engagements/<slug>/` already exists. No template
  directory tree, no README stamping — config only.
- **ASM-007:** SDB committed artifacts — **BINDING DEFAULT:** commit under
  `engagements/sdb-rehearsal/`: `engagement_config.json`,
  `intake/normalized_loanbook.csv`, `output/engagement/engagement_priority.csv`,
  `output/trisk/<sector>_demo/npv_results_latest.csv` and `company_summary.csv` for
  each sector that ran, and `pipeline_manifest.json`. Gitignore all other generated
  content under `engagements/*/` via patterns `engagements/*/snapshot/`,
  `engagements/*/reports/`, `engagements/*/output/**/figures/`,
  `engagements/*/output/engagement_letters/`, `engagements/*/output/disclosure/`.
- **ASM-008:** SDB timing documentation — **BINDING DEFAULT:** append a "Downstream
  run (2026-07)" section to `pilot/rehearsal_log.md`; do NOT edit `{{DATE_n}}`
  placeholders in `pilot/real_data_phase_proposal.md` (a client-tailoring template).
- **ASM-009:** ABCD brief pricing — **BINDING DEFAULT:** where Asset Impact license
  costs are not publicly verifiable, write "to be confirmed with vendor" instead of
  inventing numbers; the brief's deliverable is the decision framework and per-sector
  coverage assessment, not a quote.
- **ASM-010:** Where the power-2025 NA lives — **BINDING DEFAULT:** locate it at
  execution time: run `Rscript scripts/generate_vietnam_data.R`, then inspect
  power-sector 2025 rows in `synthesis_output/vietnam/04_vn_ms_portfolio.csv`
  (projected-value column, `technology` in the power set, `year == 2025`). Backfill
  at the *generator* level (`scripts/generate_vietnam_data.R`) with the same
  interpolation already used for scenario anchors — never a display-side patch.
- **ASM-011:** Package exposure — **BINDING DEFAULT:** tag new public functions
  (`run_steps`, `write_pipeline_manifest`) with roxygen `#' @export`, regenerate
  `NAMESPACE` via `Rscript -e "roxygen2::roxygenise()"`, bump `DESCRIPTION`
  `Version:` to `0.2.0`, create `NEWS.md`. Never add `@import`/`@importFrom`.
- **CON-001:** With no `--config` flag, every script's observable behavior (paths,
  CSV bytes, manifest shape) must remain identical to today — the weekly auto-commit
  CI (`.github/workflows/refresh.yml`, Mondays 02:00 UTC, test-gated), the golden
  tests, and the public app depend on it. The only sanctioned default-mode CSV change
  in this plan is PHASE-04's single refreeze commit (ASM-004).
- **CON-002:** `tests/testthat/test_manifest_json.R` and
  `dashboard/tests/test_manifest.py` pin the default `pipeline_manifest.json` keys,
  step names, order, and counts — the step-runner extraction must not change them.
- **CON-003:** Streamlit Community Cloud has no R runtime; nothing in `dashboard/`
  may gain an R dependency. `dashboard/lib/live_rerun.py` shells out to TRISK scripts
  with today's CLI — all new flags must be additive/optional.
- **CON-004:** Everything bank-visible keeps synthetic/illustrative-data disclaimers;
  SDB outputs are synthetic and must say so ("Saigon Delta Bank" is fictional).
- **DEC-001:** MCB stays the default engagement; `load_engagement_config(NULL)`
  returns MCB defaults; the default pipeline never reads
  `engagements/mcb-demo/engagement_config.json`.
- **DEC-002:** Engagement-scoring composite math stays fixed 50/50 with
  renormalization for TRISK-uncovered sectors — untouched; the
  `"N/A - sector not in TRISK pilot"` behavior stays.
- **DEC-003:** Configs are JSON via `jsonlite::read_json(path, simplifyVector = TRUE)`;
  no `yaml`, no new pipeline dependency.
- **DEC-004:** The orchestrator chains per-step `Rscript` subprocesses via
  `run_steps()` (not in-process function calls) — preserves failure semantics and
  bounds memory across TRISK runs.

## Specification

**Verify-tool decision logic (`tools/verify_refactor.R`):**

1. Parse flags: `--full` (pass `--full` to the refresh), `--skip-refresh` (classify
   the current working tree without running the pipeline).
2. Unless `--skip-refresh`: run
   `system2("Rscript", c("scripts/pipeline_refresh.R", if (full) "--full"))`; abort
   with exit 1 if it returns non-zero.
3. Collect changed tracked files: `system2("git", c("diff", "--name-only"), stdout = TRUE)`
   (git applies `core.autocrlf` normalization, which is why raw md5 comparison is
   wrong on Windows).
4. Classify each path by the first matching rule of ASM-002:
   `png-noise` → ignore; `timestamp-class` → list under "expected churn";
   `volatile` (basename match against the volatile vector) → list under
   "known-volatile (retire in PHASE-04)"; else → `DRIFT`.
5. Print a section per class. If any `DRIFT` paths exist: print
   `DRIFT DETECTED (N files)` and `quit(status = 1)`; else print
   `BYTE-IDENTITY PASS` and exit 0.

**Deterministic run-ID rewrite (N2, ASM-003):** for every output tibble `df` of run
`run_label` in sector `sector` written by `write_trisk_demo_outputs()`:
`if ("run_id" %in% names(df)) df$run_id <- sprintf("%s_%s", sector, run_label)`;
for `run_catalog`: `run_catalog$run_path <- sprintf("%s_%s", sector, run_catalog$run_label)`
(keep the existing `run_label` column unchanged). The rewrite happens after all
in-memory joins/summaries and immediately before `readr::write_csv()`.

**Orchestrator step order (fixed):** intake → validation report → PACTA → TRISK
prepare → TRISK per sector (power first) → grid (only when `cfg$run_grid`) →
prioritization → snapshot → scoring → letters → disclosure. Engagement scoring reads
from the snapshot (`cfg$paths$snapshot_dir/trisk/...`), so it MUST run after the
snapshot step.

## Phase Summary

| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | N1: codified byte-identity verification tool | None | `tools/verify_refactor.R`, `.gitignore` entry, README note |
| PHASE-02 | Orchestrator: `R/step_runner.R`, `scripts/run_engagement.R`, package 0.2.0 | PHASE-01 | Step runner + orchestrator + guard rail, regenerated `NAMESPACE`, `NEWS.md`, `tests/testthat/test_step_runner.R` |
| PHASE-03 | SDB end-to-end rehearsal + second golden fixture + N4 scaffolder + N3 CI guard | PHASE-02 | `engagements/sdb-rehearsal/` artifacts, `tests/testthat/test_sdb_engagement.R`, `scripts/new_engagement.R`, `sdb-engagement` CI job, updated `pilot/rehearsal_log.md` |
| PHASE-04 | Data closers + N2 deterministic run IDs + single golden refreeze | PHASE-03 | `docs/abcd_sourcing_decision.md`, ABCD intake contract, `data/scenarios/pdp8-2023/`, Dung Quat + power-2025 fixes, deterministic run IDs, refrozen goldens |

## Detailed Phases

### PHASE-01 - Byte-Identity Verification Tool (`tools/verify_refactor.R`)

**Goal**
Turn the hand-rolled acceptance check used by the two completed refactor phases into a
one-command tool that every later phase (and every future refactor) runs.

**Tasks**
- [ ] TASK-01-01: Create `tools/verify_refactor.R` implementing the Specification's
  decision logic. Top of file: a commented `VOLATILE_BASENAMES <- c(...)` vector
  containing the five known-volatile basenames, with a comment stating the cause
  (per-invocation `run_id`/`run_path` UUID from `trisk.model::run_trisk()`) and that
  PHASE-04 empties this vector.
- [ ] TASK-01-02: Prove the tool on the untouched tree: from a clean checkout run
  `Rscript tools/verify_refactor.R` (this runs the default 7-step refresh, ~tens of
  minutes) and confirm it prints `BYTE-IDENTITY PASS` with the five volatile files
  listed under known-volatile and the HTML/manifest churn under expected churn. Then
  `git checkout -- .` to discard the churn.
- [ ] TASK-01-03: Documentation: add a short "Refactor acceptance check" paragraph to
  `README.md` (the one command + what PASS means); add `trisk_baseline_run*.txt` to
  `.gitignore` if not already present (legacy baseline files from earlier phases).

**File Changes**
- `tools/verify_refactor.R` (create): the verification tool per TASK-01-01; base R +
  `jsonlite` only.
- `README.md` (modify): add the acceptance-check paragraph; leave everything else.
- `.gitignore` (modify): ensure `trisk_baseline_run*.txt` is listed.

**Function Signatures**
- `classify_path(path: character, volatile_basenames: character) -> character` —
  returns one of `"png-noise"`, `"timestamp-class"`, `"volatile"`, `"drift"` per the
  ASM-002 rule order (single path in, single class out; keep it a pure function at
  the top of the script so it is trivially testable by sourcing the file).

**Test Specs**
- `classify_path("synthesis_output/trisk/power_demo/figures/01_npv.png", VOLATILE_BASENAMES)`
  → `"png-noise"`.
- `classify_path("dashboard/data/pipeline_manifest.json", VOLATILE_BASENAMES)` →
  `"timestamp-class"`.
- `classify_path("dashboard/data/trisk/power/npv_results_latest.csv", VOLATILE_BASENAMES)`
  → `"volatile"`.
- `classify_path("synthesis_output/vietnam/04_vn_ms_portfolio.csv", VOLATILE_BASENAMES)`
  → `"drift"`.
- Integration (TASK-01-02): `Rscript tools/verify_refactor.R` on the untouched tree →
  exit 0, prints `BYTE-IDENTITY PASS`.

**Dependencies**
- None.

**Exit Criteria**
- [ ] `Rscript tools/verify_refactor.R` exits 0 on the untouched tree with the
  documented classification output.
- [ ] `Rscript tools/verify_refactor.R --skip-refresh` after
  `echo x >> synthesis_output/vietnam/01_vn_matched_raw.csv` exits 1 naming that file
  as DRIFT (then restore with `git checkout -- synthesis_output/vietnam/01_vn_matched_raw.csv`).
- [ ] Full R suite still green (tool is dev-side only; nothing sources it).

**Phase Risks**
- **RISK-01-01:** The tool could mask real drift in HTML/manifest files by
  classifying them as timestamp churn. Mitigation: timestamp-class files are always
  *listed* in the output, never silently dropped; a reviewer sees the list on every
  run.

### PHASE-02 - Orchestrator: `R/step_runner.R`, `scripts/run_engagement.R`, Package 0.2.0

**Goal**
One command executes the full delivery flow for any engagement config, writing an
engagement-scoped manifest — reusing (not duplicating) `pipeline_refresh.R`'s runner
logic — and the package exports the new functions at version 0.2.0.

**Tasks**
- [ ] TASK-02-01: Create `R/step_runner.R` by extracting from
  `scripts/pipeline_refresh.R` (lines ≈62–108: `count_rows`, `run_step`, the step
  loop, and manifest assembly — verify exact lines at execution time): `run_steps()`
  executes a list of `list(name, script, args)` via
  `system2("Rscript", c(script, args))`, stops after the first failure;
  `write_pipeline_manifest()` emits the existing manifest JSON shape (`generated_at`
  formatted `%Y-%m-%dT%H:%M:%S%z`, `git_sha`, `steps[{name,status,seconds}]`,
  `status`, `row_counts`) plus optional extra top-level fields. Keep top-of-file
  `library(jsonlite)` guard; roxygen `#' @export` on both functions.
- [ ] TASK-02-02: Refactor `scripts/pipeline_refresh.R` to source `R/step_runner.R`
  and call `run_steps()`/`write_pipeline_manifest()`. Step lists, `--full` flag,
  manifest path `dashboard/data/pipeline_manifest.json`, the six-file
  `snapshot_files` row-count list, and exit behavior stay byte-for-byte compatible
  (CON-002): same JSON keys, same step names/order/counts (7 + audit default; 10 +
  audit `--full`).
- [ ] TASK-02-03: Create `scripts/run_engagement.R` — CLI:
  `Rscript scripts/run_engagement.R --config engagements/<slug>/engagement_config.json [--raw-loanbook <path>] [--skip-intake] [--top-n <int>] [--dry-run]`.
  Step list in the Specification's fixed order, each pipeline step invoked with
  `--config <effective-config-path>`:
  (1) intake — only when `--raw-loanbook` given and `--skip-intake` absent:
  `scripts/intake_validate_and_map.R --input <raw> --output-dir engagements/<slug>/intake`
  plus `--anonymize` when `cfg$anonymize` (flags verified against the script:
  `--input`, `--output-dir`, `--anonymize`); then write
  `engagements/<slug>/engagement_config.resolved.json` — a copy of the loaded config
  with `inputs$loanbook_csv` pointed at
  `engagements/<slug>/intake/normalized_loanbook.csv` — and use THAT path as the
  effective config for all later steps;
  (2) `scripts/generate_validation_report.R --intake-dir engagements/<slug>/intake
  --output <cfg$paths$reports_dir>/Intake_Validation_Report.html --bank-name "<cfg$bank_name>"`
  (flags verified; skipped when intake skipped);
  (3) `scripts/pacta_vietnam_scenario.R`; (4) `scripts/trisk_prepare_inputs.R`;
  (5..) `scripts/trisk_sector_demo.R <sector>` for each of `cfg$trisk_sectors`
  (power first when present); then `scripts/trisk_scenario_grid.R` only when
  `cfg$run_grid`; `scripts/sector_prioritization.R`;
  `scripts/refresh_dashboard_data.R`; `scripts/engagement_scoring.R`;
  `scripts/generate_engagement_letters.R` (append `--top_n <int>` when `--top-n`
  given — note the underscore in the letters script's flag);
  `scripts/generate_disclosure_pack.R`. Manifest →
  `engagements/<slug>/pipeline_manifest.json` via
  `write_pipeline_manifest(..., extra = list(bank_slug = cfg$bank_slug, config_path = <effective path>))`.
  `--dry-run` prints one `name: script args` line per resolved step and exits 0
  without executing or writing anything.
- [ ] TASK-02-04: Guard rail in `run_engagement.R`, checked before any step: if
  `cfg$paths$snapshot_dir == "dashboard/data"` and `cfg$bank_slug != "mcb-demo"`,
  stop with message `Engagement snapshot_dir must not be the public dashboard/data`.
  Print a banner with the effective config path and effective loanbook path before
  step 1.
- [ ] TASK-02-05: Package refresh (ASM-011): regenerate `NAMESPACE`
  (`Rscript -e "roxygen2::roxygenise()"`), bump `DESCRIPTION` to `Version: 0.2.0`,
  create `NEWS.md` with a 0.2.0 entry (TRISK core, prioritization core, engagement
  orchestrator + step runner, verification tool). Verify
  `Rscript -e "devtools::load_all('.'); stopifnot(is.function(run_steps), is.function(write_pipeline_manifest))"`.
- [ ] TASK-02-06: Create `tests/testthat/test_step_runner.R` (Test Specs below) and
  add a "Running a client engagement" subsection to `README.md` with the exact
  command, the `--dry-run` tip, and the Windows PATH note
  (`$env:Path += ";C:\Program Files\R\R-4.5.2\bin"` — `system2("Rscript", ...)`
  needs `Rscript` on PATH even when the outer call used a full path).
- [ ] TASK-02-07: Acceptance: `Rscript tools/verify_refactor.R` → `BYTE-IDENTITY
  PASS` (the step-runner extraction changed nothing observable in default mode).

**File Changes**
- `R/step_runner.R` (create): extracted runner + manifest writer, verbatim logic.
- `scripts/pipeline_refresh.R` (modify): source the runner; observable behavior
  unchanged (same steps, same manifest keys modulo timestamp/sha values).
- `scripts/run_engagement.R` (create): orchestrator per TASK-02-03/04.
- `DESCRIPTION` (modify): `Version: 0.2.0` only. `NAMESPACE` (modify): regenerated.
- `NEWS.md` (create): 0.2.0 entry.
- `tests/testthat/test_step_runner.R` (create).
- `README.md` (modify): engagement-run subsection; leave the architecture diagram
  intact.

**Function Signatures**
- `run_steps(steps: list, stop_on_failure: logical = TRUE) -> list` — executes each
  `list(name: character, script: character, args: character vector)` via
  `system2("Rscript", ...)`; returns per-step
  `list(name, status ("ok"|"failed"), seconds: numeric)`; after a failure no further
  steps run.
- `write_pipeline_manifest(step_results: list, manifest_path: character, row_count_files: character = character(0), extra: list = list()) -> invisible(character)` —
  writes the manifest JSON (existing schema; `extra` entries merged at top level),
  returns the path.

**Test Specs**
- `run_steps(list(list(name="ok", script=<temp .R fixture containing 'quit(status=0)'>, args=character())))`
  → one result with `status == "ok"` and numeric `seconds`.
- Two-step list whose first fixture is `quit(status=1)` → first result `"failed"`,
  second step never executed (result list length 1).
- `write_pipeline_manifest(results, tempfile(fileext=".json"), extra=list(bank_slug="x"))`
  → file parses via `jsonlite::read_json`; `$bank_slug == "x"`; keys `generated_at`,
  `git_sha`, `steps`, `status` all present; `status == "failed"` when any step failed.
- Dry run: `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --skip-intake --dry-run`
  → exit 0, prints the step list (grid step present because MCB has
  `"run_grid": true`; intake and validation-report steps absent), writes nothing
  (`git status --porcelain` unchanged).
- Guard rail: a temp config JSON with `"bank_slug": "x-bank"` and `paths` at MCB
  defaults → `Rscript scripts/run_engagement.R --config <tmp> --dry-run` exits
  non-zero printing the guard message.
- `Rscript scripts/pipeline_refresh.R` → `dashboard/data/pipeline_manifest.json`
  step names/order/count identical to the committed pre-refactor manifest;
  `tests/testthat/test_manifest_json.R` and `dashboard/tests/test_manifest.py` pass
  unmodified.

**Dependencies**
- PHASE-01 (acceptance check tool).

**Exit Criteria**
- [ ] `Rscript tools/verify_refactor.R` → `BYTE-IDENTITY PASS` after the refactor.
- [ ] `--dry-run` produces the documented step list for MCB; the guard rail blocks a
  non-MCB config pointing at `dashboard/data`.
- [ ] `Rscript -e "devtools::load_all('.')"` exposes `run_steps` /
  `write_pipeline_manifest`; full R suite green; `python -m pytest dashboard/tests`
  green.

**Phase Risks**
- **RISK-02-01:** The resolved-config indirection
  (`engagement_config.resolved.json`) confuses debugging. Mitigation: the TASK-02-04
  banner prints the effective config and loanbook paths before any step runs.
- **RISK-02-02:** `dashboard/lib/live_rerun.py` shells out to TRISK scripts with
  today's CLI. Mitigation: nothing in this phase changes those scripts' CLIs; run
  `python -m pytest dashboard/tests/test_live_rerun.py -v` as part of exit criteria.

### PHASE-03 - SDB Rehearsal, Second Golden Fixture, Scaffolder, CI Guard

**Goal**
Run the dirty SDB fixture through the entire engagement flow, fix the zero-match/empty
edge cases it surfaces with small guards, freeze a second golden-number test set, make
engagement-config creation mechanical, and put the SDB run into weekly CI so "works
only for MCB" can never silently return.

**Tasks**
- [ ] TASK-03-01: Create `scripts/new_engagement.R` (N4, ASM-006). CLI:
  `Rscript scripts/new_engagement.R --slug <slug> --name "<Bank Name>" [--sectors power,cement,steel] [--grid] [--anonymize]`.
  Validates the slug against `^[a-z0-9-]+$`; exits non-zero with a clear message if
  `engagements/<slug>/` exists; writes `engagements/<slug>/engagement_config.json`
  with `bank_name`, `bank_slug = <slug>`, `inputs` copied from the MCB defaults,
  `trisk_sectors` from `--sectors` (default `power,cement,steel`),
  `run_grid`/`anonymize` from flags, and all nine `paths` keys
  (`pacta_output_dir`, `trisk_output_root`, `trisk_input_root`, `snapshot_dir`,
  `reports_dir`, `engagement_output_dir`, `letters_output_dir`,
  `disclosure_output_dir`, `prioritization_output_dir`) rooted under
  `engagements/<slug>/` (e.g. `engagements/<slug>/output/pacta`,
  `engagements/<slug>/snapshot`, `engagements/<slug>/reports`, ...).
- [ ] TASK-03-02: Generate the SDB config with the scaffolder:
  `Rscript scripts/new_engagement.R --slug sdb-rehearsal --name "Saigon Delta Bank"`
  (grid off, anonymize off) — this both creates the config and smoke-tests N4.
  Add the ASM-007 `.gitignore` patterns.
- [ ] TASK-03-03: Execute from a clean tree:
  `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --raw-loanbook data/fixtures/unseen_bank_loanbook.csv`.
  Expect failures of the class: PACTA sectors with zero matched SDB loans crashing
  chart/summary code (guard: skip the chart, emit a
  `"no matched exposure in <sector>"` note); TRISK sectors with no mapped companies
  (guard: skip the sector with a logged `[NOTE]` line and mark it unavailable in the
  snapshot manifest); empty letter target lists (guard: write zero letters plus an
  index note). Every guard sits behind an emptiness check the MCB path never enters;
  after each fix, `Rscript tools/verify_refactor.R --skip-refresh` (or the full run
  at phase end) must stay clean and the full default-mode suite green.
- [ ] TASK-03-04: Cross-contamination check immediately after the successful run:
  `git status --porcelain synthesis_output output dashboard/data reports` → empty
  (the SDB run wrote nothing outside `engagements/sdb-rehearsal/`).
- [ ] TASK-03-05: Append the "Downstream run (2026-07)" section to
  `pilot/rehearsal_log.md` (ASM-008): per-step seconds table read from
  `engagements/sdb-rehearsal/pipeline_manifest.json`; every friction point fixed in
  TASK-03-03 with file/line; a verdict sentence replacing the old "remaining gap is
  the full PACTA/TRISK downstream run" statement.
- [ ] TASK-03-06: Commit the SDB artifacts per ASM-007 and create
  `tests/testthat/test_sdb_engagement.R`. Freeze literals FROM THE COMMITTED FILES at
  authoring time (never invent values): assert
  `engagements/sdb-rehearsal/intake/normalized_loanbook.csv` has exactly 13 columns
  and the observed row count; every `loan_size_outstanding_currency == "VND"`;
  `engagements/sdb-rehearsal/output/engagement/engagement_priority.csv` has > 0 rows
  and its rank-1 borrower name equals the observed literal (tolerance ±0.005 on any
  frozen score); `pipeline_manifest.json` has `status == "ok"` and
  `bank_slug == "sdb-rehearsal"`.
- [ ] TASK-03-07: N3 CI guard: add a second job `sdb-engagement` to
  `.github/workflows/refresh.yml` (ASM-005), mirroring the `refresh` job's R setup
  steps (checkout, setup-r 4.5 with public RSPM, apt system deps, setup-renv), then:
  `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --raw-loanbook data/fixtures/unseen_bank_loanbook.csv`,
  then
  `Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"`,
  then `git status --porcelain synthesis_output output dashboard/data reports | tee /dev/stderr | wc -l | grep -qx 0`
  (cross-contamination gate). The job commits nothing. Leave the existing `refresh`
  job untouched.

**File Changes**
- `scripts/new_engagement.R` (create): scaffolder per TASK-03-01.
- `engagements/sdb-rehearsal/engagement_config.json` (create, via scaffolder).
- `engagements/sdb-rehearsal/` committed generated artifacts per ASM-007 (create).
- `.gitignore` (modify): ASM-007 engagement patterns.
- `R/pacta_core.R`, `R/trisk_core.R`, `scripts/generate_engagement_letters.R`
  (modify, only as forced by TASK-03-03): zero-match/empty-sector guards behind
  emptiness checks.
- `pilot/rehearsal_log.md` (modify): append the downstream-run section; existing
  content untouched.
- `tests/testthat/test_sdb_engagement.R` (create).
- `.github/workflows/refresh.yml` (modify): add the `sdb-engagement` job only.

**Function Signatures**
- None — no new package interfaces; the scaffolder is a standalone CLI script and
  guards are inline conditionals in existing functions.

**Test Specs**
- `Rscript scripts/new_engagement.R --slug sdb-rehearsal --name "Saigon Delta Bank"`
  (when the directory does not yet exist) → exit 0;
  `jsonlite::read_json("engagements/sdb-rehearsal/engagement_config.json")` has
  `bank_slug == "sdb-rehearsal"`, `run_grid == FALSE`, and
  `paths$snapshot_dir == "engagements/sdb-rehearsal/snapshot"`.
- Re-running the same scaffolder command → non-zero exit, directory unchanged.
- `Rscript scripts/new_engagement.R --slug "Bad Slug" --name X` → non-zero exit
  (slug regex).
- `Rscript -e "testthat::test_dir('tests/testthat')"` → green including
  `test_sdb_engagement.R` AND the untouched MCB goldens (proves both books coexist).
- `python -c "import json;m=json.load(open('engagements/sdb-rehearsal/pipeline_manifest.json'));print(m['status'],m['bank_slug'])"`
  → `ok sdb-rehearsal`.
- Cross-contamination: `git status --porcelain synthesis_output output dashboard/data reports`
  → empty output.

**Dependencies**
- PHASE-02 (orchestrator).

**Exit Criteria**
- [ ] The SDB `run_engagement.R` invocation exits 0; manifest `status == "ok"`.
- [ ] `test_sdb_engagement.R` green from committed artifacts; full R + Python suites
  green.
- [ ] `pilot/rehearsal_log.md` contains measured per-stage timings and the updated
  verdict.
- [ ] The SDB validation report under `engagements/sdb-rehearsal/reports/` opens in a
  browser with "Saigon Delta Bank" branding and the synthetic-data disclaimer footer.
- [ ] The `sdb-engagement` workflow job passes on a `workflow_dispatch` run of
  `.github/workflows/refresh.yml`.

**Phase Risks**
- **RISK-03-01:** The SDB book's sector mix surfaces divide-by-zero or empty-tibble
  crashes deeper than guards can absorb. Mitigation: guards are permitted; anything
  structural is logged in `pilot/rehearsal_log.md` as a named backlog item for a
  follow-on plan rather than force-fixed here.
- **RISK-03-02:** The CI job doubles the weekly workflow's runtime. Mitigation: SDB
  runs with `run_grid: false` (minutes, not the 243-cell grid); the job is parallel
  to `refresh`, not serial.
- **RISK-03-03:** Fixture outputs mistaken for a real bank's. Mitigation: "Saigon
  Delta Bank" is fictional; CON-004 disclaimers must render in the validation report
  and disclosure pack (verify visually).

### PHASE-04 - Data Closers, Deterministic Run IDs, Single Golden Refreeze

**Goal**
Close the two week-one external dependencies of a real engagement (ABCD sourcing
decision, ABCD intake contract), make scenario vintages explicit and auditable, fix
the two known NA-producing bugs, make the five volatile TRISK CSVs deterministic —
then refreeze goldens exactly once for all of it.

**Tasks**
- [ ] TASK-04-01: Write `docs/abcd_sourcing_decision.md` (~2–3 pages): the problem (a
  real loanbook must match against real asset-based company data;
  `data/vietnam_abcd.csv` is synthetic and MCB-shaped); Option A — Asset Impact
  license (per-sector Vietnam coverage: power/automotive strong, cement/steel
  partial; cost per ASM-009; lead time); Option B — self-collected (EVN/GENCO annual
  reports, Global Energy Monitor coal/gas/steel plant trackers, VNSTEEL/VICEM
  disclosures; per-sector effort estimate; GEM licensing/attribution constraints);
  Option C — hybrid (license power/automotive, self-build cement/steel). Include a
  per-sector coverage table, a recommendation (hybrid unless the engagement is
  power-only), and the trigger point ("decide before signing the data-phase start
  date in any real proposal"). **No code dependency — may be written at any point
  during this plan, including in parallel with PHASE-01.**
- [ ] TASK-04-02: ABCD intake contract: append an "ABCD (asset-based company data)
  table" section to `intake/SCHEMA.md` mirroring the loanbook contract's style —
  required columns matching `data/vietnam_abcd.csv`'s actual header (open the file
  and document each column's type and units) plus provenance columns `data_source`
  (character) and `as_of_year` (integer year). Create
  `intake/templates/abcd_template.csv` (header + 3 illustrative synthetic rows) and
  add one line naming it to the templates README (`ls intake/templates/` to find the
  README that exists there and edit that one).
- [ ] TASK-04-03: Scenario versioning: create `data/scenarios/pdp8-2023/` containing
  copies of `data/vietnam_scenario_ms.csv` and `data/vietnam_scenario_co2.csv`;
  change `R/engagement_config.R` defaults `inputs$scenario_ms_csv` /
  `inputs$scenario_co2_csv` to the versioned paths; update
  `engagements/mcb-demo/engagement_config.json` and any test literal asserting the
  old default paths (check `tests/testthat/test_engagement_config.R`). Keep
  `scripts/generate_vietnam_data.R` writing BOTH the legacy `data/` paths and the
  versioned dir (one extra `readr::write_csv` each). Record the two scenario file
  paths + md5 checksums in the refresh audit (`scripts/generate_refresh_audit.R`:
  add them to the metrics JSON and audit HTML). Add a "Scenario vintages" note
  (directory convention `data/scenarios/<source>-<year>/`) to `README.md`. Add to
  `tests/testthat/test_snapshot_contract.R`:
  `expect_identical(unname(tools::md5sum("data/vietnam_scenario_ms.csv")), unname(tools::md5sum("data/scenarios/pdp8-2023/vietnam_scenario_ms.csv")))`.
- [ ] TASK-04-04: Dung Quat zero-baseline fix: wire the existing, already-unit-tested
  `backfill_zero_baseline()` (in `R/trisk_core.R`) into the TRISK input-prep path
  where per-asset production/capacity trajectories are assembled
  (`trisk_prepare_sector_inputs`), so an asset whose baseline-year value is 0
  (pre-commissioning — "Dung Quat LNG Power Consortium", id `VN_ABCD_006`) gets its
  baseline backfilled from the first non-zero year with a
  `baseline_note = "backfilled_first_operating_year"` column; assets with all-zero
  trajectories are excluded with a printed `[NOTE]` line. After rerun, the power
  TRISK sensitivity CSV must contain no NA numeric values for that company.
- [ ] TASK-04-05: Power-2025 NA fix in `scripts/generate_vietnam_data.R` per
  ASM-010: backfill the NA 2025 projected power values using the interpolation
  already used for scenario anchors; regenerate and confirm the PACTA power techmix
  outputs have no NA 2025 rows.
- [ ] TASK-04-06: Deterministic run IDs (N2, ASM-003): in
  `write_trisk_demo_outputs()` (`R/trisk_core.R` ≈ lines 770–841), rewrite `run_id`
  in every written CSV that carries it and `run_path` in `run_catalog.csv` per the
  Specification. First run
  `grep -rn "run_id" scripts/ dashboard/lib/ dashboard/pages/ tests/ R/ --include="*.R" --include="*.py"`
  and confirm no consumer joins on the UUID *values* across files (labels are
  self-consistent after the rewrite because every file gets the same
  `sector_runlabel` string); if a consumer does depend on UUID values, adapt it in
  the same commit.
- [ ] TASK-04-07: Single golden refreeze: run
  `Rscript scripts/pipeline_refresh.R --full` to green; run
  `Rscript tools/verify_refactor.R --skip-refresh` and inspect the classification —
  expected DRIFT is exactly the intended fix surface (scenario paths, power-2025
  values, Dung Quat rows, run_id/run_path columns). Re-freeze changed literals in
  `tests/testthat/test_golden_numbers.R` from the newly generated CSVs; re-run the
  SDB engagement (`Rscript scripts/run_engagement.R --config
  engagements/sdb-rehearsal/engagement_config.json --raw-loanbook
  data/fixtures/unseen_bank_loanbook.csv`) and refreeze
  `test_sdb_engagement.R` + recommit the ASM-007 SDB artifacts if values moved.
  Set `VOLATILE_BASENAMES <- character(0)` in `tools/verify_refactor.R` (ASM-004).
  Commit everything as ONE commit whose message names the refreeze and each cause.
- [ ] TASK-04-08: Post-refreeze determinism proof: run
  `Rscript scripts/pipeline_refresh.R` once more, then
  `Rscript tools/verify_refactor.R --skip-refresh` → `BYTE-IDENTITY PASS` with an
  empty volatile section (the five formerly volatile CSVs are now byte-stable).

**File Changes**
- `docs/abcd_sourcing_decision.md` (create): decision brief per TASK-04-01.
- `intake/SCHEMA.md` (modify): append the ABCD section; loanbook section untouched.
- `intake/templates/abcd_template.csv` (create); templates README (modify): one line.
- `data/scenarios/pdp8-2023/vietnam_scenario_ms.csv`,
  `data/scenarios/pdp8-2023/vietnam_scenario_co2.csv` (create, generated copies).
- `scripts/generate_vietnam_data.R` (modify): dual-write scenario CSVs; 2025 power
  backfill.
- `R/engagement_config.R` (modify): scenario input defaults → versioned paths;
  nothing else.
- `engagements/mcb-demo/engagement_config.json` (modify): mirror the new paths.
- `R/trisk_core.R` (modify): wire `backfill_zero_baseline()` into
  `trisk_prepare_sector_inputs`; run_id/run_path rewrite in
  `write_trisk_demo_outputs()`.
- `scripts/generate_refresh_audit.R` (modify): scenario paths + checksums in metrics
  JSON and audit HTML.
- `tools/verify_refactor.R` (modify): empty the volatile list.
- `tests/testthat/test_engagement_config.R`, `tests/testthat/test_snapshot_contract.R`
  (modify): updated default-path literal + dual-copy checksum assertion.
- `tests/testthat/test_golden_numbers.R`, `tests/testthat/test_sdb_engagement.R`
  (modify): refrozen literals only, from newly committed files.
- Committed default-mode CSVs under `synthesis_output/`, `dashboard/data/`,
  `data/`, and SDB artifacts under `engagements/sdb-rehearsal/` (modify): the single
  sanctioned refreeze (ASM-004, CON-001).

**Function Signatures**
- `backfill_zero_baseline(assets: tbl, value_col: character, year_col: character = "year") -> tbl` —
  (already exists in `R/trisk_core.R`; do not change its signature) returns the
  assets table with leading-zero baselines backfilled from the first non-zero year
  plus a `baseline_note` column; all-zero assets dropped.

**Test Specs**
- Existing `backfill_zero_baseline` unit tests in `tests/testthat/test_trisk_core.R`
  stay green unchanged (the function moves from "tested but unwired" to "wired").
- After TASK-04-04 + rerun:
  `Rscript -e "d <- readr::read_csv('synthesis_output/trisk/power_demo/sensitivity_results.csv', show_col_types=FALSE); stopifnot(!anyNA(d[grepl('Dung Quat', d$company_name), sapply(d, is.numeric)]))"`
  → exits 0.
- After TASK-04-05 + refresh:
  `python -c "import pandas as pd; d=pd.read_csv('dashboard/data/pacta/04_vn_ms_portfolio.csv'); print(d[d.year==2025].isna().sum().sum())"`
  → `0` (adjust the file/column to where the NA actually lived, per ASM-010).
- After TASK-04-06:
  `Rscript -e "d <- readr::read_csv('synthesis_output/trisk/power_demo/npv_results_latest.csv', show_col_types=FALSE); stopifnot(all(grepl('^power_', d$run_id)))"`
  → exits 0.
- TASK-04-03 checksum assertion green; TASK-04-08 determinism proof passes; full R +
  Python suites green after TASK-04-07.

**Dependencies**
- PHASE-03 (SDB goldens exist and must be re-checked after the refreeze).
  TASK-04-01 and TASK-04-02 have no dependencies and may run any time.

**Exit Criteria**
- [ ] `docs/abcd_sourcing_decision.md` and the ABCD intake section + template exist
  and cross-link.
- [ ] Config defaults reference `data/scenarios/pdp8-2023/`; the refresh audit
  records scenario checksums; the dual-copy checksum test is green.
- [ ] No NA rows for Dung Quat in shipped TRISK sensitivity outputs; no NA 2025
  power rows in the PACTA outputs.
- [ ] Two consecutive default refreshes produce byte-identical CSVs including the
  five formerly volatile files (TASK-04-08).
- [ ] `Rscript scripts/pipeline_refresh.R --full` green; both golden sets green
  against refrozen literals; `python -m pytest dashboard/tests` green.

**Phase Risks**
- **RISK-04-01:** The refreeze visibly changes numbers on the public app. Mitigation:
  intended — these are fixes of known demo distractions; the refresh audit documents
  the delta and the single commit message explains each cause.
- **RISK-04-02:** A hidden consumer parses the run_id UUID format. Mitigation:
  TASK-04-06's grep sweep before the rewrite; the dashboard test suite runs against
  the refrozen snapshot before commit.
- **RISK-04-03:** Dual-written scenario CSVs drift if someone edits only one copy.
  Mitigation: both come from the same generator run; the TASK-04-03 checksum
  assertion fails loudly on drift.

## Gotchas

- **VND is never rescaled.** Loanbook money (`loan_size_outstanding`, literal `VND`)
  spans 1e5–5e12 raw. No new or moved code may divide/multiply it except where the
  original code already did for display.
- **Byte-identity applies to CSVs only, via git diff.** PNGs differ run-to-run
  (compression); HTML reports differ in generated-timestamp text. Use autocrlf-aware
  `git diff` (as `tools/verify_refactor.R` does), never raw md5sum on Windows.
- **Run every command from the repo root.** All scripts resolve paths via `getwd()`;
  `tests/testthat/helper-root.R` walks upward looking for a `dashboard/` directory.
- **`source()` and package-load must both keep working.** Keep top-of-file
  `library()` guards in `R/` files; roxygen `#' @export` tags only, never
  `@import`/`@importFrom`.
- **`yaml` is deliberately not a dependency** — configs are JSON via `jsonlite`. Do
  not add any new pipeline dependency; the analysis stack is pinned in `renv.lock`.
- **`system2("Rscript", ...)` needs `Rscript` on PATH** even when the outer call used
  a full path. Windows session fix: `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"`.
- **PowerShell 5.1 has no `&&`** — chain with `;`; Bash-style commands in this plan
  run as-is only in Git Bash/Linux.
- **Flag-name trap:** the letters script takes `--top_n` (underscore); the
  orchestrator's own CLI uses `--top-n` (hyphen) and must translate.
- **`clear_dir()` wipes the snapshot tree on every refresh** — never hand-place
  files under any `snapshot_dir`.
- **Manifest-shape lock:** `tests/testthat/test_manifest_json.R` and
  `dashboard/tests/test_manifest.py` pin the default manifest keys/steps — the
  step-runner extraction must not rename or reorder anything in default mode.
- **`dashboard/tests/test_loaders.py:66` asserts exactly 243 power grid scenarios** —
  do not change grid lever ranges anywhere in this plan.
- **Engagement scoring reads from the snapshot (`snapshot_dir/trisk/...`), not
  `synthesis_output/`** — the orchestrator must run it AFTER the snapshot step
  (enforced by the fixed step order in the Specification).
- **Golden literals come from committed files, never from plan text** — when
  authoring `test_sdb_engagement.R` or refreezing `test_golden_numbers.R`, open the
  generated CSV and freeze what is actually there.
- **Weekly CI auto-commits to `main`** (Mondays 02:00 UTC, test-gated): a red
  testthat suite blocks the publish by design — fix the cause, never bypass the
  gate. Land each phase only when its exit criteria pass.
- **`attic/` and `dashboard/data/` are do-not-touch** (except
  `refresh_dashboard_data.R` writing the latter); synthetic-data disclaimers must
  survive every generator change.
- **Vietnamese diacritics:** author any new CSV as UTF-8 without BOM; the intake
  reader falls back to latin1, which silently mangles diacritics.
- **`dashboard/tests/test_auth.py::test_no_password_renders_landing`** is a known
  environmental flake (hardcoded 3-second Streamlit AppTest timeout); if it fails in
  isolation with no dashboard change, re-run before investigating.

## Verification Strategy

- **TEST-001 (PHASE-01):** `Rscript tools/verify_refactor.R` on the untouched tree →
  prints `BYTE-IDENTITY PASS`, exit 0.
- **TEST-002 (PHASE-02):** `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --skip-intake --dry-run`
  → step list printed (grid present, intake/validation absent), exit 0, nothing
  written.
- **TEST-003 (PHASE-02):** `Rscript -e "devtools::load_all('.'); stopifnot(is.function(run_steps), is.function(write_pipeline_manifest))"`
  → exits 0.
- **TEST-004 (PHASE-03):** `python -c "import json;m=json.load(open('engagements/sdb-rehearsal/pipeline_manifest.json'));print(m['status'],m['bank_slug'])"`
  → `ok sdb-rehearsal`.
- **TEST-005 (PHASE-03):** `git status --porcelain synthesis_output output dashboard/data reports`
  immediately after the SDB run → empty output.
- **TEST-006 (PHASE-04):** `Rscript -e "stopifnot(identical(unname(tools::md5sum('data/vietnam_scenario_ms.csv')), unname(tools::md5sum('data/scenarios/pdp8-2023/vietnam_scenario_ms.csv'))))"`
  → exits 0.
- **TEST-007 (PHASE-04):** run `Rscript scripts/pipeline_refresh.R` twice in
  succession, then `Rscript tools/verify_refactor.R --skip-refresh` → `BYTE-IDENTITY
  PASS` with an empty volatile section (run-ID determinism proven).
- **TEST-008 (all phases):** `Rscript -e "testthat::test_dir('tests/testthat')"` →
  0 failures; `python -m pytest dashboard/tests` → 0 failures.
- **MANUAL-001 (PHASE-03):** open the SDB validation report HTML under
  `engagements/sdb-rehearsal/reports/` — "Saigon Delta Bank" branding + synthetic-data
  footer.
- **MANUAL-002 (PHASE-04):** `python -m streamlit run dashboard/app.py`, open the
  PACTA page — the power techmix panel shows populated 2025 bars.
- **OBS-001 (PHASE-03):** trigger `.github/workflows/refresh.yml` via
  `workflow_dispatch` (`gh workflow run refresh.yml`) — both the `refresh` and
  `sdb-engagement` jobs pass; the `sdb-engagement` job creates no commit.
- **OBS-002 (PHASE-04):** after the next Monday 02:00 UTC scheduled refresh, confirm
  the bot commit (if any) is empty-or-tiny: with deterministic run IDs, a no-change
  week should produce "No data changes to commit." in the job log.

## Risks and Alternatives

- **RISK-001:** A partial merge leaves the weekly auto-commit CI running against
  inconsistent scripts. Mitigation: land each phase as one commit/PR only after its
  exit criteria pass; the test gate blocks a red publish either way.
- **RISK-002:** The SDB run exposes structural assumptions guards can't absorb.
  Mitigation: PHASE-03 permits observation-plus-guard fixes only; anything structural
  is logged as a named backlog item in `pilot/rehearsal_log.md` for a follow-on plan.
- **RISK-003:** The PHASE-04 refreeze commit is large and mixes several causes.
  Mitigation: intentional (ASM-004 — goldens refrozen exactly once); the
  `tools/verify_refactor.R` classification output pasted into the commit message
  itemizes every changed file by cause.
- **ALT-001:** Run the orchestrator in-process via loaded `pactatrisk::` functions
  instead of `Rscript` subprocess chaining — rejected (DEC-004): per-step process
  isolation preserves today's failure semantics and bounds memory across TRISK runs;
  the package functions remain the substrate the scripts call.
- **ALT-002:** Land N2 (deterministic run IDs) immediately in PHASE-01 — rejected:
  it would force a golden refreeze commit of its own; folding it into PHASE-04's
  already-required refreeze means committed CSVs and goldens change exactly once
  (ASM-004).
- **ALT-003:** Put the SDB CI guard in `ci.yml` on every push — rejected (ASM-005):
  TRISK runs take minutes and would tax every PR; weekly cadence plus
  `workflow_dispatch` matches the refresh guard it complements.
- **ALT-004:** Skip the SDB golden fixture and rely on MCB goldens — rejected: MCB
  goldens cannot detect "works only for MCB" regressions, which is the exact failure
  mode multi-bank parameterization introduces.

## Suggested Next Step

Execute PHASE-01 (the verification tool proves itself on the untouched tree before
any code moves). TASK-04-01 (the ABCD sourcing brief) has zero code dependencies —
start it in parallel the same day. Each phase's exit criteria are shell-verifiable
before the next begins.
