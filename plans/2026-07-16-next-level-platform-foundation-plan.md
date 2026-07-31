---
title: "Next-Level Platform: Engineering Foundation (Repo Laws, PACTA Decompose, Loadable Package)"
date: "2026-07-16"
status: "complete — bulk-corrected 2026-07-31 per directive: plan predates 2026-07-20 and is presumed fully implemented (NOT individually verified against git/code evidence)"
request: "Turn research/2026-07-16-next-level-platform-brainstorm.md into a multi-phase implementation plan (next-level-platform). Scope: Wave 1 engineering foundation, executable against the current committed repo state."
plan_type: "multi-phase"
research_inputs:
  - "research/2026-07-16-next-level-platform-brainstorm.md"
  - "research/2026-07-13-client-engagement-runway-brainstorm.md"
---

# Plan: Next-Level Platform — Engineering Foundation

## Objective

The analytics core of this platform is an untestable 1,386-line monolith
(`scripts/pacta_vietnam_scenario.R`), and the repo advertises an R package
(`DESCRIPTION`: `pactatrisk 0.1.0`) that does not actually exist (no `NAMESPACE`, no
loadable functions). This plan turns the PACTA pipeline into pure, individually testable
functions in `R/pacta_core.R`, wraps them in a genuinely loadable `pactatrisk` package,
and writes down the sharp repo-specific traps as durable "laws" so the refactor — and the
next ten bank engagements — become cheap and safe instead of a fresh archaeology dig each
time. The acceptance bar throughout is **byte-identical Mekong Commercial Bank (MCB) CSV
outputs** under the existing golden-number tests: this is pure structural refactoring, no
observable behavior changes.

## Context Snapshot

