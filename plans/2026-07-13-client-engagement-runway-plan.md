---
title: "Client Engagement Runway: Config-Driven Pipeline & Second-Bank Run"
date: "2026-07-13"
status: "complete — bulk-corrected 2026-07-31 per directive: plan predates 2026-07-20 and is presumed fully implemented (NOT individually verified against git/code evidence)"
request: "Turn research/2026-07-13-client-engagement-runway-brainstorm.md into a multi-phase plan: engagement-config refactor, shared R core, run_engagement orchestrator, SDB end-to-end run, then dependency/methodology follow-ons"
plan_type: "multi-phase"
research_inputs:
  - "research/2026-07-13-client-engagement-runway-brainstorm.md"
  - "research/2026-07-10-real-data-readiness-and-hardening-brainstorm.md"
---

# Plan: Client Engagement Runway: Config-Driven Pipeline & Second-Bank Run

## Objective

Make "run the whole PACTA + TRISK platform on a new bank's loanbook and produce their private deliverables, in one command" a demonstrated capability. Today the analytics pipeline runs only on the hand-built synthetic Mekong Commercial Bank (MCB) CSVs — every input path, output directory, and bank name is hardcoded — so the pilot proposal's milestone "PACTA + TRISK results delivered" cannot actually be exercised for any other bank. This plan introduces an engagement-config layer, extracts the duplicated R core, adds a `run_engagement.R` orchestrator, completes the deferred Saigon Delta Bank (SDB) end-to-end dress rehearsal, and then closes the two hard external dependencies (real ABCD data sourcing, ABCD intake contract) plus two known methodology NA bugs.

## Context Snapshot

- **Current state:** Demo-complete, hardened platform for the synthetic MCB book. R pipeline (`scripts/*.R`) → snapshot (`dashboard/data/`, 3 MB) → public Streamlit app. Refresh automation verified (weekly CI, `pipeline_manifest.json`, test-gated auto-commit); `renv.lock` pins R deps; `tests/testthat/` holds golden-number/contract tests; a dirty 40-row SDB fixture (`data/fixtures/unseen_bank_loanbook.csv`) has been run through intake validation, anonymization, and a client-grade validation report (`pilot/rehearsal_log.md`). BUT: `scripts/pacta_vietnam_scenario.R` (1,385 lines) hardcodes `data/vietnam_*.csv` inputs, `synthesis_output/vietnam/` outputs, and "Mekong Commercial Bank" report copy (8 occurrences), with no CLI args; the TRISK chain and downstream generators inherit the same fixed paths; ~3,100 lines of PACTA logic are triplicated across `pacta_demo.R` / `pacta_synthesis.R` / `pacta_vietnam_scenario.R`; TRISK sector metadata lives in two hand-synced structures (`trisk_sector_demo.R` and `refresh_dashboard_data.R`); the SDB fixture's downstream PACTA/TRISK run was explicitly deferred (rehearsal log verdict).
- **Desired state:** An `engagements/<bank-slug>/` convention with a JSON config that parameterizes bank name, input files, sectors in scope, and output/snapshot directories; a shared `R/` core (config loader, sector registry, report toolkit, matching helpers, step runner) sourced by thin scripts; `scripts/run_engagement.R` executing intake → validation report → PACTA → TRISK → prioritization → snapshot → engagement scoring → letters → disclosure pack for any engagement config; the SDB fixture run end-to-end with measured stage timings appended to `pilot/rehearsal_log.md`; a second golden-number test set frozen from the SDB outputs; an ABCD sourcing decision brief, an ABCD intake schema, versioned scenario inputs, and the Dung Quat LNG / power-2025 NA bugs fixed. The MCB demo remains the default: with no `--config` flag every script behaves byte-identically (CSV-level) to today, so existing golden tests, `pipeline_refresh.R`, and `.github/workflows/refresh.yml` keep passing unchanged.
- **Key repo surfaces:** `scripts/pacta_vietnam_scenario.R`, `scripts/trisk_prepare_inputs.R`, `scripts/trisk_power_demo.R`, `scripts/trisk_sector_demo.R`, `scripts/trisk_scenario_grid.R`, `scripts/sector_prioritization.R`, `scripts/refresh_dashboard_data.R`, `scripts/engagement_scoring.R`, `scripts/generate_engagement_letters.R`, `scripts/generate_disclosure_pack.R`, `scripts/generate_validation_report.R`, `scripts/intake_validate_and_map.R`, `scripts/pipeline_refresh.R`, `tests/testthat/`, `data/fixtures/unseen_bank_loanbook.csv`, `intake/SCHEMA.md`, `pilot/rehearsal_log.md`, `docs/`.
- **Out of scope:** Automotive TRISK sector addition; steel synthetic-book enrichment; Vietnamese dashboard i18n; PDF export; pricing content; `targets` pipeline migration; real bank data execution (fixtures only); any change to synthetic-data disclaimers; renaming existing pipeline script files; multi-tenant SaaS or real auth.

## Environment & Conventions

- **Stack:** R 4.5.2 driving the analytics pipeline via `Rscript` (Windows local: `C:\Program Files\R\R-4.5.2\bin\Rscript.exe`; Linux/CI: plain `Rscript`); renv lockfile (`renv.lock`) pins: arrow, base64enc, dplyr, fs, ggplot2, ggrepel, jsonlite, pacta.loanbook, purrr, r2dii.analysis/data/match/plot, readr, rlang, scales, stringi, tibble, tidyr, trisk.model, xfun, testthat. **`yaml` is NOT in the lockfile.** Python 3.11+ with Streamlit, pandas, plotly, pyarrow, openpyxl, pytest for the dashboard.
- **Setup (Python):** `python -m pip install -r dashboard/requirements.txt`
- **Setup (R):** packages already installed locally; fresh machines: `Rscript scripts/ci/install_deps.R` (no-renv fallback) or `Rscript -e "renv::restore()"`. Note: `.Rprofile` renv auto-activation is commented out for local development; CI restores via `r-lib/actions/setup-renv@v2`.
- **Build / Run:** full MCB pipeline: `Rscript scripts/pipeline_refresh.R` (add `--full` to prepend data generation + PACTA and append engagement scoring). Dashboard: `python -m streamlit run dashboard/app.py`. Always run every command from the repo root — all R scripts resolve paths via `getwd()`.
- **Test:** R: `Rscript -e "testthat::test_dir('tests/testthat')"`. Python: `python -m pytest dashboard/tests` — single test: `python -m pytest dashboard/tests/test_loaders.py::test_name -v`.
- **Conventions & traps:** All loanbook money is raw VND (column `loan_size_outstanding`, currency literal `VND`; magnitudes 1e5–5e12 across files — never rescale). Vietnamese names carry diacritics; matching normalizes via `stringi::stri_trans_general(x, "Latin-ASCII")`. CSVs are UTF-8 (no BOM). Existing CLI convention in R scripts: `args <- commandArgs(trailingOnly = TRUE)` with a local `get_arg <- function(flag, default = NULL)` helper scanning for `--flag value` pairs (see `scripts/intake_validate_and_map.R:24-36` and `scripts/generate_validation_report.R:16-26`); boolean flags via `"--flag" %in% args`. `scripts/trisk_sector_demo.R` takes one positional arg (sector name, default `"power"`). Windows PowerShell 5.1 has no `&&` chaining. Env flags gating dashboard features: `BYOL_INTAKE=1`, `OUTPUTS_LAYER=1`, `TRISK_LIVE_RERUN=1`, `R_RSCRIPT`, `DEMO_PASSWORD`.
- **Repo map:**
  - `scripts/` — all R pipeline stages + `pipeline_refresh.R` orchestrator + `ci/install_deps.R`
  - `data/` — synthetic MCB inputs (`vietnam_loanbook.csv`, `vietnam_abcd.csv`, `vietnam_scenario_ms.csv`, `vietnam_scenario_co2.csv`, `vietnam_region_isos.csv`) + generator + `fixtures/unseen_bank_loanbook.csv`
  - `synthesis_output/` — pipeline outputs (`vietnam/` PACTA, `trisk/<sector>_demo/`, `trisk/grid/<sector>/`)
  - `output/` — TRISK prepared inputs (`trisk_inputs/<sector>_demo/`), engagement outputs (`engagement/`, `engagement_letters/`, `disclosure/`)
  - `dashboard/` — Streamlit app (`app.py`, `pages/`, `lib/`, `tests/`, snapshot `data/`)
  - `intake/` — BYOL schema (`SCHEMA.md`), templates, validator outputs (`output*/`)
  - `tests/testthat/` — R suite (`helper-root.R` locates repo root by finding a `dashboard/` dir upward from `getwd()`)
  - `pilot/`, `docs/`, `plans/`, `reports/`, `research/` — sales pack, docs, plan artifacts, rendered reports, briefs

