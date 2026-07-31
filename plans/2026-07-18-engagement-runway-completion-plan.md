---
title: "Engagement Runway Completion: TRISK Core, One-Command Orchestrator, SDB Rehearsal, Data Closers"
date: "2026-07-18"
status: "complete — bulk-corrected 2026-07-31 per directive: plan predates 2026-07-20 and is presumed fully implemented (NOT individually verified against git/code evidence)"
request: "Complete the client-engagement runway on the package foundation (Wave 0 of research/2026-07-18-runway-completion-and-credibility-brainstorm.md): merged TRISK parameterize+decompose into R/trisk_core.R, downstream generator parameterization, run_engagement.R orchestrator, SDB end-to-end run with second golden fixture, and PHASE-06 closers (ABCD sourcing brief, ABCD intake schema, scenario versioning, NA bug fixes)"
plan_type: "multi-phase"
research_inputs:
  - "research/2026-07-18-runway-completion-and-credibility-brainstorm.md"
  - "research/2026-07-16-next-level-platform-brainstorm.md"
  - "research/2026-07-13-client-engagement-runway-brainstorm.md"
---

# Plan: Engagement Runway Completion — TRISK Core, One-Command Orchestrator, SDB Rehearsal, Data Closers

## Objective

Make "run the whole PACTA + TRISK platform on a new bank's loanbook and produce their
private deliverables, in one command" a demonstrated capability. Today only the PACTA
stage reads the engagement config; the TRISK chain, prioritization, snapshot publisher,
engagement scoring, and letter/disclosure generators all hardcode the synthetic Mekong
Commercial Bank (MCB) paths, and no orchestrator exists. This plan parameterizes and
decomposes the TRISK chain in ONE pass (into `R/trisk_core.R`, mirroring the existing
`R/pacta_core.R` pattern), parameterizes the downstream generators, adds
`scripts/run_engagement.R`, proves it end-to-end on the synthetic Saigon Delta Bank
(SDB) fixture with a second frozen golden-test set, and closes the remaining
real-engagement data dependencies (ABCD sourcing brief, ABCD intake schema, scenario
vintage versioning, two NA-producing bugs).

## Context Snapshot

