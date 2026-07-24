---
title: "Wave 1 — Consistency: Invariant Detector, Cross-Artifact Correctness, and Orchestrator Convergence"
date: "2026-07-25"
status: "draft"
request: "Wave 1 'Consistency' for pacta-trisk — invariants detector, cross-artifact correctness fixes (C1-C6), orchestrator convergence (A1), SDB CI guard, single golden refreeze"
plan_type: "multi-phase"
research_inputs:
  - "research/2026-07-25-post-wave0-platform-hardening-brainstorm.md"
  - "research/2026-07-20-runway-final-phases-and-beyond-brainstorm.md"
---

# Plan: Wave 1 — Consistency

## Objective

The repository currently ships **internally contradictory committed data**: the
precomputed 243-cell TRISK scenario grid that powers the dashboard's Scenario
Builder was generated on 2026-05-02 and never regenerated, so it disagrees with
the base TRISK run on the same borrower under identical parameters. Five sibling
defects live in the same blind spot — the existing acceptance tool verifies that
*run N+1 byte-matches run N*, and never that *artifact A agrees with artifact B*.

This plan builds the missing detector first, fixes every defect it exposes,
converges the two divergent pipeline orchestrators onto one code path, adds the
multi-bank CI guard that was reported as delivered but does not exist, and closes
with a single golden refreeze commit.

## Context Snapshot

- **Current state:** R test suite 203 pass / 0 fail; Python suite 58 pass; working tree clean; package `pactatrisk` 0.2.0. Two engagement configs exist (`mcb-demo`, `sdb-rehearsal`). `tools/verify_refactor.R` enforces byte-identity between consecutive runs. Six cross-artifact defects (C1–C6 below) are present and reproducible, plus two inert dashboard controls discovered while planning (C7).
- **Desired state:** `tools/verify_refactor.R --invariants` mechanically enforces five cross-artifact invariants and runs in CI. The scenario grid regenerates whenever its inputs change. Every engagement's outputs carry its own provenance. One orchestrator serves both the public MCB demo and client engagements. A CI job runs a full non-MCB engagement end-to-end weekly. All golden literals refrozen once.
- **Key repo surfaces:** `tools/verify_refactor.R`, `R/trisk_core.R`, `R/prioritization_core.R`, `R/engagement_config.R`, `R/step_runner.R`, `R/sector_registry.R`, `scripts/pipeline_refresh.R`, `scripts/run_engagement.R`, `scripts/engagement_scoring.R`, `scripts/trisk_prepare_inputs.R`, `scripts/generate_vietnam_data.R`, `tests/testthat/`, `dashboard/tests/`, `.github/workflows/ci.yml`, `.github/workflows/refresh.yml`, `engagements/*/engagement_config.json`.
- **Out of scope:** Absolute/anchored rescoring of composites (min-max normalization stays as-is this wave); the multi-scenario traffic-light view; the executive-summary generator; automotive TRISK; a data-driven sector registry; financial-features intake; making the Streamlit dashboard engagement-aware; rescaling the synthetic loanbook magnitudes; Vietnamese i18n; PDF export; `targets` migration; any upstream change to `r2dii.*` or `trisk.model`; real (non-synthetic) bank data.

## Environment & Conventions

- **Stack:** R 4.5.2 (pinned in `renv.lock`) for the analysis pipeline; Python 3.11+ (CI uses 3.12) with Streamlit for the dashboard. R dependency management is `renv`. Python deps are plain `pip` + `dashboard/requirements.txt`. The R package in this repo is named `pactatrisk` (`DESCRIPTION`, version 0.2.0). `trisk.model` is version 2.6.1. **`yaml` is deliberately NOT a dependency — all configs are JSON via `jsonlite`.**
- **Setup:**
  ```bash
  python -m pip install -r dashboard/requirements.txt
  Rscript -e "renv::restore()"          # or, without renv:
  Rscript scripts/ci/install_deps.R
  ```
- **Build / Run:**
  ```bash
  Rscript scripts/pipeline_refresh.R           # 8-step default TRISK refresh + snapshot
  Rscript scripts/pipeline_refresh.R --full    # 11-step: prepends data-gen + PACTA, appends scoring + audit
  Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --raw-loanbook data/fixtures/unseen_bank_loanbook.csv
  python -m streamlit run dashboard/app.py
  ```
- **Test:**
  - Full R suite: `Rscript -e "testthat::test_dir('tests/testthat')"`
  - Single R file: `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`
  - Full Python suite: `python -m pytest dashboard/tests`
  - Single Python test: `python -m pytest dashboard/tests/test_loaders.py::test_trisk_grid_scenario_count`
- **Conventions & traps:**
  - **Always run R commands from the repository root.** Every script resolves paths via `getwd()`. `tests/testthat/helper-root.R`'s `project_root()` walks upward looking for a `dashboard/` directory.
  - **VND is never rescaled by the pipeline.** Loanbook money (`loan_size_outstanding`, currency literal `VND`) spans raw magnitudes 1e5–5e12. Never divide or multiply except where existing code already does so for console display.
  - **Vietnamese names are matched after ASCII normalization** via `normalize_vn_name()` in `R/matching_helpers.R` (wraps `stringi::stri_trans_general(x, "Latin-ASCII")`). CSVs are UTF-8 without BOM.
  - **Acceptance bar:** any change touching `scripts/` or `R/` must leave every default-mode `synthesis_output/**/*.csv` byte-identical unless the change is an intentional, documented refreeze. Verify with `Rscript tools/verify_refactor.R`, **not** raw `md5sum` — git applies `core.autocrlf` normalization, so a file that is byte-identical after normalization shows as unchanged in `git diff` even when raw `md5sum` differs across Windows/Linux.
  - **Engagement-config convention:** scripts source `R/engagement_config.R` and call `cfg <- load_engagement_config(get_config_arg())`. No `--config` flag ⇒ built-in MCB defaults reproducing today's hardcoded paths exactly. Never hardcode a new path outside this mechanism.
  - **Windows PowerShell 5.1 has no `&&` chaining.** Use `;` sequencing or separate commands. On Windows, either prepend `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe"` or add that directory to `PATH` for the session — `system2("Rscript", ...)` needs `Rscript` resolvable on `PATH` even when the outer call used a full path.
  - **Do not touch:** `attic/` (retired reference scripts). `dashboard/data/` may only be written by `scripts/refresh_dashboard_data.R`. Synthetic-data disclaimers (README banner, dashboard banners, report footers) must always state the data is synthetic/illustrative.
  - Roxygen docs live inline in `R/*.R`; `NAMESPACE` and `man/` are generated — regenerate with `Rscript -e "roxygen2::roxygenise()"` after changing `@export` tags.
- **Repo map:**
  ```
  R/                  shared modules: engagement_config, sector_registry, pacta_core,
                      trisk_core, prioritization_core, step_runner, report_toolkit
  scripts/            R pipeline stages + the two orchestrators
                      (pipeline_refresh.R = MCB/public; run_engagement.R = any bank)
  tools/              dev-only tooling — currently just verify_refactor.R
  data/               synthetic inputs; data/scenarios/<vintage>/ holds versioned scenarios
  synthesis_output/   pipeline outputs: vietnam/ (PACTA), trisk/<sector>_demo/, trisk/grid/<sector>/
  output/             engagement scoring, letters, disclosure, trisk_inputs
  engagements/<slug>/ per-engagement config + committed regression artifacts
  dashboard/          Streamlit app; dashboard/data/ is the frozen public snapshot
  tests/testthat/     R tests   |   dashboard/tests/  Python tests
  .github/workflows/  ci.yml (push/PR) and refresh.yml (Mondays 02:00 UTC, auto-commits)
  ```

## Research Inputs