## Research Inputs

- From `research/2026-07-13-client-engagement-runway-brainstorm.md`:
  - The one undemonstrable proposal promise is "PACTA + TRISK results delivered": the platform has never run analytics on any loanbook except MCB's; `pacta_vietnam_scenario.R` has no `commandArgs` handling and hardcodes everything. The engagement-config refactor, shared-core extraction, and deferred SDB downstream run should be one coherent move — doing them separately touches the same ~3,100 lines twice.
  - The intake validator's `normalized_loanbook.csv` has **exactly the same 13 columns** as `data/vietnam_loanbook.csv` (`id_loan, id_direct_loantaker, name_direct_loantaker, id_ultimate_parent, name_ultimate_parent, loan_size_outstanding, loan_size_outstanding_currency, loan_size_credit_limit, loan_size_credit_limit_currency, sector_classification_system, sector_classification_direct_loantaker, lei_direct_loantaker, isin_direct_loantaker`) — downstream compatibility is by construction.
  - The SDB fixture was designed so ~28 clean rows reuse company names present in `data/vietnam_abcd.csv` (EVN subsidiaries, VinFast, THACO, VICEM, Hoa Phat, Vinacomin), so PACTA matching demonstrably succeeds against the existing synthetic ABCD; 3 rows are deliberately unmatchable.
  - Acceptance bar for the refactor: refactor under green golden tests with **byte-identical MCB CSV outputs**; PNGs compared visually only (compression nondeterminism), HTML reports allowed to differ only in generated-timestamp text.
  - Deferred-and-stays-deferred: `targets` migration, automotive TRISK (follow-on plan), steel enrichment, VN toggle, multi-tenant auth.
- From `research/2026-07-10-real-data-readiness-and-hardening-brainstorm.md`:
  - C4 (shared R core: report toolkit copy-pasted across six generators, diacritic matching in four places, TRISK sector metadata duplicated in two hand-synced structures) and C5 (run configuration scattered: shock year 2028, discount 0.08, prioritization weights, snapshot file lists) were identified and deferred — this plan implements both.
  - The rehearsal log's own verdict: "The remaining gap is the full PACTA/TRISK downstream run on the normalized fixture loanbook, which requires parameterizing the pipeline scripts."
  - D5 (real ABCD sourcing decision brief: Asset Impact license vs self-collected from EVN/GENCO reports and Global Energy Monitor trackers) remains unwritten and blocks the commercial conversation for any real engagement.

## Assumptions and Constraints

- **ASM-001:** Engagement config format — **BINDING DEFAULT:** JSON parsed with `jsonlite::read_json(path, simplifyVector = TRUE)`. `yaml` is not in `renv.lock`; do NOT add a new package dependency for configuration.
- **ASM-002:** Script filenames — **BINDING DEFAULT:** keep all existing script filenames (`pacta_vietnam_scenario.R` etc.). `pipeline_refresh.R`, `.github/workflows/refresh.yml`, `dashboard/lib/live_rerun.py`, and docs reference them; renaming is churn with no functional gain.
- **ASM-003:** Where retired scripts go — **BINDING DEFAULT:** `git mv scripts/pacta_demo.R attic/pacta_demo.R` and `git mv scripts/pacta_synthesis.R attic/pacta_synthesis.R` (create `attic/` with a 3-line README saying these are superseded methodology references, not maintained, not part of any pipeline). Do not delete; their rendered reports in `reports/` stay.
- **ASM-004:** How scripts receive the config — **BINDING DEFAULT:** every parameterized script accepts `--config <path>`; when absent, `load_engagement_config(NULL)` returns defaults reproducing today's MCB paths exactly. `scripts/trisk_sector_demo.R` keeps its positional sector arg and additionally accepts `--config`.
- **ASM-005:** Engagement grid runs — **BINDING DEFAULT:** the 243-cell scenario grid is opt-in per engagement (`run_grid: false` default in engagement configs); the public MCB pipeline (`pipeline_refresh.R`) keeps running the grid exactly as today. Rationale: grid runtime dominates the pipeline and the Scenario Builder page is optional for a private instance.
- **ASM-006:** What SDB outputs get committed — **BINDING DEFAULT:** commit under `engagements/sdb-rehearsal/`: `engagement_config.json`, `intake/normalized_loanbook.csv`, `output/engagement/engagement_priority.csv`, `output/trisk/<sector>_demo/npv_results_latest.csv` and `company_summary.csv` per sector, and `pipeline_manifest.json`. Gitignore everything else under `engagements/*/` (PNGs, HTML, letters, disclosure, snapshot) via `.gitignore` patterns `engagements/*/snapshot/`, `engagements/*/reports/`, `engagements/*/output/**/figures/`, `engagements/*/output/engagement_letters/`, `engagements/*/output/disclosure/`.
- **ASM-007:** `data/vietnam_trisk_*.csv` side copies — **BINDING DEFAULT:** `trisk_prepare_inputs.R` currently writes duplicates to both `data/vietnam_trisk_*.csv` and `output/trisk_inputs/<sector>_demo/`. Before changing anything run `grep -rn "vietnam_trisk_" scripts/ dashboard/ tests/ --include="*.R" --include="*.py"`; if nothing outside `trisk_prepare_inputs.R` reads the `data/` copies, write them only in default (MCB, no-config) mode and skip them for engagement runs. If something reads them, mirror them into the engagement's `trisk_input_root` instead.
- **ASM-008:** SDB "measured turnaround" documentation location — **BINDING DEFAULT:** append a "Downstream run (2026-07)" section to `pilot/rehearsal_log.md`; do NOT edit the `{{DATE_n}}` placeholders in `pilot/real_data_phase_proposal.md` (that file is a client-tailoring template).
- **ASM-009:** ABCD sourcing brief pricing figures — **BINDING DEFAULT:** where Asset Impact license costs are not publicly verifiable, state ranges as "to be confirmed with vendor" rather than inventing numbers; the brief's deliverable is the decision framework and per-sector coverage assessment, not a quote.
- **ASM-010:** Golden-number updates after PHASE-06 methodology fixes — **BINDING DEFAULT:** the Dung Quat and power-2025 fixes are expected to change some TRISK/PACTA outputs. After a verified full rerun (`Rscript scripts/pipeline_refresh.R --full` exits 0), re-freeze affected literals in `tests/testthat/test_golden_numbers.R` and `tests/testthat/test_sdb_engagement.R` from the newly committed CSVs, and say so in the commit message. Never adjust goldens without a green full pipeline run.
- **CON-001:** With no `--config` flag, every script's observable behavior (paths written, CSV bytes, manifest shape) must remain identical to today — the weekly auto-commit CI, golden tests, and the public app depend on it.
- **CON-002:** Streamlit Community Cloud has no R runtime; nothing in `dashboard/` may require R at render time unless env-gated off by default. `run_engagement.R` is operator-side only.
- **CON-003:** Everything bank-visible keeps synthetic/illustrative-data disclaimers intact; the SDB engagement outputs are synthetic and must say so.
- **CON-004:** `tests/testthat/test_manifest_json.R` and `dashboard/tests/test_manifest.py` assert on the current `pipeline_manifest.json` shape and step count — the step-runner extraction must not change the default manifest schema or step list.
- **DEC-001:** MCB stays the default engagement; `engagements/mcb-demo/engagement_config.json` exists as documentation of the defaults but nothing in the default pipeline requires reading it.
- **DEC-002:** The composite engagement score stays fixed 50/50 (alignment vs TRISK) with renormalization for TRISK-uncovered sectors, per `scripts/engagement_scoring.R` header — this plan does not touch scoring math.