- **Current state:** A hardened demo platform for a synthetic Vietnamese bank (MCB;
  **all data is synthetic**). R pipeline (`scripts/*.R`) → frozen snapshot
  (`dashboard/data/`, ~3 MB) → public Streamlit app. An engineering foundation was just
  completed: `R/pacta_core.R` holds 9 pure PACTA functions;
  `scripts/pacta_vietnam_scenario.R` is a 115-line wrapper; the repo is a genuinely
  loadable R package (`pactatrisk 0.1.0`, generated `NAMESPACE`, `man/`,
  `tests/testthat.R`, CI package-load gate); a config layer exists
  (`R/engagement_config.R` with `load_engagement_config()`/`get_config_arg()`,
  `R/sector_registry.R`, `engagements/mcb-demo/engagement_config.json`). BUT only
  `scripts/pacta_vietnam_scenario.R` consumes the config. The TRISK chain
  (`trisk_prepare_inputs.R` 392 lines, `trisk_sector_demo.R` 491 lines with 10 named
  functions, `trisk_scenario_grid.R` 431 lines, `trisk_power_demo.R` — a 12-line
  compatibility wrapper that sources `trisk_sector_demo.R`), `sector_prioritization.R`
  (363 lines, writes `synthesis_output/prioritization/`), `refresh_dashboard_data.R`,
  `engagement_scoring.R`, `generate_engagement_letters.R` (1 hardcoded "Mekong
  Commercial Bank"), and `generate_disclosure_pack.R` (3 occurrences) all hardcode MCB
  inputs/outputs. `scripts/run_engagement.R` and `R/step_runner.R` do not exist.
  `engagements/` holds only `mcb-demo/`. `data/scenarios/` and
  `docs/abcd_sourcing_decision.md` do not exist. `scripts/engagement_scoring.R:149`
  emits `"N/A - sector not in TRISK pilot"` for non-TRISK sectors (unchanged by this
  plan). A dirty 40-row SDB fixture (`data/fixtures/unseen_bank_loanbook.csv`) has been
  run through intake validation/anonymization only — never through PACTA/TRISK.
- **Desired state:** All pipeline stages accept `--config <path>` with no-flag behavior
  byte-identical (CSV-level) to today; TRISK stage logic lives in `R/trisk_core.R` as
  exported package functions; `Rscript scripts/run_engagement.R --config
  engagements/<slug>/engagement_config.json --raw-loanbook <csv>` executes intake →
  validation report → PACTA → TRISK → prioritization → snapshot → scoring → letters →
  disclosure into an engagement-scoped directory tree with its own
  `pipeline_manifest.json`; the SDB fixture runs end-to-end with measured stage timings
  logged and a second golden-number test set (`tests/testthat/test_sdb_engagement.R`)
  frozen from committed outputs; scenario inputs are versioned under
  `data/scenarios/pdp8-2023/`; the Dung Quat zero-baseline and power-2025 NA bugs are
  fixed with goldens refrozen; `docs/abcd_sourcing_decision.md` and an ABCD intake
  contract exist.
- **Key repo surfaces:** `scripts/trisk_prepare_inputs.R`, `scripts/trisk_sector_demo.R`,
  `scripts/trisk_power_demo.R`, `scripts/trisk_scenario_grid.R`,
  `scripts/sector_prioritization.R`, `scripts/refresh_dashboard_data.R`,
  `scripts/engagement_scoring.R`, `scripts/generate_engagement_letters.R`,
  `scripts/generate_disclosure_pack.R`, `scripts/pipeline_refresh.R`,
  `scripts/intake_validate_and_map.R`, `scripts/generate_validation_report.R`,
  `R/engagement_config.R`, `R/sector_registry.R`, `R/pacta_core.R` (pattern reference),
  `DESCRIPTION`, `NAMESPACE`, `tests/testthat/`, `data/fixtures/unseen_bank_loanbook.csv`,
  `intake/SCHEMA.md`, `pilot/rehearsal_log.md`, `.github/workflows/ci.yml`,
  `.github/workflows/refresh.yml`.
- **Out of scope:** Automotive TRISK; steel synthetic-book enrichment; multi-scenario
  traffic-light view; executive summary generator; Vietnamese i18n; PDF export;
  `targets`/caching migration; real bank data execution (synthetic fixtures only); any
  change to synthetic-data disclaimers; renaming existing script files; changes to
  engagement-scoring math; multi-tenant auth; changes to the 243-cell grid lever ranges.

## Environment & Conventions

- **Stack:** R 4.5.2 drives the analytics pipeline via `Rscript`. Windows local:
  `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe"` or `$env:Path += ";C:\Program
  Files\R\R-4.5.2\bin"` for the session; Linux/CI: plain `Rscript`. R dependencies
  pinned in `renv.lock` (analysis stack: arrow, base64enc, dplyr, fs, ggplot2, ggrepel,
  jsonlite, pacta.loanbook, purrr, r2dii.analysis/data/match/plot, readr, rlang, scales,
  stringi, tibble, tidyr, trisk.model; dev-only: testthat, roxygen2, devtools). **`yaml`
  is deliberately NOT a dependency** — configs are JSON via `jsonlite`. Python 3.11+
  with Streamlit/pandas/plotly/pytest runs the dashboard.
- **Setup:** R: `Rscript -e "renv::restore()"` or the no-renv fallback
  `Rscript scripts/ci/install_deps.R`. Python:
  `python -m pip install -r dashboard/requirements.txt`. Note: `.Rprofile` renv
  auto-activation is commented out for local development; CI restores via
  `r-lib/actions/setup-renv@v2`.
- **Build / Run:** full MCB pipeline: `Rscript scripts/pipeline_refresh.R` (7-step TRISK
  refresh + audit; `--full` prepends data generation + PACTA and appends engagement
  scoring). PACTA only: `Rscript scripts/pacta_vietnam_scenario.R`. Always run from the
  repo root — every script resolves paths via `getwd()`.
- **Test:** full R suite: `Rscript -e "testthat::test_dir('tests/testthat')"` — single
  file: `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`.
  Package harness: `Rscript -e "devtools::test()"`. Python:
  `python -m pytest dashboard/tests` — single:
  `python -m pytest dashboard/tests/test_loaders.py -v`.
- **Conventions & traps:** All loanbook money is raw VND (`loan_size_outstanding`,
  currency literal `VND`, magnitudes 1e5–5e12) — **never rescale**. Vietnamese names are
  matched after ASCII normalization via `normalize_vn_name()` (`R/matching_helpers.R`);
  CSVs are UTF-8 without BOM. Config convention: scripts source `R/engagement_config.R`
  and call `cfg <- load_engagement_config(get_config_arg())`; no `--config` flag → MCB
  defaults reproducing today's hardcoded paths exactly. Refactor acceptance bar:
  **byte-identical MCB CSV outputs** (verify with `tools::md5sum`); PNGs are compared
  visually only (compression nondeterminism); HTML reports may differ only in
  generated-timestamp text. The golden-number tests
  (`tests/testthat/test_golden_numbers.R`) are load-bearing. Windows PowerShell 5.1 has
  no `&&` chaining — use `;` or the portable `Rscript -e "..."` one-liners in this plan.
  Existing CLI arg style in scripts: local `parse_arg(args, name, default)` helpers
  scanning `--flag value` pairs; `trisk_sector_demo.R` takes one positional sector arg.
- **Repo map:**
  - `scripts/` — R pipeline stage entrypoints + `pipeline_refresh.R` orchestrator.
  - `R/` — package modules (`pacta_core.R`, `engagement_config.R`, `sector_registry.R`,
    `report_toolkit.R`, `matching_helpers.R`); this plan ADDS `trisk_core.R` and
    `step_runner.R`.
  - `data/` — synthetic MCB inputs + `data/fixtures/unseen_bank_loanbook.csv` (SDB) +
    generator `scripts/generate_vietnam_data.R`; this plan ADDS `data/scenarios/`.
  - `output/` — TRISK prepared inputs (`trisk_inputs/<sector>_demo/`), engagement
    outputs (`engagement/`, `engagement_letters/`, `disclosure/`).
  - `synthesis_output/` — pipeline outputs (`vietnam/` PACTA, `trisk/<sector>_demo/`,
    `trisk/grid/<sector>/`, `prioritization/`).
  - `dashboard/` — Streamlit app + frozen snapshot `dashboard/data/` (only
    `refresh_dashboard_data.R` may write it).
  - `engagements/` — per-engagement configs; `mcb-demo/` documents defaults; this plan
    ADDS `sdb-rehearsal/`.
  - `intake/` — BYOL schema (`SCHEMA.md`), templates; `pilot/` — pilot pack incl.
    `rehearsal_log.md`; `tests/testthat/` — R suite (`helper-root.R` finds the repo root
    by walking up to a directory containing `dashboard/`).
  - `attic/` — retired scripts. **Do not touch.**

## Research Inputs

- From `research/2026-07-18-runway-completion-and-credibility-brainstorm.md`:
  - The TRISK parameterization and the TRISK decompose touch the same ~1,300 lines of
    script code; executing them as two passes would rewrite the same sections twice
    under the same byte-identity gate. They must be one merged pass producing
    `R/trisk_core.R` with `cfg` as a parameter from birth (adopted here as PHASE-01).
  - The orchestrator should call loaded `pactatrisk::` functions where they exist, with
    scripts kept as thin CLI shims — consistent with the just-completed package
    investment; the default-mode manifest schema is locked by existing tests.
  - The ABCD sourcing brief is research-only, gates the commercial conversation, and
    should start early rather than waiting for the final phase (it is scheduled in
    PHASE-05 but has zero code dependencies — it may be written at any point).
- From `research/2026-07-16-next-level-platform-brainstorm.md`:
  - The foundation refactor's acceptance discipline that proved safe: move code
    verbatim, treat any CSV hash mismatch as a defect (never a new baseline), keep
    `library()` guards so `R/` files work both `source()`d and package-loaded, use
    `@export` roxygen tags only (never `@import`, which breaks standalone sourcing).
- From `research/2026-07-13-client-engagement-runway-brainstorm.md`:
  - The intake validator's `normalized_loanbook.csv` has exactly the same 13 columns as
    `data/vietnam_loanbook.csv` (`id_loan, id_direct_loantaker, name_direct_loantaker,
    id_ultimate_parent, name_ultimate_parent, loan_size_outstanding,
    loan_size_outstanding_currency, loan_size_credit_limit,
    loan_size_credit_limit_currency, sector_classification_system,
    sector_classification_direct_loantaker, lei_direct_loantaker,
    isin_direct_loantaker`) — downstream compatibility is by construction.
  - The SDB fixture was designed so ~28 clean rows reuse company names present in
    `data/vietnam_abcd.csv` (EVN subsidiaries, VinFast, THACO, VICEM, Hoa Phat,
    Vinacomin), so PACTA matching demonstrably succeeds against the existing synthetic
    ABCD; 3 rows are deliberately unmatchable. The SDB run's friction points are
    themselves the deliverable — fix with inline guards and log them, do not redesign.

## Assumptions and Constraints

- **ASM-001:** How the TRISK core is organized — **BINDING DEFAULT:** one new file
  `R/trisk_core.R` holding the functions moved from `scripts/trisk_prepare_inputs.R`,
  `scripts/trisk_sector_demo.R`, and `scripts/trisk_scenario_grid.R`, plus one file
  `R/prioritization_core.R` for `scripts/sector_prioritization.R`'s logic. Do not split
  further this plan. Scripts remain as thin CLI entrypoints with their current
  filenames (referenced by `pipeline_refresh.R`, CI, `dashboard/lib/live_rerun.py`).
- **ASM-002:** Extraction method — **BINDING DEFAULT:** move function bodies and inline
  code *verbatim*; the only permitted edits are (a) replacing a hardcoded path literal
  with a value derived from a new `cfg`/dir parameter whose default equals today's
  literal, (b) replacing a hardcoded bank-name string with `cfg$bank_name` (or a short
  label derived from it), and (c) promoting top-level variables to parameters/returns.
  No logic edits, no dplyr reordering, no changed `readr::write_csv` arguments. Any CSV
  hash drift in default mode is a defect to fix, never a new baseline.
- **ASM-003:** Byte-identity scope for the TRISK refactor — **BINDING DEFAULT:** the
  comparison set is every `*.csv` under `synthesis_output/trisk/`,
  `synthesis_output/prioritization/`, `synthesis_output/vietnam/`, `output/trisk_inputs/`,
  and `dashboard/data/` after a default-mode `Rscript scripts/pipeline_refresh.R` run.
  If a specific TRISK CSV proves non-byte-stable across two *unmodified* back-to-back
  baseline runs (e.g. an embedded run timestamp or row-order nondeterminism from the
  upstream `trisk.model` package), exclude exactly that file from the byte comparison,
  compare it with the volatile column dropped (or row-sorted), and name the exclusion +
  reason in the phase commit message. Establish this by running the baseline TWICE
  before touching code (TASK-01-01).
- **ASM-004:** `data/vietnam_trisk_*.csv` side copies — **BINDING DEFAULT:**
  `trisk_prepare_inputs.R` currently writes duplicates to both `data/vietnam_trisk_*.csv`
  and `output/trisk_inputs/<sector>_demo/`. Before changing anything run
  `grep -rn "vietnam_trisk_" scripts/ dashboard/ tests/ R/ --include="*.R" --include="*.py"`.
  If nothing outside `trisk_prepare_inputs.R` reads the `data/` copies, keep writing
  them only in default (no-config) mode and skip them for engagement runs; if something
  reads them, mirror them into the engagement's `trisk_input_root` instead.
- **ASM-005:** Grid runs per engagement — **BINDING DEFAULT:** the 243-cell scenario
  grid is opt-in per engagement (`"run_grid": false` in engagement configs); the public
  MCB pipeline keeps `run_grid = TRUE` and runs the grid exactly as today. Grid lever
  ranges are untouched (a dashboard test asserts exactly 243 power scenarios).
- **ASM-006:** Package exposure of new functions — **BINDING DEFAULT:** tag the new
  public functions in `R/trisk_core.R`, `R/prioritization_core.R`, and `R/step_runner.R`
  with `#' @export` (roxygen), regenerate `NAMESPACE` with
  `Rscript -e "roxygen2::roxygenise()"`, and bump `DESCRIPTION` `Version:` to `0.2.0`.
  Never add `@import`/`@importFrom` directives — the `R/` files must keep working when
  `source()`d standalone (keep top-of-file `library()`/`requireNamespace()` guards,
  matching the existing `R/pacta_core.R` style).
- **ASM-007:** SDB committed artifacts — **BINDING DEFAULT:** commit under
  `engagements/sdb-rehearsal/`: `engagement_config.json`,
  `intake/normalized_loanbook.csv`, `output/engagement/engagement_priority.csv`,
  `output/trisk/<sector>_demo/npv_results_latest.csv` and `company_summary.csv` per
  sector that ran, and `pipeline_manifest.json`. Gitignore all other generated content
  under `engagements/*/` (snapshot, reports, PNGs, letters, disclosure) via `.gitignore`
  patterns `engagements/*/snapshot/`, `engagements/*/reports/`,
  `engagements/*/output/**/figures/`, `engagements/*/output/engagement_letters/`,
  `engagements/*/output/disclosure/`.
- **ASM-008:** SDB timing documentation — **BINDING DEFAULT:** append a "Downstream run
  (2026-07)" section to `pilot/rehearsal_log.md`; do NOT edit `{{DATE_n}}` placeholders
  in `pilot/real_data_phase_proposal.md` (a client-tailoring template).
- **ASM-009:** ABCD brief pricing — **BINDING DEFAULT:** where Asset Impact license
  costs are not publicly verifiable, write "to be confirmed with vendor" instead of
  inventing numbers; the brief's deliverable is the decision framework and per-sector
  coverage assessment, not a quote.
- **ASM-010:** Golden refreeze after the NA fixes — **BINDING DEFAULT:** the Dung Quat
  and power-2025 fixes are *expected* to change some published numbers. After a green
  `Rscript scripts/pipeline_refresh.R --full`, re-freeze changed literals in
  `tests/testthat/test_golden_numbers.R` (and `test_sdb_engagement.R` if SDB values
  moved — rerun the SDB engagement if its inputs changed) by reading the newly committed
  CSVs, and state the refreeze in the commit message. Never adjust goldens without a
  green full pipeline run.
- **ASM-011:** Where the power-2025 NA lives — **BINDING DEFAULT:** locate it at
  execution time: run `Rscript scripts/generate_vietnam_data.R` then check which
  power-sector 2025 rows in the PACTA market-share outputs are NA (start with
  `synthesis_output/vietnam/04_vn_ms_portfolio.csv`, column bearing projected values,
  `technology` in the power set, `year == 2025`). Backfill at the *generator* level with
  the same interpolation already used for scenario anchors — not with a display-side
  patch.
- **CON-001:** With no `--config` flag, every script's observable behavior (paths
  written, CSV bytes, manifest shape) must remain identical to today — the weekly
  auto-commit CI (`.github/workflows/refresh.yml`, Mondays 02:00 UTC, test-gated), the
  golden tests, and the public app depend on it.