- From `research/2026-07-25-post-wave0-platform-hardening-brainstorm.md`:
  - **C1 (critical):** `trisk_run_grid()` keys its cache on `scenario_id` alone — the five lever values — with no dependency on input data, ABCD, scenario vintage, or `trisk.model` version, and short-circuits entirely when the committed `borrower_results.parquet` already covers every `scenario_id`. Git archaeology: `dashboard/data/trisk/grid/power/borrower_results.parquet` last changed in commit `251adc8` (2026-05-02) while `data/vietnam_trisk_assets_power.csv` and `synthesis_output/trisk/power_demo/npv_results_latest.csv` changed in `0e57fd9` (2026-07-21 refreeze). Measured disagreement at identical parameters — Dung Quat LNG Power Consortium: grid −0.432056 vs base run −0.374884 (5.72 pp, 15.3% relative); PVN Power Corporation: −0.425554 vs −0.406385.
  - **C2:** `scripts/engagement_scoring.R` line 79 hardcodes `data_source <- "MCB_synthetic"` although `cfg$bank_slug` is loaded 18 lines earlier. The committed Saigon Delta Bank deliverable `engagements/sdb-rehearsal/output/engagement/engagement_priority.csv` therefore reads `MCB_synthetic` in every row. `R/prioritization_core.R` line 69 does this correctly (`data_source <- cfg$bank_slug`), which makes C2 a bug rather than a convention.
  - **C3:** `tests/testthat/test_sdb_engagement.R` contains no `system2` / `Rscript` / pipeline invocation — it reads three committed files and asserts on their contents, so it guards the artifacts, not the code. `grep -rn "run_engagement\|sdb\|engagement" .github/workflows/` returns nothing: the weekly SDB CI job described in `reports/2026-07-22-final-wave0-completion.html` does not exist. Separately, `engagements/sdb-rehearsal/engagement_config.json` points `inputs.loanbook_csv` at `data/vietnam_loanbook.csv` (MCB's book); the rehearsal actually ran with `--raw-loanbook data/fixtures/unseen_bank_loanbook.csv`, a flag recorded nowhere — so the config does not self-describe its own reproduction.
  - **C4:** `prioritize_sectors()` in `R/prioritization_core.R` hardcodes `sectors <- c("power", "cement", "steel")` (line 68) and the ISIC→Decision-263 map (line 149) instead of deriving them from `cfg$trisk_sectors`, which the config layer validates and then this function ignores.
  - **C5:** `data/vietnam_scenario_ms.csv` and `data/scenarios/pdp8-2023/vietnam_scenario_ms.csv` are byte-identical (`md5 1827b2776aa0df5f50b72ff866d54665`). `mcb-demo` reads the versioned path; `sdb-rehearsal` reads the flat one.
  - **C6:** `intake/SCHEMA.md` and `intake/templates/abcd_template.csv` specify 14 ABCD columns including `data_source` and `as_of_year`; the actual `data/vietnam_abcd.csv` has only the 12 non-provenance columns, so the demo's own ABCD fails the demo's own documented contract. No ABCD validator exists.
  - **A1:** Two orchestrators must not diverge and already have. `scripts/pipeline_refresh.R` runs `scripts/trisk_power_demo.R` and includes `generate_refresh_audit.R` but no intake, letters, or disclosure, and does not accept `--config`. `scripts/run_engagement.R` runs `scripts/trisk_sector_demo.R power`, includes intake/letters/disclosure, but has no refresh audit and no data-generation step. The public demo — the artifact prospects see — never travels the engagement code path, and only `pipeline_refresh.R` runs in CI.
  - **A5:** The generalized fix is an invariants mode on `tools/verify_refactor.R`: the tool answers "does run N+1 match run N?" and is structurally blind to "does artifact A agree with artifact B", which is where every C-finding lives.
- Measured directly against the committed artifacts while preparing this plan (no prior brief records it):
  - **C7 — two of the Scenario Builder's five levers are inert.** Holding the other four fixed, `shock_year`, `discount_rate`, and `market_passthrough` each yield 3 distinct outcomes; `risk_free_rate` and `carbon_price_family` each yield exactly 1. The 243-cell power grid therefore contains only 27 distinct results. Root cause for the carbon-price lever: `carbon_price_model_map` maps all three `NGFS_*` families to a single model per sector (`increasing_carbon_tax_50` for power), and `.trisk_build_carbon_price()` emits only that one price path — so the "strict / moderate / mild" choice the dashboard advertises does not exist in the data. The `risk_free_rate` no-op is independently visible in the base sensitivity table: in `dashboard/data/trisk/power/sensitivity_results.csv`, `risk_free_rate_0.02`, `risk_free_rate_0.04`, and `base` all sum to `-4.034687` in `npv_change`.
  - Corroborating evidence for C1 from the same table: that base sum is `-4.034687`, while the grid's parameter-identical base cell sums to `-4.112455` — a second, independent confirmation that the grid predates the Wave-0 refreeze.
- From `research/2026-07-20-runway-final-phases-and-beyond-brainstorm.md`:
  - Byte-identity must be checked with autocrlf-aware `git diff`, never raw `md5sum` — established empirically during the phase-1/2 refactors.
  - `dashboard/tests/test_auth.py::test_no_password_renders_landing` is a known environmental flake caused by a hardcoded 3-second Streamlit `AppTest` timeout. It did not fire during the most recent verification run but may fire on slower machines; treat a lone failure there as environmental, not as a regression.
  - Golden refreezes are batched into a single commit so the test suite is refrozen exactly once per wave.

## Assumptions and Constraints

- **ASM-001:** The scenario grid's staleness is a defect, not an intentional freeze. Nothing in the repo documents an intentional freeze, `grid_meta.json` already records `generated_at`, `trisk_model_version`, and `grid_contract_version` that nothing checks, and the Scenario Builder presents grid output as the same quantity the TRISK page presents. — **BINDING DEFAULT:** treat as a defect and regenerate.
- **ASM-002:** Which of the five grid levers actually influence TRISK results was measured during planning, not assumed. Holding the other four levers fixed, `shock_year`, `discount_rate`, and `market_passthrough` each produce 3 distinct outcomes; `risk_free_rate` and `carbon_price_family` each produce exactly 1. The 243-cell grid therefore contains only 27 distinct results. The `risk_free_rate` no-op is independently confirmed in the base sensitivity table (`dashboard/data/trisk/power/sensitivity_results.csv`: `risk_free_rate_0.02`, `risk_free_rate_0.04`, and `base` all sum to `-4.034687`). — **BINDING DEFAULT:** the `carbon_price_family` no-op has a known root cause (one carbon-price scenario per sector) and is **fixed** in PHASE-04. The `risk_free_rate` no-op is investigated in PHASE-04 TASK-04-02; if `trisk.model` 2.6.1 genuinely ignores the parameter, **remove** the lever from `grid_levers`, from `trisk_sensitivity_specs`, and from the Scenario Builder UI, shrinking the grid from 243 to 81 cells and bumping `grid_contract_version` to `"v2"`.
- **ASM-003:** Golden test literals are refrozen exactly once, in PHASE-06. PHASE-02 through PHASE-05 are committed as code commits whose exit criteria are unit-test-based and invariant-based, never byte-identity-based; the working tree is expected to show data drift between PHASE-02 and PHASE-06. — **BINDING DEFAULT:** do not update any golden literal before PHASE-06.
- **ASM-004:** The public-snapshot guard rail currently compares magic strings (`cfg$paths$snapshot_dir == "dashboard/data"` and `cfg$bank_slug != "mcb-demo"`). — **BINDING DEFAULT:** replace with an explicit boolean config key `public_snapshot_allowed` defaulting to `FALSE`, set to `true` only in `engagements/mcb-demo/engagement_config.json`. The orchestrator refuses when `snapshot_dir` resolves to `dashboard/data` and `public_snapshot_allowed` is not `TRUE`.
- **ASM-005:** Fixing the `carbon_price_family` no-op must not change the base run's numbers. — **BINDING DEFAULT:** keep the existing per-sector carbon-price scenario name as the `NGFS_NetZero2050` variant with its current `carbon_tax` values unchanged, and *add* two new scenario rows-sets (`NGFS_Below2C`, `NGFS_Delayed`) to `ngfs_carbon_price.csv`. `trisk.model` filters that file by scenario name, so the base run reads identical prices and produces identical numbers; only the input CSV gains rows.
- **ASM-006:** A full ABCD intake validator (mirroring `scripts/intake_validate_and_map.R`) is Wave-3 scope. — **BINDING DEFAULT:** this wave adds only the two missing provenance columns to the generated ABCD plus a pure `validate_abcd_schema()` function with unit tests, wired into `trisk_prepare_sector_inputs()` as a hard failure. No new CLI script.
- **ASM-007:** After PHASE-05, `scripts/pipeline_refresh.R` remains as a thin backwards-compatible wrapper rather than being deleted, because `.github/workflows/refresh.yml`, `README.md`, `CLAUDE.md`, `AGENTS.md`, and `tools/verify_refactor.R` all invoke it by name. — **BINDING DEFAULT:** keep the file and its `--full` flag; make it delegate.
- **ASM-008:** Manifest step names will change when MCB moves onto the engagement code path (`trisk_power_demo` → `trisk_sector_demo_power`). `pipeline_manifest.json` is already classified `timestamp-class` by `tools/verify_refactor.R:TIMESTAMP_BASENAMES`, so this is not drift. — **BINDING DEFAULT:** accept the rename; `tests/testthat/test_manifest_json.R` asserts `length(steps) >= 7` and `status == "ok"`, both of which survive.
- **CON-001:** No new pipeline dependency may be added. All work uses packages already in `renv.lock`: `arrow`, `base64enc`, `devtools`, `dplyr`, `fs`, `ggplot2`, `ggrepel`, `jsonlite`, `pacta.loanbook`, `purrr`, `r2dii.analysis`, `r2dii.data`, `r2dii.match`, `r2dii.plot`, `readr`, `rlang`, `roxygen2`, `scales`, `stringi`, `testthat`, `tibble`, `tidyr`, `trisk.model`, `xfun`.
- **CON-002:** `dashboard/` must never acquire an R runtime dependency — Streamlit Community Cloud has no R.
- **CON-003:** `.github/workflows/refresh.yml` auto-commits to `main` every Monday and is gated by the R test suite. Any test made to fail deliberately (PHASE-01) must be fixed before the next Monday or the weekly publish blocks.
- **DEC-001:** Build the detector before the fixes. PHASE-01 must end with `tools/verify_refactor.R --invariants` **exiting non-zero** on the untouched tree, naming the violations the later phases fix. This mirrors the Wave-0 sequencing that put `tools/verify_refactor.R` before every refactor.
- **DEC-002:** One golden refreeze commit for the whole wave (PHASE-06).
- **DEC-003:** Convergence direction is `pipeline_refresh.R` → `run_engagement.R`, not the reverse, and not a third orchestrator.

## Specification

### S1 — Invariant INV-001: grid base cell equals base run

For each sector `k` in the published TRISK manifest with `grid_available == TRUE`:

Let

- `B_k` = the base-parameter scenario id for sector `k`, constructed by
  `build_scenario_id(shock_year = 2028, discount_rate = 0.08, risk_free_rate = 0.03, market_passthrough = 0.25, carbon_price_family = "NGFS_NetZero2050")`.
  With the `sprintf("s%s_d%.2f_rf%.2f_mp%.2f_c%s", ...)` format this is the literal string
  `s2028_d0.08_rf0.03_mp0.25_cNGFS_NetZero2050`.
  *(These five numbers are `trisk_base_params()`'s `shock_year`, `discount_rate`, `risk_free_rate`, and `market_passthrough`, plus the first `carbon_price_family` lever value.)*
- `G_k` = rows of `<snapshot>/trisk/grid/<k>/borrower_results.parquet` where `scenario_id == B_k`, keyed by `company_id`.
- `S_k` = rows of `<snapshot>/trisk/<k>/company_summary.csv`, keyed by `company_id`.

The invariant holds when, for every `company_id` present in either set:

```
company_id set of G_k  ==  company_id set of S_k
|G_k.npv_change_pct[i] − S_k.npv_change[i]|  ≤  1e-6      for all i
|G_k.pd_change_pct[i]  − S_k.pd_change[i]|   ≤  1e-6      for all i
```

Symbols: `npv_change_pct` and `npv_change` are both **fractional** changes in net
present value (−0.98 means a 98% loss), not percentages out of 100. `pd_change_pct`
and `pd_change` are both **absolute changes in probability of default**, expressed
as a fraction (0.21 means +21 percentage points of PD). The tolerance `1e-6` is
chosen because unaffected companies currently agree to 6 decimal places
(`-0.980411` in both artifacts) while affected companies differ in the 2nd
decimal place.

**Validity note:** for `power`, all three `carbon_price_family` values map to the
same `carbon_price_model` (`increasing_carbon_tax_50`, per
`carbon_price_model_map$power`), which is also `sector_meta("power")$carbon_price_model`.
The base grid cell is therefore parameter-identical to the base sensitivity run
(`run_label == "base"`). The same holds for cement and steel with their own model
names. After PHASE-04's carbon-price fix (ASM-005), `NGFS_NetZero2050` still maps
to the unchanged original price path, so the invariant remains valid.

### S2 — Grid cache fingerprint

The grid cache is valid only when the fingerprint recorded at generation time
still matches the current environment. Define:

```
input_fingerprint = md5( concat_in_sorted_filename_order(
    md5(<grid_dir>/input/assets.csv),
    md5(<grid_dir>/input/scenarios.csv),
    md5(<grid_dir>/input/financial_features.csv),
    md5(<grid_dir>/input/ngfs_carbon_price.csv)
) )
```

Symbols: `md5(f)` is `tools::md5sum(f)` — the raw file digest, unnormalized.
`<grid_dir>` is `file.path(getwd(), cfg$paths$trisk_output_root, "grid", sector)`.
The four filenames are sorted lexicographically before concatenation so the
digest is order-stable across platforms: `assets.csv`, `financial_features.csv`,
`ngfs_carbon_price.csv`, `scenarios.csv`.

Cache reuse is permitted if and only if **all three** hold:

1. `grid_meta.json$input_fingerprint` exists and equals the freshly computed `input_fingerprint`.
2. `grid_meta.json$trisk_model_version` equals `as.character(utils::packageVersion("trisk.model"))`.
3. `grid_meta.json$grid_contract_version` equals the in-code `grid_contract_version` constant.

If any check fails, every cached scenario is discarded: `completed_ids` is set to
`character()`, `existing$borrower_results` is treated as an empty tibble, and the
on-disk `runs/` directory for that sector is deleted before regeneration so
`find_cached_run_path()` cannot resurrect stale per-run CSVs.

**Ordering requirement:** the fingerprint must be computed **after**
`build_grid_input_dir()` has refreshed `<grid_dir>/input/` from the sector's
current input package, because that function copies the live inputs in. Computing
it earlier fingerprints the previous run's inputs.

### S3 — Decision logic for the `risk_free_rate` lever (PHASE-04 TASK-04-02)

1. Run two ad-hoc power TRISK runs that differ **only** in `risk_free_rate` (0.02 vs 0.04), using `scripts/trisk_run_adhoc.R`.
2. Compare the resulting `npv_results.csv` `npv_change` columns.
3. **If the two runs differ** for at least one company by more than `1e-9`: the lever is live, the observed no-op is a bug elsewhere in this repo's parameter plumbing. Fix the plumbing (inspect `build_run_params()`'s `overrides` merge and `run_trisk_sensitivity_case()`'s argument forwarding), keep the lever, and leave `grid_contract_version` at `"v1"`.
4. **If the two runs are identical:** `trisk.model` 2.6.1 ignores the parameter. Remove `risk_free_rate` from `grid_levers`, remove the `risk_free_rate_0.02` and `risk_free_rate_0.04` rows from `trisk_sensitivity_specs`, remove the risk-free-rate slider from `dashboard/pages/5_Scenario_Builder.py`, drop `rf` from `build_scenario_id()`/`build_grid_label()`/`_build_scenario_id()`/`_parse_scenario_id()`, set `grid_contract_version <- "v2"`, and update the hardcoded `243` in `dashboard/tests/test_loaders.py` to derive from `grid_meta.json$scenario_count`.
5. Record the outcome and the evidence in `docs/TRISK_Demo_Assumptions.md` either way.

## Phase Summary

| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Build the cross-artifact invariant detector and prove it fails on the current tree | None | `tools/verify_refactor.R --invariants`, `tests/testthat/test_verify_invariants.R` |
| PHASE-02 | Fix provenance and config-fidelity defects (C2, C4, C3-config) | PHASE-01 | Correct `data_source`; sector-aware prioritization; self-describing engagement configs |
| PHASE-03 | Single source of truth for scenario vintages and ABCD provenance (C5, C6) | PHASE-01 | Retired duplicate scenario files; ABCD provenance columns + schema validator |
| PHASE-04 | Grid correctness: input fingerprinting, regeneration, and dead levers (C1, C7) | PHASE-01, PHASE-03 | Fingerprinted `grid_meta.json`; regenerated grid; live carbon-price lever; risk-free-rate resolved |
| PHASE-05 | Converge the two orchestrators onto one code path (A1) | PHASE-02, PHASE-04 | `pipeline_refresh.R` delegates to `run_engagement.R`; `trisk_power_demo.R` removed |
| PHASE-06 | SDB CI guard, single golden refreeze, docs (C3-CI) | PHASE-01…05 | SDB CI job; invariants in CI; one refreeze commit; updated docs and `NEWS.md` 0.3.0 |

## Detailed Phases

### PHASE-01 - Cross-Artifact Invariant Detector

**Goal**

Add an `--invariants` mode to `tools/verify_refactor.R` that checks five
cross-artifact invariants, unit-test its pure functions, and demonstrate that it
exits non-zero on the untouched tree by detecting exactly the defects PHASE-02
through PHASE-04 will fix. No production behavior changes in this phase.

**Tasks**

- [ ] TASK-01-01: Add `INVARIANTS` implementation to `tools/verify_refactor.R`. Implement each check as a standalone pure-ish function taking a repo root and returning a `list(id, ok, detail)` record. Keep the existing `classify_path()` / `run_refresh()` / `main()` code untouched apart from arg parsing and dispatch.
- [ ] TASK-01-02: Implement `inv_grid_matches_base_run(root, snapshot_dir, tolerance)` per Specification S1.
- [ ] TASK-01-03: Implement `inv_scenario_vintage_single_source(root)` — fails when any file under `data/scenarios/<vintage>/` has a byte-identical twin directly under `data/`, reporting each duplicate pair. (Expected to FAIL now; fixed in PHASE-03.)
- [ ] TASK-01-04: Implement `inv_engagement_data_source(root)` — for every `engagements/*/engagement_config.json`, if `<engagement_output_dir>/engagement_priority.csv` exists, assert every value in its `data_source` column equals that config's `bank_slug`. (Expected to FAIL now for `sdb-rehearsal`; fixed in PHASE-02.)
- [ ] TASK-01-05: Implement `inv_sector_lists_agree(root)` — assert the sector sets in `R/sector_registry.R`'s `sector_registry()$sector`, `R/engagement_config.R`'s `supported_sectors` literal, `R/trisk_core.R`'s `trisk_supported_sectors`, and `scripts/new_engagement.R`'s `supported` literal are all identical as sets. Extract the three literal vectors by sourcing `R/sector_registry.R` and `R/trisk_core.R` and by regex-scanning `R/engagement_config.R` and `scripts/new_engagement.R` for `c("power", ...)` on the line following the `supported`/`supported_sectors` assignment. (Expected to PASS now; guards future drift.)
- [ ] TASK-01-06: Implement `inv_snapshot_manifest_sectors(root, snapshot_dir)` — assert every `sector` in `<snapshot_dir>/trisk/manifest.csv` is present in `sector_registry()$sector`. (Expected to PASS now.)
- [ ] TASK-01-07: Wire `--invariants` into `main()`. When present, run only the invariant checks (never the refresh) unless `--skip-refresh` is absent AND `--invariants` is combined with a normal run — see File Changes for exact dispatch. Print one `[PASS]`/`[FAIL]` line per invariant plus a detail block per failure. Exit `1` if any invariant failed, else `0`, printing `INVARIANTS PASS`.
- [ ] TASK-01-08: Create `tests/testthat/test_verify_invariants.R` with unit tests over the pure helpers using `tempdir()`-built fixtures — never over the live repo tree, so the tests stay green through PHASE-02…05.
- [ ] TASK-01-09: Run the detector on the untouched tree and capture its output verbatim into the phase's commit message.

**File Changes**

- `tools/verify_refactor.R` (modify): add a new section below `classify_path()` containing the six invariant functions and a `run_invariants(root, snapshot_dir)` dispatcher. Extend `main()`'s arg parsing with `invariants_mode <- "--invariants" %in% args`; when TRUE, skip `run_refresh()` entirely and call `run_invariants()` instead of the diff classification, then `quit(status = if (any_failed) 1L else 0L)`. Extend the usage comment block at the top. **Leave `VOLATILE_BASENAMES`, `TIMESTAMP_BASENAMES`, `classify_path()`, `run_refresh()`, and `changed_paths()` byte-identical.** Keep the existing bottom guard `if (identical(environment(), globalenv()) && sys.nframe() == 0L) main()` unchanged so the file stays safely `source()`-able from tests.
- `tests/testthat/test_verify_invariants.R` (create): `source(file.path(project_root(), "tools", "verify_refactor.R"))` then unit tests per Test Specs below.

**Function Signatures**

- `inv_grid_matches_base_run(root: character, snapshot_dir: character = "dashboard/data", tolerance: numeric = 1e-6) -> list` — returns `list(id = "INV-001", ok = logical(1), detail = character())`; `detail` holds one line per mismatching `(sector, company_id)` formatted `"<sector>/<company_id>: grid <npv_grid> vs base <npv_base> (delta <d>)"`.
- `inv_scenario_vintage_single_source(root: character) -> list` — returns `list(id = "INV-002", ok, detail)`; `detail` holds one line per duplicate pair formatted `"<flat_path> == <versioned_path> (md5 <hash>)"`.
- `inv_engagement_data_source(root: character) -> list` — returns `list(id = "INV-003", ok, detail)`; `detail` holds one line per offending file formatted `"<path>: expected data_source '<slug>', found '<values>'"`.
- `inv_sector_lists_agree(root: character) -> list` — returns `list(id = "INV-004", ok, detail)`; `detail` names each source and its sector set when they disagree.
- `inv_snapshot_manifest_sectors(root: character, snapshot_dir: character = "dashboard/data") -> list` — returns `list(id = "INV-005", ok, detail)`; `detail` lists manifest sectors absent from the registry.
- `run_invariants(root: character, snapshot_dir: character = "dashboard/data") -> logical(1)` — prints a `[PASS]`/`[FAIL]` line and detail block per invariant; returns `TRUE` when every invariant passed.
- `.md5_of(path: character) -> character` — returns the unnamed `tools::md5sum()` digest, or `NA_character_` when the file is missing.

**Test Specs**

- `inv_grid_matches_base_run()` against a `tempdir()` fixture where `trisk/grid/power/borrower_results.parquet` holds one row `(scenario_id = "s2028_d0.08_rf0.03_mp0.25_cNGFS_NetZero2050", company_id = "X", npv_change_pct = -0.5, pd_change_pct = 0.1)` and `trisk/power/company_summary.csv` holds `(company_id = "X", npv_change = -0.5, pd_change = 0.1)`, with `trisk/manifest.csv` listing `power` and `grid_available = TRUE` → `$ok == TRUE`, `length($detail) == 0`.
- Same fixture with `npv_change = -0.45` in `company_summary.csv` → `$ok == FALSE`, `length($detail) == 1`, and `grepl("power/X", $detail[1]) == TRUE`.
- Same fixture with `npv_change = -0.5000005` (delta `5e-7`, below tolerance `1e-6`) → `$ok == TRUE`.
- Fixture where the grid has company `X` and `company_summary.csv` has companies `X` and `Y` → `$ok == FALSE` with a detail line naming the missing `Y`.
- Fixture where `manifest.csv` marks `power` as `grid_available = FALSE` → sector skipped entirely, `$ok == TRUE`.
- `inv_scenario_vintage_single_source()` on a fixture with `data/foo.csv` and `data/scenarios/v1/foo.csv` written with identical content → `$ok == FALSE`, one detail line. With differing content → `$ok == TRUE`. With no `data/scenarios/` directory at all → `$ok == TRUE`.
- `inv_engagement_data_source()` on a fixture engagement whose config has `bank_slug = "acme"` and whose `engagement_priority.csv` has `data_source` values `c("acme", "acme")` → `$ok == TRUE`; with values `c("acme", "MCB_synthetic")` → `$ok == FALSE` with one detail line containing `MCB_synthetic`. With the CSV absent → the engagement is skipped and `$ok == TRUE`.
- `inv_sector_lists_agree()` on the live repo → `$ok == TRUE` (all four sources are currently `power, cement, steel`).
- `.md5_of("<nonexistent>")` → `NA_character_`.
- **Phase acceptance (manual, not a testthat assertion):** `Rscript tools/verify_refactor.R --invariants` on the untouched tree exits `1` and prints `[FAIL]` for exactly `INV-001`, `INV-002`, and `INV-003`, and `[PASS]` for `INV-004` and `INV-005`.

**Dependencies**

- None beyond packages already in `renv.lock` (`arrow` for `read_parquet`, `jsonlite`, `readr`, `tools`).

**Exit Criteria**

- [ ] `Rscript -e "testthat::test_file('tests/testthat/test_verify_invariants.R')"` → all tests pass.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` → `FAIL 0`, pass count ≥ 203 plus the new tests.
- [ ] `Rscript tools/verify_refactor.R --invariants; echo "exit=$?"` → prints `exit=1` with `[FAIL] INV-001`, `[FAIL] INV-002`, `[FAIL] INV-003`.
- [ ] The `INV-001` detail block names `Dung Quat LNG Power Consortium` (`VN_ABCD_006`) with grid `-0.432056` vs base `-0.374884`.
- [ ] `Rscript tools/verify_refactor.R --skip-refresh` still prints `BYTE-IDENTITY PASS` and exits `0` (the existing mode is untouched).
- [ ] `git diff --stat` shows changes confined to `tools/verify_refactor.R` and the new test file.

**Phase Risks**

- **RISK-01-01:** `read_parquet()` requires `arrow`, which emits an "built under R version 4.5.3" startup warning in this environment. Mitigation: wrap the `library(arrow)` call in `suppressPackageStartupMessages()`; the warning is cosmetic and already present in the existing suite (`WARN 4`).
- **RISK-01-02:** Regex-scanning R source for the sector literals (TASK-01-05) is brittle if a future edit reformats those lines. Mitigation: on failure to parse a literal, return `ok = FALSE` with a detail line saying the literal could not be located — a parse failure must fail loudly, never pass silently.

---

### PHASE-02 - Provenance and Config Fidelity

**Goal**

Fix the three defects that make an engagement's outputs misrepresent the
engagement: hardcoded `data_source`, a sector list that ignores the config, and
engagement configs that cannot reproduce their own run.

**Tasks**

- [ ] TASK-02-01: Replace the hardcoded `data_source` in `scripts/engagement_scoring.R` with `cfg$bank_slug`.
- [ ] TASK-02-02: Make `prioritize_sectors()` derive its sector list from `cfg$trisk_sectors` instead of a hardcoded vector.
- [ ] TASK-02-03: Promote the ISIC→Decision-263 sector map in `prioritize_sectors()` to a module-level named vector so it has one definition, and filter it to the configured sectors.
- [ ] TASK-02-04: Add an optional `inputs.raw_loanbook_csv` key to the engagement-config schema; when present and no `--raw-loanbook` CLI flag is given, `scripts/run_engagement.R` uses it as the intake source.
- [ ] TASK-02-05: Set `inputs.raw_loanbook_csv` to `data/fixtures/unseen_bank_loanbook.csv` in `engagements/sdb-rehearsal/engagement_config.json` so the config reproduces its own documented run.
- [ ] TASK-02-06: Add `public_snapshot_allowed` to the config defaults (`FALSE`) and to `engagements/mcb-demo/engagement_config.json` (`true`); rewrite the orchestrator guard rail to use it (ASM-004).
- [ ] TASK-02-07: Extend `tests/testthat/test_engagement_config.R` with cases for the two new keys.

**File Changes**

- `scripts/engagement_scoring.R` (modify): line 79, change `data_source   <- "MCB_synthetic"` to `data_source   <- cfg$bank_slug`. Update the header comment block that documents the composite formula to note the provenance column. **Leave the composite-score math, the `normalise_01()` helper, the automotive branch, and the empty-borrower early-exit untouched** — scoring methodology is out of scope for this wave.
- `R/prioritization_core.R` (modify): replace line 68 `sectors <- c("power", "cement", "steel")` with `sectors <- cfg$trisk_sectors`; move the `isic_to_d263` literal (line 149) to a module-level constant `.d263_isic_map` defined near the top of the file and subset it with `.d263_isic_map[.d263_isic_map %in% sectors]` at the call site. Guard the `align_min/align_max` and `stress_min/stress_max` blocks against a single-sector config: they already handle a zero range by assigning `0.5`, so no further change is needed — verify, do not rewrite. **Leave `classify_band()`, the weights, the normalization approach, the detail-CSV shape, and the ggplot block unchanged.**
- `R/engagement_config.R` (modify): add `raw_loanbook_csv = NULL` inside the `inputs` list of `.default_engagement_config()` and `public_snapshot_allowed = FALSE` at the top level. In `.validate_engagement_config()`, **exclude `raw_loanbook_csv` from the existing "every input file must exist" loop when it is `NULL`**, and validate it as a must-exist path when non-`NULL`. Add validation that `public_snapshot_allowed` is a length-1 logical.
- `scripts/run_engagement.R` (modify): after `cfg <- load_engagement_config(config_path)`, set `raw_loanbook <- get_flag_value(args, "--raw-loanbook") %||% cfg$inputs$raw_loanbook_csv` (define `%||%` locally — `rlang` is not sourced here). Replace the guard-rail block at lines 58–62 with the `public_snapshot_allowed` form. Update the header usage comment.
- `engagements/sdb-rehearsal/engagement_config.json` (modify): add `"raw_loanbook_csv": "data/fixtures/unseen_bank_loanbook.csv"` inside `inputs`.
- `engagements/mcb-demo/engagement_config.json` (modify): add `"public_snapshot_allowed": true` at the top level.
- `scripts/new_engagement.R` (modify): emit `raw_loanbook_csv` as `NULL` and `public_snapshot_allowed` as `FALSE` in the scaffolded config so new engagements are safe by default.
- `tests/testthat/test_engagement_config.R` (modify): append the new test cases; leave existing cases unchanged.

**Function Signatures**

- `prioritize_sectors(cfg: list, weights: list = NULL) -> tbl` — unchanged signature; now returns one row per sector in `cfg$trisk_sectors` (previously always three rows).
- `load_engagement_config(config_path: character = NULL) -> list` — unchanged signature; the returned list gains `inputs$raw_loanbook_csv` (character or `NULL`) and `public_snapshot_allowed` (logical(1)).

**Test Specs**

- `load_engagement_config(NULL)$public_snapshot_allowed` → `FALSE`.
- `load_engagement_config("engagements/mcb-demo/engagement_config.json")$public_snapshot_allowed` → `TRUE`.
- `load_engagement_config("engagements/sdb-rehearsal/engagement_config.json")$inputs$raw_loanbook_csv` → `"data/fixtures/unseen_bank_loanbook.csv"`.
- A temp config with `{"bank_slug":"t","bank_name":"T","inputs":{"raw_loanbook_csv":"does/not/exist.csv"}}` → `load_engagement_config()` throws an error whose message contains `does/not/exist.csv`.
- A temp config with `{"public_snapshot_allowed":"yes"}` → throws an error containing `public_snapshot_allowed`.
- `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --dry-run` → exit 0, and the printed step list's first line starts with `intake: scripts/intake_validate_and_map.R --input data/fixtures/unseen_bank_loanbook.csv` (proving TASK-02-04/05 without executing anything).
- A temp config with `snapshot_dir = "dashboard/data"`, `bank_slug = "other-bank"`, and no `public_snapshot_allowed` → `Rscript scripts/run_engagement.R --config <tmp> --dry-run` exits non-zero with a message containing `public_snapshot_allowed`.
- A temp config with `trisk_sectors = ["power"]` passed to `prioritize_sectors()` → the written `sector_priority_ranking.csv` has exactly 1 row with `sector == "power"`, and `alignment_score == 0.5` (single-sector zero-range branch).

**Dependencies**

- PHASE-01 (the invariant detector is how TASK-02-01 is verified end-to-end).

**Exit Criteria**

- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` → `FAIL 0`.
- [ ] `Rscript scripts/engagement_scoring.R --config engagements/sdb-rehearsal/engagement_config.json` → exit 0, and `awk -F, 'NR>1 {print $NF}' engagements/sdb-rehearsal/output/engagement/engagement_priority.csv | sort -u` prints exactly `sdb-rehearsal`.
- [ ] `Rscript tools/verify_refactor.R --invariants; echo "exit=$?"` → `[PASS] INV-003` (INV-001 and INV-002 still fail — they are PHASE-03/04 scope).
- [ ] `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --dry-run` → exit 0 and the step list names the fixture loanbook.
- [ ] `Rscript scripts/new_engagement.R --slug tmp-check --name "Tmp Bank"` then `grep -c 'public_snapshot_allowed' engagements/tmp-check/engagement_config.json` → `1`; then `rm -rf engagements/tmp-check`.

**Phase Risks**

- **RISK-02-01:** `engagement_scoring.R` writes MCB's `output/engagement/engagement_priority.csv`, whose `data_source` will flip from `MCB_synthetic` to `mcb-demo` — a real content change to a committed artifact. Mitigation: this is intended and is covered by the PHASE-06 refreeze; `tests/testthat/test_golden_numbers.R` does not assert on `data_source`, so nothing breaks meanwhile.
- **RISK-02-02:** `.validate_engagement_config()`'s existing loop iterates `names(cfg$inputs)` and fails on any non-existent path. Adding a `NULL`-valued key changes iteration behavior. Mitigation: the `NULL` is dropped by `jsonlite`/list semantics in some paths and retained in others — explicitly `if (is.null(path)) next` before the `file.exists()` check for `raw_loanbook_csv` only, and add the temp-config test above that pins the behavior.

---

### PHASE-03 - Scenario Vintage Single Source of Truth and ABCD Provenance

**Goal**

Retire the byte-identical duplicate scenario files so exactly one path per
vintage is authoritative, and make the demo's own ABCD satisfy the demo's own
documented schema.

**Tasks**

- [ ] TASK-03-01: Make `scripts/generate_vietnam_data.R` write the scenario CSVs to `data/scenarios/pdp8-2023/` only, and delete the flat `data/vietnam_scenario_ms.csv` and `data/vietnam_scenario_co2.csv`.
- [ ] TASK-03-02: Point `engagements/sdb-rehearsal/engagement_config.json` at the versioned scenario paths.
- [ ] TASK-03-03: Replace the `test_snapshot_contract.R` test that *asserts the duplicates are byte-identical* with one that asserts the flat paths no longer exist.
- [ ] TASK-03-04: Add `data_source` and `as_of_year` columns to the generated ABCD in `scripts/generate_vietnam_data.R`, with values `"synthetic_demo"` and `2025` on every row — matching `intake/templates/abcd_template.csv` exactly.
- [ ] TASK-03-05: Add `validate_abcd_schema()` to `R/trisk_core.R` and call it at the top of `trisk_prepare_sector_inputs()` immediately after the ABCD is read, failing the run on a schema violation.
- [ ] TASK-03-06: Add unit tests for `validate_abcd_schema()`.
- [ ] TASK-03-07: Grep the repo for remaining references to the flat scenario paths and update every one.

**File Changes**

- `scripts/generate_vietnam_data.R` (modify): change the two scenario write targets to `data/scenarios/pdp8-2023/vietnam_scenario_ms.csv` and `data/scenarios/pdp8-2023/vietnam_scenario_co2.csv`, creating the directory with `dir.create(..., recursive = TRUE, showWarnings = FALSE)` first. Add `data_source = "synthetic_demo"` and `as_of_year = 2025L` to the ABCD tibble immediately before it is written, positioned as the **last two columns** so the header order matches `intake/templates/abcd_template.csv`. **Leave every production/capacity/emission-factor value, the loanbook generator, and the region-ISO generator untouched.**
- `data/vietnam_scenario_ms.csv` (delete) and `data/vietnam_scenario_co2.csv` (delete): remove with `git rm`.
- `engagements/sdb-rehearsal/engagement_config.json` (modify): change `scenario_ms_csv` to `data/scenarios/pdp8-2023/vietnam_scenario_ms.csv` and `scenario_co2_csv` to `data/scenarios/pdp8-2023/vietnam_scenario_co2.csv`.
- `tests/testthat/test_snapshot_contract.R` (modify): delete the `test_that("scenario vintage copies are byte-identical to legacy data/ files", ...)` block entirely and replace it with `test_that("scenario vintages have exactly one authoritative path", ...)` asserting `!file.exists(file.path(root, "data", "vietnam_scenario_ms.csv"))`, `!file.exists(file.path(root, "data", "vietnam_scenario_co2.csv"))`, and that both versioned files do exist. **Leave the TRISK-snapshot-contract test in the same file unchanged.**
- `R/trisk_core.R` (modify): add `validate_abcd_schema()` in SECTION A above `.trisk_input_sector_specs`, with a roxygen block and `@export`. Call it in `trisk_prepare_sector_inputs()` on the line immediately after `vietnam_abcd <- read_csv(...)`. **Leave `.trisk_input_sector_specs`, `.trisk_company_archetypes`, and every build helper unchanged.**
- `tests/testthat/test_trisk_core.R` (modify): append `validate_abcd_schema()` cases; leave the existing 21 tests unchanged.
- `docs/abcd_sourcing_decision.md` (modify): in the "Relation to This Demo" section, state that `data/vietnam_abcd.csv` now carries the provenance columns and is validated at pipeline entry.
- `NAMESPACE`, `man/` (regenerate): run `Rscript -e "roxygen2::roxygenise()"` after adding the `@export`.

**Function Signatures**

- `validate_abcd_schema(abcd: data.frame, source_label: character = "ABCD") -> invisible(TRUE)` — returns `invisible(TRUE)` when the frame satisfies the `intake/SCHEMA.md` ABCD contract; otherwise `stop()`s with a message listing every problem, one per line. Checks, in order: (1) all 14 required column names present — `company_id`, `name_company`, `lei`, `sector`, `technology`, `production_unit`, `year`, `production`, `emission_factor`, `plant_location`, `is_ultimate_owner`, `emission_factor_unit`, `data_source`, `as_of_year`; (2) `year` and `as_of_year` coercible to integer with no `NA` introduced; (3) `production` numeric and non-negative (`NA` permitted); (4) `company_id` and `name_company` non-empty on every row; (5) `is_ultimate_owner` logical or coercible from the literals `"TRUE"`/`"FALSE"`; (6) `data_source` non-empty on every row.

**Test Specs**

- `validate_abcd_schema(readr::read_csv("data/vietnam_abcd.csv"))` after TASK-03-04 → returns invisibly, no error.
- `validate_abcd_schema(data.frame(company_id = "X"))` → error whose message contains `name_company` and `as_of_year`.
- A 14-column frame with `production = -5` → error containing `production`.
- A 14-column frame with `year = "not-a-year"` → error containing `year`.
- A 14-column frame with `data_source = ""` on one row → error containing `data_source`.
- A valid 14-column frame with `emission_factor = NA` and `emission_factor_unit = NA` → returns invisibly (NA is permitted on those two columns; cement and steel rows legitimately carry `NA` there).
- `ncol(readr::read_csv("data/vietnam_abcd.csv"))` after regeneration → `14`.
- `names(readr::read_csv("data/vietnam_abcd.csv"))[13:14]` → `c("data_source", "as_of_year")`.
- `file.exists("data/vietnam_scenario_ms.csv")` → `FALSE`.

**Dependencies**

- PHASE-01 (INV-002 is the acceptance signal for TASK-03-01/02).

**Exit Criteria**

- [ ] `Rscript scripts/generate_vietnam_data.R` → exit 0; `ls data/vietnam_scenario_*.csv 2>/dev/null | wc -l` prints `0`; `ls data/scenarios/pdp8-2023/*.csv | wc -l` prints `2`.
- [ ] `head -1 data/vietnam_abcd.csv` ends with `,data_source,as_of_year`.
- [ ] `grep -rn "data/vietnam_scenario_" --include=*.R --include=*.json --include=*.py --include=*.md . | grep -v "data/scenarios/"` → no output.
- [ ] `Rscript tools/verify_refactor.R --invariants; echo "exit=$?"` → `[PASS] INV-002` and `[PASS] INV-003` (INV-001 still fails).
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` → `FAIL 0`.

**Phase Risks**

- **RISK-03-01:** `tests/testthat/test_snapshot_contract.R` currently *asserts the duplication exists*. Deleting that assertion is intentional and must be called out in the commit message, otherwise a future reader will read it as a weakened test.
- **RISK-03-02:** Regenerating the ABCD changes `data/vietnam_abcd.csv`, which cascades into every PACTA and TRISK output. Mitigation: the two new columns are appended and are not read by any matching or analysis code (verify with `grep -rn "as_of_year\|data_source" R/ scripts/` before running); numeric outputs must therefore be unchanged. If any numeric output moves, stop and investigate before proceeding — that would indicate positional rather than name-based column access somewhere.

---

### PHASE-04 - Grid Correctness: Fingerprinting, Regeneration, and Dead Levers

**Goal**

Make the scenario grid regenerate whenever its inputs, the `trisk.model`
version, or the grid contract changes; regenerate it; and make the Scenario
Builder's five levers all actually do something.

**Tasks**

- [ ] TASK-04-01: Implement `grid_input_fingerprint()` and cache validation per Specification S2 in `R/trisk_core.R`.
- [ ] TASK-04-02: Resolve the `risk_free_rate` no-op per Specification S3, using `scripts/trisk_run_adhoc.R` for the two probe runs.
- [ ] TASK-04-03: Make the `carbon_price_family` lever live: emit three distinct carbon-price scenarios per sector from `.trisk_build_carbon_price()` and map each `NGFS_*` family to its own scenario name in `carbon_price_model_map`.
- [ ] TASK-04-04: Regenerate all three sector grids from scratch and confirm INV-001 passes.
- [ ] TASK-04-05: Add an R unit test for the fingerprint helpers and a Python test asserting the grid scenario count is derived from `grid_meta.json` rather than hardcoded.
- [ ] TASK-04-06: Document the lever findings and the carbon-price paths in `docs/TRISK_Demo_Assumptions.md` and `docs/trisk_scenario_grid_contract.md`.

**File Changes**

- `R/trisk_core.R` (modify):
  - Add `grid_input_fingerprint(grid_input_dir)` near `read_existing_grid()`.
  - Add `grid_cache_is_valid(grid_dir, grid_input_dir, contract_version, model_version)` returning `list(valid = logical(1), reason = character(1))`.
  - In `trisk_run_grid()`, **after** the existing `grid_input_dir <- build_grid_input_dir(...)` call (currently line 1365) and **before** `existing <- read_existing_grid(grid_dir)` (line 1367), evaluate `grid_cache_is_valid()`. When invalid: print `[<sector>] grid cache invalidated: <reason> — regenerating all N scenarios`, `unlink(runs_dir, recursive = TRUE, force = TRUE)`, recreate `runs_dir`, and force `existing <- list(scenarios = tibble(), borrower_results = tibble())`.
  - Add `input_fingerprint = <computed value>` to the `grid_meta` list built at line 1458.
  - In `.trisk_build_carbon_price()`, return a three-scenario tibble per sector via `dplyr::bind_rows()`. **Keep the existing `scenario` name and its exact `carbon_tax` vector as the first block unchanged** (power: `increasing_carbon_tax_50` with `c(0, 0, 0, 50, 52, 54.08)`; cement: `cement_intensity_transition` with `c(12, 18, 26, 34, 42, 50)`; steel: `steel_intensity_transition` with `c(10, 16, 24, 33, 42, 52)`), then append two new blocks per sector using scenario names `<existing_name>_below2c` and `<existing_name>_delayed` with `carbon_tax` scaled to `0.60×` and `0.30×` the NetZero path respectively, rounded to 2 decimals. This encodes the semantics the dashboard already advertises: "Net Zero 2050 (strict)", "Below 2°C (moderate)", "Delayed transition (mild)".
  - In `carbon_price_model_map`, map `NGFS_NetZero2050` → the existing name, `NGFS_Below2C` → `<existing_name>_below2c`, `NGFS_Delayed` → `<existing_name>_delayed`, for all three sectors.
  - Apply the Specification-S3 outcome to `grid_levers`, `trisk_sensitivity_specs`, `build_scenario_id()`, `build_grid_label()`, and `grid_contract_version`.
  - **Leave `sector_meta()`'s `carbon_price_model` value unchanged** so the base run keeps reading the original scenario name.
- `dashboard/pages/5_Scenario_Builder.py` (modify): only if Specification S3 step 4 applies — remove the risk-free-rate slider and drop `rf` from `_build_scenario_id()` and `_parse_scenario_id()`. **Leave `CARBON_PRICE_LABELS` unchanged**; after TASK-04-03 those labels finally describe real differences.
- `dashboard/tests/test_loaders.py` (modify): replace the hardcoded `assert n_scenarios == 243` in `test_trisk_grid_scenario_count()` with a comparison against `json.loads((TRISK_DIR / "grid" / "power" / "grid_meta.json").read_text())["scenario_count"]`, plus an assertion that the count equals the product of the lever cardinalities recorded in the same file.
- `tests/testthat/test_trisk_core.R` (modify): append fingerprint tests.
- `docs/trisk_scenario_grid_contract.md` (modify): document `input_fingerprint`, the invalidation rule, the contract-version bump, and the final lever set.
- `docs/TRISK_Demo_Assumptions.md` (modify): add a subsection "Scenario lever sensitivity" recording, with the measured evidence, which levers move results and the three carbon-price paths.

**Function Signatures**

- `grid_input_fingerprint(grid_input_dir: character) -> character` — returns a single lowercase md5 hex string over the four input files in sorted-filename order, or `NA_character_` if any of the four is missing.
- `grid_cache_is_valid(grid_dir: character, grid_input_dir: character, contract_version: character, model_version: character) -> list` — returns `list(valid = logical(1), reason = character(1))`; `reason` is one of `"ok"`, `"no grid_meta.json"`, `"no input_fingerprint recorded"`, `"input fingerprint changed"`, `"trisk.model version changed"`, `"grid contract version changed"`.
- `.trisk_build_carbon_price(spec: list) -> tbl` — unchanged signature; now returns 18 rows per sector (3 scenarios × 6 years) instead of 6.

**Test Specs**

- `grid_input_fingerprint(<tempdir with the four named CSVs>)` → a 32-character lowercase hex string; calling it twice on unchanged files returns the identical value.
- Modify one byte of `assets.csv` in that fixture → the returned fingerprint differs.
- `grid_input_fingerprint(<tempdir missing ngfs_carbon_price.csv>)` → `NA_character_`.
- `grid_cache_is_valid()` with `grid_meta.json` absent → `list(valid = FALSE, reason = "no grid_meta.json")`.
- `grid_cache_is_valid()` with a `grid_meta.json` whose `input_fingerprint` matches and whose `trisk_model_version` and `grid_contract_version` match → `valid == TRUE`, `reason == "ok"`.
- `grid_cache_is_valid()` with a matching fingerprint but `grid_contract_version = "v0"` → `valid == FALSE`, `reason == "grid contract version changed"`.
- `nrow(.trisk_build_carbon_price(.trisk_input_sector_specs$power))` → `18`; `sort(unique(...$scenario))` → the three power scenario names; the rows where `scenario == "increasing_carbon_tax_50"` have `carbon_tax` exactly `c(0, 0, 0, 50, 52, 54.08)`.
- After TASK-04-04, in R: reading `synthesis_output/trisk/grid/power/borrower_results.parquet`, filtering to `scenario_id` starting `s2028_d0.08_rf0.03_mp0.25_c` (or `s2028_d0.08_mp0.25_c` if S3 step 4 applied) and summing `npv_change_pct` per `scenario_id` → **three distinct sums** (previously all three were `-4.112455`).
- After TASK-04-04, `inv_grid_matches_base_run(getwd())$ok` → `TRUE`.

**Dependencies**

- PHASE-01 (INV-001 is the acceptance signal), PHASE-03 (the ABCD regeneration must land before the grid is rebuilt, so the grid is fingerprinted against final inputs).

**Exit Criteria**

- [ ] `Rscript -e "testthat::test_file('tests/testthat/test_trisk_core.R')"` → all pass.
- [ ] `Rscript scripts/trisk_prepare_inputs.R` then `Rscript scripts/trisk_scenario_grid.R` → exit 0, and the console prints `grid cache invalidated: input fingerprint changed` for each of the three sectors on the first run.
- [ ] Re-running `Rscript scripts/trisk_scenario_grid.R` immediately afterwards prints `grid already complete, skipping regeneration` for all three sectors (the fingerprint now matches — proving the cache still works when it should).
- [ ] `python -c "import json;m=json.load(open('synthesis_output/trisk/grid/power/grid_meta.json'));print(m['input_fingerprint'], m['scenario_count'])"` → a 32-char hex string and the expected scenario count (`243` if the risk-free lever survived, `81` if it was removed).
- [ ] `Rscript tools/verify_refactor.R --invariants; echo "exit=$?"` → `exit=0` and `INVARIANTS PASS`.
- [ ] `python -m pytest dashboard/tests` → all pass (after `Rscript scripts/refresh_dashboard_data.R` republishes the snapshot).

**Phase Risks**

- **RISK-04-01:** Full grid regeneration is the longest operation in this plan — `grid_meta.json` records `runtime_seconds: 280.259` for 243 power scenarios, so budget roughly 15 minutes for all three sectors, more if the carbon-price fix makes previously-identical cells genuinely distinct. Mitigation: run it once, deliberately, and do not interrupt; the `runs/` directory is gitignored so a partial run is safe to delete and restart.
- **RISK-04-02:** If the risk-free lever is removed (S3 step 4), every `scenario_id` string changes shape, invalidating any bookmarked Scenario Builder URL and the `_parse_scenario_id()` round-trip. Mitigation: `dashboard/tests/test_scenario_builder.py` exercises that round-trip — run it before and after and confirm it passes; there are no persisted user bookmarks because shareable links are not implemented.
- **RISK-04-03:** `trisk.model` may error rather than fall back if a `carbon_price_model` name is absent from `ngfs_carbon_price.csv`. Mitigation: TASK-04-03 adds the names to the input file *before* TASK-04-04 maps the grid onto them; verify with a single `Rscript scripts/trisk_run_adhoc.R` probe using one new scenario name before regenerating the whole grid.

---

### PHASE-05 - Orchestrator Convergence

**Goal**

Make `scripts/run_engagement.R` the single orchestrator and reduce
`scripts/pipeline_refresh.R` to a thin wrapper, so the public MCB demo and every
client engagement travel one code path.

**Tasks**

- [ ] TASK-05-01: Add three optional boolean config keys that let one step list serve both callers: `run_data_generation`, `run_refresh_audit`, `run_outputs`.
- [ ] TASK-05-02: Extend `build_step_list()` in `scripts/run_engagement.R` to honour those keys.
- [ ] TASK-05-03: Add a `row_count_files` config key so the engagement manifest can record the same row counts the MCB manifest records today.
- [ ] TASK-05-04: Make `pipeline_refresh.R` delegate to `run_engagement.R` with the MCB config, preserving its `--full` flag semantics.
- [ ] TASK-05-05: Delete `scripts/trisk_power_demo.R` and remove its references.
- [ ] TASK-05-06: Add subprocess smoke tests for both orchestrators' `--dry-run` output.

**File Changes**

- `R/engagement_config.R` (modify): add to `.default_engagement_config()`: `run_data_generation = FALSE`, `run_refresh_audit = FALSE`, `run_outputs = TRUE`, and `row_count_files = character(0)`. Validate each as the right type. **Leave every existing default value byte-identical.**
- `engagements/mcb-demo/engagement_config.json` (modify): add `"run_refresh_audit": true` and the six-element `"row_count_files"` array currently hardcoded in `scripts/pipeline_refresh.R` lines 60–67 (`dashboard/data/trisk/{power,cement,steel}/company_trajectories_latest.csv` and `dashboard/data/trisk/{power,cement,steel}/npv_results_latest.csv`, in that order). Do **not** set `run_data_generation` here — it is supplied per-invocation by the `--full` flag.
- `scripts/run_engagement.R` (modify): accept a `--full` flag that sets `cfg$run_data_generation <- TRUE` for the run. In `build_step_list()`, prepend a `generate_vietnam_data` step when `run_data_generation` is `TRUE`; append a `refresh_audit` step (`scripts/generate_refresh_audit.R`) when `run_refresh_audit` is `TRUE`; skip the `generate_engagement_letters` and `generate_disclosure_pack` steps when `run_outputs` is `FALSE`. Pass `cfg$row_count_files` as `write_pipeline_manifest()`'s `row_count_files` argument. Write the manifest to `cfg$paths$snapshot_dir/pipeline_manifest.json` when `public_snapshot_allowed` is `TRUE`, otherwise to `engagements/<slug>/pipeline_manifest.json` as today. **Leave the intake/resolved-config logic and the fixed step order otherwise unchanged.**
- `scripts/pipeline_refresh.R` (modify): replace the whole body below the header comment with argument pass-through — build `args <- c("scripts/run_engagement.R", "--config", "engagements/mcb-demo/engagement_config.json")`, append `"--full"` when the caller passed it, `status <- system2("Rscript", args)`, `quit(status = status)`. Keep the file executable and keep its header comment, updated to say it is a compatibility wrapper. **Do not delete the file** (ASM-007).
- `scripts/trisk_power_demo.R` (delete): `git rm`. Its entire body is `trisk_run_sector(cfg, "power")`, which `scripts/trisk_sector_demo.R power` already does.
- `README.md`, `CLAUDE.md`, `AGENTS.md`, `docs/demo-script.md` (modify): update every reference to `trisk_power_demo.R` and to the two-orchestrator model.
- `tests/testthat/test_step_runner.R` (modify): append the dry-run smoke tests; leave existing tests unchanged.

**Function Signatures**

- `build_step_list(cfg: list, effective_config_path: character, run_intake: logical, raw_loanbook: character, intake_dir: character, top_n: character) -> list` — unchanged signature; the returned list now varies with `cfg$run_data_generation`, `cfg$run_refresh_audit`, and `cfg$run_outputs`.

**Test Specs**

- `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --full --dry-run` → exit 0, and the printed step names, in order, are exactly: `generate_vietnam_data`, `pacta_vietnam_scenario`, `trisk_prepare_inputs`, `trisk_sector_demo_power`, `trisk_sector_demo_cement`, `trisk_sector_demo_steel`, `trisk_scenario_grid`, `sector_prioritization`, `refresh_dashboard_data`, `engagement_scoring`, `generate_engagement_letters`, `generate_disclosure_pack`, `refresh_audit`.
- `Rscript scripts/pipeline_refresh.R --full --dry-run` → exit 0 and prints the identical step list (proving delegation).
- `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --dry-run` → exit 0; the list contains `intake` and `validation_report` first, contains no `generate_vietnam_data` and no `refresh_audit`, and contains no `trisk_scenario_grid` (the SDB config sets `run_grid: false`).
- A temp config with `run_outputs = false` → the dry-run step list contains neither `generate_engagement_letters` nor `generate_disclosure_pack`.
- `test -f scripts/trisk_power_demo.R` → non-zero exit (file gone).
- `grep -rn "trisk_power_demo" --include=*.R --include=*.yml --include=*.md . | grep -v '^./reports/' | grep -v '^./plans/' | grep -v '^./research/'` → no output.

**Dependencies**

- PHASE-02 (`public_snapshot_allowed` gates the MCB snapshot write), PHASE-04 (do not converge orchestrators while the grid is still being regenerated — a failure would be ambiguous between the two changes).

**Exit Criteria**

- [ ] Both dry-run step lists above match exactly.
- [ ] `Rscript scripts/pipeline_refresh.R --full` → exit 0 and `dashboard/data/pipeline_manifest.json` has `status == "ok"`, `length(steps) == 13`, and a `row_counts` object with the same six keys it has today.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` → `FAIL 0`.
- [ ] `python -m pytest dashboard/tests` → all pass.
- [ ] `Rscript tools/verify_refactor.R --invariants` → `INVARIANTS PASS`, exit 0.
- [ ] `Rscript scripts/pipeline_refresh.R --full` run twice in a row leaves the second run's `git diff --name-only` containing only `.png`, `.html`, and timestamp-class files — verify with `Rscript tools/verify_refactor.R --skip-refresh` printing `BYTE-IDENTITY PASS`.

**Phase Risks**

- **RISK-05-01:** MCB's manifest step names change (`trisk_power_demo` → `trisk_sector_demo_power`) and the step count changes from 11 to 13 (letters and disclosure are now included). `tests/testthat/test_manifest_json.R` asserts `expect_gte(length(manifest$steps), 7)` and that every step is `"ok"`, both of which survive; `pipeline_manifest.json` is already `timestamp-class` in `tools/verify_refactor.R`. Mitigation: confirmed compatible by inspection — but re-read `test_manifest_json.R` before running, and note the change in the commit message.
- **RISK-05-02:** `generate_engagement_letters.R` and `generate_disclosure_pack.R` now run as part of the public MCB refresh, writing into `output/engagement_letters/` and `output/disclosure/` — both fully gitignored except for `.gitkeep`, so nothing new gets committed. Verify with `git status --porcelain output/` being empty after a full run. If the weekly CI job's runtime becomes a concern, set `run_outputs: false` in the MCB config instead.
- **RISK-05-03:** `scripts/generate_refresh_audit.R` does not accept `--config` (it is one of nine config-unaware scripts). Called as a step it will run in MCB-default mode, which is correct for MCB but wrong for any other engagement. Mitigation: `run_refresh_audit` defaults to `FALSE`, so only the MCB config enables it; add an inline comment in `run_engagement.R` recording this constraint.

---

### PHASE-06 - CI Guard, Golden Refreeze, and Documentation

**Goal**

Add the multi-bank CI guard that does not currently exist, wire the invariant
detector into CI, refreeze every golden literal exactly once, and update the docs
and package metadata.

**Tasks**

- [ ] TASK-06-01: Convert `tests/testthat/test_sdb_engagement.R` from a fixture-content test into a genuine regression test that executes the SDB engagement.
- [ ] TASK-06-02: Add an `sdb-engagement` job to `.github/workflows/ci.yml`.
- [ ] TASK-06-03: Add an invariants step to both workflows.
- [ ] TASK-06-04: Run the full pipeline for MCB and the full engagement for SDB, then refreeze every golden literal from the regenerated committed artifacts.
- [ ] TASK-06-05: Update `NEWS.md` and bump `DESCRIPTION` to 0.3.0.
- [ ] TASK-06-06: Create `lessons.md` at the repo root with the four lessons this wave and Wave 0 established.
- [ ] TASK-06-07: Update `README.md` and `CLAUDE.md` with the invariants command and the single-orchestrator model.
- [ ] TASK-06-08: Commit everything as one refreeze commit.

**File Changes**

- `tests/testthat/test_sdb_engagement.R` (modify): add a new first `test_that()` block that (a) skips when `Sys.getenv("RUN_SDB_ENGAGEMENT") != "1"` so the default local suite stays fast, (b) otherwise runs `system2("Rscript", c("scripts/run_engagement.R", "--config", "engagements/sdb-rehearsal/engagement_config.json"))` from `project_root()` and expects exit `0`. **Keep the three existing fixture-content tests** — after the run they assert on freshly regenerated files, which is exactly the guard that was missing.
- `.github/workflows/ci.yml` (create job): add a third job `sdb-engagement` mirroring the `r-tests` job's checkout / setup-r / apt / setup-renv steps, then `- name: Run SDB engagement end-to-end` running `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json`, then `- name: SDB golden tests` running `RUN_SDB_ENGAGEMENT=1 Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"`, then `- name: Assert no cross-contamination` running `git status --porcelain synthesis_output output dashboard/data reports` and failing if the output is non-empty. Add `- name: Cross-artifact invariants` running `Rscript tools/verify_refactor.R --invariants` to the existing `r-tests` job, after the test step.
- `.github/workflows/refresh.yml` (modify): insert `- name: Cross-artifact invariants` running `Rscript tools/verify_refactor.R --invariants` between the existing "Regression-test refreshed outputs" step and the "Commit refreshed snapshot" step, so a violated invariant blocks the weekly auto-commit. **Leave the `git add` path list unchanged** — it is what keeps CI from committing gitignored raw run directories.
- `tests/testthat/test_golden_numbers.R` (modify): re-read the regenerated `output/engagement/engagement_priority.csv` and update every literal from the file. Expect `nrow` to stay `23` and the top-three ordering to hold; the composite scores may shift because the grid regeneration changes nothing upstream of scoring but the ABCD provenance columns and carbon-price rows do touch the TRISK inputs — **take every literal from the committed CSV, never from this plan's text.**
- `tests/testthat/test_sdb_engagement.R` (modify, second pass): refreeze `ncol`, `nrow`, and the rank-1 literals from the regenerated SDB artifacts.
- `dashboard/tests/test_loaders.py` (modify): confirm the `grid_meta.json`-derived scenario count assertion from PHASE-04 still holds.
- `DESCRIPTION` (modify): `Version: 0.3.0`.
- `NEWS.md` (modify): add a `# pactatrisk 0.3.0` section at the top describing the invariants mode, the grid fingerprinting, the orchestrator convergence, the provenance fix, the scenario-vintage retirement, the ABCD schema validation, and the carbon-price lever fix.
- `lessons.md` (create): four entries — (1) verify byte-identity with autocrlf-aware `git diff`, never raw `md5sum`; (2) `file.path(getwd(), ...)` double-join produces silently wrong absolute paths; (3) **caches must be keyed on their inputs, not only on their parameters**; (4) **a golden test that reads committed artifacts guards the artifacts, not the code — a regression test must regenerate them.** Each entry states the pattern and the rule that prevents recurrence.
- `README.md` (modify): in the "Refactor acceptance check" section add the `--invariants` invocation and what it checks; update the architecture diagram to show one orchestrator.
- `CLAUDE.md` (modify): update the commands list and Law 5 to name `Rscript tools/verify_refactor.R --invariants` as part of the acceptance bar.

**Function Signatures**

- None — no code interfaces change in this phase.

**Test Specs**

- `RUN_SDB_ENGAGEMENT=1 Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"` → all pass, and the run leaves `git status --porcelain synthesis_output output dashboard/data reports` empty.
- `Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"` (without the env var) → the engagement-execution test skips; the three fixture tests still run and pass.
- `Rscript -e "testthat::test_dir('tests/testthat')"` → `FAIL 0`, `SKIP 1`.
- `python -m pytest dashboard/tests` → `58 passed` (or more; a lone `test_auth.py` timeout failure is the known environmental flake and is not a regression).
- Two consecutive `Rscript scripts/pipeline_refresh.R --full` runs → `Rscript tools/verify_refactor.R --skip-refresh` prints `BYTE-IDENTITY PASS`.

**Dependencies**

- All prior phases.

**Exit Criteria**

- [ ] `Rscript tools/verify_refactor.R --invariants; echo "exit=$?"` → `INVARIANTS PASS`, `exit=0`.
- [ ] `Rscript tools/verify_refactor.R --full` → `BYTE-IDENTITY PASS`, exit 0.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` → `FAIL 0`.
- [ ] `python -m pytest dashboard/tests` → no failures other than the documented `test_auth.py` flake.
- [ ] `grep -c "0.3.0" DESCRIPTION NEWS.md` → at least `1` in each.
- [ ] `test -f lessons.md` → exit 0.
- [ ] `git log --oneline -1` shows a single refreeze commit; `git status --porcelain` is empty afterwards.

**Phase Risks**

- **RISK-06-01:** The SDB CI job runs a full TRISK chain on a GitHub runner. The SDB config sets `run_grid: false`, so the expensive 243-cell grid is skipped and the job should complete in minutes. Mitigation: if it exceeds the runner limit, move the job from `ci.yml` (every push) to `refresh.yml` (weekly) rather than deleting it.
- **RISK-06-02:** `RUN_SDB_ENGAGEMENT=1 <cmd>` is POSIX shell syntax and does not work in PowerShell 5.1. Mitigation: on Windows use `$env:RUN_SDB_ENGAGEMENT = "1"; Rscript -e "..."` as a separate statement; CI runs `ubuntu-latest`, so the workflow file uses the POSIX form.
- **RISK-06-03:** The refreeze may reveal an unexpected numeric movement. Mitigation: before updating any literal, diff the regenerated `engagement_priority.csv` against its committed predecessor and confirm every moved value traces to a change this plan intended (ABCD provenance columns, carbon-price rows, grid regeneration, `data_source`). An unexplained movement means stop and investigate, not refreeze.

---

## Gotchas

- **Fractions, not percentages.** `npv_change`, `npv_change_pct`, `pd_change`, and `pd_change_pct` are all fractional (`-0.98` = a 98% NPV loss; `0.21` = +21 percentage points of PD). Never multiply by 100 when comparing across artifacts.
- **`npv_change_pct` (grid) and `npv_change` (base run) are the same quantity under different column names.** `build_borrower_results()` renames `npv_change` → `npv_change_pct` verbatim. Do not "convert" between them.
- **The grid fingerprint must be computed after `build_grid_input_dir()`.** That function copies the live inputs into `<grid_dir>/input/`; fingerprinting before it hashes the *previous* run's inputs and the cache never invalidates.
- **`find_cached_run_path()` is a second cache layer.** Emptying `existing$borrower_results` is not enough — the per-scenario `runs/<scenario_id>/` directories must be deleted too, or stale results are reloaded one cell at a time.
- **`prioritize_sectors()` reads from the published snapshot, not from `synthesis_output/`.** `trisk_dir` is `cfg$paths$snapshot_dir/trisk/...`, so prioritization must always run *after* `refresh_dashboard_data`. The existing step order already enforces this; preserve it in PHASE-05.
- **`sector_registry()$grid_available` is a dead literal.** All three values are hardcoded `FALSE` and then overwritten by a filesystem probe in `scripts/refresh_dashboard_data.R` line 154. Do not "fix" the literals; do not rely on them.
- **Two `--config` parsers coexist.** `get_config_arg()` in `R/engagement_config.R` and `get_flag_value()` in `scripts/run_engagement.R` / `scripts/new_engagement.R`. `scripts/trisk_sector_demo.R` additionally strips the `--config` pair out of the positional args before reading the sector name — preserve that when touching argument handling.
- **`system2("Rscript", ...)` needs `Rscript` on `PATH`.** Invoking the outer script with a full path is not enough; every orchestrator shells out. On Windows: `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"` first.
- **CSVs are UTF-8 without BOM and contain Vietnamese diacritics** (e.g. `Covered — TRISK power pilot` uses an em dash). Writing with a different encoding produces mojibake that `git diff` reports as drift. Always write via `readr::write_csv()`.
- **`renv.lock` pins R 4.5.2 but the local library was built under 4.5.3**, producing four benign startup warnings (`testthat`, `fs`, `arrow`, and one more). A run showing `WARN 4` is normal; only `FAIL` counts.
- **`engagements/*/output/` is aggressively gitignored** with negation rules for exactly three tracked artifacts per engagement (`engagement_priority.csv`, and per sector `npv_results_latest.csv` and `company_summary.csv`). If a refreeze appears to lose files, check `.gitignore` before assuming a bug.
- **`data/vietnam_trisk_*.csv` side copies are written only in default MCB mode** (`is_default_mode <- identical(cfg$bank_slug, "mcb-demo")` in `trisk_prepare_sector_inputs()`). This is deliberate cross-contamination protection — do not remove the guard when touching that function.
- **The grid's `carbon_price_family` lever is currently inert and `risk_free_rate` is inert in both the grid and the base sensitivity table.** Verified during planning: 243 grid cells contain only 27 distinct outcomes, and `risk_free_rate_0.02`, `risk_free_rate_0.04`, and `base` all sum to `-4.034687` in `dashboard/data/trisk/power/sensitivity_results.csv`. Treat any claim that a lever "works" as requiring measurement, not inspection.

## Verification Strategy

- **TEST-001:** `Rscript -e "testthat::test_dir('tests/testthat')"` → `[ FAIL 0 | WARN 4 | SKIP 1 | PASS >=210 ]`.
- **TEST-002:** `python -m pytest dashboard/tests` → `58 passed` or more; a lone `test_auth.py::test_no_password_renders_landing` failure is the documented environmental flake.
- **TEST-003:** `Rscript tools/verify_refactor.R --invariants; echo "exit=$?"` → `INVARIANTS PASS` and `exit=0` at the end of PHASE-04 onward. At the end of PHASE-01 this same command must print `exit=1` with `INV-001`, `INV-002`, `INV-003` failing — that is PHASE-01's acceptance signal.
- **TEST-004:** `Rscript tools/verify_refactor.R --full; echo "exit=$?"` → `BYTE-IDENTITY PASS`, `exit=0` (PHASE-06 only).
- **TEST-005:** Grid cache behaves as designed — `Rscript scripts/trisk_scenario_grid.R` twice in a row: the first run after any input change prints `grid cache invalidated`, the second prints `grid already complete, skipping regeneration`.
- **TEST-006:** Provenance is correct for every engagement — `awk -F, 'NR>1 {print $NF}' engagements/sdb-rehearsal/output/engagement/engagement_priority.csv | sort -u` → exactly `sdb-rehearsal`; the same command on `output/engagement/engagement_priority.csv` → exactly `mcb-demo`.
- **TEST-007:** Single source of truth for scenarios — `ls data/vietnam_scenario_*.csv 2>/dev/null | wc -l` → `0`.
- **TEST-008:** ABCD satisfies its contract — `head -1 data/vietnam_abcd.csv | tr ',' '\n' | wc -l` → `14`.
- **TEST-009:** Orchestrator convergence — `diff <(Rscript scripts/pipeline_refresh.R --full --dry-run) <(Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --full --dry-run)` → the step lists are identical (the banner lines may differ; compare only the `name: script args` lines).
- **TEST-010:** No cross-contamination from a non-MCB engagement — after `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json`, `git status --porcelain synthesis_output output dashboard/data reports` → empty output.
- **MANUAL-001:** Launch `python -m streamlit run dashboard/app.py`, open **TRISK Risk** (page 2) and note Dung Quat LNG Power Consortium's NPV change, then open **Scenario Builder** (page 5) with the default levers (shock 2028, discount 0.08, risk-free 0.03, passthrough 0.25, Net Zero 2050) and confirm the same borrower shows the same value. Before this plan they differ (−37.5% vs −43.2%).
- **MANUAL-002:** In the Scenario Builder, change **only** the carbon-price family selector between "Net Zero 2050 (strict)", "Below 2°C (moderate)", and "Delayed transition (mild)" and confirm the borrower ranking or values visibly change. Before this plan the selector has no effect whatsoever.
- **OBS-001:** After PHASE-06, confirm `.github/workflows/refresh.yml` fails the weekly job when an invariant breaks, by temporarily editing one value in `dashboard/data/trisk/power/company_summary.csv`, running `Rscript tools/verify_refactor.R --invariants` (expect exit 1 naming `INV-001`), then restoring the file with `git checkout -- dashboard/data/trisk/power/company_summary.csv`.
- **OBS-002:** `python -c "import json;m=json.load(open('dashboard/data/pipeline_manifest.json'));print(m['status'], len(m['steps']), sorted(m['row_counts'].keys())[:2])"` → `ok 13` and the first two of the six row-count keys, confirming the converged orchestrator preserved the manifest contract.

## Risks and Alternatives

- **RISK-001:** The wave touches provenance, inputs, the grid, and the orchestrator, and closes with one refreeze — so an unexplained numeric movement at PHASE-06 has four candidate causes. **Mitigation:** each phase's exit criteria include a targeted check that isolates its own effect (INV-003 for PHASE-02, INV-002 for PHASE-03, INV-001 for PHASE-04, dry-run step-list equality for PHASE-05), and PHASE-03 RISK-03-02 explicitly requires stopping if the ABCD column addition moves any number.
- **RISK-002:** `.github/workflows/refresh.yml` auto-commits to `main` every Monday at 02:00 UTC and is gated by the R suite. PHASE-01 deliberately ships a repo state where an *invariant* fails — but the R suite still passes, so the weekly publish is unaffected. Only after TASK-06-03 wires invariants into that workflow does a violated invariant block publishing, by which point every invariant passes. **Mitigation:** do not add the invariants step to `refresh.yml` before PHASE-04 is complete.
- **RISK-003:** Regenerating three 243-cell grids is the wave's long pole and could reveal that `trisk.model` errors on the new carbon-price scenario names. **Mitigation:** PHASE-04 RISK-04-03 requires a single-scenario `trisk_run_adhoc.R` probe before the full regeneration.
- **RISK-004:** Removing the `risk_free_rate` lever (if Specification S3 step 4 applies) is a public contract change — `grid_contract_version` v1 → v2 and every `scenario_id` string changes shape. **Mitigation:** the decision is data-driven, the contract version exists precisely to record it, and `docs/trisk_scenario_grid_contract.md` is updated in the same phase.
- **ALT-001:** *Fix the grid staleness by simply regenerating it once, without fingerprinting.* Rejected: the cache would silently go stale again on the very next input change, which is exactly how the current three-month gap opened. The fingerprint is ~30 lines and permanently closes the class.
- **ALT-002:** *Delete `scripts/pipeline_refresh.R` outright rather than keeping it as a wrapper.* Rejected: it is referenced by name in `.github/workflows/refresh.yml`, `tools/verify_refactor.R:run_refresh()`, `README.md`, `CLAUDE.md`, and `AGENTS.md`. A wrapper preserves every caller at the cost of nine lines.
- **ALT-003:** *Make the invariants a testthat file instead of a `verify_refactor.R` mode.* Rejected: `tools/verify_refactor.R` is the repo's established acceptance-bar entry point, invariants must be runnable against an arbitrary snapshot directory (not just the repo default), and a `testthat` file that asserts on live pipeline outputs would fail on a clean checkout before the pipeline has ever run. The pure helpers *are* unit-tested via testthat against `tempdir()` fixtures — which is the right split.
- **ALT-004:** *Defer orchestrator convergence (PHASE-05) to a later wave.* Rejected: every week the two step lists drift further, and PHASE-06's SDB CI job plus the invariants-in-CI step are far more valuable when the public demo travels the same code path they guard.

## Suggested Next Step

Execute PHASE-01. Its acceptance signal is deliberately inverted: the phase is
complete when `Rscript tools/verify_refactor.R --invariants` **exits 1** and
prints `[FAIL]` for `INV-001`, `INV-002`, and `INV-003` while
`Rscript -e "testthat::test_dir('tests/testthat')"` still reports `FAIL 0`.
Capture that output verbatim in the phase commit message — it is the baseline
every later phase is measured against.