## Phase Summary

| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Engagement config layer + sector registry (single source of truth) | None | `R/engagement_config.R`, `R/sector_registry.R`, `engagements/mcb-demo/engagement_config.json`, config tests |
| PHASE-02 | Shared R core + PACTA parameterization, byte-identical MCB | PHASE-01 | `R/report_toolkit.R`, `R/matching_helpers.R`, config-driven `pacta_vietnam_scenario.R`, `attic/` retirement |
| PHASE-03 | Parameterize the TRISK chain + downstream generators | PHASE-01, PHASE-02 | All TRISK/prioritization/engagement/letters/disclosure/snapshot scripts accept `--config` |
| PHASE-04 | `run_engagement.R` orchestrator + shared step runner + engagement manifest | PHASE-03 | `R/step_runner.R`, `scripts/run_engagement.R`, refactored `pipeline_refresh.R` (behavior unchanged) |
| PHASE-05 | SDB end-to-end run, rehearsal log timings, second golden fixture | PHASE-04 | `engagements/sdb-rehearsal/` committed outputs, updated `pilot/rehearsal_log.md`, `tests/testthat/test_sdb_engagement.R` |
| PHASE-06 | Data-dependency briefs + scenario versioning + NA bug fixes | PHASE-05 | `docs/abcd_sourcing_decision.md`, ABCD intake schema + template, `data/scenarios/pdp8-2023/`, Dung Quat + power-2025 fixes, refrozen goldens |

## Detailed Phases

### PHASE-01 - Engagement Config Layer & Sector Registry

**Goal**
Create the configuration substrate every later phase builds on: a JSON engagement config with an R loader whose no-config defaults reproduce today's MCB paths exactly, plus a single sector-metadata registry replacing the two hand-synced copies.

**Tasks**
- [ ] TASK-01-01: Create `R/engagement_config.R` with `load_engagement_config()` and `get_config_arg()` (signatures below). Defaults (returned when `config_path` is `NULL`) must be exactly: `bank_name = "Mekong Commercial Bank"`, `bank_slug = "mcb-demo"`, `inputs$loanbook_csv = "data/vietnam_loanbook.csv"`, `inputs$abcd_csv = "data/vietnam_abcd.csv"`, `inputs$scenario_ms_csv = "data/vietnam_scenario_ms.csv"`, `inputs$scenario_co2_csv = "data/vietnam_scenario_co2.csv"`, `inputs$region_isos_csv = "data/vietnam_region_isos.csv"`, `trisk_sectors = c("power", "cement", "steel")`, `run_grid = TRUE`, `paths$pacta_output_dir = "synthesis_output/vietnam"`, `paths$trisk_output_root = "synthesis_output/trisk"`, `paths$trisk_input_root = "output/trisk_inputs"`, `paths$snapshot_dir = "dashboard/data"`, `paths$reports_dir = "reports"`, `paths$engagement_output_dir = "output/engagement"`, `paths$letters_output_dir = "output/engagement_letters"`, `paths$disclosure_output_dir = "output/disclosure"`, `anonymize = FALSE`. When a config file IS given, missing keys fall back to these defaults (recursive `modifyList` over the default list), and every relative path is interpreted from the repo root (`getwd()`).
- [ ] TASK-01-02: Validate on load: `bank_name` and `bank_slug` non-empty; every file in `inputs` exists (`stop()` listing all missing ones at once); `trisk_sectors` ⊆ `c("power", "cement", "steel")` (until new sectors exist); `bank_slug` matches `^[a-z0-9-]+$`.
- [ ] TASK-01-03: Create `engagements/mcb-demo/engagement_config.json` containing exactly the default values from TASK-01-01 (documentation-by-example; the default pipeline never reads it).
- [ ] TASK-01-04: Create `R/sector_registry.R` with `sector_registry()` returning ONE tibble merging the two duplicated metadata sources: from `scripts/refresh_dashboard_data.R:96-101` the columns `sector, label, folder, price_unit, pathway_unit, alignment_mode, grid_available, disclaimer`, and from `scripts/trisk_sector_demo.R:26-60` (the `trisk_sector_meta` list) the columns `title, subtitle, scenario_geography, carbon_price_model, baseline_scenario, target_scenario, company_aliases` (store `company_aliases` as a list-column). Also move `trisk_base_params` (shock_year 2028, discount_rate 0.08, risk_free_rate 0.03, growth_rate 0.02, div_netprofit_prop_coef 1, market_passthrough 0.25, show_params_cols TRUE) into this file as `trisk_base_params()`. Copy values verbatim — this task moves data, it must not change any value.
- [ ] TASK-01-05: Point both consumers at the registry: in `scripts/trisk_sector_demo.R` replace the `trisk_sector_meta` list and `trisk_base_params` literal with `source("R/sector_registry.R")` lookups; in `scripts/refresh_dashboard_data.R` build `trisk_manifest` from `sector_registry()` selecting its original 8 columns. Leave all other logic in both scripts untouched in this phase.
- [ ] TASK-01-06: Create `tests/testthat/test_engagement_config.R` (specs below).

**File Changes**
- `R/engagement_config.R` (create): loader + arg parser as specified; `source()`-able, no side effects on load.
- `R/sector_registry.R` (create): registry tibble + base params, values copied verbatim.
- `engagements/mcb-demo/engagement_config.json` (create): the defaults as JSON.
- `scripts/trisk_sector_demo.R` (modify): swap inline metadata/base-params for registry lookups; leave `trisk_sensitivity_specs`, `build_run_params`, `execute_trisk_run`, and the positional-arg CLI alone.
- `scripts/refresh_dashboard_data.R` (modify): derive `trisk_manifest` from `sector_registry()`; leave copy logic, `clear_dir`, and the fail-loud miss accumulator alone.
- `tests/testthat/test_engagement_config.R` (create).
- `.gitignore` (modify): add `engagements/*/snapshot/`, `engagements/*/reports/`, `engagements/*/output/**/figures/`, `engagements/*/output/engagement_letters/`, `engagements/*/output/disclosure/`.

**Function Signatures**
- `load_engagement_config(config_path: character|NULL = NULL) -> list` — returns the fully-populated named config list (defaults when NULL, defaults recursively overridden by the JSON file otherwise); `stop()`s with an aggregated message on validation failure.
- `get_config_arg(args: character = commandArgs(trailingOnly = TRUE)) -> character|NULL` — returns the value following `--config`, or NULL when the flag is absent.
- `sector_registry() -> tibble` — one row per sector (power, cement, steel) with the 15 merged metadata columns.
- `trisk_base_params() -> list` — the 7 TRISK base parameters, values identical to today's literals.

**Test Specs**
- `load_engagement_config(NULL)$inputs$loanbook_csv` → `"data/vietnam_loanbook.csv"`; `$run_grid` → `TRUE`; `$trisk_sectors` → `c("power","cement","steel")`.
- `load_engagement_config("engagements/mcb-demo/engagement_config.json")` → identical (`identical()` on the list, after normalizing list vs vector types) to `load_engagement_config(NULL)`.
- A temp config JSON containing only `{"bank_name":"X Bank","bank_slug":"x-bank","paths":{"snapshot_dir":"engagements/x-bank/snapshot"}}` → loader returns `bank_name "X Bank"`, `paths$snapshot_dir "engagements/x-bank/snapshot"`, and `inputs$abcd_csv` still `"data/vietnam_abcd.csv"`.
- A temp config with `inputs$loanbook_csv = "does/not/exist.csv"` → `stop()` whose message contains `does/not/exist.csv`.
- A temp config with `bank_slug = "X Bank!"` → `stop()` (slug regex).
- `nrow(sector_registry())` → 3; `sector_registry()$carbon_price_model` → `c("increasing_carbon_tax_50","cement_intensity_transition","steel_intensity_transition")`; `trisk_base_params()$shock_year` → 2028.
- `get_config_arg(c("--config","a.json"))` → `"a.json"`; `get_config_arg(character(0))` → NULL.