- **Current state:** A hardened demo platform for a synthetic Vietnamese bank ("Mekong
  Commercial Bank", MCB). An R pipeline (`scripts/*.R`) produces a frozen 3 MB snapshot
  (`dashboard/data/`) consumed by a Streamlit app. Reproducibility rails exist: `renv.lock`
  pins R deps; `tests/testthat/` holds golden-number/contract/config tests; two GitHub
  Actions workflows (`ci.yml` test gate, `refresh.yml` weekly auto-commit). An engagement-
  config layer (`R/engagement_config.R`), a single sector registry (`R/sector_registry.R`),
  a shared report toolkit (`R/report_toolkit.R`), and matching helpers (`R/matching_helpers.R`)
  already exist and are `source()`d by scripts. `scripts/pacta_vietnam_scenario.R` is already
  config-driven (reads `load_engagement_config(get_config_arg())`) but remains ONE linear
  1,386-line script with 9 inline sections and no extractable functions — the only way to
  test PACTA is to run the whole script and diff CSVs. `DESCRIPTION` declares an R package
  but there is no `NAMESPACE`, no roxygen, and `library(pactatrisk)` / `devtools::load_all()`
  do not work. There is no root `CLAUDE.md`; `AGENTS.md` is thin and stale (it references
  `pacta_demo.R`, now retired to `attic/`, and a `compare/` AI-vs-staff workflow that is
  historical).
- **Desired state:** PACTA analysis logic lives in pure functions in `R/pacta_core.R`
  (load → pre-join → match → coverage → market-share → SDA → alignment-gap → chart-encode →
  report), each unit-testable with tiny fixtures in seconds; `scripts/pacta_vietnam_scenario.R`
  becomes a thin orchestration wrapper that sources the core and calls the functions in order,
  producing byte-identical MCB CSVs. `pactatrisk` becomes a genuinely loadable package:
  `devtools::load_all(".")` exposes the `R/` functions, `DESCRIPTION` lists real `Imports`,
  a generated `NAMESPACE` exports the public functions, and `devtools::test()` runs the
  `tests/testthat/` suite through the package harness. A root `CLAUDE.md` and a refreshed
  `AGENTS.md` codify the repo's laws and traps.
- **Key repo surfaces:** `scripts/pacta_vietnam_scenario.R`, `R/engagement_config.R`,
  `R/sector_registry.R`, `R/report_toolkit.R`, `R/matching_helpers.R`, `DESCRIPTION`,
  `.Rbuildignore`, `tests/testthat/` (`helper-root.R`, `test_golden_numbers.R`,
  `test_matching_helpers.R`, `test_engagement_config.R`, `test_snapshot_contract.R`,
  `test_manifest_json.R`, `test_intake_fixture.R`), `renv.lock`, `.github/workflows/ci.yml`,
  `AGENTS.md`, `README.md`.
- **Out of scope:** The client-engagement-runway plan's remaining phases (PHASE-03–06:
  parameterizing the TRISK chain + downstream generators, `scripts/run_engagement.R`
  orchestrator, the Saigon Delta Bank end-to-end run, ABCD sourcing brief, scenario
  versioning) — those are a separate, prerequisite effort tracked in
  `plans/2026-07-13-client-engagement-runway-plan.md`. Also out of scope: decomposing the
  TRISK scripts (`scripts/trisk_*.R`) into functions (a follow-on once PACTA proves the
  pattern); the second-book regression fixture (depends on the runway's SDB run);
  multi-scenario traffic-light output, automotive TRISK, Vietnamese i18n, PDF export
  (Wave 2/3 of the brainstorm). No changes to any published number, the Streamlit app, the
  snapshot, or the synthetic-data disclaimers.

## Environment & Conventions

- **Stack:** R 4.5.2 drives the analytics pipeline via `Rscript`. Local (Windows):
  `C:\Program Files\R\R-4.5.2\bin\Rscript.exe`; Linux/CI: plain `Rscript` on PATH. R
  dependencies are pinned in `renv.lock`: arrow, base64enc, dplyr, fs, ggplot2, ggrepel,
  jsonlite, pacta.loanbook, purrr, r2dii.analysis, r2dii.data, r2dii.match, r2dii.plot,
  readr, rlang, scales, stringi, tibble, tidyr, trisk.model, xfun, testthat. Python 3.11+
  with Streamlit/pandas/plotly/pytest runs the dashboard (unaffected by this plan). **`roxygen2`
  and `devtools` are NOT in `renv.lock`** — see ASM-004 for how PHASE-03 handles this.
- **Setup (R):** packages already installed in the local renv library. Fresh machine:
  `Rscript -e "renv::restore()"` (or the no-renv fallback `Rscript scripts/ci/install_deps.R`).
  Note: `.Rprofile` renv auto-activation is commented out for local development; CI restores
  via `r-lib/actions/setup-renv@v2`.
- **Build / Run (the acceptance workload):** regenerate the MCB PACTA outputs with
  `Rscript scripts/pacta_vietnam_scenario.R` (run from the repo root — the script resolves
  paths via `getwd()`). This writes `synthesis_output/vietnam/*.csv` + `*.png` and an HTML
  report under `reports/`. Full pipeline: `Rscript scripts/pipeline_refresh.R`.
- **Test:** full R suite: `Rscript -e "testthat::test_dir('tests/testthat')"`. Single test
  file: `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`. Python
  (unaffected): `python -m pytest dashboard/tests`.
- **Conventions & traps:**
  - All loanbook money is raw **VND** (column `loan_size_outstanding`, currency literal
    `VND`; magnitudes span 1e5–5e12). **Never rescale it.**
  - Vietnamese company names carry diacritics; matching normalizes via
    `normalize_vn_name()` in `R/matching_helpers.R` (wraps `stringi::stri_trans_general(x,
    "Latin-ASCII")`). CSVs are UTF-8, no BOM.
  - Always run every R command from the repo root; scripts use `getwd()`-relative paths.
  - The R CLI convention: scripts source `R/engagement_config.R` and call
    `cfg <- load_engagement_config(get_config_arg())`; `--config <path>` selects an
    engagement, absent flag = MCB defaults reproduced exactly.
  - `tests/testthat/helper-root.R` defines `project_root()` by walking upward from `getwd()`
    until it finds a directory containing `dashboard/`. Tests read outputs via that root.
  - Refactor acceptance bar (from prior phases, reused here): **byte-identical MCB CSV
    outputs**; PNGs compared visually only (PNG compression is nondeterministic); HTML
    reports may differ only in generated-timestamp text.
  - Windows PowerShell 5.1 has no `&&` chaining; prefer the portable `Rscript -e "..."`
    commands in this plan, which run identically on Windows and Linux.
- **Repo map (relevant to this plan):**
  - `scripts/` — R pipeline stages; the target is `pacta_vietnam_scenario.R` only.
  - `R/` — shared sourced modules (config loader, sector registry, report toolkit, matching
    helpers); this plan ADDS `R/pacta_core.R`.
  - `tests/testthat/` — R test suite; `helper-root.R` + golden/contract tests; this plan
    ADDS `test_pacta_core.R`.
  - `data/` — synthetic MCB inputs (`vietnam_loanbook.csv`, `vietnam_abcd.csv`,
    `vietnam_scenario_ms.csv`, `vietnam_scenario_co2.csv`, `vietnam_region_isos.csv`).
  - `synthesis_output/vietnam/` — PACTA CSV + PNG outputs (the byte-identity target).
  - `DESCRIPTION`, `.Rbuildignore`, `renv.lock`, `.github/workflows/ci.yml` — package/CI.
  - `attic/` — retired `pacta_demo.R`, `pacta_synthesis.R` (do not touch).

## Research Inputs

- From `research/2026-07-16-next-level-platform-brainstorm.md`:
  - The runway plan parameterized PACTA's *paths* but left `pacta_vietnam_scenario.R` an
    untestable 1,386-line monolith (still 21 inline `#` section banners) and left
    `DESCRIPTION`'s "package" a promise with no `NAMESPACE` — this is the biggest remaining
    structural debt and the foundation multi-bank scale rests on (Theme 1, T1.1/T1.2).
  - **ASM-1A (adopted):** the PACTA decompose sequences *after* the runway's golden refreeze,
    using the existing MCB goldens as the safety net — but it does NOT itself depend on the
    runway's TRISK-chain work, because PACTA is already config-driven (runway PHASE-02, done).
    It is therefore executable now.
  - **ASM-1B (adopted):** complete the package rather than delete the `DESCRIPTION` pretense —
    `library(pactatrisk); run_pacta(cfg)` beats `source()`-ing eight scripts once you run the
    pipeline for N banks.
  - **T1.3 (adopted):** a root `CLAUDE.md` codifying the traps (VND never rescaled, run from
    root, byte-identical acceptance bar, diacritic normalization, load-bearing goldens) is
    near-zero cost and prevents a class of regressions; `AGENTS.md` is stale.
  - Explicitly deferred to follow-on plans: second-book regression fixture (needs the runway's
    SDB run), TRISK-chain decompose, multi-scenario traffic-light, automotive TRISK.
- From `research/2026-07-13-client-engagement-runway-brainstorm.md`:
  - The golden-number suite plus snapshot-contract tests were built precisely to make large
    refactors safe — refactor under green tests with byte-identical MCB outputs as the bar.
  - `yaml` is deliberately NOT a dependency; configs are JSON via `jsonlite`. (Relevant here
    only as a reminder not to add casual new dependencies — see ASM-004.)

## Assumptions and Constraints

- **ASM-001:** Where the extracted PACTA functions live — **BINDING DEFAULT:** a single new
  file `R/pacta_core.R`, sourced by `scripts/pacta_vietnam_scenario.R` exactly as the existing
  `R/*.R` modules are (`source("R/pacta_core.R")`). Do NOT split into multiple files this
  phase; one cohesive core module keeps the diff reviewable.
- **ASM-002:** Extraction method — **BINDING DEFAULT:** move code *verbatim* into function
  bodies. Each function receives the current top-level variables it reads as parameters and
  returns exactly the objects downstream sections consume. No logic edits, no "tidy-ups", no
  reordering of dplyr pipelines, no changing `readr::write_csv` call sites' arguments. Any CSV
  hash mismatch is a defect to fix, never a new baseline.
- **ASM-003:** Chart (PNG) and HTML-report code — **BINDING DEFAULT:** also extract into
  functions for symmetry, but their outputs are verified visually/structurally, not by hash
  (PNG compression and HTML timestamps are nondeterministic). Keep `ggsave`/`png()` call sites
  and dimensions byte-for-byte to minimize visual drift.
- **ASM-004:** `roxygen2`/`devtools` absent from `renv.lock` — **BINDING DEFAULT:** for
  PHASE-03, add `roxygen2` and `devtools` to the renv lockfile via
  `Rscript -e "renv::install(c('roxygen2','devtools')); renv::snapshot()"` and commit the
  updated `renv.lock`. If network install is unavailable in the execution environment, fall
  back to hand-writing `NAMESPACE` (export one line per public function) and skip roxygen tag
  generation — the package must still `load_all()` and `test()` green; document which path was
  taken in the commit message.
- **ASM-005:** Package R-CMD-check cleanliness — **BINDING DEFAULT:** the PHASE-03 target is a
  package that `devtools::load_all(".")` loads and `devtools::test()` runs green, and that
  `R CMD build` produces a tarball with **zero ERRORs** (WARNINGs/NOTEs from retained
  `library()` calls, missing `man/` for non-exported helpers, or the large `data/` dir are
  acceptable and out of scope). Converting every `library()` call to `@importFrom` for a fully
  clean `--as-cran` check is explicitly deferred.
- **ASM-006:** Whether `R/*.R` files keep working when `source()`d standalone — **BINDING
  DEFAULT:** yes. The scripts must keep sourcing `R/*.R` and running unchanged. Achieve this by
  leaving the existing top-of-file `library(...)`/`requireNamespace(...)` guards in the `R/`
  files intact (they are harmless inside a package and required for standalone `source()`),
  and by NOT introducing roxygen `@import` directives that would break standalone sourcing.
  roxygen is used ONLY to generate `NAMESPACE` export lines from `@export` tags.
- **CON-001:** With no behavior change intended, every MCB CSV under `synthesis_output/vietnam/`
  must be byte-identical before vs after each phase. The weekly auto-commit CI, the golden
  tests, and the public app depend on it.
- **CON-002:** Do not add or change any dependency used by the *pipeline* (the analysis stack
  is pinned). The only new dev dependencies permitted are `roxygen2`/`devtools` for PHASE-03
  (ASM-004), which the pipeline itself never imports.
- **CON-003:** Streamlit Community Cloud has no R runtime; nothing in `dashboard/` may gain an
  R dependency. This plan does not touch `dashboard/`.
- **DEC-001:** MCB stays the default engagement; `load_engagement_config(NULL)` returns MCB
  defaults and the default pipeline never reads `engagements/mcb-demo/engagement_config.json`.
  (Fixed by the current system; this plan does not change it.)
- **DEC-002:** The package name is `pactatrisk` and version stays `0.1.0` (per `DESCRIPTION`);
  this plan does not bump the version.

## Phase Summary

| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Write down the repo laws & traps so the refactor is safe for any executor | None | `CLAUDE.md` (create), refreshed `AGENTS.md` |
| PHASE-02 | Decompose the PACTA monolith into pure, unit-tested functions; byte-identical MCB | PHASE-01 | `R/pacta_core.R`, thinned `scripts/pacta_vietnam_scenario.R`, `tests/testthat/test_pacta_core.R` |
| PHASE-03 | Make `pactatrisk` a genuinely loadable package + wire package tests into CI | PHASE-02 | `NAMESPACE`, updated `DESCRIPTION`/`.Rbuildignore`/`renv.lock`, `tests/testthat.R`, roxygen headers, CI step |

## Detailed Phases

### PHASE-01 - Repo Laws & Trap Documentation

**Goal**
Capture the non-obvious, expensive-to-rediscover rules of this repo in a root `CLAUDE.md`
and refresh the stale `AGENTS.md`, so the PHASE-02/03 refactor (and future engagements) can
be executed correctly by anyone with only a checkout. This phase touches no code and cannot
break the pipeline; doing it first de-risks everything after.

**Tasks**
- [ ] TASK-01-01: Create root `CLAUDE.md` documenting: (a) one-paragraph project description
  (synthetic-data PACTA+TRISK Vietnam bank platform); (b) the exact test commands
  (`Rscript -e "testthat::test_dir('tests/testthat')"` for R, `python -m pytest dashboard/tests`
  for Python); (c) the build/refresh commands (`Rscript scripts/pacta_vietnam_scenario.R`,
  `Rscript scripts/pipeline_refresh.R`, run from repo root); (d) the traps list from the
  Environment & Conventions section above (VND never rescaled; run from root; diacritic
  normalization via `normalize_vn_name()`; byte-identical MCB CSV is the refactor acceptance
  bar; the golden-number suite is load-bearing; PowerShell 5.1 has no `&&`); (e) the config
  convention (`--config`/`load_engagement_config`); (f) a "do not touch" list (`attic/`,
  `dashboard/data/` snapshot except via `refresh_dashboard_data.R`, synthetic-data disclaimers).
  Keep it under ~60 lines — a laws file, not a manual.
- [ ] TASK-01-02: Refresh `AGENTS.md`: remove the reference to `pacta_demo.R` (retired to
  `attic/`) and the `compare/` AI-vs-staff workflow framing; update the "How to run" and
  "essential commands" to match the current `scripts/` entrypoints (`pacta_vietnam_scenario.R`,
  `pipeline_refresh.R`) and add a one-line pointer to `CLAUDE.md` as the source of truth for
  laws. Keep the file short.
- [ ] TASK-01-03: Verify no stale references remain: `grep -rn "pacta_demo\|pacta_synthesis" AGENTS.md CLAUDE.md README.md`
  returns nothing (these scripts live only in `attic/` now).

**File Changes**
- `CLAUDE.md` (create): the repo-laws file per TASK-01-01. Place at repo root.
- `AGENTS.md` (modify): remove stale `pacta_demo.R`/`compare/` references; update run commands;
  add a `CLAUDE.md` pointer. Leave the high-level map structure intact.
- `README.md` (modify, only if TASK-01-03 finds a stale reference): correct it; otherwise leave
  untouched.

**Function Signatures**
None — no code interfaces change in this phase.

**Test Specs**
None — no testable behavior changes in this phase. (Verification is the grep in TASK-01-03 and
the doc review in Exit Criteria.)

**Dependencies**
- None.

**Exit Criteria**
- [ ] `CLAUDE.md` exists at repo root and lists the VND-never-rescale rule, the run-from-root
  rule, and the byte-identical-MCB-CSV acceptance bar verbatim.
- [ ] `grep -rn "pacta_demo\|pacta_synthesis" AGENTS.md CLAUDE.md README.md` prints nothing.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` still green (unchanged — proves the
  doc-only phase touched no behavior).

**Phase Risks**
- **RISK-01-01:** Documenting a command that does not actually work. Mitigation: run every
  command written into `CLAUDE.md` once before committing (they are all in this plan's
  Environment section and verified against the repo).

### PHASE-02 - Decompose the PACTA Monolith into Tested Functions

**Goal**
Extract the 9 inline sections of `scripts/pacta_vietnam_scenario.R` into pure functions in
`R/pacta_core.R`, reduce the script to a thin orchestration wrapper that calls them in order,
and add a fast unit-test suite — while every `synthesis_output/vietnam/*.csv` stays
byte-identical to the pre-refactor baseline.

**Tasks**
- [ ] TASK-02-01: Snapshot the acceptance baseline BEFORE touching code. Run
  `Rscript scripts/pacta_vietnam_scenario.R` from the repo root, then record hashes with a
  portable one-liner:
  `Rscript -e "f<-sort(list.files('synthesis_output/vietnam',pattern='[.]csv$',full.names=TRUE)); writeLines(paste(tools::md5sum(f), basename(f)), 'pacta_baseline_hashes.txt')"`.
  Keep `pacta_baseline_hashes.txt` out of the commit (add to `.gitignore` or delete after
  TASK-02-06).
- [ ] TASK-02-02: Read `scripts/pacta_vietnam_scenario.R` in full and map each section to a
  function. The section banners are at these line ranges (verify at execution time, they may
  drift): SECTION 1 Load (≈52–89), SECTION 2 Sector pre-join (≈90–152), SECTION 3 Fuzzy
  matching (≈153–230), SECTION 4 Coverage (≈231–313), SECTION 5 Market-share + its 5 charts
  (≈314–479), SECTION 6 SDA + its 2 charts (≈480–587), SECTION 7 Alignment-gap + its 2 charts
  (≈588–728), SECTION 8 Encode charts for HTML (≈729–778), SECTION 9 Build HTML report
  (≈779–1352).
- [ ] TASK-02-03: Create `R/pacta_core.R` with the functions in the Function Signatures below.
  Move code verbatim (ASM-002): the body of each function is the corresponding section's code,
  with the section's read-from variables promoted to parameters and its written-to variables
  returned. Keep the exact `readr::write_csv(...)` call sites inside the functions that
  currently write each CSV — the functions write to `output_dir` (from `cfg$paths$pacta_output_dir`)
  exactly as today. Preserve the top-of-file `library(...)` calls by leaving them in the
  script's preamble (the script still `library()`s the analysis stack before sourcing core), OR
  move them into `R/pacta_core.R`'s preamble guarded the same way the other `R/` modules guard
  theirs — pick one and be consistent; do not duplicate.
- [ ] TASK-02-04: Rewrite `scripts/pacta_vietnam_scenario.R` as a thin wrapper: keep the
  existing preamble (lines 1–49: header comment, `source("R/*.R")` including the new
  `source("R/pacta_core.R")`, `cfg <- load_engagement_config(get_config_arg())`, bank-name
  banner, `dir.create` of output dirs), then replace the 9 inline sections with ordered calls:
  `inputs <- pacta_load_inputs(cfg)` → `prejoined <- pacta_prejoin_sectors(inputs$loanbook)`
  → `matches <- pacta_match_and_prioritize(prejoined, inputs$abcd, output_dir)` →
  `coverage <- pacta_coverage(matches$prioritized, inputs$loanbook, output_dir)` →
  `ms <- pacta_market_share(matches$prioritized, inputs$abcd, inputs$scenario, inputs$region, output_dir, bank_name, bank_short)`
  → `sda <- pacta_sda(matches$prioritized, inputs$abcd, inputs$co2, inputs$region, output_dir, bank_name, bank_short)`
  → `gaps <- pacta_alignment_gaps(ms, sda, output_dir)` →
  `charts <- pacta_encode_charts(output_dir)` →
  `pacta_build_report(charts, cfg, report_dir, ms, sda, gaps, coverage)`. The exact parameter
  set per function is whatever that section actually reads — derive it from the code, do not
  invent parameters. The wrapper should be well under 100 lines.
- [ ] TASK-02-05: Create `tests/testthat/test_pacta_core.R` with fast unit tests (Test Specs
  below) that exercise the pure, cheap functions (pre-join sector mapping, coverage arithmetic)
  on tiny in-test fixtures — NOT a full pipeline run. These must run in seconds and not require
  the real `data/` CSVs.
- [ ] TASK-02-06: Acceptance check. Re-run `Rscript scripts/pacta_vietnam_scenario.R` (no
  flags) and compare CSV hashes to the TASK-02-01 baseline:
  `Rscript -e "f<-sort(list.files('synthesis_output/vietnam',pattern='[.]csv$',full.names=TRUE)); now<-paste(tools::md5sum(f),basename(f)); base<-readLines('pacta_baseline_hashes.txt'); if(!identical(now,base)) stop('CSV DRIFT:\n', paste(setdiff(now,base),collapse='\n')) else cat('BYTE-IDENTICAL: ', length(f), ' CSVs match\n')"`.
  Every `synthesis_output/vietnam/*.csv` hash must match. Open 2–3 regenerated PNGs and confirm
  titles still read "Mekong Commercial Bank".

**File Changes**
- `R/pacta_core.R` (create): the 9 extracted PACTA functions per Function Signatures; code moved
  verbatim from the script sections; writes the same CSVs to `output_dir` as today.
- `scripts/pacta_vietnam_scenario.R` (modify): keep preamble lines ≈1–49 (add
  `source("R/pacta_core.R")`); replace the 9 inline sections (≈50–1352) with the ordered
  function calls in TASK-02-04; keep the final completion banner (≈1353–end). Change no analysis
  logic, no `write_csv` arguments, no chart dimensions.
- `tests/testthat/test_pacta_core.R` (create): fast unit tests per Test Specs.
- `.gitignore` (modify, optional): add `pacta_baseline_hashes.txt` if you keep it around during
  the phase; otherwise delete the file before committing.

**Function Signatures**
<!-- Parameter sets are the section's actual read/write variables; confirm exact names against the code during TASK-02-02. Types are R classes. -->
- `pacta_load_inputs(cfg: list) -> list` — returns `list(loanbook, abcd, scenario, co2, region)`,
  each a tibble read from `cfg$inputs`; preserves the existing missing-file `stop()` and the
  portfolio-summary `cat()` output.
- `pacta_prejoin_sectors(loanbook: tbl) -> tbl` — returns the loanbook with the VSIC→PACTA/ISIC
  sector pre-join applied (SECTION 2), ready for matching.
- `pacta_match_and_prioritize(loanbook_prejoined: tbl, abcd: tbl, output_dir: chr) -> list` —
  returns `list(raw, prioritized)`; writes `01_vn_matched_raw.csv` and
  `02_vn_matched_prioritized.csv` to `output_dir` exactly as today.
- `pacta_coverage(matched_prioritized: tbl, loanbook: tbl, output_dir: chr) -> tbl` — returns the
  coverage table; writes the coverage pie PNG (`03_vn_coverage_pie.png`) to `output_dir`.
- `pacta_market_share(matched_prioritized: tbl, abcd: tbl, scenario: tbl, region: tbl, output_dir: chr, bank_name: chr, bank_short: chr) -> list` —
  returns `list(ms_company, ms_portfolio, ms_alignment)`; writes `04_vn_ms_company.csv`,
  `04_vn_ms_portfolio.csv`, and the 5 market-share PNGs; chart titles use `bank_name`/`bank_short`.
- `pacta_sda(matched_prioritized: tbl, abcd: tbl, co2: tbl, region: tbl, output_dir: chr, bank_name: chr, bank_short: chr) -> list` —
  returns `list(sda_portfolio, sda_alignment)`; writes `05_vn_sda_portfolio.csv` and the 2 SDA
  PNGs.
- `pacta_alignment_gaps(ms: list, sda: list, output_dir: chr) -> list` — returns
  `list(ms_alignment_2030, sda_alignment_2030)`; writes `06_vn_ms_alignment_2030.csv`,
  `06_vn_sda_alignment_2030.csv`, and the alignment-overview + stranded-asset PNGs.
- `pacta_encode_charts(output_dir: chr) -> list` — returns a named list of
  `data:image/png;base64,...` URIs (one per PNG in `output_dir`), using `img_to_base64()` from
  `R/report_toolkit.R` (SECTION 8).
- `pacta_build_report(charts: list, cfg: list, report_dir: chr, ms: list, sda: list, gaps: list, coverage: tbl) -> invisible(chr)` —
  assembles and writes the self-contained HTML report to `report_dir`; returns the written path
  (SECTION 9).

**Test Specs**
- `pacta_prejoin_sectors(tibble::tibble(sector_classification_direct_loantaker = c("D3511","C2910"), sector_classification_system = c("ISIC","ISIC"), ...minimal cols...))`
  → returns a tibble whose derived PACTA sector column maps `D3511` → `power` and `C2910` →
  `automotive` (use the exact mapping from `vsic_to_pacta` in the current code; assert the
  mapped sector values, not internal column order).
- `pacta_coverage()` on a 3-loan fixture where 2 loans matched and 1 did not → coverage table
  reports the matched exposure fraction consistent with the input VND weights (assert the
  matched/total ratio to `tolerance = 1e-9`; VND magnitudes are NOT rescaled).
- Byte-identity (integration, not a unit test): after TASK-02-06, the hash-comparison one-liner
  prints `BYTE-IDENTICAL: N CSVs match` and exits 0.
- Existing suite: `Rscript -e "testthat::test_dir('tests/testthat')"` → green, including
  `test_golden_numbers.R` (still asserts `engagement_priority.csv` rank-1 `name_abcd` ==
  `"Nghi Son Power LLC"`, `composite_score[1]` == 1.0) and `test_matching_helpers.R` unchanged.

**Dependencies**
- PHASE-01 (laws documented so the byte-identity bar is explicit).
- The analysis stack in `renv.lock` (already present).

**Exit Criteria**
- [ ] `R/pacta_core.R` exists and defines all 9 functions; `scripts/pacta_vietnam_scenario.R` is
  a thin wrapper (< 100 lines of non-comment code) that sources it and calls them in order.
- [ ] The TASK-02-06 hash comparison prints `BYTE-IDENTICAL` for every
  `synthesis_output/vietnam/*.csv`.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` green, including the new
  `test_pacta_core.R`.
- [ ] 2–3 regenerated PNGs still render "Mekong Commercial Bank" titles (visual check).

**Phase Risks**
- **RISK-02-01:** A dplyr pipeline gets subtly reordered or "tidied" during extraction, shifting
  `readr::write_csv` number formatting and breaking byte-identity. Mitigation: ASM-002 — move
  code verbatim; treat any hash mismatch as a defect to fix, never as a new baseline; the
  extraction is mechanical (cut section, wrap in `function(...) { ... }`, add params/return).
- **RISK-02-02:** A section reads a top-level variable created by an *earlier* section that isn't
  obviously a parameter (hidden coupling). Mitigation: TASK-02-02's line-range map + reading the
  full script first; make every cross-section dependency an explicit parameter or a field in a
  returned list; if a variable is used but never returned upward, the extraction has missed a
  dependency — the byte-identity check in TASK-02-06 will catch it as a crash or drift.
- **RISK-02-03:** The report toolkit / chart encoding relies on the PNGs already existing on
  disk when `pacta_encode_charts()` runs. Mitigation: preserve call order (charts are written by
  earlier functions before encoding); `pacta_encode_charts` globs `output_dir` exactly as
  SECTION 8 does today.

### PHASE-03 - Make `pactatrisk` a Genuinely Loadable Package

**Goal**
Turn the advertised-but-nonexistent package into a real one: `devtools::load_all(".")` exposes
the `R/` functions, `DESCRIPTION` lists real `Imports`, a generated `NAMESPACE` exports the
public functions, `devtools::test()` runs the suite, `R CMD build` produces a tarball with zero
ERRORs, and CI gains a package-load check — all without breaking the `source()`-based scripts.

**Tasks**
- [ ] TASK-03-01: Add `roxygen2` + `devtools` to the dev toolchain per ASM-004
  (`Rscript -e "renv::install(c('roxygen2','devtools')); renv::snapshot()"`; commit updated
  `renv.lock`). If network install is unavailable, take the hand-written `NAMESPACE` fallback in
  ASM-004 and note it in the commit message.
- [ ] TASK-03-02: Add `@export` roxygen tags above the public functions in `R/pacta_core.R`
  (the 9 `pacta_*` functions), `R/engagement_config.R` (`load_engagement_config`,
  `get_config_arg`), `R/sector_registry.R` (`sector_registry`, `trisk_base_params`),
  `R/report_toolkit.R` (`img_to_base64`, `report_css`, `write_html_report`, and any other
  public helpers), and `R/matching_helpers.R` (`normalize_vn_name` + siblings). Do NOT add
  `@import`/`@importFrom` directives (ASM-006 — they would break standalone `source()`); leave
  the existing `library()`/`requireNamespace()` guards in place.
- [ ] TASK-03-03: Generate `NAMESPACE` with
  `Rscript -e "roxygen2::roxygenise()"` (or hand-write `export(...)` lines per ASM-004 fallback).
  Confirm it contains an `export()` line for every function tagged in TASK-03-02.
- [ ] TASK-03-04: Update `DESCRIPTION`: add an `Imports:` field listing the pipeline packages
  actually used (dplyr, tidyr, ggplot2, scales, ggrepel, readr, stringi, base64enc, jsonlite,
  tibble, purrr, rlang, r2dii.data, r2dii.match, r2dii.analysis, r2dii.plot, pacta.loanbook,
  arrow, fs — cross-check against `renv.lock`); add `Suggests: testthat, roxygen2, devtools`;
  add `RoxygenNote` and `Roxygen: list(markdown = TRUE)`. Keep `Package: pactatrisk`,
  `Version: 0.1.0`, `License: Proprietary`, `Encoding: UTF-8` unchanged (DEC-002).
- [ ] TASK-03-05: Create `tests/testthat.R` (the standard package test entrypoint:
  `library(testthat); library(pactatrisk); test_check("pactatrisk")`) so `devtools::test()` and
  `R CMD check` discover `tests/testthat/`. Verify the existing tests still resolve
  `project_root()` correctly when run via the package harness (they walk up to the `dashboard/`
  dir; under `devtools::test()` the working directory is the package root, so this still works —
  confirm).
- [ ] TASK-03-06: Update `.Rbuildignore` to exclude non-package dirs from the build tarball so
  `R CMD build` stays fast and ERROR-free: add patterns for `dashboard`, `synthesis_output`,
  `output`, `intake`, `reports`, `plans`, `research`, `docs`, `pilot`, `present`, `compare`,
  `attic`, `renv`, `scripts`, `data`, `.github`, `activeContext.md`, `Rplots.pdf`,
  `pacta_baseline_hashes.txt`, and any other top-level non-R-package artifacts (verify current
  `.Rbuildignore` contents first and extend, don't clobber).
- [ ] TASK-03-07: Verify the package loads and tests pass through the package harness, and that
  the scripts still work via `source()`:
  `Rscript -e "devtools::load_all('.'); stopifnot(is.function(pacta_load_inputs), is.function(load_engagement_config))"`
  and `Rscript -e "devtools::test()"` and a fresh `Rscript scripts/pacta_vietnam_scenario.R`
  (byte-identity re-check from PHASE-02).
- [ ] TASK-03-08: Add a package-load check to `.github/workflows/ci.yml` in the existing
  `r-tests` job: after the renv restore step, add a step
  `Rscript -e "if (!requireNamespace('devtools', quietly=TRUE)) install.packages('devtools'); devtools::load_all('.'); cat('pactatrisk loads OK\n')"`
  BEFORE the existing `testthat::test_dir` step. Leave the rest of the workflow untouched.

**File Changes**
- `NAMESPACE` (create): generated `export()` lines for all public functions.
- `DESCRIPTION` (modify): add `Imports`, `Suggests`, `RoxygenNote`, `Roxygen`; keep
  Package/Version/License/Encoding.
- `R/pacta_core.R`, `R/engagement_config.R`, `R/sector_registry.R`, `R/report_toolkit.R`,
  `R/matching_helpers.R` (modify): add `#' @export` tags above public functions; no logic change;
  keep existing `library()`/`requireNamespace()` guards.
- `tests/testthat.R` (create): standard `test_check("pactatrisk")` entrypoint.
- `.Rbuildignore` (modify): extend with non-package top-level dirs/files (do not remove existing
  entries).
- `renv.lock` (modify): add `roxygen2`, `devtools` (dev deps) per ASM-004.
- `.github/workflows/ci.yml` (modify): add the `devtools::load_all` package-load step to the
  `r-tests` job before the test step.

**Function Signatures**
None — no code interfaces change in this phase (roxygen tags and package metadata only; the
function signatures from PHASE-02 are unchanged).

**Test Specs**
- `Rscript -e "devtools::load_all('.'); stopifnot(is.function(pacta_market_share), is.function(sector_registry))"`
  → exits 0 (package loads, functions exposed).
- `Rscript -e "devtools::test()"` → all tests green, including `test_pacta_core.R`,
  `test_golden_numbers.R`, `test_engagement_config.R`, `test_matching_helpers.R`.
- `R CMD build .` (or `Rscript -e "devtools::build()"`) → produces `pactatrisk_0.1.0.tar.gz`
  with zero ERRORs (WARNINGs/NOTEs acceptable per ASM-005).
- Regression: `Rscript scripts/pacta_vietnam_scenario.R` after package-ification →
  `synthesis_output/vietnam/*.csv` still byte-identical to the PHASE-02 baseline (scripts still
  work via `source()`, ASM-006).
- `NAMESPACE` contains `export(load_engagement_config)`, `export(pacta_load_inputs)`, and one
  `export(...)` per function tagged `@export`.

**Dependencies**
- PHASE-02 (the `pacta_*` functions must exist to be exported and tested).
- `roxygen2`/`devtools` (added in TASK-03-01 per ASM-004).

**Exit Criteria**
- [ ] `Rscript -e "devtools::load_all('.')"` succeeds and exposes the `pacta_*` and
  `load_engagement_config` functions.
- [ ] `Rscript -e "devtools::test()"` green.
- [ ] `Rscript -e "devtools::build()"` produces a tarball with zero ERRORs.
- [ ] `Rscript scripts/pacta_vietnam_scenario.R` still produces byte-identical MCB CSVs
  (scripts unbroken).
- [ ] `.github/workflows/ci.yml` `r-tests` job runs the package-load check before the test step.

**Phase Risks**
- **RISK-03-01:** Adding roxygen `@import` directives (instead of only `@export`) would make the
  `R/` files fail when `source()`d standalone by the scripts, breaking the pipeline. Mitigation:
  ASM-006 — `@export` tags ONLY; keep the `library()` guards; verify the scripts still run
  (TASK-03-07).
- **RISK-03-02:** `R CMD build` chokes on the large `data/`, `synthesis_output/`, or `dashboard/`
  trees, or on non-ASCII in `data/`. Mitigation: `.Rbuildignore` excludes them (TASK-03-06);
  the build target is a minimal R-code-only tarball, not a data package.
- **RISK-03-03:** `roxygen2`/`devtools` cannot be installed in the execution environment.
  Mitigation: ASM-004 hand-written `NAMESPACE` fallback; the CI step uses a conditional install
  so it degrades gracefully.
- **RISK-03-04:** `renv::snapshot()` prunes packages it thinks are unused, dropping a pipeline
  dep. Mitigation: after snapshot, diff `renv.lock` and confirm only `roxygen2`/`devtools` were
  ADDED and nothing was removed; restore any dropped entry.

## Gotchas

- **VND is never rescaled.** Loanbook money magnitudes span 1e5–5e12 in raw VND. No function in
  `R/pacta_core.R` may divide/multiply loan sizes except where the *original* section already
  did (e.g. the `/1000` in the portfolio-summary `cat`, which is display-only). Copy such
  arithmetic verbatim.
- **Byte-identity is measured on CSVs only.** PNGs differ run-to-run (compression); HTML reports
  differ in the generated timestamp. Do not chase PNG/HTML hash differences — only
  `synthesis_output/vietnam/*.csv` must match.
- **Run from repo root always.** Every command in this plan assumes `getwd()` is the repo root.
  `pacta_vietnam_scenario.R` and the tests' `project_root()` both depend on it.
- **`source()` and package-load must both keep working.** The scripts source `R/*.R`; the package
  loads them. Keep `library()`/`requireNamespace()` guards; use `@export` only, never `@import`.
- **Hidden cross-section coupling.** The monolith shares top-level variables across sections.
  When extracting, a variable read in SECTION 7 but created in SECTION 5 must flow as an explicit
  parameter/return — not a global. The byte-identity check surfaces any miss as a crash or drift.
- **Don't add pipeline dependencies.** The analysis stack is pinned; only `roxygen2`/`devtools`
  (dev-only) may be added, and the pipeline must never import them.
- **`helper-root.R` resolves the root via `dashboard/`.** Under `devtools::test()` the working
  directory is the package root (which contains `dashboard/`), so `project_root()` still works —
  confirm rather than assume.
- **The golden numbers are load-bearing.** `test_golden_numbers.R` pins
  `engagement_priority.csv` (23 rows, rank-1 `Nghi Son Power LLC`, composite 1.0) and the TRISK
  top borrower. A green run of these after each phase is the primary proof the refactor changed
  nothing.

## Verification Strategy

- **TEST-001 (PHASE-01):** `grep -rn "pacta_demo\|pacta_synthesis" AGENTS.md CLAUDE.md README.md`
  → prints nothing.
- **TEST-002 (PHASE-02 baseline):**
  `Rscript scripts/pacta_vietnam_scenario.R && Rscript -e "f<-sort(list.files('synthesis_output/vietnam',pattern='[.]csv$',full.names=TRUE)); writeLines(paste(tools::md5sum(f),basename(f)),'pacta_baseline_hashes.txt')"`
  → creates the baseline hash file (run BEFORE the decompose).
- **TEST-003 (PHASE-02 byte-identity):** after the decompose, re-run the script then
  `Rscript -e "f<-sort(list.files('synthesis_output/vietnam',pattern='[.]csv$',full.names=TRUE)); now<-paste(tools::md5sum(f),basename(f)); base<-readLines('pacta_baseline_hashes.txt'); if(!identical(now,base)) stop('DRIFT') else cat('BYTE-IDENTICAL\n')"`
  → prints `BYTE-IDENTICAL`.
- **TEST-004 (PHASE-02 unit tests):**
  `Rscript -e "testthat::test_file('tests/testthat/test_pacta_core.R')"` → green.
- **TEST-005 (all phases, regression):** `Rscript -e "testthat::test_dir('tests/testthat')"`
  → green (golden numbers, contracts, config, matching, pacta_core all pass).
- **TEST-006 (PHASE-03 load):**
  `Rscript -e "devtools::load_all('.'); stopifnot(is.function(pacta_load_inputs), is.function(load_engagement_config))"`
  → exits 0.
- **TEST-007 (PHASE-03 package tests):** `Rscript -e "devtools::test()"` → green.
- **TEST-008 (PHASE-03 build):** `Rscript -e "devtools::build()"` → produces
  `pactatrisk_0.1.0.tar.gz`, zero ERRORs.
- **MANUAL-001 (PHASE-02):** open 2–3 files in `synthesis_output/vietnam/*.png` and confirm chart
  titles still read "Mekong Commercial Bank".
- **MANUAL-002 (PHASE-03):** confirm `renv.lock` diff shows only `roxygen2`/`devtools` added and
  no pipeline package removed.
- **OBS-001 (CI):** push to a branch and confirm the `r-tests` job runs the new
  `devtools::load_all` step green before the `testthat::test_dir` step, and the `python-tests`
  job is unaffected.

## Risks and Alternatives

- **RISK-001:** The decompose silently shifts a published number, corrupting the public snapshot
  via the next weekly `refresh.yml` auto-commit. Mitigation: byte-identity gate (TEST-003) +
  golden tests (TEST-005) must both be green before merge; the refresh workflow is itself
  test-gated.
- **RISK-002:** Scope creep — the executor "improves" analysis logic while extracting.
  Mitigation: ASM-002 forbids logic changes; the acceptance bar is byte-identity, which any
  improvement would break.
- **RISK-003:** PHASE-03 package-ification breaks the `source()`-based scripts, taking down the
  whole pipeline. Mitigation: ASM-006 (`@export` only), TASK-03-07 re-runs the script and
  re-checks byte-identity.
- **ALT-001:** Delete `DESCRIPTION`/`.Rbuildignore` and commit to the "sourced scripts + renv"
  model instead of building the package (brainstorm ASM-1B option b). Not chosen: the stated
  commercial direction is running the pipeline for many banks, where a loadable
  `library(pactatrisk)` core is the clean substrate for orchestration and testing; the package
  also gives a standard test/check harness for free.
- **ALT-002:** Split `R/pacta_core.R` into per-stage files (`pacta_match.R`, `pacta_sda.R`, …).
  Not chosen this phase (ASM-001): one cohesive module keeps the extraction diff reviewable and
  the byte-identity comparison simple; splitting is cheap to do later once the functions are
  proven.
- **ALT-003:** Adopt a `targets` DAG for the pipeline now. Not chosen: premature at single-book
  scale (the brainstorm defers it to the 2nd–3rd real engagement); this plan's decompose is the
  prerequisite that makes a future `targets` adoption trivial.

## Suggested Next Step

Execute PHASE-01 (repo laws — no code risk), then PHASE-02 (decompose under the byte-identity
gate), then PHASE-03 (package-ify). Each phase's Exit Criteria are shell-verifiable before the
next begins; do not start PHASE-02 until TEST-002 has captured the baseline hashes on a clean
tree. After this plan lands, the natural follow-ons (separate plans) are: the TRISK-chain
decompose using the same pattern, and — once the client-engagement-runway plan's SDB run exists —
the second-book regression fixture.