- **CON-002:** `tests/testthat/test_manifest_json.R` and
  `dashboard/tests/test_manifest.py` assert on the default `pipeline_manifest.json`
  shape and step list — the step-runner extraction must not change default manifest
  keys, step names, order, or counts.
- **CON-003:** Streamlit Community Cloud has no R runtime; nothing in `dashboard/` may
  gain an R dependency. `run_engagement.R` is operator-side only.
  `dashboard/lib/live_rerun.py` shells out to TRISK scripts with today's CLI — `--config`
  must be additive/optional.
- **CON-004:** Everything bank-visible keeps synthetic/illustrative-data disclaimers;
  SDB outputs are synthetic and must say so.
- **DEC-001:** MCB stays the default engagement; `load_engagement_config(NULL)` returns
  MCB defaults; the default pipeline never reads
  `engagements/mcb-demo/engagement_config.json`.
- **DEC-002:** Engagement-scoring composite math stays fixed 50/50
  (alignment vs TRISK) with renormalization for TRISK-uncovered sectors — untouched.
- **DEC-003:** Configs are JSON via `jsonlite::read_json(path, simplifyVector = TRUE)`;
  do not add `yaml` or any new pipeline dependency.

## Phase Summary

| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Merged TRISK parameterize + decompose: config-driven TRISK chain & prioritization as package functions, byte-identical default mode | None | `R/trisk_core.R`, `R/prioritization_core.R`, thinned `scripts/trisk_*.R` + `sector_prioritization.R`, config key additions, `tests/testthat/test_trisk_core.R` |
| PHASE-02 | Parameterize downstream generators (snapshot, scoring, letters, disclosure) | PHASE-01 | Config-driven `refresh_dashboard_data.R`, `engagement_scoring.R`, `generate_engagement_letters.R`, `generate_disclosure_pack.R`; `tests/testthat/test_config_paths.R` |
| PHASE-03 | `run_engagement.R` orchestrator + shared step runner + package export refresh (v0.2.0) | PHASE-02 | `R/step_runner.R`, `scripts/run_engagement.R` (with `--dry-run` + guard rail), refactored `pipeline_refresh.R` (behavior unchanged), regenerated `NAMESPACE`, `tests/testthat/test_step_runner.R` |
| PHASE-04 | SDB end-to-end dress rehearsal, timings, second golden fixture | PHASE-03 | `engagements/sdb-rehearsal/` committed artifacts, updated `pilot/rehearsal_log.md`, `tests/testthat/test_sdb_engagement.R`, zero-match guards |
| PHASE-05 | Data closers: ABCD sourcing brief, ABCD intake contract, scenario versioning, Dung Quat + power-2025 NA fixes, golden refreeze | PHASE-04 | `docs/abcd_sourcing_decision.md`, extended `intake/SCHEMA.md` + `intake/templates/abcd_template.csv`, `data/scenarios/pdp8-2023/`, fixed generator/prep scripts, refrozen goldens |

## Detailed Phases

### PHASE-01 - Merged TRISK Parameterize + Decompose (`R/trisk_core.R`)

**Goal**
Move the TRISK chain's logic into config-parameterized package functions in ONE pass —
`R/trisk_core.R` (prepare inputs, sector runs, scenario grid) and
`R/prioritization_core.R` (sector ranking) — leaving the four scripts as thin CLI
wrappers, while a default-mode (no `--config`) full refresh stays byte-identical.

**Tasks**
- [ ] TASK-01-01: Capture the acceptance baseline TWICE before touching code, to learn
  which files are byte-stable (ASM-003). From a clean tree, run
  `Rscript scripts/pipeline_refresh.R` to completion, then:
  `Rscript -e "f<-sort(list.files(c('synthesis_output/trisk','synthesis_output/prioritization','synthesis_output/vietnam','output/trisk_inputs','dashboard/data'),pattern='[.]csv$',recursive=TRUE,full.names=TRUE)); writeLines(paste(tools::md5sum(f),f),'trisk_baseline_run1.txt')"`.
  Re-run the refresh and write `trisk_baseline_run2.txt` the same way. Diff the two
  files; any CSV whose hash differs between unmodified runs goes on the "volatile list"
  (compare those sorted/column-dropped per ASM-003). Keep both baseline files out of
  commits (`.gitignore` or delete at phase end).
- [ ] TASK-01-02: Read all four target scripts in full and produce a function map. The
  scripts already contain named functions — move them, don't re-invent:
  `trisk_sector_demo.R` defines `assert_supported_sector`, `resolve_trisk_paths`
  (line ≈51, already takes an `output_root` parameter), `assert_required_input_files`,
  `load_alignment_context`, `build_run_params`, `summarize_trisk_run`,
  `execute_trisk_run`, `run_trisk_sensitivity_case`, `write_trisk_demo_outputs`,
  `run_sector_demo(sector)`; `trisk_scenario_grid.R` defines `build_scenario_id`,
  `build_grid_label`, `build_sector_grid`, `read_existing_grid`,
  `extend_yearly_inputs`, `build_grid_input_dir`, `find_cached_run_path`,
  `load_cached_run`, `build_borrower_results`, `apply_base_deltas`,
  `run_sector_grid(sector)`; `trisk_prepare_inputs.R` and `sector_prioritization.R`
  are linear — map their sections the way `R/pacta_core.R`'s extraction mapped PACTA's
  (verify line ranges at execution time).
- [ ] TASK-01-03: Create `R/trisk_core.R`: move the mapped functions verbatim (ASM-002),
  adding config-derived path parameters. Public API (signatures below):
  `trisk_prepare_sector_inputs(cfg, sectors)`, `trisk_run_sector(cfg, sector)`,
  `trisk_run_grid(cfg, sector)`. Internally: `resolve_trisk_paths()` gains
  `input_root`/`output_root` parameters whose defaults equal today's literals
  (`output/trisk_inputs`, `synthesis_output/trisk`); every chart/report title that
  hardcodes bank naming uses `cfg$bank_name`. Keep the existing
  `trisk_sensitivity_specs` tribble and all `trisk.model` call sites verbatim. Preamble:
  `library()` guards in the same style as `R/pacta_core.R`.
- [ ] TASK-01-04: Create `R/prioritization_core.R` with
  `prioritize_sectors(cfg)`: body moved verbatim from `sector_prioritization.R`, reading
  alignment files from `cfg$paths$pacta_output_dir` (today:
  `synthesis_output/vietnam/06_vn_ms_alignment_2030.csv` and
  `06_vn_sda_alignment_2030.csv`), TRISK results from `cfg$paths$trisk_output_root`,
  writing to a NEW config key `cfg$paths$prioritization_output_dir`. Preserve
  `classify_band()` and the existing `parse_arg` CLI options as wrapper-level concerns.