**Dependencies**
- None (jsonlite already in `renv.lock`).

**Exit Criteria**
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` green (new + existing tests).
- [ ] `Rscript scripts/pipeline_refresh.R` exits 0 and `dashboard/data/pipeline_manifest.json` reports the same step list/status as before this phase (registry swap changed nothing observable).
- [ ] `python -m pytest dashboard/tests` green.

**Phase Risks**
- **RISK-01-01:** Subtle value drift while moving the metadata tribbles (e.g. a disclaimer string typo "fix"). Mitigation: copy strings verbatim; verify by diffing `dashboard/data/trisk/manifest.csv` before/after a refresh run — must be byte-identical.

### PHASE-02 - Shared R Core & PACTA Parameterization (Byte-Identical MCB)

**Goal**
Extract the copy-pasted report toolkit and matching helpers into `R/`, drive `pacta_vietnam_scenario.R` from the engagement config (inputs, output dir, bank name), and retire the two superseded PACTA scripts — proving the refactor with byte-identical MCB CSV outputs.

**Tasks**
- [ ] TASK-02-01: Snapshot the acceptance baseline BEFORE touching code: run `Rscript scripts/pacta_vietnam_scenario.R`, then record hashes: `find synthesis_output/vietnam -name "*.csv" -exec md5sum {} \; | sort -k2 > /tmp/pacta_baseline_hashes.txt` (PowerShell alternative: `Get-ChildItem synthesis_output/vietnam -Filter *.csv | Get-FileHash -Algorithm MD5 | Sort-Object Path | Format-Table -AutoSize > pacta_baseline_hashes.txt`).
- [ ] TASK-02-02: Create `R/report_toolkit.R` extracting the duplicated HTML helpers from `scripts/generate_report.R` / `scripts/pacta_vietnam_scenario.R:40-45` / `scripts/generate_validation_report.R`: `img_to_base64()`, the shared CSS block as `report_css()`, and `html_section()` / `write_html_report()` wrappers matching however the existing generators compose sections (extract the common denominator; where generators differ, keep their local variant and only lift what is genuinely identical).
- [ ] TASK-02-03: Create `R/matching_helpers.R` with `normalize_vn_name(x: character) -> character` (the `stringi::stri_trans_general(x, "Latin-ASCII")` + whitespace/case handling currently repeated in `pacta_vietnam_scenario.R`, `intake_validate_and_map.R`, and the retired scripts) and any VSIC→ISIC pre-join helper shared between `pacta_vietnam_scenario.R` SECTION 2 and `intake_validate_and_map.R`. Point `pacta_vietnam_scenario.R` and `intake_validate_and_map.R` at it.
- [ ] TASK-02-04: Parameterize `scripts/pacta_vietnam_scenario.R`: at the top, `source("R/engagement_config.R")`, `cfg <- load_engagement_config(get_config_arg())`. Replace: the 5 hardcoded input paths in SECTION 1 (`required_files`) with `cfg$inputs`; `vn_output` with `cfg$paths$pacta_output_dir`; `report_dir` with `cfg$paths$reports_dir`; all 8 "Mekong Commercial Bank"/"MCB" occurrences in chart titles, cat banners, and HTML copy with `cfg$bank_name` (and derive short label from it where "MCB" appears). Keep the 9-section structure and all analysis logic untouched.
- [ ] TASK-02-05: Retire the superseded scripts per ASM-003: create `attic/README.md`, `git mv scripts/pacta_demo.R attic/`, `git mv scripts/pacta_synthesis.R attic/`. Grep for references first: `grep -rn "pacta_demo\|pacta_synthesis" --include="*.R" --include="*.py" --include="*.yml" --include="*.md" scripts/ dashboard/ .github/ docs/ README.md` — update the root `README.md` repo map if it names them; do not chase references inside `plans/`/`research/`/`activeContext.md` (historical documents).
- [ ] TASK-02-06: Acceptance check: rerun `Rscript scripts/pacta_vietnam_scenario.R` (no flags) and compare CSV hashes against TASK-02-01's baseline — every `synthesis_output/vietnam/*.csv` hash identical. The HTML report may differ only in generated-timestamp text; PNGs are inspected visually (open 2–3, confirm titles still read "Mekong Commercial Bank").

**File Changes**
- `R/report_toolkit.R` (create): shared HTML/report helpers.
- `R/matching_helpers.R` (create): name normalization + VSIC pre-join helpers.
- `scripts/pacta_vietnam_scenario.R` (modify): config-driven paths + bank name; source the new helpers; analysis logic untouched.
- `scripts/intake_validate_and_map.R` (modify): use `normalize_vn_name()` from the shared helper; nothing else.
- `scripts/generate_report.R`, `scripts/generate_validation_report.R` (modify): source `R/report_toolkit.R` instead of local copies of the lifted helpers; local specifics stay.
- `attic/README.md` (create), `attic/pacta_demo.R` (create via git mv), `attic/pacta_synthesis.R` (create via git mv), `scripts/pacta_demo.R` + `scripts/pacta_synthesis.R` (delete via git mv).
- `README.md` (modify): repo-map line for `attic/`; remove any mention of the retired scripts.

**Function Signatures**
- `img_to_base64(path: character) -> character` — returns a `data:image/png;base64,...` URI for the file.
- `report_css() -> character` — returns the shared report CSS block as a single string.
- `write_html_report(html: character, path: character) -> invisible(character)` — writes the document, returns the path.
- `normalize_vn_name(x: character) -> character` — vectorized ASCII-transliterated, whitespace-squashed name for matching.

**Test Specs**
- `normalize_vn_name("Nhiệt Điện Vĩnh Tân 1")` → `"Nhiet Dien Vinh Tan 1"` (exact diacritic stripping; add to a new `tests/testthat/test_matching_helpers.R`).
- `img_to_base64()` on a 1-pixel PNG written by the test → string starting `"data:image/png;base64,"` with nchar > 50.
- Byte-identity: after TASK-02-06, `md5sum` comparison of all `synthesis_output/vietnam/*.csv` vs baseline → zero differences.
- Existing suite: `Rscript -e "testthat::test_dir('tests/testthat')"` → green (golden numbers unchanged).

**Dependencies**
- PHASE-01 (config loader).

**Exit Criteria**
- [ ] MCB CSV hashes match the pre-refactor baseline exactly.
- [ ] `scripts/pacta_demo.R` and `scripts/pacta_synthesis.R` no longer exist in `scripts/`; nothing in `scripts/`, `dashboard/`, `.github/` references them.
- [ ] Full R + Python test suites green.

**Phase Risks**
- **RISK-02-01:** `readr::write_csv` number formatting could shift if any dplyr pipeline is "tidied" during the move. Mitigation: TASK-02-04 changes only path/name variables — treat any hash mismatch as a defect to fix, never as a new baseline.
- **RISK-02-02:** The report toolkit extraction subtly changes report HTML used by `dashboard/pages/3_Reports.py` iframes. Mitigation: reports are re-copied by `refresh_dashboard_data.R` from `reports/`; open the regenerated PACTA report in a browser and spot-check sections render.

### PHASE-03 - Parameterize the TRISK Chain & Downstream Generators

**Goal**
Every remaining pipeline stage accepts `--config` and honors the engagement's paths, sectors, and bank name, so a non-MCB engagement writes exclusively under its own roots — while no-flag behavior stays byte-identical.

**Tasks**
- [ ] TASK-03-01: `scripts/trisk_prepare_inputs.R`: load config; read `cfg$inputs$abcd_csv`, `cfg$inputs$scenario_ms_csv`, `cfg$inputs$scenario_co2_csv`; write per-sector inputs under `cfg$paths$trisk_input_root/<sector>_demo/`; apply ASM-007 for the `data/vietnam_trisk_*.csv` side copies; only prepare sectors in `cfg$trisk_sectors`.
- [ ] TASK-03-02: `scripts/trisk_power_demo.R` and `scripts/trisk_sector_demo.R`: load config; input dir from `cfg$paths$trisk_input_root`, outputs under `cfg$paths$trisk_output_root/<sector>_demo/`; report/chart titles use `cfg$bank_name`. `trisk_sector_demo.R` keeps its positional sector argument; `--config` is parsed independently of it (filter `args` for the flag pair before reading the positional).
- [ ] TASK-03-03: `scripts/trisk_scenario_grid.R`: load config; grid outputs under `cfg$paths$trisk_output_root/grid/<sector>/`; only sectors in `cfg$trisk_sectors`. (Whether an engagement runs it at all is the orchestrator's decision via `run_grid` — PHASE-04.)
- [ ] TASK-03-04: `scripts/sector_prioritization.R`: load config; read from `cfg$paths` (its PACTA and TRISK inputs), write under `cfg$paths$trisk_output_root/../prioritization/` — verify its actual current input/output paths at execution time (`grep -n "synthesis_output\|output/" scripts/sector_prioritization.R`) and map each to the corresponding config path; add a `prioritization_output_dir` key to the config defaults if its current output dir (`synthesis_output/prioritization`) doesn't fit an existing key.
- [ ] TASK-03-05: `scripts/refresh_dashboard_data.R`: load config; source root for PACTA files = `cfg$paths$pacta_output_dir`, TRISK = `cfg$paths$trisk_output_root`, destination = `cfg$paths$snapshot_dir`; sectors from `cfg$trisk_sectors`; grid copy skipped for sectors whose grid dir is absent when `run_grid` is false (set `grid_available` accordingly in the emitted `manifest.csv`). Keep the fail-loud required-file behavior; when `run_grid = FALSE` the three grid files are NOT required.
- [ ] TASK-03-06: `scripts/engagement_scoring.R`: load config; read `top_borrowers_alignment_trisk.csv` from `cfg$paths$snapshot_dir/trisk/<sector>/`, PACTA company file from `cfg$paths$pacta_output_dir/04_vn_ms_company.csv`, matched book from `cfg$paths$pacta_output_dir/02_vn_matched_prioritized.csv`; write to `cfg$paths$engagement_output_dir/engagement_priority.csv`. Scoring math untouched (DEC-002).
- [ ] TASK-03-07: `scripts/generate_engagement_letters.R` and `scripts/generate_disclosure_pack.R`: load config; priority file from `cfg$paths$engagement_output_dir`; outputs to `cfg$paths$letters_output_dir` / `cfg$paths$disclosure_output_dir`; replace the hardcoded "Mekong Commercial Bank" occurrences (1 in letters, 3 in disclosure) with `cfg$bank_name`; keep their existing `--top_n` / other flags working alongside `--config`. Templates stay shared from `templates/`.
- [ ] TASK-03-08: Default-mode regression: run `Rscript scripts/pipeline_refresh.R --full` (no config anywhere) to completion and confirm golden tests pass and `dashboard/data/trisk/manifest.csv` is unchanged.

**File Changes**
- `scripts/trisk_prepare_inputs.R`, `scripts/trisk_power_demo.R`, `scripts/trisk_sector_demo.R`, `scripts/trisk_scenario_grid.R`, `scripts/sector_prioritization.R`, `scripts/refresh_dashboard_data.R`, `scripts/engagement_scoring.R`, `scripts/generate_engagement_letters.R`, `scripts/generate_disclosure_pack.R` (modify): config loading + path/bank-name substitution only; no analysis/scoring/copy-logic changes beyond path derivation and sector filtering.
- `R/engagement_config.R` (modify): add `paths$prioritization_output_dir` default `"synthesis_output/prioritization"` (per TASK-03-04) and any other path key discovered during the mapping — each new key's default must equal today's hardcoded value.

**Function Signatures**
- None — no new code interfaces; every script gains the same `cfg <- load_engagement_config(get_config_arg())` preamble.

**Test Specs**
- Default-mode byte-identity: after TASK-03-08, `tests/testthat/test_golden_numbers.R` and `test_snapshot_contract.R` pass unmodified.
- Config-mode smoke (add `tests/testthat/test_config_paths.R`): write a temp config with `paths$engagement_output_dir = tempfile()`; run `Rscript scripts/engagement_scoring.R --config <tmp.json>` via `system2`; assert `engagement_priority.csv` appears under the temp dir and NOT freshly written under `output/engagement/` (compare mtimes).
- `Rscript scripts/trisk_sector_demo.R cement --config engagements/mcb-demo/engagement_config.json` → exit 0, outputs land in the default locations (config == defaults).

**Dependencies**
- PHASE-01, PHASE-02.

**Exit Criteria**
- [ ] All nine scripts run green with no flags AND with `--config engagements/mcb-demo/engagement_config.json`, producing identical outputs in both modes.
- [ ] Full R + Python suites green; `Rscript scripts/pipeline_refresh.R --full` exits 0.

**Phase Risks**
- **RISK-03-01:** A missed hardcoded path sends part of an engagement run into the MCB tree (cross-contamination). Mitigation: PHASE-05's SDB run uses a fully engagement-rooted config; before it, `grep -n '"synthesis_output\|"dashboard/data\|"output/' scripts/*.R` and confirm every remaining literal is a config default, not a direct consumer.
- **RISK-03-02:** `dashboard/lib/live_rerun.py` shells out to TRISK scripts with today's CLI. Mitigation: `--config` is additive and optional; run `python -m pytest dashboard/tests/test_live_rerun.py` to confirm.

### PHASE-04 - Orchestrator: `run_engagement.R` + Shared Step Runner

**Goal**
One command executes the full promised delivery flow for any engagement config, writing an engagement-scoped manifest — reusing (not duplicating) the step-runner logic in `pipeline_refresh.R`.

**Tasks**
- [ ] TASK-04-01: Create `R/step_runner.R` by extracting from `scripts/pipeline_refresh.R:59-101`: `run_steps()` executes a list of `list(name, script, args)` via `system2("Rscript", c(script, args))`, stops on first failure, and `write_pipeline_manifest()` emits the existing manifest JSON shape (`generated_at`, `git_sha`, `steps[{name,status,seconds}]`, `status`, `row_counts`) plus optional extra top-level fields.
- [ ] TASK-04-02: Refactor `scripts/pipeline_refresh.R` to source `R/step_runner.R`. Its step lists, `--full` flag, manifest path (`dashboard/data/pipeline_manifest.json`), row-count file list, and exit behavior stay byte-for-byte compatible (CON-004): same JSON keys, same step names/order/counts.
- [ ] TASK-04-03: Create `scripts/run_engagement.R` — CLI: `Rscript scripts/run_engagement.R --config engagements/<slug>/engagement_config.json [--raw-loanbook <path>] [--skip-intake] [--top-n <int>]`. Step list, in order, all invoked with `--config <path>`: (1) `intake_validate_and_map` — only when `--raw-loanbook` given and `--skip-intake` absent: runs `scripts/intake_validate_and_map.R --input <raw> --output-dir engagements/<slug>/intake` plus `--anonymize` when `cfg$anonymize`; then the orchestrator sets the engagement's effective loanbook to `engagements/<slug>/intake/normalized_loanbook.csv` by writing a resolved copy of the config to `engagements/<slug>/engagement_config.resolved.json` (with `inputs$loanbook_csv` pointed at the normalized file) and using THAT path for all later steps; (2) `generate_validation_report` → `reports_dir/<slug>_Intake_Validation_Report.html` with `--bank-name cfg$bank_name` (skipped when intake skipped); (3) `pacta_vietnam_scenario`; (4) `trisk_prepare_inputs`; (5) `trisk_power_demo` if `"power" %in% trisk_sectors`; (6) `trisk_sector_demo <s>` for each of cement/steel in scope; (7) `trisk_scenario_grid` only when `cfg$run_grid`; (8) `sector_prioritization`; (9) `refresh_dashboard_data` (into `cfg$paths$snapshot_dir`); (10) `engagement_scoring`; (11) `generate_engagement_letters` (pass `--top_n` when given); (12) `generate_disclosure_pack`. Manifest → `engagements/<slug>/pipeline_manifest.json` with extra fields `bank_slug` and `config_path`.
- [ ] TASK-04-04: Guard rail: `run_engagement.R` refuses to run when `cfg$paths$snapshot_dir == "dashboard/data"` AND `cfg$bank_slug != "mcb-demo"` (`stop("Engagement snapshot_dir must not be the public dashboard/data")`) — prevents a client engagement from overwriting the public snapshot.
- [ ] TASK-04-05: Add `tests/testthat/test_step_runner.R` and document the orchestrator in root `README.md` (one "Running a client engagement" subsection with the exact command).

**File Changes**
- `R/step_runner.R` (create): extracted runner + manifest writer.
- `scripts/pipeline_refresh.R` (modify): source the runner; observable behavior unchanged.
- `scripts/run_engagement.R` (create): orchestrator per TASK-04-03/04.
- `tests/testthat/test_step_runner.R` (create).
- `README.md` (modify): engagement-run subsection.

**Function Signatures**
- `run_steps(steps: list, stop_on_failure: logical = TRUE) -> list` — returns per-step results `list(name, status ("ok"|"failed"), seconds)`; stops executing after the first failure.
- `write_pipeline_manifest(step_results: list, manifest_path: character, row_count_files: character = character(0), extra: list = list()) -> invisible(character)` — writes the manifest JSON (existing schema + `extra` merged at top level), returns the path.

**Test Specs**
- `run_steps(list(list(name="ok", script="tests/fixtures/exit0.R", args=character())))` (create a 1-line fixture script `quit(status=0)`) → status `"ok"`; a fixture exiting 1 → status `"failed"` and subsequent steps not run.
- `write_pipeline_manifest(..., extra=list(bank_slug="x"))` → JSON parses; `$bank_slug == "x"`; keys `generated_at, git_sha, steps, status` all present.
- `Rscript scripts/pipeline_refresh.R` → manifest step names/count identical to the pre-refactor committed `dashboard/data/pipeline_manifest.json`; `tests/testthat/test_manifest_json.R` passes unmodified.
- Guard rail: a config with `bank_slug "x-bank"` and default snapshot_dir → `run_engagement.R` exits non-zero with the guard message before any step runs.

**Dependencies**
- PHASE-03 (all steps accept `--config`).

**Exit Criteria**
- [ ] `Rscript scripts/pipeline_refresh.R` behavior verified unchanged (manifest diff, existing tests).
- [ ] `run_engagement.R --config engagements/mcb-demo/engagement_config.json --skip-intake` — do NOT actually run this against the public snapshot as a test (it would rewrite `dashboard/data`); instead verify the guard-rail and step-list construction via a dry inspection: temporarily add `--dry-run` support printing the resolved step list without executing (include this small flag in TASK-04-03) and assert the printed list matches the 12-step spec.
- [ ] Full R + Python suites green.

**Phase Risks**
- **RISK-04-01:** `system2("Rscript", ...)` requires `Rscript` on PATH (Windows: `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"` for the session) — same constraint as `pipeline_refresh.R` today; document in the README subsection.
- **RISK-04-02:** The resolved-config indirection (TASK-04-03 step 1) confuses debugging. Mitigation: the orchestrator prints the effective config path and loanbook path in its banner before step 1.

### PHASE-05 - SDB End-to-End Run, Timings, Second Golden Fixture

**Goal**
Cash the deferred rehearsal cheque: run the dirty SDB fixture through the entire engagement flow, log measured stage timings and every friction point, and freeze a second golden-number test set so "works only for MCB" can never silently return.

**Tasks**
- [ ] TASK-05-01: Create `engagements/sdb-rehearsal/engagement_config.json`: `bank_name "Saigon Delta Bank"`, `bank_slug "sdb-rehearsal"`, `inputs$loanbook_csv` left at the MCB default (the orchestrator overrides it from intake), all other `inputs` at defaults (SDB matches against the same synthetic ABCD by fixture design), `trisk_sectors ["power","cement","steel"]`, `run_grid false`, `anonymize false`, and all `paths` rooted under `engagements/sdb-rehearsal/` (`pacta_output_dir "engagements/sdb-rehearsal/output/pacta"`, `trisk_output_root "engagements/sdb-rehearsal/output/trisk"`, `trisk_input_root "engagements/sdb-rehearsal/output/trisk_inputs"`, `snapshot_dir "engagements/sdb-rehearsal/snapshot"`, `reports_dir "engagements/sdb-rehearsal/reports"`, `engagement_output_dir "engagements/sdb-rehearsal/output/engagement"`, `letters_output_dir "engagements/sdb-rehearsal/output/engagement_letters"`, `disclosure_output_dir "engagements/sdb-rehearsal/output/disclosure"`, `prioritization_output_dir "engagements/sdb-rehearsal/output/prioritization"`).
- [ ] TASK-05-02: Execute, timing the whole run and reading per-step seconds from the manifest afterwards: `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --raw-loanbook data/fixtures/unseen_bank_loanbook.csv`. Expect and fix (as small guarded changes, not redesigns) failures of the class: PACTA sectors with zero matched SDB loans crashing chart code (guard: skip chart + emit a "no matched exposure in <sector>" note row), TRISK sectors with no mapped companies (skip sector with a logged notice and `grid_available/na` handling in the snapshot manifest), empty engagement-letter target lists. Every fix must keep the MCB byte-identity tests green.
- [ ] TASK-05-03: Append a "Downstream run (2026-07)" section to `pilot/rehearsal_log.md` (ASM-008): per-step seconds table from `engagements/sdb-rehearsal/pipeline_manifest.json`, mapped to the proposal milestone names (Loanbook received → Validation report returned → Results delivered); every friction point fixed in TASK-05-02 with file/line; a verdict sentence updating the old "remaining gap" statement.
- [ ] TASK-05-04: Commit the SDB artifacts per ASM-006 and freeze `tests/testthat/test_sdb_engagement.R`: read the actual committed values at authoring time (row counts, top-borrower name, composite score to ±0.005) — do NOT copy MCB's goldens. Assert at minimum: `engagements/sdb-rehearsal/intake/normalized_loanbook.csv` has 13 columns and the row count observed (expected 23 valid rows per the previous rehearsal, verify); `engagements/sdb-rehearsal/output/engagement/engagement_priority.csv` exists with > 0 rows and its rank-1 `company_name` equals the observed literal; every `loan_size_outstanding_currency == "VND"`.
- [ ] TASK-05-05: Confirm cross-contamination absence: `git status` shows no modifications under `synthesis_output/`, `output/`, `dashboard/data/`, or `reports/` caused by the SDB run (the run started from a clean tree).

**File Changes**
- `engagements/sdb-rehearsal/engagement_config.json` (create).
- `engagements/sdb-rehearsal/` committed outputs per ASM-006 (create, generated).
- `scripts/pacta_vietnam_scenario.R`, `scripts/trisk_*.R`, `scripts/generate_engagement_letters.R` (modify, only as forced by TASK-05-02 guards): zero-match/empty-sector guards.
- `pilot/rehearsal_log.md` (modify): append the downstream-run section; leave the existing 2026-07-10 content untouched.
- `tests/testthat/test_sdb_engagement.R` (create).

**Function Signatures**
- None — no new code interfaces; guards are inline conditionals in existing scripts.

**Test Specs**
- `Rscript -e "testthat::test_dir('tests/testthat')"` → green including `test_sdb_engagement.R` AND the untouched MCB goldens (proves both books coexist).
- `python - <<'EOF'` / read `engagements/sdb-rehearsal/pipeline_manifest.json`, assert `status == "ok"` and `bank_slug == "sdb-rehearsal"` / `EOF`.
- Cross-contamination: `git status --porcelain synthesis_output output dashboard/data reports` → empty after the SDB run.

**Dependencies**
- PHASE-04.

**Exit Criteria**
- [ ] `run_engagement.R` on the SDB fixture exits 0; manifest `status "ok"`.
- [ ] `pilot/rehearsal_log.md` contains the measured per-stage timings and the updated verdict.
- [ ] `test_sdb_engagement.R` green from committed artifacts; full suites green.
- [ ] `engagements/sdb-rehearsal/reports/sdb-rehearsal_Intake_Validation_Report.html` opens in a browser with "Saigon Delta Bank" branding.

**Phase Risks**
- **RISK-05-01:** The SDB book's sector mix (no automotive borrowers with TRISK coverage, thin cement/steel) surfaces divide-by-zero or empty-tibble crashes deep in analysis code. Mitigation: this is the point of the rehearsal — fix with guards, log each in the rehearsal section; if a fix threatens MCB byte-identity, guard it behind an emptiness check so the MCB path never enters the new branch.
- **RISK-05-02:** Fixture-derived outputs could be mistaken for a real bank's. Mitigation: `bank_name` "Saigon Delta Bank" is fictional; ensure the synthetic-data disclaimer footer (CON-003) renders in the SDB validation report and disclosure pack.

### PHASE-06 - Data-Dependency Briefs, Scenario Versioning, NA Bug Fixes

**Goal**
Close the two week-one external dependencies of a real engagement (ABCD sourcing decision, ABCD intake contract), make scenario vintages explicit, and fix the two known NA-producing methodology bugs.

**Tasks**
- [ ] TASK-06-01: Write `docs/abcd_sourcing_decision.md` (~2-3 pages): the problem (real loanbooks must match against real asset-based company data; `data/vietnam_abcd.csv` is synthetic); Option A — Asset Impact license (coverage by sector for Vietnam: power/auto strong, cement/steel partial; cost per ASM-009 "confirm with vendor"; lead time); Option B — self-collected (EVN/GENCO annual reports, Global Energy Monitor coal/gas/steel plant trackers, VNSTEEL/VICEM disclosures; effort estimate per sector; licensing/attribution constraints of GEM data); Option C — hybrid (license power/auto, self-build cement/steel). Per-sector coverage table, decision recommendation (hybrid unless the engagement is power-only), and the trigger point ("decide before signing DATE_1 in any real proposal").
- [ ] TASK-06-02: ABCD intake contract: append an "ABCD (asset-based company data) table" section to `intake/SCHEMA.md` mirroring the loanbook contract style — required columns matching `data/vietnam_abcd.csv`'s schema (verify with `head -1 data/vietnam_abcd.csv` and document each column's type/units), plus provenance columns `data_source` and `as_of_year`. Create `intake/templates/abcd_template.csv` (header + 3 illustrative rows) and add one line to `intake/templates/README_vi.md` naming the new template.
- [ ] TASK-06-03: Scenario versioning: create `data/scenarios/pdp8-2023/` containing copies of `vietnam_scenario_ms.csv` and `vietnam_scenario_co2.csv`; change the config defaults `inputs$scenario_ms_csv` / `inputs$scenario_co2_csv` to the new versioned paths; keep `data/generate_vietnam_data.R` writing to BOTH the legacy `data/` paths and the versioned dir (one extra `write_csv` each) so nothing else breaks; record the scenario paths in the refresh audit (`scripts/generate_refresh_audit.R`: include the two scenario file paths + md5 checksums in the metrics JSON and audit HTML). Add a short "Scenario vintages" note to `docs/trisk_scenario_grid_contract.md` or `README.md` explaining the directory convention (`data/scenarios/<source>-<year>/`).
- [ ] TASK-06-04: Fix the Dung Quat LNG zero-baseline edge case in `scripts/trisk_prepare_inputs.R`: locate the asset "Dung Quat LNG Power Consortium" (`VN_ABCD_006`); for assets whose baseline-year production/capacity is 0 (pre-commissioning), backfill the baseline from the first year with a non-zero value and tag the row with a new column `baseline_note = "backfilled_first_operating_year"`; if no non-zero year exists, exclude the asset and print a `[NOTE]` line. Confirm downstream sensitivity outputs contain no NA rows for this company afterwards.
- [ ] TASK-06-05: Fix the power 2025-NA gap in `data/generate_vietnam_data.R`: locate where 2025 projected power values are emitted as NA and backfill with the modeled 2025 value (interpolate from the nearest defined years using the same interpolation already used for scenario anchors); confirm via the dashboard PACTA page that the power techmix panel no longer renders empty 2025 bars.
- [ ] TASK-06-06: Refreeze goldens per ASM-010: run `Rscript scripts/pipeline_refresh.R --full` to green, inspect the diff of committed CSVs, update any changed literals in `tests/testthat/test_golden_numbers.R` (and `test_sdb_engagement.R` if SDB values moved — rerun the SDB engagement if its inputs changed), and state the refreeze in the commit message.

**File Changes**
- `docs/abcd_sourcing_decision.md` (create): decision brief per TASK-06-01.
- `intake/SCHEMA.md` (modify): append the ABCD section; loanbook section untouched.
- `intake/templates/abcd_template.csv` (create); `intake/templates/README_vi.md` (modify): one added line.
- `data/scenarios/pdp8-2023/vietnam_scenario_ms.csv`, `data/scenarios/pdp8-2023/vietnam_scenario_co2.csv` (create, generated copies).
- `data/generate_vietnam_data.R` (modify): dual-write scenario CSVs; 2025 power backfill.
- `R/engagement_config.R` (modify): scenario input defaults point at the versioned paths.
- `scripts/trisk_prepare_inputs.R` (modify): zero-baseline backfill + `baseline_note` column.
- `scripts/generate_refresh_audit.R` (modify): scenario paths + checksums in metrics and HTML.
- `tests/testthat/test_golden_numbers.R`, `tests/testthat/test_sdb_engagement.R` (modify): refrozen literals only, per ASM-010.

**Function Signatures**
- `backfill_zero_baseline(assets: tibble, value_col: character, year_col: character = "year") -> tibble` — R helper inside `trisk_prepare_inputs.R`; returns the assets table with zero-baseline first-year values replaced by the first non-zero year's value and a `baseline_note` character column added.

**Test Specs**
- Add to `tests/testthat/` (new `test_trisk_input_prep.R`): a 3-row toy tibble with years 2025–2027 and values `c(0, 0, 500)` → `backfill_zero_baseline` returns 2025 value 500 (and 2026 value 500) with `baseline_note == "backfilled_first_operating_year"`; a tibble with all-zero values → asset excluded (0 rows returned for it).
- `grep -c "NA" synthesis_output/trisk/power_demo/sensitivity_results.csv` (or the file's actual NA-bearing column) after TASK-06-04 + a rerun → Dung Quat rows contain no NA sensitivity values (verify by filtering the CSV for "Dung Quat").
- `python -c "import pandas as pd; d=pd.read_csv('dashboard/data/pacta/04_vn_ms_portfolio.csv'); print(d[(d.year==2025)].isna().sum().sum())"` → 0 for the power projected metric after TASK-06-05 + refresh (adjust the file/column to where the 2025 NA actually lives — locate it first).
- Full suites green after TASK-06-06.

**Dependencies**
- PHASE-05 (SDB goldens exist and must be re-checked); TASK-06-06 depends on 06-03/04/05.

**Exit Criteria**
- [ ] `docs/abcd_sourcing_decision.md` and the ABCD intake contract exist and cross-link.
- [ ] Config defaults reference `data/scenarios/pdp8-2023/`; refresh audit records scenario checksums.
- [ ] No NA rows for Dung Quat in shipped TRISK sensitivity outputs; no empty 2025 power bars.
- [ ] `Rscript scripts/pipeline_refresh.R --full` green; both golden test sets green against refrozen literals.

**Phase Risks**
- **RISK-06-01:** The 2025 backfill changes PACTA alignment numbers visibly on the public app. Mitigation: that is the intended fix of a known demo distraction; the audit report's changed-since-last-run table documents the delta, and the commit message explains it.
- **RISK-06-02:** Dual-writing scenario CSVs drifts if someone edits only one copy. Mitigation: both copies come from the same generator run; add one testthat assertion (`test_snapshot_contract.R`) that the md5 of `data/vietnam_scenario_ms.csv` equals `data/scenarios/pdp8-2023/vietnam_scenario_ms.csv`.

## Gotchas

- **`yaml` is not in `renv.lock`** — engagement configs are JSON via `jsonlite` (ASM-001). Do not introduce YAML.
- **`system2("Rscript", ...)` needs `Rscript` on PATH** even when the outer call used a full path. Windows session fix: `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"`.
- **Windows PowerShell 5.1 has no `&&`** — chain with `;` or `if ($?) { ... }`; the Bash examples in this plan run as-is only in Git Bash/Linux.
- **All money is raw VND** (`loan_size_outstanding`, exposures 1e5–5e12 across files). Never convert or rescale; downstream sums raw values.
- **Vietnamese diacritics**: author every new CSV as UTF-8 without BOM; the intake reader falls back to latin1, which silently mangles diacritics.
- **`clear_dir()` wipes `dashboard/data/trisk` (or the engagement's `snapshot_dir/trisk`) on every refresh run** — never hand-place files in a snapshot tree; the refresh script must re-copy everything each run.
- **CON-004 manifest-shape lock:** `tests/testthat/test_manifest_json.R` and `dashboard/tests/test_manifest.py` assert on the default manifest — the step-runner extraction (PHASE-04) must not rename keys or change default step names/counts.
- **`dashboard/tests/test_loaders.py` asserts exactly 243 grid scenarios for power** — do not change grid lever ranges anywhere in this plan.
- **Golden literals come from committed files, never from plan text** — at authoring time of any golden test, open the committed CSV and freeze what is actually there (RISK of stale numbers otherwise).
- **The engagement scoring script reads from the snapshot (`snapshot_dir/trisk/...`), not from `synthesis_output/`** — in any orchestration it must run AFTER the snapshot copy step (enforced by the PHASE-04 step order).
- **PNG byte-comparison is a trap**: ggplot PNG output is not byte-stable across runs; the byte-identity acceptance bar applies to CSVs only.
- **`.Rprofile` renv auto-activation is commented out locally** — if a fresh clone behaves oddly (empty library), that is renv activating; CI uses `setup-renv@v2` instead.
- **Weekly CI auto-commits to `main`**: any change that breaks the gating testthat suite blocks Monday's refresh publish — that is by design; fix the tests or the pipeline, never bypass the gate.

## Verification Strategy

- **TEST-001 (PHASE-01):** `Rscript -e "source('R/engagement_config.R'); cfg <- load_engagement_config(); stopifnot(cfg$inputs$loanbook_csv == 'data/vietnam_loanbook.csv', cfg$run_grid)"` → exits 0, no output.
- **TEST-002 (PHASE-02):** baseline vs post-refactor MCB hashes: `find synthesis_output/vietnam -name "*.csv" -exec md5sum {} \; | sort -k2 | md5sum` → same digest before and after PHASE-02 (run the PACTA script once on each side).
- **TEST-003 (all phases):** `Rscript -e "testthat::test_dir('tests/testthat')"` → all pass, 0 failures.
- **TEST-004 (all phases):** `python -m pytest dashboard/tests` → all pass, 0 failures.
- **TEST-005 (PHASE-04):** `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --raw-loanbook data/fixtures/unseen_bank_loanbook.csv --dry-run` → prints the resolved 12-step list (grid step absent because `run_grid false`, so 11 lines) and exits 0 without executing.
- **TEST-006 (PHASE-05):** `python -c "import json;m=json.load(open('engagements/sdb-rehearsal/pipeline_manifest.json'));print(m['status'],m['bank_slug'])"` → `ok sdb-rehearsal`.
- **TEST-007 (PHASE-05):** `git status --porcelain synthesis_output output dashboard/data reports` immediately after the SDB run → empty output (no cross-contamination).
- **TEST-008 (PHASE-06):** `Rscript -e "stopifnot(tools::md5sum('data/vietnam_scenario_ms.csv') == tools::md5sum('data/scenarios/pdp8-2023/vietnam_scenario_ms.csv'))"` → exits 0.
- **MANUAL-001 (PHASE-02):** open the regenerated `reports/PACTA_Vietnam_Bank_Report.html` (or the actual PACTA report filename in `reports/`) in a browser — sections and charts render, titles read "Mekong Commercial Bank".
- **MANUAL-002 (PHASE-05):** open `engagements/sdb-rehearsal/reports/sdb-rehearsal_Intake_Validation_Report.html` — "Saigon Delta Bank" branding, synthetic-data footer present.
- **MANUAL-003 (PHASE-06):** run the app (`python -m streamlit run dashboard/app.py`), open the PACTA page — power techmix panel shows populated 2025 bars.
- **OBS-001:** after the next scheduled Monday 02:00 UTC refresh, confirm the bot commit exists, the gating tests passed in the Actions log, and the audit HTML includes the scenario checksums (post-PHASE-06).

## Risks and Alternatives

- **RISK-001:** The refactor spans every published number; a partial merge (e.g. PHASE-03 half-done) leaves the weekly auto-commit CI running against inconsistent scripts. Mitigation: land each phase as one commit/PR only after its exit criteria pass; the gating testthat suite blocks a red publish either way.
- **RISK-002:** Byte-identity may be impossible for one or two CSVs due to row-order nondeterminism already latent in the pipeline. Mitigation: investigate any mismatch first (it usually means an accidental logic change); if a file is genuinely order-unstable today, compare it sorted (`sort file | md5sum`) and note the exception in the phase commit message.
- **RISK-003:** The SDB run exposes deeper assumptions than zero-match guards can absorb (e.g. PACTA needing every sector present). Mitigation: PHASE-05 explicitly permits observation-plus-guard fixes; anything structural gets logged in `pilot/rehearsal_log.md` as a named backlog item for a follow-on plan rather than force-fixed here.
- **ALT-001:** Turn `R/` into a proper internal package (DESCRIPTION, `devtools::load_all`) instead of `source()`-d modules — rejected for now: adds build tooling for six files; revisit if `R/` grows past ~10 modules.
- **ALT-002:** Parameterize via environment variables instead of a config file — rejected: a dozen path/name knobs in env vars is error-prone and unauditable; a committed JSON per engagement is self-documenting and diffable.
- **ALT-003:** Rename `pacta_vietnam_scenario.R` → `run_pacta.R` as part of PHASE-02 — rejected (ASM-002): breaks references in `pipeline_refresh.R`, CI, live-rerun, and docs for zero functional gain.
- **ALT-004:** Run the grid for engagements by default so private instances get the Scenario Builder — rejected (ASM-005): grid runtime dominates; enable per engagement with `"run_grid": true` when a client wants the page.

## Suggested Next Step

Execute PHASE-01. It is small, purely additive (two `R/` modules, one JSON, one test file, two verbatim-value swaps), and its exit criteria — green suites plus an unchanged refresh manifest — establish the config substrate every later phase consumes.