- [ ] TASK-01-05: Add the new default to `R/engagement_config.R`:
  `paths$prioritization_output_dir = "synthesis_output/prioritization"` (must equal
  today's hardcoded output dir). While mapping paths, add any OTHER path key a script
  needs that has no config home yet — each new key's default must equal today's
  hardcoded value. Extend `tests/testthat/test_engagement_config.R` with one assertion:
  `load_engagement_config(NULL)$paths$prioritization_output_dir ==
  "synthesis_output/prioritization"`. Add the same key to
  `engagements/mcb-demo/engagement_config.json`.
- [ ] TASK-01-06: Thin the four scripts to wrappers: each keeps its shebang/header, its
  existing CLI parsing (positional sector for `trisk_sector_demo.R`; `parse_arg` options
  for `sector_prioritization.R`), adds
  `source("R/engagement_config.R"); source("R/sector_registry.R"); source("R/trisk_core.R")`
  (or `R/prioritization_core.R`), `cfg <- load_engagement_config(get_config_arg())`,
  and calls the core function(s). `trisk_prepare_inputs.R` prepares only
  `cfg$trisk_sectors` and applies ASM-004 for the `data/vietnam_trisk_*.csv` side
  copies. `trisk_power_demo.R` stays a compatibility wrapper (it sources
  `trisk_sector_demo.R`; verify it still runs power by default). `--config` must be
  parsed independently of the positional sector arg (filter the `--config <path>` pair
  out of `args` before reading the positional).
- [ ] TASK-01-07: Create `tests/testthat/test_trisk_core.R` with fast unit tests on
  pure, cheap functions using tiny in-test fixtures (no `trisk.model` execution, no real
  `data/` files) — see Test Specs.
- [ ] TASK-01-08: Acceptance check: from a clean tree run
  `Rscript scripts/pipeline_refresh.R`, regenerate the hash file as in TASK-01-01, and
  compare to `trisk_baseline_run1.txt` minus the volatile list. Every non-volatile CSV
  hash must match. Then run
  `Rscript scripts/trisk_sector_demo.R cement --config engagements/mcb-demo/engagement_config.json`
  and confirm exit 0 with outputs landing in the default locations (config == defaults).

**File Changes**
- `R/trisk_core.R` (create): TRISK prepare/run/grid functions per TASK-01-03, code moved
  verbatim with path/bank-name parameterization only.
- `R/prioritization_core.R` (create): `prioritize_sectors(cfg)` + `classify_band()`.
- `R/engagement_config.R` (modify): add `paths$prioritization_output_dir` default (and
  any other key discovered per TASK-01-05); nothing else.
- `engagements/mcb-demo/engagement_config.json` (modify): mirror the new key(s) with
  default values.
- `scripts/trisk_prepare_inputs.R`, `scripts/trisk_sector_demo.R`,
  `scripts/trisk_scenario_grid.R`, `scripts/sector_prioritization.R` (modify): thin to
  CLI wrappers per TASK-01-06; keep filenames, headers, and existing CLI flags.
- `scripts/trisk_power_demo.R` (modify only if needed): keep working as the power
  wrapper.
- `tests/testthat/test_engagement_config.R` (modify): new-key assertion.
- `tests/testthat/test_trisk_core.R` (create): unit tests per Test Specs.
- `.gitignore` (modify): add `trisk_baseline_run*.txt`.

**Function Signatures**
- `trisk_prepare_sector_inputs(cfg: list, sectors: character = cfg$trisk_sectors) -> invisible(character)` —
  writes the per-sector TRISK input CSVs under `cfg$paths$trisk_input_root/<sector>_demo/`
  (assets, scenarios, financial features, company mapping, NGFS carbon price), returns
  the vector of directories written; reads `cfg$inputs$abcd_csv`,
  `cfg$inputs$scenario_ms_csv`, `cfg$inputs$scenario_co2_csv`.
- `trisk_run_sector(cfg: list, sector: character) -> invisible(list)` — runs the base +
  sensitivity TRISK cases for one sector (power/cement/steel) from
  `cfg$paths$trisk_input_root`, writing all current demo outputs (npv/pd/trajectories/
  company summary/sensitivity CSVs + PNGs) under
  `cfg$paths$trisk_output_root/<sector>_demo/`; returns the run-results list
  `write_trisk_demo_outputs` consumes today.
- `trisk_run_grid(cfg: list, sector: character) -> invisible(tbl)` — runs (or extends
  from cache) the 243-cell scenario grid for one sector, writing under
  `cfg$paths$trisk_output_root/grid/<sector>/`; returns the grid results table.
- `prioritize_sectors(cfg: list, weights: list = NULL) -> invisible(tbl)` — computes the
  sector ranking from PACTA alignment + TRISK results + exposure, writes the current
  prioritization CSVs to `cfg$paths$prioritization_output_dir`, returns the ranking
  table. `weights = NULL` keeps today's defaults (the existing `parse_arg` CLI options
  map onto this parameter in the wrapper).

**Test Specs**
- `build_scenario_id(2028, 0.08, 0.03, 0.25, "increasing_carbon_tax_50")` → the exact
  ID string the current committed grid files use (read one row of
  `synthesis_output/trisk/grid/power/scenario_results.csv` — or the actual grid file
  name — at authoring time and freeze that literal).
- `extend_yearly_inputs()` on a toy 2-group tibble with years 2025–2027 and a
  `target_year = 2030` → rows extended to 2030 per group with the function's current
  extrapolation rule (freeze expected values from a hand-computed example).
- `classify_band()` on the boundary scores → the exact band labels used today (read the
  thresholds from the moved code; assert e.g. `classify_band(0.0)`,
  `classify_band(0.5)`, `classify_band(1.0)` literals).
- Byte-identity (integration): TASK-01-08 comparison passes for every non-volatile CSV.
- Existing suite: `Rscript -e "testthat::test_dir('tests/testthat')"` → green,
  including untouched `test_golden_numbers.R` and `test_snapshot_contract.R`.

**Dependencies**
- None (the config layer, sector registry, and package harness already exist).

**Exit Criteria**
- [ ] `R/trisk_core.R` and `R/prioritization_core.R` exist; the four scripts are thin
  wrappers; `Rscript scripts/pipeline_refresh.R` exits 0.
- [ ] TASK-01-08 hash comparison: every non-volatile CSV byte-identical; volatile list
  (if any) named in the commit message with reasons.
- [ ] Full R suite green: `Rscript -e "testthat::test_dir('tests/testthat')"`.
- [ ] `python -m pytest dashboard/tests` green (incl. `test_live_rerun.py` — CLI
  unchanged).

**Phase Risks**
- **RISK-01-01:** `trisk.model` internals may write timestamped artifacts making some
  CSVs non-byte-stable. Mitigation: the double-baseline in TASK-01-01 detects this
  BEFORE the refactor, so volatility is never misattributed to the code move.
- **RISK-01-02:** Hidden coupling — a grid function reading a variable created by the
  sector-demo section at top level. Mitigation: TASK-01-02's full read + function map;
  every cross-file dependency becomes an explicit parameter; the byte-identity check
  surfaces misses as crashes or drift.
- **RISK-01-03:** `dashboard/lib/live_rerun.py` shells out to
  `scripts/trisk_run_adhoc.R` / sector scripts with today's CLI. Mitigation: `--config`
  is additive; wrappers keep positional args; run
  `python -m pytest dashboard/tests/test_live_rerun.py -v`.

### PHASE-02 - Parameterize the Downstream Generators

**Goal**
The snapshot publisher, engagement scoring, letters, and disclosure pack all honor the
engagement config's paths, sectors, and bank name — no-flag behavior byte-identical.

**Tasks**
- [ ] TASK-02-01: `scripts/refresh_dashboard_data.R`: add the config preamble; source
  root for PACTA files = `cfg$paths$pacta_output_dir`, TRISK =
  `cfg$paths$trisk_output_root`, prioritization = `cfg$paths$prioritization_output_dir`,
  destination = `cfg$paths$snapshot_dir`; sectors from `cfg$trisk_sectors`. When
  `cfg$run_grid` is `FALSE`, the three grid files are NOT in the required set and the
  emitted `manifest.csv` marks `grid_available` accordingly. Keep `clear_dir()`, the
  fail-loud `record_miss` accumulator, and all copy logic untouched otherwise.
- [ ] TASK-02-02: `scripts/engagement_scoring.R`: config preamble; read the TRISK top
  borrowers from `cfg$paths$snapshot_dir/trisk/<sector>/`, PACTA company file from
  `cfg$paths$pacta_output_dir/04_vn_ms_company.csv`, matched book from
  `cfg$paths$pacta_output_dir/02_vn_matched_prioritized.csv`; write to
  `cfg$paths$engagement_output_dir/engagement_priority.csv`. Scoring math untouched
  (DEC-002); the `"N/A - sector not in TRISK pilot"` behavior stays.
- [ ] TASK-02-03: `scripts/generate_engagement_letters.R` and
  `scripts/generate_disclosure_pack.R`: config preamble; priority file from
  `cfg$paths$engagement_output_dir`; outputs to `cfg$paths$letters_output_dir` /
  `cfg$paths$disclosure_output_dir`; replace the hardcoded "Mekong Commercial Bank"
  occurrences (verify count at execution: 1 in letters, 3 in disclosure) with
  `cfg$bank_name`; keep existing `--top_n` and other flags working alongside `--config`
  (both scripts already use `parse_arg`-style parsing). Templates stay shared from
  `templates/`.
- [ ] TASK-02-04: Create `tests/testthat/test_config_paths.R`: config-mode smoke test
  per Test Specs (temp-dir redirection proves engagement isolation without running the
  full pipeline).
- [ ] TASK-02-05: Default-mode regression: `Rscript scripts/pipeline_refresh.R --full`
  to completion; golden tests green; `dashboard/data/trisk/manifest.csv` unchanged
  (byte compare against the committed copy).

**File Changes**
- `scripts/refresh_dashboard_data.R` (modify): config-derived roots + grid-optional
  handling only; copy logic and fail-loud behavior untouched.
- `scripts/engagement_scoring.R` (modify): config-derived paths only; math untouched.
- `scripts/generate_engagement_letters.R`, `scripts/generate_disclosure_pack.R`
  (modify): config-derived paths + bank name; template mechanics untouched.
- `tests/testthat/test_config_paths.R` (create).

**Function Signatures**
- None — no new code interfaces; each script gains the same
  `cfg <- load_engagement_config(get_config_arg())` preamble.

**Test Specs**
- `test_config_paths.R`: write a temp config JSON overriding
  `paths$engagement_output_dir` to a `tempfile()` dir (inputs left at defaults); run
  `system2("Rscript", c("scripts/engagement_scoring.R", "--config", tmp_json))`; assert
  exit 0, `engagement_priority.csv` exists under the temp dir, and the committed
  `output/engagement/engagement_priority.csv` mtime did not change.
- `Rscript scripts/generate_engagement_letters.R --config engagements/mcb-demo/engagement_config.json`
  → exit 0; letters appear in the default `output/engagement_letters/` (config ==
  defaults) with "Mekong Commercial Bank" in the letter body.
- Default-mode: `test_golden_numbers.R` and `test_snapshot_contract.R` pass unmodified
  after TASK-02-05.

**Dependencies**
- PHASE-01 (config keys + TRISK outputs land config-driven).

**Exit Criteria**
- [ ] All four generators run green both with no flags AND with
  `--config engagements/mcb-demo/engagement_config.json`, producing identical outputs
  in both modes.
- [ ] `Rscript scripts/pipeline_refresh.R --full` exits 0; full R + Python suites green.
- [ ] `grep -n "Mekong Commercial Bank" scripts/*.R` returns no hits outside comments
  (all runtime occurrences flow from `cfg$bank_name`).

**Phase Risks**
- **RISK-02-01:** A missed hardcoded path sends part of an engagement run into the MCB
  tree (cross-contamination). Mitigation: before PHASE-04's SDB run, run
  `grep -n "\"synthesis_output\|\"dashboard/data\|\"output/" scripts/*.R R/*.R` and
  confirm every remaining literal is a config *default*, not a direct consumer.
- **RISK-02-02:** Marking grid files optional accidentally relaxes the default-mode
  fail-loud contract. Mitigation: optionality is conditional on `cfg$run_grid == FALSE`
  only; default config has `run_grid = TRUE`, so default behavior is provably unchanged
  by TASK-02-05's manifest byte-compare.

### PHASE-03 - Orchestrator: `run_engagement.R`, Step Runner, Package v0.2.0

**Goal**
One command executes the full delivery flow for any engagement config, writing an
engagement-scoped manifest — reusing (not duplicating) `pipeline_refresh.R`'s runner
logic — and the package exports the new core functions.

**Tasks**
- [ ] TASK-03-01: Create `R/step_runner.R` by extracting from
  `scripts/pipeline_refresh.R` (currently lines ≈59–101: `count_rows`, `run_step`, the
  step loop, and manifest assembly): `run_steps()` executes a list of
  `list(name, script, args)` via `system2("Rscript", c(script, args))`, stops after the
  first failure; `write_pipeline_manifest()` emits the existing manifest JSON shape
  (`generated_at` `%Y-%m-%dT%H:%M:%S%z`, `git_sha`, `steps[{name,status,seconds}]`,
  `status`, `row_counts`) plus optional extra top-level fields.
- [ ] TASK-03-02: Refactor `scripts/pipeline_refresh.R` to source `R/step_runner.R`.
  Step lists, `--full` flag, manifest path (`dashboard/data/pipeline_manifest.json`),
  row-count file list, and exit behavior stay byte-for-byte compatible (CON-002): same
  JSON keys, same step names/order/counts (7 + audit default; 10 + audit `--full`).
- [ ] TASK-03-03: Create `scripts/run_engagement.R` — CLI:
  `Rscript scripts/run_engagement.R --config engagements/<slug>/engagement_config.json [--raw-loanbook <path>] [--skip-intake] [--top-n <int>] [--dry-run]`.
  Step list, in order, each step invoked with `--config <effective-config-path>`:
  (1) intake — only when `--raw-loanbook` given and `--skip-intake` absent: run
  `scripts/intake_validate_and_map.R --input <raw> --output-dir engagements/<slug>/intake`
  (+ `--anonymize` when `cfg$anonymize`); then write
  `engagements/<slug>/engagement_config.resolved.json` — a copy of the loaded config
  with `inputs$loanbook_csv` pointed at
  `engagements/<slug>/intake/normalized_loanbook.csv` — and use THAT path for all later
  steps (verify the exact flag names of `intake_validate_and_map.R` at execution time
  and adapt);
  (2) `generate_validation_report` → into `cfg$paths$reports_dir` with the bank name
  (skipped when intake skipped);
  (3) `pacta_vietnam_scenario`; (4) `trisk_prepare_inputs`;
  (5–6) `trisk_sector_demo <s>` for each sector in `cfg$trisk_sectors` (power first for
  continuity with the default pipeline's step naming);
  (7) `trisk_scenario_grid` only when `cfg$run_grid`;
  (8) `sector_prioritization`; (9) `refresh_dashboard_data` (into
  `cfg$paths$snapshot_dir`); (10) `engagement_scoring`;
  (11) `generate_engagement_letters` (pass `--top_n` when given);
  (12) `generate_disclosure_pack`. Manifest →
  `engagements/<slug>/pipeline_manifest.json` via `write_pipeline_manifest(...,
  extra = list(bank_slug = cfg$bank_slug, config_path = <effective path>))`.
  `--dry-run` prints the resolved step list (one `name: script args` line each) and
  exits 0 without executing anything.
- [ ] TASK-03-04: Guard rail in `run_engagement.R`, checked before any step: if
  `cfg$paths$snapshot_dir == "dashboard/data"` and `cfg$bank_slug != "mcb-demo"`, stop
  with `"Engagement snapshot_dir must not be the public dashboard/data"`. Also print a
  banner with the effective config path and effective loanbook path before step 1.
- [ ] TASK-03-05: Package refresh (ASM-006): add `#' @export` roxygen headers to
  `trisk_prepare_sector_inputs`, `trisk_run_sector`, `trisk_run_grid`,
  `prioritize_sectors`, `run_steps`, `write_pipeline_manifest`; regenerate `NAMESPACE`
  (`Rscript -e "roxygen2::roxygenise()"`); bump `DESCRIPTION` `Version:` to `0.2.0`;
  create `NEWS.md` with a 3-bullet 0.2.0 entry (TRISK core, prioritization core,
  engagement orchestrator). Verify
  `Rscript -e "devtools::load_all('.'); stopifnot(is.function(trisk_run_sector), is.function(run_steps))"`.
- [ ] TASK-03-06: Create `tests/testthat/test_step_runner.R` (Test Specs below) and add
  a "Running a client engagement" subsection to `README.md` with the exact command,
  the `--dry-run` tip, and the Rscript-on-PATH note for Windows.

**File Changes**
- `R/step_runner.R` (create): extracted runner + manifest writer, verbatim logic.
- `scripts/pipeline_refresh.R` (modify): source the runner; observable behavior
  unchanged (same steps, same manifest bytes modulo timestamp/sha).
- `scripts/run_engagement.R` (create): orchestrator per TASK-03-03/04.
- `DESCRIPTION` (modify): `Version: 0.2.0` only. `NAMESPACE` (modify): regenerated.
  `NEWS.md` (create).
- `R/trisk_core.R`, `R/prioritization_core.R` (modify): roxygen `@export` headers only.
- `tests/testthat/test_step_runner.R` (create).
- `README.md` (modify): engagement-run subsection; leave the architecture diagram
  intact.

**Function Signatures**
- `run_steps(steps: list, stop_on_failure: logical = TRUE) -> list` — executes each
  `list(name, script, args)` via `system2("Rscript", ...)`; returns per-step
  `list(name, status ("ok"|"failed"), seconds)`; after a failure no further steps run.
- `write_pipeline_manifest(step_results: list, manifest_path: character, row_count_files: character = character(0), extra: list = list()) -> invisible(character)` —
  writes the manifest JSON (existing schema; `extra` merged at top level), returns the
  path.

**Test Specs**
- `run_steps(list(list(name="ok", script=<temp fixture 'quit(status=0)'>, args=character())))`
  → one result with `status == "ok"` and numeric `seconds`; a two-step list whose first
  fixture is `quit(status=1)` → first result `"failed"`, second step never executed
  (list length 1).
- `write_pipeline_manifest(results, tmp, extra=list(bank_slug="x"))` → file parses with
  `jsonlite::read_json`; `$bank_slug == "x"`; keys `generated_at, git_sha, steps,
  status` all present; `status == "failed"` when any step failed.
- `Rscript scripts/pipeline_refresh.R` → `dashboard/data/pipeline_manifest.json` step
  names/order/count identical to the pre-refactor committed manifest;
  `tests/testthat/test_manifest_json.R` and `dashboard/tests/test_manifest.py` pass
  unmodified.
- Guard rail: a temp config with `bank_slug "x-bank"` (snapshot_dir left at default) →
  `Rscript scripts/run_engagement.R --config <tmp> --dry-run` exits non-zero printing
  the guard message.
- Dry run: `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --skip-intake --dry-run`
  → prints the step list (grid step present because MCB has `run_grid true`; intake and
  validation-report steps absent) and exits 0 with nothing written.

**Dependencies**
- PHASE-02 (all steps accept `--config`).

**Exit Criteria**
- [ ] `Rscript scripts/pipeline_refresh.R` behavior verified unchanged (manifest
  key/step diff empty; existing manifest tests green).
- [ ] `--dry-run` produces the documented step list for both MCB and a temp non-MCB
  config; the guard rail blocks non-MCB configs pointing at `dashboard/data`.
- [ ] `Rscript -e "devtools::load_all('.')"` exposes the new functions;
  `Rscript -e "devtools::test()"` green; full Python suite green.

**Phase Risks**
- **RISK-03-01:** `system2("Rscript", ...)` requires `Rscript` on PATH even when the
  outer call used a full path (Windows session fix:
  `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"`). Documented in the README
  subsection; same constraint as `pipeline_refresh.R` today.
- **RISK-03-02:** The resolved-config indirection confuses debugging. Mitigation: the
  TASK-03-04 banner prints the effective config and loanbook paths before any step.

### PHASE-04 - SDB End-to-End Run, Timings, Second Golden Fixture

**Goal**
Run the dirty SDB fixture through the entire engagement flow, fix the zero-match/empty
edge cases it surfaces with small guards, log measured stage timings, and freeze a
second golden-number test set so "works only for MCB" can never silently return.

**Tasks**
- [ ] TASK-04-01: Create `engagements/sdb-rehearsal/engagement_config.json`:
  `bank_name "Saigon Delta Bank"`, `bank_slug "sdb-rehearsal"`, all `inputs` at
  defaults (the orchestrator overrides the loanbook from intake; SDB matches against
  the same synthetic ABCD by fixture design),
  `trisk_sectors ["power","cement","steel"]`, `run_grid false`, `anonymize false`, and
  ALL `paths` rooted under `engagements/sdb-rehearsal/`:
  `pacta_output_dir "engagements/sdb-rehearsal/output/pacta"`,
  `trisk_output_root "engagements/sdb-rehearsal/output/trisk"`,
  `trisk_input_root "engagements/sdb-rehearsal/output/trisk_inputs"`,
  `snapshot_dir "engagements/sdb-rehearsal/snapshot"`,
  `reports_dir "engagements/sdb-rehearsal/reports"`,
  `engagement_output_dir "engagements/sdb-rehearsal/output/engagement"`,
  `letters_output_dir "engagements/sdb-rehearsal/output/engagement_letters"`,
  `disclosure_output_dir "engagements/sdb-rehearsal/output/disclosure"`,
  `prioritization_output_dir "engagements/sdb-rehearsal/output/prioritization"`.
  Add the ASM-007 `.gitignore` patterns.
- [ ] TASK-04-02: Execute from a clean tree:
  `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --raw-loanbook data/fixtures/unseen_bank_loanbook.csv`.
  Expect failures of the class: PACTA sectors with zero matched SDB loans crashing
  chart/summary code (guard: skip the chart and emit a
  "no matched exposure in <sector>" note instead); TRISK sectors with no mapped
  companies (guard: skip the sector with a logged `[NOTE]` line and mark it unavailable
  in the snapshot manifest); empty letter target lists (guard: write zero letters plus
  an index note). Every guard must be behind an emptiness check the MCB path never
  enters, and each fix keeps the full default-mode suite green.
- [ ] TASK-04-03: Append the "Downstream run (2026-07)" section to
  `pilot/rehearsal_log.md` (ASM-008): per-step seconds table read from
  `engagements/sdb-rehearsal/pipeline_manifest.json`, mapped to the proposal milestone
  names (Loanbook received → Validation report returned → Results delivered); every
  friction point fixed in TASK-04-02 with file/line; a verdict sentence replacing the
  old "remaining gap is the full PACTA/TRISK downstream run" statement.
- [ ] TASK-04-04: Commit the SDB artifacts per ASM-007 and create
  `tests/testthat/test_sdb_engagement.R`. Freeze literals FROM THE COMMITTED FILES at
  authoring time (never invent values): assert
  `engagements/sdb-rehearsal/intake/normalized_loanbook.csv` has exactly 13 columns and
  the observed row count; every `loan_size_outstanding_currency == "VND"`;
  `engagements/sdb-rehearsal/output/engagement/engagement_priority.csv` has > 0 rows
  and its rank-1 borrower name equals the observed literal (tolerance ±0.005 on any
  frozen score); `pipeline_manifest.json` has `status == "ok"` and
  `bank_slug == "sdb-rehearsal"`.
- [ ] TASK-04-05: Cross-contamination check immediately after the run:
  `git status --porcelain synthesis_output output dashboard/data reports` → empty (the
  SDB run wrote nothing outside `engagements/sdb-rehearsal/`).

**File Changes**
- `engagements/sdb-rehearsal/engagement_config.json` (create).
- `engagements/sdb-rehearsal/` committed generated artifacts per ASM-007 (create).
- `.gitignore` (modify): ASM-007 engagement patterns.
- `R/pacta_core.R`, `R/trisk_core.R`, `scripts/generate_engagement_letters.R` (modify,
  only as forced by TASK-04-02): zero-match/empty-sector guards behind emptiness checks.
- `pilot/rehearsal_log.md` (modify): append the downstream-run section; existing
  content untouched.
- `tests/testthat/test_sdb_engagement.R` (create).

**Function Signatures**
- None — no new code interfaces; guards are inline conditionals in existing functions.

**Test Specs**
- `Rscript -e "testthat::test_dir('tests/testthat')"` → green including
  `test_sdb_engagement.R` AND the untouched MCB goldens (proves both books coexist).
- `python -c "import json;m=json.load(open('engagements/sdb-rehearsal/pipeline_manifest.json'));print(m['status'],m['bank_slug'])"`
  → `ok sdb-rehearsal`.
- Cross-contamination: `git status --porcelain synthesis_output output dashboard/data reports`
  → empty output.

**Dependencies**
- PHASE-03 (orchestrator).

**Exit Criteria**
- [ ] The SDB `run_engagement.R` invocation exits 0; manifest `status "ok"`.
- [ ] `pilot/rehearsal_log.md` contains measured per-stage timings and the updated
  verdict.
- [ ] `test_sdb_engagement.R` green from committed artifacts; full suites green.
- [ ] The SDB validation report under `engagements/sdb-rehearsal/reports/` opens in a
  browser with "Saigon Delta Bank" branding and the synthetic-data disclaimer footer.

**Phase Risks**
- **RISK-04-01:** The SDB book's sector mix surfaces divide-by-zero or empty-tibble
  crashes deep in analysis code beyond what guards can absorb. Mitigation: guards are
  permitted; anything structural gets logged in `pilot/rehearsal_log.md` as a named
  backlog item for a follow-on plan rather than force-fixed here.
- **RISK-04-02:** Fixture outputs mistaken for a real bank's. Mitigation: "Saigon Delta
  Bank" is fictional; CON-004 disclaimers must render in the validation report and
  disclosure pack (verify visually).

### PHASE-05 - Data Closers: ABCD Brief, Intake Contract, Scenario Versioning, NA Fixes

**Goal**
Close the two week-one external dependencies of a real engagement (ABCD sourcing
decision, ABCD intake contract), make scenario vintages explicit and auditable, and fix
the two known NA-producing bugs — then refreeze goldens once.

**Tasks**
- [ ] TASK-05-01: Write `docs/abcd_sourcing_decision.md` (~2–3 pages): the problem (a
  real loanbook must match against real asset-based company data;
  `data/vietnam_abcd.csv` is synthetic and MCB-shaped); Option A — Asset Impact license
  (per-sector Vietnam coverage: power/automotive strong, cement/steel partial; cost per
  ASM-009; lead time); Option B — self-collected (EVN/GENCO annual reports, Global
  Energy Monitor coal/gas/steel plant trackers, VNSTEEL/VICEM disclosures; per-sector
  effort estimate; GEM licensing/attribution constraints); Option C — hybrid (license
  power/automotive, self-build cement/steel). Include a per-sector coverage table, a
  recommendation (hybrid unless the engagement is power-only), and the trigger point
  ("decide before signing the data-phase start date in any real proposal"). This task
  has no code dependency and may be executed at any point during the plan.
- [ ] TASK-05-02: ABCD intake contract: append an "ABCD (asset-based company data)
  table" section to `intake/SCHEMA.md` mirroring the loanbook contract's style —
  required columns matching `data/vietnam_abcd.csv`'s actual header (verify with the
  file; document each column's type and units) plus provenance columns `data_source`
  (character) and `as_of_year` (integer year). Create
  `intake/templates/abcd_template.csv` (header + 3 illustrative synthetic rows) and add
  one line to the templates README naming it (check whether the README is
  `intake/templates/README_vi.md` or similar and edit the one that exists).
- [ ] TASK-05-03: Scenario versioning: create `data/scenarios/pdp8-2023/` containing
  copies of `vietnam_scenario_ms.csv` and `vietnam_scenario_co2.csv`; change
  `R/engagement_config.R` defaults `inputs$scenario_ms_csv` /
  `inputs$scenario_co2_csv` to `"data/scenarios/pdp8-2023/vietnam_scenario_ms.csv"` /
  `"data/scenarios/pdp8-2023/vietnam_scenario_co2.csv"`; update
  `engagements/mcb-demo/engagement_config.json` and any test literal asserting the old
  default paths (check `tests/testthat/test_engagement_config.R`). Keep
  `scripts/generate_vietnam_data.R` writing BOTH the legacy `data/` paths and the
  versioned dir (one extra `readr::write_csv` each) so nothing else breaks. Record the
  two scenario file paths + md5 checksums in the refresh audit
  (`scripts/generate_refresh_audit.R`: add them to the metrics JSON and audit HTML).
  Add a "Scenario vintages" note (directory convention
  `data/scenarios/<source>-<year>/`) to `README.md` or
  `docs/trisk_scenario_grid_contract.md`. Add one assertion to
  `tests/testthat/test_snapshot_contract.R`:
  `tools::md5sum("data/vietnam_scenario_ms.csv") == tools::md5sum("data/scenarios/pdp8-2023/vietnam_scenario_ms.csv")`.
- [ ] TASK-05-04: Dung Quat zero-baseline fix in the TRISK input prep (now in
  `R/trisk_core.R`): add helper `backfill_zero_baseline()` (signature below); apply it
  where per-asset production/capacity trajectories are assembled, so an asset whose
  baseline-year value is 0 (pre-commissioning, e.g. "Dung Quat LNG Power Consortium",
  id `VN_ABCD_006`) gets its baseline backfilled from the first non-zero year and a
  `baseline_note = "backfilled_first_operating_year"` column; assets with all-zero
  trajectories are excluded with a printed `[NOTE]` line. Confirm downstream TRISK
  sensitivity outputs contain no NA rows for that company after a rerun.
- [ ] TASK-05-05: Power-2025 NA fix in `scripts/generate_vietnam_data.R` per ASM-011:
  backfill the NA 2025 projected power values with the modeled 2025 value using the
  interpolation already used for scenario anchors; regenerate and confirm the PACTA
  power techmix output has no NA 2025 rows.
- [ ] TASK-05-06: Golden refreeze per ASM-010: `Rscript scripts/pipeline_refresh.R
  --full` to green; inspect the CSV diff; update changed literals in
  `tests/testthat/test_golden_numbers.R` from the newly committed files; rerun the SDB
  engagement (its scenario inputs changed via the new default paths — same underlying
  values, but confirm) and refreeze `test_sdb_engagement.R` if any value moved; state
  the refreeze explicitly in the commit message.

**File Changes**
- `docs/abcd_sourcing_decision.md` (create): decision brief per TASK-05-01.
- `intake/SCHEMA.md` (modify): append the ABCD section; loanbook section untouched.
- `intake/templates/abcd_template.csv` (create); templates README (modify): one line.
- `data/scenarios/pdp8-2023/vietnam_scenario_ms.csv`,
  `data/scenarios/pdp8-2023/vietnam_scenario_co2.csv` (create, generated copies).
- `scripts/generate_vietnam_data.R` (modify): dual-write scenario CSVs; 2025 power
  backfill.
- `R/engagement_config.R` (modify): scenario input defaults → versioned paths.
- `engagements/mcb-demo/engagement_config.json` (modify): mirror the new paths.
- `R/trisk_core.R` (modify): `backfill_zero_baseline()` + application at trajectory
  assembly.
- `scripts/generate_refresh_audit.R` (modify): scenario paths + checksums in metrics
  JSON and audit HTML.
- `tests/testthat/test_engagement_config.R`, `tests/testthat/test_snapshot_contract.R`
  (modify): updated default-path literal + dual-copy checksum assertion.
- `tests/testthat/test_trisk_input_prep.R` (create): backfill unit tests.
- `tests/testthat/test_golden_numbers.R`, `tests/testthat/test_sdb_engagement.R`
  (modify): refrozen literals only, per ASM-010.

**Function Signatures**
- `backfill_zero_baseline(assets: tbl, value_col: character, year_col: character = "year") -> tbl` —
  returns the assets table with each asset whose earliest-year value is 0 given the
  first non-zero year's value for all leading zero years, plus a `baseline_note`
  character column (`"backfilled_first_operating_year"` on touched rows, `NA`
  otherwise); assets with all-zero values are dropped from the returned table.

**Test Specs**
- `backfill_zero_baseline(tibble(company="X", year=2025:2027, capacity=c(0,0,500)), "capacity")`
  → 2025 and 2026 capacity become 500; `baseline_note == "backfilled_first_operating_year"`
  on those rows.
- Same call with `capacity=c(0,0,0)` → company X absent from the result (0 rows).
- Same call with `capacity=c(100,200,300)` → values unchanged, `baseline_note` all `NA`.
- After TASK-05-04 + rerun: filtering the power TRISK sensitivity CSV for "Dung Quat"
  shows no NA values in the numeric result columns.
- After TASK-05-05 + refresh:
  `python -c "import pandas as pd; d=pd.read_csv('dashboard/data/pacta/04_vn_ms_portfolio.csv'); print(d[d.year==2025].isna().sum().sum())"`
  → `0` (adjust the file/column to where the NA actually lived, per ASM-011).
- TASK-05-03 checksum assertion green; full suites green after TASK-05-06.

**Dependencies**
- PHASE-04 (SDB goldens exist and must be re-checked after refreeze). TASK-05-01 and
  TASK-05-02 have no dependencies and may run any time.

**Exit Criteria**
- [ ] `docs/abcd_sourcing_decision.md` and the ABCD intake section + template exist and
  cross-link.
- [ ] Config defaults reference `data/scenarios/pdp8-2023/`; the refresh audit records
  scenario checksums; the dual-copy checksum test is green.
- [ ] No NA rows for Dung Quat in shipped TRISK sensitivity outputs; no NA 2025 power
  rows in the PACTA outputs.
- [ ] `Rscript scripts/pipeline_refresh.R --full` green; both golden sets green against
  refrozen literals; `python -m pytest dashboard/tests` green.

**Phase Risks**
- **RISK-05-01:** The 2025 backfill visibly changes numbers on the public app.
  Mitigation: that is the intended fix of a known demo distraction; the refresh audit
  documents the delta and the commit message explains it (ASM-010).
- **RISK-05-02:** Dual-written scenario CSVs drift if someone edits only one copy.
  Mitigation: both come from the same generator run; the TASK-05-03 checksum assertion
  fails loudly on drift.

## Gotchas

- **VND is never rescaled.** Loanbook money (`loan_size_outstanding`, literal `VND`)
  spans 1e5–5e12 raw. No moved function may divide/multiply it except where the original
  code already did for display (copy such arithmetic verbatim).
- **Byte-identity applies to CSVs only.** PNGs differ run-to-run (compression); HTML
  reports differ in generated-timestamp text. Never chase PNG/HTML hashes.
- **Run every command from the repo root.** All scripts resolve paths via `getwd()`;
  `tests/testthat/helper-root.R` walks upward looking for a `dashboard/` directory.
- **`source()` and package-load must both keep working.** Keep top-of-file
  `library()`/`requireNamespace()` guards in `R/` files; roxygen `@export` tags only,
  never `@import`/`@importFrom` (they break standalone sourcing).
- **`yaml` is deliberately not a dependency** — configs are JSON via `jsonlite`. Do not
  add any new pipeline dependency; the analysis stack is pinned in `renv.lock`.
- **`system2("Rscript", ...)` needs `Rscript` on PATH** even when the outer call used a
  full path. Windows session fix: `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"`.
- **PowerShell 5.1 has no `&&`** — chain with `;`; the Bash-style commands in this plan
  run as-is only in Git Bash/Linux; prefer the portable `Rscript -e "..."` one-liners.
- **`clear_dir()` wipes the snapshot tree on every refresh** — never hand-place files
  under any `snapshot_dir`; the refresh script must re-copy everything each run.
- **Manifest-shape lock:** `tests/testthat/test_manifest_json.R` and
  `dashboard/tests/test_manifest.py` pin the default manifest keys/steps — the
  step-runner extraction must not rename or reorder anything in default mode.
- **`dashboard/tests/test_loaders.py:66` asserts exactly 243 power grid scenarios** —
  do not change grid lever ranges anywhere in this plan.
- **Engagement scoring reads from the snapshot (`snapshot_dir/trisk/...`), not
  `synthesis_output/`** — in the orchestrator it must run AFTER the snapshot copy step
  (enforced by the PHASE-03 step order).
- **Golden literals come from committed files, never from plan text** — when authoring
  `test_sdb_engagement.R` or refreezing `test_golden_numbers.R`, open the committed CSV
  and freeze what is actually there.
- **Weekly CI auto-commits to `main`** (Mondays 02:00 UTC, test-gated): a red testthat
  suite blocks the publish by design — fix the cause, never bypass the gate. Land each
  phase only when its exit criteria pass, so the Monday run never sees a half-migrated
  pipeline.
- **`attic/` and `dashboard/data/` are do-not-touch** (except `refresh_dashboard_data.R`
  writing the latter); synthetic-data disclaimers must survive every generator change.
- **Vietnamese diacritics:** author any new CSV as UTF-8 without BOM; the intake reader
  falls back to latin1 which silently mangles diacritics.

## Verification Strategy

- **TEST-001 (PHASE-01 baseline):** run `Rscript scripts/pipeline_refresh.R` twice on
  the untouched tree, hashing after each run per TASK-01-01 → the diff of the two hash
  files defines the volatile list (expected: empty or very small).
- **TEST-002 (PHASE-01 byte-identity):** after the refactor,
  `Rscript -e "f<-sort(list.files(c('synthesis_output/trisk','synthesis_output/prioritization','synthesis_output/vietnam','output/trisk_inputs','dashboard/data'),pattern='[.]csv$',recursive=TRUE,full.names=TRUE)); now<-paste(tools::md5sum(f),f); base<-readLines('trisk_baseline_run1.txt'); drift<-setdiff(now,base); if(length(drift)) stop(paste(c('DRIFT:',drift),collapse='\n')) else cat('BYTE-IDENTICAL:',length(f),'CSVs\n')"`
  → prints `BYTE-IDENTICAL` (volatile-list files excluded per ASM-003).
- **TEST-003 (all phases):** `Rscript -e "testthat::test_dir('tests/testthat')"` → all
  green, 0 failures.
- **TEST-004 (all phases):** `python -m pytest dashboard/tests` → all green.
- **TEST-005 (PHASE-03):** `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --raw-loanbook data/fixtures/unseen_bank_loanbook.csv --dry-run`
  → prints the resolved step list (grid step absent because `run_grid` is false) and
  exits 0 without executing.
- **TEST-006 (PHASE-03):** `Rscript -e "devtools::load_all('.'); stopifnot(is.function(trisk_run_sector), is.function(prioritize_sectors), is.function(run_steps))"`
  → exits 0.
- **TEST-007 (PHASE-04):** `python -c "import json;m=json.load(open('engagements/sdb-rehearsal/pipeline_manifest.json'));print(m['status'],m['bank_slug'])"`
  → `ok sdb-rehearsal`.
- **TEST-008 (PHASE-04):** `git status --porcelain synthesis_output output dashboard/data reports`
  immediately after the SDB run → empty output.
- **TEST-009 (PHASE-05):** `Rscript -e "stopifnot(tools::md5sum('data/vietnam_scenario_ms.csv') == tools::md5sum('data/scenarios/pdp8-2023/vietnam_scenario_ms.csv'))"`
  → exits 0.
- **MANUAL-001 (PHASE-01):** open 2–3 regenerated PNGs under
  `synthesis_output/trisk/power_demo/` — charts render with "Mekong Commercial Bank"
  titling where present.
- **MANUAL-002 (PHASE-04):** open the SDB validation report HTML — "Saigon Delta Bank"
  branding + synthetic-data footer.
- **MANUAL-003 (PHASE-05):** `python -m streamlit run dashboard/app.py`, open the PACTA
  page — the power techmix panel shows populated 2025 bars.
- **OBS-001:** after the next Monday 02:00 UTC scheduled refresh, confirm the bot
  commit exists, the gating tests passed in the Actions log, and (post-PHASE-05) the
  audit HTML includes the scenario checksums.

## Risks and Alternatives

- **RISK-001:** A partial merge leaves the weekly auto-commit CI running against
  inconsistent scripts. Mitigation: land each phase as one commit/PR only after its
  exit criteria pass; the test gate blocks a red publish either way.
- **RISK-002:** Byte-identity proves impossible for some TRISK CSV due to latent
  nondeterminism. Mitigation: the double-baseline (TEST-001) separates pre-existing
  volatility from refactor-caused drift; genuinely volatile files get the documented
  ASM-003 exclusion, never a silent re-baseline.
- **RISK-003:** The SDB run exposes structural assumptions guards can't absorb.
  Mitigation: PHASE-04 explicitly permits observation-plus-guard fixes only; anything
  structural is logged as a named backlog item in `pilot/rehearsal_log.md` for a
  follow-on plan.
- **ALT-001:** Parameterize the TRISK scripts first and decompose later (two passes) —
  rejected: both passes touch the same ~1,300 lines under the same byte-identity gate;
  the merged pass halves the risk exposure and matches the proven `pacta_core` pattern.
- **ALT-002:** Have `run_engagement.R` call `Rscript` per step (pure script chaining)
  versus calling package functions in-process — chosen: **script chaining via
  `run_steps()`**, because per-step process isolation preserves today's failure
  semantics, keeps memory bounded across the TRISK runs, and reuses the proven
  `pipeline_refresh.R` mechanism; the package functions are still the substrate the
  scripts call.
- **ALT-003:** Skip the SDB golden fixture and rely on MCB goldens — rejected: MCB
  goldens cannot detect "works only for MCB" regressions, which is the exact failure
  mode multi-bank parameterization introduces.
- **ALT-004:** Version scenarios by renaming the existing `data/vietnam_scenario_*.csv`
  files in place — rejected: many scripts and docs reference the legacy paths; dual-write
  plus a checksum guard achieves auditability with zero breakage.

## Suggested Next Step

Execute PHASE-01. Its first task (the double baseline) must run on a clean tree BEFORE
any code changes; everything after is gated by the byte-identity comparison. Each
phase's exit criteria are shell-verifiable before the next begins. After this plan
lands, the natural follow-ons (separate plans) are the credibility wave: the
multi-scenario traffic-light matrix, the executive summary generator, and automotive
TRISK.
