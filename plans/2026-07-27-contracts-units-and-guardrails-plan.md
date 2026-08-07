---
title: "Wave 2 — Contracts, Units, and Guard Rails"
date: "2026-07-27"
status: "open — PHASE-01 (byte-identity CI gate + refresh drift gate) landed in 994a1af, PHASE-02 (true VND, R/format_money.R, INV-006) in cf2adeb, PHASE-03 (absolute severity scoring, R/severity_scoring.R, docs/scoring_anchors.md, stress_severity_score) in b712a2d, and PHASE-04 (single golden refreeze to 0.4.0, re-pinned golden tests, non-degeneracy guards, roxygen metadata) in e1825be; PHASE-05 (intake contract fixes) and PHASE-06 (coverage and reconciliation report) are not started — verified 2026-08-07: scripts/generate_coverage_report.R absent and scripts/intake_validate_and_map.R has no add_warning/convert_to_vnd/map_sector_code/fx_rate_usd_vnd"
request: "Wave 2 'Contracts & Units' — byte-identity CI gate, loanbook units rescale, anchored absolute scores, golden refreeze, intake contract fixes, coverage & reconciliation report"
plan_type: "multi-phase"
research_inputs:
  - "research/2026-07-27-post-wave1-contracts-units-and-guardrails-brainstorm.md"
  - "research/2026-07-25-post-wave0-platform-hardening-brainstorm.md"
---

# Plan: Wave 2 — Contracts, Units, and Guard Rails

## Objective

Fix three defects that make this repository's client-facing output wrong rather
than merely incomplete: (1) the synthetic MCB loanbook is denominated in
**millions of VND** while every column, label, and document says **VND**, making
the public demo portfolio read as USD 950 instead of the ~USD 1B its own pitch
deck claims; (2) every priority score is min-max normalized — twice, in two
cases — so the top-ranked sector and borrower are **always exactly 1.0** for any
input, and two structurally different banks produce identical score patterns;
(3) the loanbook intake contract published in `intake/SCHEMA.md` disagrees with
its implementation in ways that **silently delete a real bank's exposure**.
Before any of that is touched, put a byte-identity gate in CI so the changes are
provable and so the weekly job that auto-publishes the public snapshot stops
being an ungated write path.

## Context Snapshot

- **Current state:** The pipeline is internally consistent (a cross-artifact
  invariant checker, `tools/verify_refactor.R --invariants`, runs in CI and
  passes 5/5) and reproducible (a byte-identity checker exists but runs
  **only** on developer machines). The R suite passes 276/0 and the Python suite
  58/0. But the money is on the wrong scale, the scores are rank-relative, and
  the intake validator drops rows the schema promises to accept.
- **Desired state:** Money is true VND everywhere and formatted by one shared
  function; priority scores come from documented absolute anchor tables so a
  score of 0.83 means the same thing for every bank in every refresh; the intake
  validator accepts the sector codes and currencies its own schema advertises
  and never silently discards exposure; and both acceptance checks
  (byte-identity and invariants) run in CI on every push, with byte-identity
  also gating the weekly auto-publish.
- **Key repo surfaces:** `scripts/generate_vietnam_data.R` (synthetic loanbook
  literals), `R/trisk_core.R` (`stress_priority_score` at line 829),
  `scripts/engagement_scoring.R` (`normalise_01`),
  `R/prioritization_core.R` (`prioritize_sectors`, `classify_band`),
  `scripts/intake_validate_and_map.R` (`known_isic`, currency check),
  `intake/SCHEMA.md`, `tools/verify_refactor.R`,
  `.github/workflows/ci.yml`, `.github/workflows/refresh.yml`,
  `tests/testthat/test_golden_numbers.R`, `tests/testthat/test_sdb_engagement.R`.
- **Out of scope:** Real bank data; new TRISK sectors (automotive TRISK stays
  out); making the Streamlit dashboard engagement-aware; the multi-scenario
  traffic-light matrix; the executive-summary generator; retiring dead scripts;
  `R CMD check` cleanup; any change to the 243-cell scenario grid's lever ranges
  or to the `trisk.model` / `r2dii.*` package pins.

## Environment & Conventions

- **Stack:** R 4.5.x for the entire analysis pipeline (no Node, no npm) and
  Python 3.11+ with Streamlit for the dashboard. R dependencies are pinned in
  `renv.lock`; the R package in this repo is named `pactatrisk` (see
  `DESCRIPTION`, currently version 0.3.0). Key analysis packages: `dplyr`,
  `readr`, `tibble`, `tidyr`, `ggplot2`, `jsonlite`, `arrow`, `fs`, `scales`,
  `stringi`, `r2dii.data`, `r2dii.match`, `r2dii.analysis`, `pacta.loanbook`,
  and `trisk.model` (version 2.6.1).
- **Setup:**
  ```sh
  python -m pip install -r dashboard/requirements.txt
  Rscript -e "renv::restore()"          # preferred
  Rscript scripts/ci/install_deps.R      # no-renv fallback
  ```
- **Build / Run:**
  ```sh
  Rscript scripts/pipeline_refresh.R                                   # full MCB refresh (~110 s with grid cached)
  Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json
  python -m streamlit run dashboard/app.py
  ```
- **Test:**
  - Full R suite: `Rscript -e "testthat::test_dir('tests/testthat')"` — expect `[ FAIL 0 | WARN 4 | SKIP 1 | PASS 276 ]` on the pre-change tree (the 4 warnings are "package built under R version 4.5.3" notices and are harmless; the 1 skip is the opt-in SDB end-to-end test).
  - Single R test file: `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`
  - Full Python suite: `python -m pytest dashboard/tests` — expect `58 passed`.
  - Single Python test: `python -m pytest dashboard/tests/test_loaders.py -v`
  - Byte-identity acceptance: `Rscript tools/verify_refactor.R` → prints `BYTE-IDENTITY PASS`, exit 0.
  - Cross-artifact invariants: `Rscript tools/verify_refactor.R --invariants` → prints `INVARIANTS PASS`, exit 0.
- **Conventions & traps:**
  - **Always run R commands from the repository root.** Every script resolves paths via `getwd()`, and `tests/testthat/helper-root.R`'s `project_root()` walks upward looking for a `dashboard/` directory.
  - **On Windows**, `Rscript` is at `C:\Program Files\R\R-4.5.2\bin\Rscript.exe`. Add it to `PATH` for the session before running anything that shells out: `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"`. Several scripts call `system2("Rscript", ...)`, which needs `Rscript` resolvable on `PATH` even when the outer call used a full path. On Linux/CI use plain `Rscript`.
  - **PowerShell 5.1 has no `&&` chaining.** Use `;` or separate commands on Windows. Prefer the portable `Rscript -e "..."` one-liners used throughout this repo — they run identically on Windows and Linux.
  - **Never verify byte-identity with `md5sum` or `tools::md5sum()`.** Git's `core.autocrlf` normalizes line endings on checkout/diff but not on disk, so a file that is byte-identical after normalization can have a different raw digest across Windows and Linux. `tools/verify_refactor.R` classifies changes via `git diff --name-only`, which respects `core.autocrlf`. Extend that tool rather than hand-rolling a comparison.
  - **Vietnamese names are matched after ASCII normalization** using `normalize_vn_name()` from `R/matching_helpers.R` (wraps `stringi::stri_trans_general(x, "Latin-ASCII")`). All CSVs are UTF-8 without a BOM.
  - **Engagement-config convention:** scripts `source("R/engagement_config.R")` and call `cfg <- load_engagement_config(get_config_arg())`. No `--config` flag means built-in Mekong Commercial Bank (MCB) defaults. Do not hardcode a new path outside this mechanism.
  - **Do not add pipeline dependencies.** The stack is pinned in `renv.lock`; `yaml` was deliberately rejected in favor of JSON configs via `jsonlite`. Dev-only tooling is the only category added without a strong reason. Everything in this plan uses base R plus packages already in `renv.lock`.
  - **Do not touch `attic/`** (retired reference scripts) or write to `dashboard/data/` from anything other than `scripts/refresh_dashboard_data.R`.
  - **Synthetic-data disclaimers** in the README banner, dashboard banners, and report footers must always state the data is synthetic/illustrative. Never weaken or remove them.
- **Repo map:**
  ```
  R/                  Shared modules, also loadable as the `pactatrisk` package.
                      engagement_config.R (config loader + validator),
                      sector_registry.R, pacta_core.R, trisk_core.R (~1750 lines),
                      prioritization_core.R, step_runner.R, report_toolkit.R,
                      matching_helpers.R
  scripts/            R pipeline stages and report generators. run_engagement.R is
                      the single orchestrator; pipeline_refresh.R is a 42-line
                      wrapper that delegates to it with the mcb-demo config.
  engagements/        Per-engagement JSON configs. mcb-demo (public demo) and
                      sdb-rehearsal (Saigon Delta Bank, a second synthetic bank).
  data/               Synthetic input CSVs, written by generate_vietnam_data.R.
  synthesis_output/   Pipeline outputs (PACTA under vietnam/, TRISK under trisk/,
                      sector ranking under prioritization/).
  output/             MCB engagement outputs; engagement/engagement_priority.csv
                      is tracked, letters and disclosure packs are gitignored.
  dashboard/          Streamlit app (app.py, pages/, lib/, tests/) plus the frozen
                      public snapshot in dashboard/data/.
  intake/             "Bring Your Own Loanbook" schema contract and templates.
  tools/              verify_refactor.R — the two-mode acceptance checker.
  tests/testthat/     R test suite (13 files).
  docs/               Methodology guides and assumption registers.
  ```

## Research Inputs

- From `research/2026-07-27-post-wave1-contracts-units-and-guardrails-brainstorm.md`:
  - **The MCB loanbook is denominated in millions of VND but declares `VND`.** `scripts/generate_vietnam_data.R` line 196 and line 715 both divide `loan_size_outstanding` by 1,000 and label the result "bn VND" — arithmetic that is only correct if the column holds millions. `sum(loan_size_outstanding)` is 25,020,000 while `plans/PROGRESS.md` line 14 and the live pitch deck (`present/build_deck_v2.py` line 210) both claim "43 loans, 25 trillion VND (~$1B USD)". The inline section comments in the generator (e.g. `# --- Power - Coal (11 loans, ~7,020 bn VND) ---`) confirm the millions intent.
  - **The second engagement is on a different scale through the same code.** `data/fixtures/unseen_bank_loanbook.csv` (Saigon Delta Bank) totals 22,375,000,000,000 in true VND. The two committed `sector_priority_ranking.csv` files show the same `exposure_vnd` column at 15,770,000 (MCB power) versus 4,435,000,000,000 (SDB power) — a factor of 281,000 with an identical column name and unit label.
  - **The mislabeling has already propagated into committed prose:** `synthesis_output/prioritization/interpretation_notes.md` line 4, `reports/BIDV_Framework_Recommendation_Report_README.md` line 13, and `docs/bidv_sector_prioritization_methodology.md` line 222 all describe MCB's 19,300,000 Decision-263 exposure as "19.3 billion VND".
  - **Min-max normalization is applied two or three times to the same quantity.** `R/trisk_core.R` line 829 builds `stress_priority_score` from three `scales::rescale()` calls over the sector's own range (so the worst borrower is always 100). `scripts/engagement_scoring.R` line 89's `normalise_01()` then min-maxes that again, and `R/prioritization_core.R` lines 254-263 min-max an exposure-weighted mean of it a third time.
  - **Two banks therefore score identically.** Both `sector_priority_ranking.csv` files give power `composite_score` exactly 1.000 / band "Critical" and the bottom sector ~0.000 / "Low", despite SDB's cement being 13% of a ~USD 850M book and MCB's being 10% of a ~USD 750 book. With three sectors, min-max forces one sector to 1.0 and one to 0.0 in every dimension; only the middle sector carries information.
  - **Two golden assertions are tautologies:** `tests/testthat/test_golden_numbers.R` line 13 and `tests/testthat/test_sdb_engagement.R` line 63 both assert `composite_score[1] == 1.0`, which holds for any input under min-max.
  - **`intake/SCHEMA.md` line 23 says `currency` may be `VND` or `USD`**, but `scripts/intake_validate_and_map.R` lines 130-134 add a hard error for any non-VND currency, and errored rows are excluded from `normalized_loanbook.csv`. There is no FX conversion anywhere in the repo.
  - **`intake/SCHEMA.md` line 51 says out-of-scope codes are "classified as not in scope"**, but `scripts/intake_validate_and_map.R` line 146 raises an error and the row is dropped. Its `known_isic` allow-list (line 137) is six exact codes — `3511`, `2910`, `2394`, `2410`, `0510`, `0610` — and therefore rejects ISIC Rev.4 class `3510`, the standard 4-digit class for electricity generation, transmission and distribution.
  - **The rehearsal fixture already demonstrates the damage:** `engagements/sdb-rehearsal/intake/validation_summary.txt` reports 40 rows in, 17 rejected, seven of them `D3510` power rows listed under "Unresolved ISIC Codes (not in PACTA scope)". The engagement then produced a complete-looking deliverable over the surviving rows.
  - **Nothing reconciles submitted money against processed money.** `validation_summary.txt` counts rows only, and is gitignored via `engagements/*/intake/*`, so it is not a durable engagement artifact.
  - **`CLAUDE.md` law 5 claims both acceptance checks run in CI on every push. They do not.** `grep -rn "verify_refactor" .github/` returns only two `--invariants` invocations. Byte-identity has never run in CI, and no CI job executes the MCB pipeline at all — `ci.yml`'s three jobs are Python tests, R tests, and the *SDB* engagement.
  - **`.github/workflows/refresh.yml` auto-commits the public snapshot** (`git add dashboard/data synthesis_output ...` then `git commit` and `git push`) gated only by the R suite, whose numeric coverage of MCB is six pinned values in `test_golden_numbers.R` — two of which are the tautologies above.
  - **The committed `dashboard/data/pipeline_manifest.json` shows the full MCB chain runs in 107 seconds** with the scenario grid cached, so adding byte-identity to CI costs roughly 3-4 minutes on top of dependency restore.
- From `research/2026-07-25-post-wave0-platform-hardening-brainstorm.md`:
  - Golden refreezes are **batched**: each wave gets exactly one refreeze commit covering every change that alters committed numbers. This discipline has now worked twice and is retained here.
  - The acceptance ladder is built **detector first**: build and prove the check before making the change it is meant to catch. Both prior waves gated everything on a phase 1 that added a check.

## Assumptions and Constraints

- **ASM-001:** The `outstanding` values in `scripts/generate_vietnam_data.R`'s 43 `make_loan(...)` calls are denominated in **millions of VND** and are correct at that scale. The defect is the missing multiplication, not the literals. — **BINDING DEFAULT:** Multiply by 1,000,000 in exactly one place (inside `make_loan()`), rename the parameter to `outstanding_mn_vnd`, and leave all 43 call-site literals and their section comments (e.g. `~7,020 bn VND`) unchanged.
- **ASM-002:** Rescaling every loan by the same constant does not change any PACTA alignment result, because PACTA market share and SDA intensity are ratio-based and loan size enters only as a relative weight. `plans/vietnam_bank_pacta_scenario_plan.md` line 1035 states this explicitly. — **BINDING DEFAULT:** Treat any change to `06_vn_ms_alignment_2030.csv`, `06_vn_sda_alignment_2030.csv`, `04_vn_ms_company.csv`, `04_vn_ms_portfolio.csv`, `05_vn_sda_portfolio.csv`, or any file under `dashboard/data/trisk/` (other than `top_borrowers_alignment_trisk.csv`, which PHASE-03 modifies) as a **bug in the rescale**, not as expected churn. This is an exit criterion of PHASE-02, not a hope.
- **ASM-003:** The exact anchor breakpoints for the absolute severity bands are a judgment call with no external standard to copy. — **BINDING DEFAULT:** Use the five-point anchor tables given verbatim in `## Specification` below. They are chosen so that MCB power lands in "Critical" and MCB cement lands in "Low" (preserving today's qualitative ordering) while producing non-degenerate interior values. Record them in a new `docs/scoring_anchors.md` as the single source of truth so a reviewer can argue with the numbers without reading code.
- **ASM-004:** `stress_priority_score` (0-100, rank-relative within a sector) is consumed by the dashboard **only for sorting and ranking** — verified: `dashboard/pages/2_TRISK_Risk.py` lines 158-177 and `dashboard/pages/5_Scenario_Builder.py` lines 171-214 and 434-451 all use it as a sort key or a rank input, and `dashboard/tests/test_loaders.py` line 57 asserts only that the column exists in the grid parquet. — **BINDING DEFAULT:** Keep `stress_priority_score` unchanged and with its existing meaning; add a new, separate absolute column rather than redefining the existing one. No dashboard Python changes are required by PHASE-03.
- **ASM-005:** The scenario-grid parquet files (`dashboard/data/trisk/grid/*/borrower_results.parquet`) carry `stress_priority_score` but not the new absolute severity column, and regenerating all three grids costs roughly 10 minutes per sector. — **BINDING DEFAULT:** Do **not** regenerate the scenario grid in this wave. `grid_contract_version` in `R/trisk_core.R` (currently `"v2"`) stays at `"v2"`, and `grid_input_fingerprint()` must not change, so the existing cache stays valid. If a grid regeneration is triggered accidentally, stop and investigate rather than committing it.
- **ASM-006:** The FX rate for converting USD-denominated exposure at intake has no authoritative source in this repo. — **BINDING DEFAULT:** Add an optional engagement-config key `inputs.fx_rate_usd_vnd` (a single positive number, VND per 1 USD) defaulting to `NULL` ("not configured"). When a loanbook contains a non-VND currency and no rate is configured, the affected rows are retained and flagged with a warning classification, and the intake exits non-zero with a clear message naming the missing key — never silently dropped and never silently converted at a guessed rate. When the key is set, convert once at intake and record the rate in the engagement's `pipeline_manifest.json`.
- **ASM-007:** The Vietnamese VSIC 2018 sub-classes for electricity (`35101`, `35102`, `35103`) and the ISIC Rev.4 class `3510` all denote power-sector activity for this pipeline's purposes. — **BINDING DEFAULT:** Map `3510`, `35101`, `35102`, `35103`, and `3511` all to PACTA sector `power`. Apply the same widening for the other four sectors using the codes listed in PHASE-05's `vsic_to_pacta` table. Do not add any new PACTA sector.
- **CON-001:** Every default-mode MCB CSV output must remain byte-identical to its pre-change content **except** where a phase explicitly declares a refreeze. Verify with `Rscript tools/verify_refactor.R`, never with raw digests. PNG files are compared visually only (PNG compression is not deterministic) and generated-timestamp text in HTML reports may differ.
- **CON-002:** No new package may be added to `renv.lock` or to `DESCRIPTION`'s `Imports`. Everything in this plan is base R plus `dplyr`, `readr`, `tibble`, `tidyr`, `jsonlite`, `stringi`, and `arrow`, all already pinned.
- **CON-003:** All data in this repository is synthetic. Generated letters and disclosure packs must never be committed (they are gitignored under `output/engagement_letters/*` and `output/disclosure/*`). Synthetic-data disclaimers stay intact.
- **DEC-001:** Build the detector before the fix. PHASE-01 adds the byte-identity CI gate and must be green on the unmodified tree before any numeric change is made, so that a later red result is unambiguously caused by the change under test.
- **DEC-002:** PHASE-02 and PHASE-03 both alter committed numbers. They share **one** refreeze commit, produced in PHASE-04. Do not commit regenerated artifacts at the end of PHASE-02 or PHASE-03.
- **DEC-003:** `scripts/pipeline_refresh.R` remains a thin wrapper over `scripts/run_engagement.R`; no orchestration logic is added to it.
- **DEC-004:** `CLAUDE.md` law 5's wording is corrected to match reality as part of PHASE-01, in the same commit that makes the statement true.

## Specification

### S1 — Money units

Let `L_i` be the `outstanding_mn_vnd` literal passed to `make_loan()` for loan
`i` (unit: millions of VND). The generator must emit:

```
loan_size_outstanding_i    = L_i * 1e6                 (unit: VND)
loan_size_credit_limit_i   = round(L_i * 1e6 * 1.2)    (unit: VND)
```

- `L_i` — the unchanged literal in the source (for example `800000`, meaning 800,000 million VND = 800 billion VND).
- `1e6` — VND per million VND. This is the single conversion constant; define it once as `VND_PER_MILLION <- 1e6`.
- `1.2` — the existing synthetic credit-limit multiplier; unchanged.

Display conversions, replacing the two existing `/ 1000` expressions:

```
billion_VND = VND / 1e9
```

- `VND` — a money figure already in true VND.
- `1e9` — VND per billion VND.

### S2 — Absolute severity anchor tables

Every severity is a number in `[0, 1]` obtained by **clamped piecewise-linear
interpolation** over a five-point anchor table:

```
severity(x) = approx(x = anchors_x, y = anchors_y, xout = clamp(x, min(anchors_x), max(anchors_x)))$y
```

- `x` — the raw metric being scored.
- `anchors_x` — the five breakpoint values of that metric, ascending.
- `anchors_y` — the five severity values `0.00, 0.25, 0.50, 0.75, 1.00`.
- `clamp(x, lo, hi)` — `min(max(x, lo), hi)`; values beyond the last breakpoint saturate at `1.00` rather than extrapolating.
- `approx` — base R's `stats::approx()` with default `method = "linear"`.

**Table A1 — market-share alignment gap** (sectors `power` and `automotive`; unit: percentage points of technology market share, absolute value):

| gap (pp) | 0 | 5 | 10 | 20 | 40 |
|---|---|---|---|---|---|
| severity | 0.00 | 0.25 | 0.50 | 0.75 | 1.00 |

**Table A2 — SDA emission-intensity gap** (sectors `cement` and `steel`; unit: percent of the sector's 2030 target intensity, absolute value — the `gap_pct` column):

| gap (%) | 0 | 2 | 5 | 10 | 20 |
|---|---|---|---|---|---|
| severity | 0.00 | 0.25 | 0.50 | 0.75 | 1.00 |

Two tables are required because the two quantities are not comparable:
percentage points of market share and percent-of-target emission intensity share
a numeric scale but not a meaning. `scripts/engagement_scoring.R`'s own header
comment (lines 32-35) already documents this, and today's code min-maxes them
together anyway.

**Table B — TRISK value-loss severity** (unit: fraction of baseline NPV lost). Input is `loss = max(0, -npv_change)`, so a positive `npv_change` (value gain under the shock) scores `0.00`:

| loss | 0.00 | 0.05 | 0.15 | 0.30 | 0.60 |
|---|---|---|---|---|---|
| severity | 0.00 | 0.25 | 0.50 | 0.75 | 1.00 |

**Table C — exposure-concentration severity** (unit: fraction of the engagement's total Decision-263-relevant exposure, in `[0, 1]`):

| share | 0.00 | 0.05 | 0.15 | 0.30 | 0.50 |
|---|---|---|---|---|---|
| severity | 0.00 | 0.25 | 0.50 | 0.75 | 1.00 |

### S3 — Composite scores using absolute severities

**Borrower composite** (`scripts/engagement_scoring.R`), for borrower `b`:

```
severity_alignment_b = severity(alignment_gap_b, table A1 if sector in {power, automotive} else table A2)
severity_trisk_b     = severity(max(0, -npv_change_b), table B)          # NA when the borrower has no TRISK coverage
composite_score_b    = (w_align * severity_alignment_b + w_trisk * severity_trisk_b) / (w_align + w_trisk)
                       when severity_trisk_b is not NA
composite_score_b    = severity_alignment_b
                       when severity_trisk_b is NA  (composite_partial = TRUE)
```

- `w_align`, `w_trisk` — CLI weights, default `0.5` each; unchanged.
- The renormalization-to-available-weight behavior for TRISK-uncovered borrowers (currently automotive) is unchanged in form; only the inputs become absolute.
- `severity_trisk_b` replaces today's `norm_trisk_priority`, which was a min-max of `stress_priority_score`, which was itself already a min-max. This removes both layers.

**Sector composite** (`R/prioritization_core.R`), for sector `s`:

```
alignment_score_s = severity(alignment_gap_raw_s, table A1 if s == "power" else table A2)
stress_score_s    = severity(weighted_mean_loss_s, table B)
exposure_score_s  = severity(exposure_share_s, table C)
composite_score_s = w_alignment * alignment_score_s + w_stress * stress_score_s + w_exposure * exposure_score_s
```

- `w_alignment = 0.35`, `w_stress = 0.35`, `w_exposure = 0.30` — unchanged defaults.
- `weighted_mean_loss_s` — the exposure-weighted mean of `max(0, -npv_change)` across the sector's borrowers, computed from `top_borrowers_alignment_trisk.csv`'s `npv_change` column. This replaces today's exposure-weighted mean of `stress_priority_score`. Because every borrower in a sector currently receives the same per-borrower exposure (`sector_exposure / n_borrowers`), the weighting reduces to a plain mean today; keep the weighted form so it stays correct if per-borrower exposure is introduced later.
- `exposure_share_s` — unchanged: the sector's share of total Decision-263 exposure.

**Band thresholds** (`classify_band()` in `R/prioritization_core.R`) keep their
current cut points and only now describe an absolute quantity:

```
score >= 0.70 -> "Critical"
score >= 0.50 -> "High"
score >= 0.30 -> "Medium"
otherwise     -> "Low"
```

### S4 — Worked example (use this to check the implementation)

Using today's MCB inputs from `synthesis_output/prioritization/sector_priority_ranking.csv`:

- Power: `alignment_gap_raw = 14.39` pp. Table A1, between breakpoints 10 (0.50) and 20 (0.75): `0.50 + (14.39 - 10) / (20 - 10) * 0.25 = 0.60975`.
- Power: `exposure_share = 0.8184`. Table C, at or beyond the last breakpoint 0.50: saturates to `1.00`.
- Cement: `alignment_gap_raw = 2.1` (SDA `gap_pct`). Table A2, between 2 (0.25) and 5 (0.50): `0.25 + (2.1 - 2) / (5 - 2) * 0.25 = 0.2583`.
- Steel: `alignment_gap_raw = 7.2`. Table A2, between 5 (0.50) and 10 (0.75): `0.50 + (7.2 - 5) / (10 - 5) * 0.25 = 0.61`.
- Cement: `exposure_share = 0.1038`. Table C, between 0.05 (0.25) and 0.15 (0.50): `0.25 + (0.1038 - 0.05) / (0.15 - 0.05) * 0.25 = 0.3845`.

Under min-max today, cement's alignment score is exactly `0` and steel's is
`0.4150` purely because cement is last of three. Under the anchors they are
`0.2583` and `0.61`, and neither depends on how many sectors are in scope.

## Phase Summary

| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Byte-identity runs in CI and gates the weekly auto-publish; `CLAUDE.md` law 5 becomes true | None | New `byte-identity` job in `ci.yml`; drift gate in `refresh.yml`; corrected `CLAUDE.md` and `README.md` |
| PHASE-02 | Money is true VND everywhere, formatted by one shared function, guarded by a new invariant | PHASE-01 | `R/format_money.R`; rescaled `generate_vietnam_data.R`; `INV-006` in `tools/verify_refactor.R`; corrected prose |
| PHASE-03 | Priority scores come from documented absolute anchor tables instead of min-max | PHASE-01 | `R/severity_scoring.R`; rewritten scoring in `engagement_scoring.R` and `prioritization_core.R`; new `stress_severity_score` column; `docs/scoring_anchors.md` |
| PHASE-04 | One golden refreeze covering PHASE-02 and PHASE-03, proven correct by PHASE-01's gate | PHASE-02, PHASE-03 | Regenerated MCB and SDB artifacts; re-pinned golden tests; `NEWS.md` 0.4.0 |
| PHASE-05 | The intake validator honors its own published contract and never silently deletes exposure | PHASE-01 | Widened sector map; FX at intake; warn-not-drop classifications; reconciled `intake/SCHEMA.md` |
| PHASE-06 | Every engagement produces a money-denominated coverage and reconciliation report | PHASE-05 | `scripts/generate_coverage_report.R`; new orchestrator step; tracked SDB fixture |

## Detailed Phases

### PHASE-01 - Byte-identity gate in CI and on the weekly publish

**Goal**
Make `tools/verify_refactor.R` (byte-identity mode) run on every push and gate
the weekly job that auto-commits the public snapshot, and correct the two
documents that already claim this is happening. This phase must be green on the
unmodified tree so that every later phase's red result is attributable.

**Tasks**
- [x] TASK-01-01: Confirm the pre-change tree is clean and both acceptance modes pass locally. Run `git status --porcelain` (expect empty output), `Rscript tools/verify_refactor.R --invariants` (expect `INVARIANTS PASS`), and `Rscript tools/verify_refactor.R` (expect `BYTE-IDENTITY PASS`). If byte-identity does **not** pass on the unmodified tree, stop and resolve that first — everything downstream depends on this baseline.
- [x] TASK-01-02: Add a `byte-identity` job to `.github/workflows/ci.yml`, modelled structurally on the existing `sdb-engagement` job (same checkout, `r-lib/actions/setup-r@v2` with `r-version: "4.5"` and `use-public-rspm: true`, the same `apt-get` system dependencies, and `r-lib/actions/setup-renv@v2` with `cache-version: 1`). The job's single analysis step runs `Rscript tools/verify_refactor.R`. Add `timeout-minutes: 30`.
- [x] TASK-01-03: In `.github/workflows/refresh.yml`, insert a drift-classification step **after** "Cross-artifact invariants" and **before** "Commit refreshed snapshot", running `Rscript tools/verify_refactor.R --skip-refresh`. The `--skip-refresh` flag classifies the working tree that the refresh step just produced, without running the pipeline a second time.
- [x] TASK-01-04: Make the drift gate overridable for intentional refreezes. Add a `workflow_dispatch` boolean input named `allow_drift` (default `false`) to `refresh.yml`, and guard the new step with `if: github.event.inputs.allow_drift != 'true'`. Document in a comment directly above the step that a scheduled run always enforces the gate because `github.event.inputs` is empty for `schedule` triggers.
- [x] TASK-01-05: Correct `CLAUDE.md`. In law 5, replace the sentence asserting that both checks run in CI on every push with an accurate one: byte-identity runs in `ci.yml` on every push and gates `refresh.yml` before it commits; the invariants check runs in both workflows.
- [x] TASK-01-06: Correct `README.md`'s "Refactor acceptance check" section, which currently states that both `.github/workflows/ci.yml` and `.github/workflows/refresh.yml` run "this" on every push and every weekly refresh. State which mode runs where, and mention the `allow_drift` dispatch input as the documented escape hatch for a planned refreeze.

**File Changes**
- `.github/workflows/ci.yml` (modify): add one new job `byte-identity` after the existing `sdb-engagement` job. Do not change the `python-tests`, `r-tests`, or `sdb-engagement` jobs.
- `.github/workflows/refresh.yml` (modify): add the `workflow_dispatch` input `allow_drift`, and insert one new step between "Cross-artifact invariants" and "Commit refreshed snapshot". Do not change the `schedule` cron, the `permissions` block, or the `git add` path list.
- `CLAUDE.md` (modify): law 5 wording only. Leave laws 1-4 and 6-8 and the "Do-not-touch" section untouched.
- `README.md` (modify): the "Refactor acceptance check" section only.

**Function Signatures**
None — no code interfaces change in this phase.

**Test Specs**
- `Rscript tools/verify_refactor.R` on the unmodified tree → stdout ends with `BYTE-IDENTITY PASS`, exit status `0`.
- `Rscript tools/verify_refactor.R --skip-refresh` on a clean tree → stdout contains `=== --skip-refresh: classifying current working tree only ===` then `No tracked files changed.` and `BYTE-IDENTITY PASS`, exit status `0`.
- Negative control, proving the gate can fail: append a single line to a tracked pipeline CSV, then run the classifier and confirm it reports drift and exits non-zero.
  ```sh
  printf '\n' >> synthesis_output/vietnam/06_vn_ms_alignment_2030.csv
  Rscript tools/verify_refactor.R --skip-refresh; echo "exit=$?"
  git checkout -- synthesis_output/vietnam/06_vn_ms_alignment_2030.csv
  ```
  → output contains a `--- DRIFT (1) ---` section naming `synthesis_output/vietnam/06_vn_ms_alignment_2030.csv`, then `DRIFT DETECTED (1 files)`, and `exit=1`. The final `git checkout` restores the file; confirm `git status --porcelain` is empty afterwards.
- `Rscript -e "testthat::test_dir('tests/testthat')"` → `[ FAIL 0 | ... | PASS 276 ]` (unchanged; this phase adds no R code).

**Dependencies**
- GitHub Actions runners with the same `renv` cache the existing `r-tests` job uses. No new action or package.

**Exit Criteria**
- [ ] `.github/workflows/ci.yml` contains a `byte-identity` job whose analysis step is exactly `Rscript tools/verify_refactor.R`.
- [ ] `.github/workflows/refresh.yml` runs `Rscript tools/verify_refactor.R --skip-refresh` before `git add`, guarded by `allow_drift`.
- [ ] The negative control above produces `exit=1` and names the touched file, and the tree is clean again afterwards.
- [ ] Neither `CLAUDE.md` nor `README.md` contains a claim about CI behavior that `grep -rn "verify_refactor" .github/` contradicts.
- [ ] `git status --porcelain` is empty except for the four intentionally edited files.

**Phase Risks**
- **RISK-01-01:** Byte-identity may fail on the GitHub Actions runner even though it passes locally, because Linux and Windows produce different R graphics output or because a package version differs from the local machine. Mitigation: `classify_path()` in `tools/verify_refactor.R` already routes all `.png` files to the ignored `png-noise` bucket and all `.html` files plus `pipeline_manifest.json` / `refresh_audit_metrics.json` / `manifest.csv` to the ignored `timestamp-class` bucket, so only CSV and JSON numeric content is enforced. If a genuine cross-platform CSV difference appears, capture the failing job's DRIFT list verbatim into the pull request before adjusting anything, and prefer fixing the nondeterminism over widening the ignore list.
- **RISK-01-02:** The `byte-identity` job runs the full MCB pipeline, so it will regenerate the scenario grid if `grid_input_fingerprint()` no longer matches `grid_meta.json`. On the unmodified tree it matches (`input_fingerprint: 57600f19091de0077cb6a904d68e6c12` for power), so the grid step takes about 4 seconds. Mitigation: the `timeout-minutes: 30` cap turns an unexpected full regeneration into a fast, obvious failure rather than a 30-minute silent one.

### PHASE-02 - True VND everywhere, one money formatter, one new invariant

**Goal**
Move the synthetic MCB loanbook onto true VND so it sits on the same scale as
the Saigon Delta Bank fixture, route every money rendering through one shared
function, and add a cross-artifact invariant that fails if any engagement's
loanbook is implausible for its declared currency.

**Tasks**
- [x] TASK-02-01: Create `R/format_money.R` with the three functions specified below. It must depend only on base R.
- [x] TASK-02-02: In `scripts/generate_vietnam_data.R`, define `VND_PER_MILLION <- 1e6` near the `isic_*` constants (around line 58). Rename `make_loan()`'s `outstanding` parameter to `outstanding_mn_vnd`, and set `loan_size_outstanding = outstanding_mn_vnd * VND_PER_MILLION` and `loan_size_credit_limit = round(outstanding_mn_vnd * VND_PER_MILLION * 1.2)`. Add a comment above `make_loan()` stating that call-site literals are in millions of VND and that the emitted CSV columns are in true VND. **Do not edit the 43 call-site literals.**
- [x] TASK-02-03: In the same file, replace the two display expressions that divide by 1000. Line ~196 (`Total: %s bn VND`) and line ~715 (`total_bn_vnd = sum(loan_size_outstanding) / 1000`) must divide by `1e9` instead. Source `R/format_money.R` at the top of the script and use `format_vnd_bn()` for the console line.
- [x] TASK-02-04: Replace the three ad-hoc money formatters with the shared ones. In `scripts/generate_engagement_letters.R` (line ~141) delete the local `format_vnd()` — including its misleading `"(synthetic units)"` suffix — and source `R/format_money.R`, calling `format_vnd_full()`. In `scripts/generate_disclosure_pack.R` (line ~127) delete the local `fmt_vnd()` and do the same. In `R/prioritization_core.R` (lines ~204-209) replace the inline `formatC(..., format = "f", big.mark = ",")` console output with `format_vnd_full()`.
- [x] TASK-02-05: Add `inv_loanbook_currency_scale()` to `tools/verify_refactor.R` as `INV-006`, and register it in `run_invariants()` alongside the existing five. See the signature and rule below.
- [x] TASK-02-06: Add `tests/testthat/test_format_money.R` and extend `tests/testthat/test_verify_invariants.R` with INV-006 cases, following the structure the existing invariant tests already use.
- [x] TASK-02-07: Correct the three committed prose files that describe the old scale with the wrong unit word: `plans/PROGRESS.md` line 14 and line 27, `reports/BIDV_Framework_Recommendation_Report_README.md` line 13, and `docs/bidv_sector_prioritization_methodology.md` line 222. After the rescale, MCB's book is 25,020,000,000,000 VND (25.02 trillion VND, ~USD 950M at 26,300 VND/USD) and its Decision-263 exposure is 19,300,000,000,000 VND (19.3 trillion VND). Also correct `synthesis_output/prioritization/interpretation_notes.md` lines 4 and 25 — this file is hand-maintained, not generated, despite living under `synthesis_output/`.
- [x] TASK-02-08: Correct the one number in the pitch-deck source. `present/build_deck_v2.py` line 210 and line 344 currently say "25 trillion VND" and "~$1B USD"; the trillion figure is now correct, so change only the USD figure to "~$950M USD". Do not rebuild the `.pptx`; changing the source is sufficient for this plan.
- [x] TASK-02-09: Add a "Units" subsection to `intake/SCHEMA.md` stating that `exposure_vnd` and `credit_limit_vnd` are in **whole VND**, not thousands and not millions, and give a worked example (a 1 billion VND loan is `1000000000`). Mirror the same statement into `pilot/loanbook_data_spec.md`, which is the document sent to prospects.

**File Changes**
- `R/format_money.R` (create): the three formatting functions below plus roxygen comments with `@export` tags matching the style of `R/report_toolkit.R`.
- `scripts/generate_vietnam_data.R` (modify): add `VND_PER_MILLION`, rename and rescale inside `make_loan()`, fix the two `/1000` display expressions, source `R/format_money.R`. Leave the 43 `make_loan(...)` call-site literals, all ABCD generation, all scenario generation, and every section comment unchanged.
- `scripts/generate_engagement_letters.R` (modify): delete the local `format_vnd()`, source `R/format_money.R`, call `format_vnd_full()` at line ~183. Leave `format_gap`, `format_npv`, `format_pd`, and the template substitution machinery unchanged.
- `scripts/generate_disclosure_pack.R` (modify): delete the local `fmt_vnd()`, source `R/format_money.R`, call `format_vnd_full()` at line ~213. Leave the CSS block and all section markup unchanged.
- `R/prioritization_core.R` (modify): source-level use of `format_vnd_full()` in the two console `cat()` calls only. Do not touch the scoring logic in this phase — PHASE-03 owns that.
- `tools/verify_refactor.R` (modify): add `inv_loanbook_currency_scale()` and add it to the `results` list in `run_invariants()`. Leave INV-001 through INV-005 unchanged.
- `tests/testthat/test_format_money.R` (create): unit tests for the three formatters.
- `tests/testthat/test_verify_invariants.R` (modify): append INV-006 tests. Leave the existing tests unchanged.
- `plans/PROGRESS.md`, `reports/BIDV_Framework_Recommendation_Report_README.md`, `docs/bidv_sector_prioritization_methodology.md`, `synthesis_output/prioritization/interpretation_notes.md`, `present/build_deck_v2.py`, `intake/SCHEMA.md`, `pilot/loanbook_data_spec.md` (modify): the specific lines named in the tasks above.

**Function Signatures**
- `format_vnd_full(x: numeric) -> character` — a whole-VND figure with comma thousands separators and a trailing ` VND`, e.g. `format_vnd_full(1030000000000)` returns `"1,030,000,000,000 VND"`. Returns `"Not available"` for `NA`.
- `format_vnd_bn(x: numeric, digits: integer = 1) -> character` — the same figure expressed in billions of VND, e.g. `format_vnd_bn(1030000000000)` returns `"1,030.0 bn VND"`. Returns `"Not available"` for `NA`.
- `vnd_to_billion(x: numeric) -> numeric` — the plain numeric conversion `x / 1e9`, for use in data frames rather than display. Propagates `NA`.
- `inv_loanbook_currency_scale(root: character) -> list(id = character, ok = logical, detail = character)` — for every `engagements/*/engagement_config.json`, reads the config's `inputs$loanbook_csv`; when every row's `loan_size_outstanding_currency` is `"VND"`, asserts the **median** of `loan_size_outstanding` is at least `1e8` (100 million VND, about USD 3,800 — below any plausible corporate loan floor but far above the 1e5-1e6 range a millions-denominated book produces). Returns `id = "INV-006"`, `ok = FALSE` and one detail line per violating engagement naming the file, the median, and the threshold. Skips any engagement whose loanbook file is absent, and skips rows whose currency is not `"VND"`.

**Test Specs**
- `format_vnd_full(1030000000000)` → `"1,030,000,000,000 VND"`
- `format_vnd_full(0)` → `"0 VND"`
- `format_vnd_full(NA_real_)` → `"Not available"`
- `format_vnd_bn(1030000000000)` → `"1,030.0 bn VND"`
- `format_vnd_bn(25020000000000)` → `"25,020.0 bn VND"`
- `format_vnd_bn(500000000, digits = 3)` → `"0.500 bn VND"`
- `vnd_to_billion(2.5e12)` → `2500`
- `vnd_to_billion(NA_real_)` → `NA_real_`
- `inv_loanbook_currency_scale()` against a temporary fixture engagement whose loanbook has `loan_size_outstanding = c(800000, 650000)` and currency `VND` → `ok = FALSE`, and `detail` contains the substring `median` and the substring `1e+08` or `100000000`.
- `inv_loanbook_currency_scale()` against a fixture with `loan_size_outstanding = c(8e11, 6.5e11)` and currency `VND` → `ok = TRUE`, `detail` is `character(0)`.
- `inv_loanbook_currency_scale()` against a fixture whose config points at a nonexistent loanbook path → `ok = TRUE` (skip, not fail).
- After running `Rscript scripts/generate_vietnam_data.R`: `sum(read.csv("data/vietnam_loanbook.csv")$loan_size_outstanding)` → `25020000000000` exactly; `min(...)` → `250000000000`; `max(...)` → `1200000000000`; `nrow(...)` → `43`.

**Dependencies**
- PHASE-01 (the byte-identity gate must exist and be green before numbers move).

**Exit Criteria**
- [ ] `Rscript scripts/generate_vietnam_data.R` produces a `data/vietnam_loanbook.csv` totalling exactly `25020000000000`.
- [ ] `Rscript -e "testthat::test_file('tests/testthat/test_format_money.R')"` passes with zero failures.
- [ ] `Rscript tools/verify_refactor.R --invariants` prints `[PASS] INV-006` and `INVARIANTS PASS` **after** the full pipeline has been rerun (INV-006 will legitimately fail against the pre-rescale committed loanbook — that failure is the detector working, and it clears once TASK-02-02 lands and the pipeline reruns).
- [ ] **ASM-002 holds.** After `Rscript scripts/pipeline_refresh.R`, `git diff --name-only` lists **no** changes to `synthesis_output/vietnam/04_vn_ms_company.csv`, `04_vn_ms_portfolio.csv`, `05_vn_sda_portfolio.csv`, `06_vn_ms_alignment_2030.csv`, `06_vn_sda_alignment_2030.csv`, or to any file under `dashboard/data/trisk/`. Verify with:
  ```sh
  git diff --name-only -- synthesis_output/vietnam/04_vn_ms_company.csv synthesis_output/vietnam/04_vn_ms_portfolio.csv synthesis_output/vietnam/05_vn_sda_portfolio.csv synthesis_output/vietnam/06_vn_ms_alignment_2030.csv synthesis_output/vietnam/06_vn_sda_alignment_2030.csv dashboard/data/trisk
  ```
  → empty output. Any file listed here means the rescale leaked into ratio-based results and must be fixed before proceeding.
- [ ] Exactly three files show money-column drift: `data/vietnam_loanbook.csv`, `synthesis_output/vietnam/02_vn_matched_prioritized.csv` (mirrored to `dashboard/data/pacta/02_vn_matched_prioritized.csv`), and `output/engagement/engagement_priority.csv` plus `synthesis_output/prioritization/sector_priority_ranking.csv` (the `exposure_vnd` column only).
- [ ] `grep -rn "synthetic units" scripts/` returns nothing.
- [ ] `grep -rn "/ 1000" scripts/generate_vietnam_data.R` returns nothing.

**Phase Risks**
- **RISK-02-01:** The `exposure_score` and `composite_score` columns in `sector_priority_ranking.csv` are computed from `exposure_share`, a ratio, and must therefore be **unchanged** by the rescale. If they move, a raw money figure is leaking into a score. Mitigation: the exit-criteria diff above plus an explicit check that `sector_priority_ranking.csv`'s `exposure_share` column is byte-identical before and after.
- **RISK-02-02:** `data/vietnam_loanbook.csv` feeds PACTA matching, and `r2dii.match` may apply a loan-size threshold or produce different tie-breaking at different magnitudes. Mitigation: this is exactly what the ASM-002 exit criterion detects. If `02_vn_matched_prioritized.csv` shows changes beyond the two `loan_size_*` columns (for example a different row order or a different `score`), stop and investigate before continuing to PHASE-03.
- **RISK-02-03:** `synthesis_output/prioritization/interpretation_notes.md` lives under an output directory but is hand-maintained, so a pipeline rerun will not fix it and a reviewer may assume it is generated. Mitigation: TASK-02-07 edits it explicitly, and a comment is added at its top recording that it is hand-maintained.

### PHASE-03 - Absolute severity scores replacing min-max normalization

**Goal**
Replace every rank-relative score that feeds a composite with an absolute
severity derived from the documented anchor tables in `## Specification`, so a
score means the same thing across sectors, across banks, and across refreshes —
and so the top-ranked entity is no longer 1.0 by construction.

**Tasks**
- [x] TASK-03-01: Create `R/severity_scoring.R` with the four functions specified below. Base R plus `stats::approx()` only.
- [x] TASK-03-02: Create `docs/scoring_anchors.md` documenting all four anchor tables verbatim from `## Specification` section S2, the rationale for two separate alignment tables, the saturation-not-extrapolation rule, the band thresholds, and the worked example from S4. State plainly that these thresholds are a documented judgment call, reviewable independently of the code.
- [x] TASK-03-03: In `R/trisk_core.R`, add a `stress_severity_score` column alongside the existing `stress_priority_score` in the `prioritization` mutate at lines ~827-833. Compute it as `severity_trisk(npv_change)`. **Leave `stress_priority_score`'s three `scales::rescale()` calls exactly as they are** — the dashboard sorts by it and its rank-relative meaning is legitimate for that purpose (ASM-004). Add the new column to the `select()` in `write_trisk_demo_outputs()` (around line 950) so it reaches `top_borrowers_alignment_trisk.csv`, and add a comment distinguishing the two columns.
- [x] TASK-03-04: Rewrite the scoring block in `scripts/engagement_scoring.R` (lines ~219-246). Delete `normalise_01()` entirely. Compute `severity_alignment` from the sector-appropriate alignment table and `severity_trisk` from `npv_change`, then the composite per `## Specification` S3. Replace the output columns `norm_alignment` and `norm_trisk_priority` with `severity_alignment` and `severity_trisk`, and append a new `composite_rank_pct` column holding the borrower's percentile rank within this engagement (`rank(composite_score) / n`), so the relative view survives as an explicit, separately-named quantity. Update the file's header comment block (lines 11-16 and 32-35) to describe the new method and to remove the now-obsolete note about incomparable cross-family magnitudes being min-maxed together.
- [x] TASK-03-05: Rewrite the three dimension blocks in `R/prioritization_core.R` (lines ~216-295). Delete all three min-max blocks and their zero-range `rep(0.5, ...)` fallbacks. Compute `alignment_score`, `stress_score`, and `exposure_score` from the anchor tables per S3. Change `stress_raw` to be the exposure-weighted mean of `max(0, -npv_change)` read from `top_borrowers_alignment_trisk.csv`'s `npv_change` column, rather than of `stress_priority_score`. Keep `classify_band()`, the three weights, the output column names, and the ggplot chart code unchanged.
- [x] TASK-03-06: Fix the latent NA bug in `R/prioritization_core.R` while in this code. Lines ~125-129 build `alignment_raw_all` as a fixed named vector of `power`/`cement`/`steel`, then line 133 subsets it by `cfg$trisk_sectors`. A configured sector absent from that literal yields `NA`, which propagates silently through the dimension scores. Replace the literal with a lookup that emits an explicit `stop()` naming any configured sector for which no alignment source exists.
- [x] TASK-03-07: Add `tests/testthat/test_severity_scoring.R` with the cases listed below.
- [x] TASK-03-08: Add a unit test for `prioritize_sectors()` — currently one of 27 untested functions in `R/`. Build a temporary engagement config and minimal fixture CSVs in `tempdir()`, run the function, and assert the exact composite scores for a two-sector case computed by hand from the anchor tables.

**File Changes**
- `R/severity_scoring.R` (create): the four functions below with roxygen `@export` tags.
- `docs/scoring_anchors.md` (create): the anchor tables, rationale, and worked example.
- `R/trisk_core.R` (modify): add `stress_severity_score` to the `prioritization` mutate (~line 830) and to the `select()` in `write_trisk_demo_outputs()` (~line 950). Do not change `stress_priority_score`, `npv_range`, `pd_range`, `gap_range`, `grid_contract_version`, `grid_input_fingerprint()`, or anything in the grid code path.
- `scripts/engagement_scoring.R` (modify): delete `normalise_01()`, rewrite the mutate chain and the `select()` column list, update the header comment. Leave the automotive PACTA-gap computation (Section 3), the exposure join (Section 4), the empty-borrowers early exit, and the console summary structure intact — but update the console summary's caveat text to describe absolute scoring.
- `R/prioritization_core.R` (modify): rewrite the three dimension blocks and `stress_raw`; add the explicit `stop()` for unmapped sectors. Leave `classify_band()`, `.d263_isic_map`, the loanbook exposure aggregation, the output tibble column names, and the chart unchanged.
- `tests/testthat/test_severity_scoring.R` (create).
- `tests/testthat/test_prioritization_core.R` (create).

**Function Signatures**
- `severity_from_anchors(x: numeric, anchors_x: numeric, anchors_y: numeric = c(0, 0.25, 0.5, 0.75, 1)) -> numeric` — clamped piecewise-linear severity in `[0, 1]`; vectorized over `x`; returns `NA_real_` for `NA` input; errors if `anchors_x` is not strictly ascending or if its length differs from `anchors_y`.
- `severity_alignment(gap: numeric, basis: character) -> numeric` — severity for an alignment gap. `basis` must be `"market_share"` (uses Table A1: breakpoints `c(0, 5, 10, 20, 40)`) or `"sda_intensity"` (uses Table A2: breakpoints `c(0, 2, 5, 10, 20)`); any other value is an error. Applies `abs()` to `gap` before scoring.
- `severity_trisk(npv_change: numeric) -> numeric` — severity for TRISK value loss using Table B (breakpoints `c(0, 0.05, 0.15, 0.30, 0.60)`) applied to `max(0, -npv_change)`; returns `NA_real_` when `npv_change` is `NA`.
- `severity_exposure(share: numeric) -> numeric` — severity for exposure concentration using Table C (breakpoints `c(0, 0.05, 0.15, 0.30, 0.50)`); `share` is a fraction in `[0, 1]`, not a percentage.
- `alignment_basis_for_sector(sector: character) -> character` — returns `"market_share"` for `"power"` and `"automotive"`, `"sda_intensity"` for `"cement"` and `"steel"`, and errors naming the sector otherwise.

**Test Specs**
- `severity_from_anchors(10, c(0, 5, 10, 20, 40))` → `0.50`
- `severity_from_anchors(14.39, c(0, 5, 10, 20, 40))` → `0.60975` (tolerance `1e-4`)
- `severity_from_anchors(1000, c(0, 5, 10, 20, 40))` → `1.0` (saturation, not extrapolation)
- `severity_from_anchors(-3, c(0, 5, 10, 20, 40))` → `0.0` (clamped at the low end)
- `severity_from_anchors(NA_real_, c(0, 5, 10, 20, 40))` → `NA_real_`
- `severity_from_anchors(c(0, 5, 40), c(0, 5, 10, 20, 40))` → `c(0, 0.25, 1)` (vectorized)
- `severity_from_anchors(5, c(0, 5, 5, 20, 40))` → error (breakpoints not strictly ascending)
- `severity_alignment(2.1, "sda_intensity")` → `0.2583` (tolerance `1e-4`)
- `severity_alignment(7.2, "sda_intensity")` → `0.61` (tolerance `1e-4`)
- `severity_alignment(25.821596244131456, "market_share")` → `0.8228` (tolerance `1e-4`)
- `severity_alignment(-14.39, "market_share")` → `0.60975` (absolute value applied)
- `severity_alignment(5, "emissions")` → error mentioning `"emissions"`
- `severity_trisk(-0.980411177362964)` → `1.0` (loss saturates past the 0.60 breakpoint)
- `severity_trisk(-0.15)` → `0.50`
- `severity_trisk(0.000870)` → `0.0` (a value gain is not stress)
- `severity_trisk(NA_real_)` → `NA_real_`
- `severity_exposure(0.8183705241307733)` → `1.0`
- `severity_exposure(0.1038)` → `0.3845` (tolerance `1e-4`)
- `severity_exposure(0)` → `0.0`
- `alignment_basis_for_sector("power")` → `"market_share"`; `alignment_basis_for_sector("cement")` → `"sda_intensity"`; `alignment_basis_for_sector("coal")` → error mentioning `"coal"`
- `prioritize_sectors()` on a two-sector fixture (`power` with `share_gap_pp = 14.39`, `exposure_share = 0.80`, one borrower at `npv_change = -0.50`; `cement` with `gap_pct = 2.1`, `exposure_share = 0.20`, one borrower at `npv_change = -0.10`) → power `alignment_score = 0.60975`, `stress_score = 0.91667`, `exposure_score = 1.0`, `composite_score = 0.83425` (tolerance `1e-4`), `priority_band = "Critical"`; cement `alignment_score = 0.25833`, `stress_score = 0.375`, `exposure_score = 0.58333`, `composite_score = 0.39667` (tolerance `1e-4`), `priority_band = "Medium"`.
- **Degeneracy check, the point of the whole phase:** with a single-sector config (`trisk_sectors = ["power"]`), `prioritize_sectors()` must return `composite_score` strictly between `0` and `1` — under today's min-max it would return the `rep(0.5, ...)` zero-range fallback for every dimension.
- `prioritize_sectors()` with `cfg$trisk_sectors = c("power", "automotive")` → error naming `automotive` as having no alignment source (TASK-03-06), not a silent `NA`.

**Dependencies**
- PHASE-01. Independent of PHASE-02 in code, but both must be complete before PHASE-04's single refreeze.

**Exit Criteria**
- [x] `Rscript -e "testthat::test_file('tests/testthat/test_severity_scoring.R')"` and `Rscript -e "testthat::test_file('tests/testthat/test_prioritization_core.R')"` both pass with zero failures.
- [x] `grep -n "normalise_01" scripts/engagement_scoring.R` returns nothing.
- [x] `grep -n "rescale(" R/prioritization_core.R` returns nothing.
- [x] `grep -n "rescale(" R/trisk_core.R` still returns the three lines inside the `stress_priority_score` mutate — that column is deliberately preserved.
- [x] `docs/scoring_anchors.md` exists and contains all four anchor tables.
- [x] After a pipeline rerun, `output/engagement/engagement_priority.csv` has columns `severity_alignment`, `severity_trisk`, and `composite_rank_pct`, and no longer has `norm_alignment` or `norm_trisk_priority`.
- [x] After a pipeline rerun, no `composite_score` in either `output/engagement/engagement_priority.csv` or `synthesis_output/prioritization/sector_priority_ranking.csv` equals exactly `1.0` or exactly `0.0`, for either the MCB or the SDB engagement. Verify with:
  ```sh
  Rscript -e "for (p in c('output/engagement/engagement_priority.csv','synthesis_output/prioritization/sector_priority_ranking.csv','engagements/sdb-rehearsal/output/engagement/engagement_priority.csv')) { if (file.exists(p)) { s <- read.csv(p)\$composite_score; cat(p, ': min=', min(s), ' max=', max(s), ' any_exact_0_or_1=', any(s == 0 | s == 1), '\n', sep='') } }"
  ```
  → every line reports `any_exact_0_or_1=FALSE`.
- [x] `grid_contract_version` in `R/trisk_core.R` is still `"v2"` and `dashboard/data/trisk/grid/power/grid_meta.json`'s `input_fingerprint` is unchanged at `57600f19091de0077cb6a904d68e6c12`, confirming the grid was not regenerated (ASM-005).

**Phase Risks**
- **RISK-03-01:** Adding `stress_severity_score` to `top_borrowers_alignment_trisk.csv` changes a file published into `dashboard/data/`, and `dashboard/lib/loaders.py` loads that file as `"combined"`. Mitigation: the Python loaders read whole data frames without column allow-lists, and no test asserts a column count on that file — confirmed by inspecting `dashboard/tests/test_loaders.py`, which asserts column sets only for the grid parquet and grid scenarios. Run `python -m pytest dashboard/tests` at the end of this phase to confirm; expect `58 passed`.
- **RISK-03-02:** `prioritize_sectors()` reads TRISK results from the **published snapshot** (`cfg$paths$snapshot_dir/trisk/...`), not from `synthesis_output/trisk/` directly, so it must run after the snapshot-copy step. This ordering already exists in `run_engagement.R`'s step list and must not be disturbed. Mitigation: do not reorder steps; if `npv_change` reads as `NA` during development, the cause is a stale snapshot, not a scoring bug — rerun `scripts/refresh_dashboard_data.R` first.
- **RISK-03-03:** Both golden tests currently assert `composite_score[1] == 1.0`, so they will fail the moment this phase lands. That failure is expected and is resolved in PHASE-04, not by weakening the assertion here. Do not edit the golden tests during this phase.

### PHASE-04 - Single golden refreeze

**Goal**
Regenerate every committed artifact affected by PHASE-02 and PHASE-03, re-pin
the golden tests to values that are no longer tautologies, and land it all as
one reviewable refreeze commit whose diff is fully explained.

**Tasks**
- [x] TASK-04-01: Regenerate MCB from a clean tree with data generation enabled, so the rescaled loanbook is actually rewritten: `Rscript scripts/pipeline_refresh.R --full`.
- [x] TASK-04-02: Regenerate the Saigon Delta Bank engagement: `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json`. SDB's loanbook is already in true VND so its `exposure_vnd` values must **not** change; only its score columns should move.
- [x] TASK-04-03: Classify the full diff before committing anything: `Rscript tools/verify_refactor.R --skip-refresh`. Capture the DRIFT list verbatim into the commit message body. Every drifting file must be attributable to PHASE-02's rescale or PHASE-03's rescoring; anything else is a bug to fix before committing.
- [x] TASK-04-04: Re-pin `tests/testthat/test_golden_numbers.R`. Keep the row count and the three borrower-name assertions. Replace the three `composite_score` assertions with the newly computed values at `tolerance = 1e-4`, and add a comment recording that these are now absolute severity composites from `docs/scoring_anchors.md` and are therefore falsifiable — the previous `1.0` held for any input.
- [x] TASK-04-05: Add a non-degeneracy assertion to `tests/testthat/test_golden_numbers.R`: `expect_true(all(ep$composite_score > 0 & ep$composite_score < 1))`, with a comment explaining that this is the regression guard against a min-max normalization being reintroduced anywhere upstream.
- [x] TASK-04-06: Re-pin `tests/testthat/test_sdb_engagement.R` line 63 the same way, and add the same non-degeneracy assertion for the SDB fixture.
- [x] TASK-04-07: Add a golden assertion that the two banks' top composite scores now **differ**: assert `abs(mcb_top - sdb_top) > 0.01`, with a comment that under min-max both were exactly 1.0. Place it in `tests/testthat/test_golden_numbers.R`, guarded by `skip_if_not(file.exists(...))` for the SDB path in the same style the existing tests use.
- [x] TASK-04-08: Update `NEWS.md` with a `# pactatrisk 0.4.0` section describing the units fix, the absolute scoring change, the CI gate, and the intake contract work. Bump `Version:` in `DESCRIPTION` to `0.4.0`.
- [x] TASK-04-09: Regenerate the roxygen-derived package metadata so the new exports are declared: `Rscript -e "roxygen2::roxygenise()"`. Confirm `NAMESPACE` gains `format_vnd_full`, `format_vnd_bn`, `vnd_to_billion`, `severity_from_anchors`, `severity_alignment`, `severity_trisk`, `severity_exposure`, and `alignment_basis_for_sector`.
- [x] TASK-04-10: Commit everything as one commit whose message names both causes and includes the DRIFT list from TASK-04-03.

**File Changes**
- `data/vietnam_loanbook.csv`, `synthesis_output/vietnam/02_vn_matched_prioritized.csv`, `synthesis_output/prioritization/sector_priority_ranking.csv`, `synthesis_output/prioritization/sector_priority_detail.csv`, `output/engagement/engagement_priority.csv`, `dashboard/data/pacta/02_vn_matched_prioritized.csv`, `dashboard/data/trisk/*/top_borrowers_alignment_trisk.csv`, `synthesis_output/trisk/*_demo/top_borrowers_alignment_trisk.csv`, `engagements/sdb-rehearsal/output/engagement/engagement_priority.csv`, `engagements/sdb-rehearsal/output/prioritization/sector_priority_ranking.csv` (modify, all regenerated — never hand-edited).
- `tests/testthat/test_golden_numbers.R` (modify): re-pinned values plus two new assertions.
- `tests/testthat/test_sdb_engagement.R` (modify): re-pinned value plus one new assertion. Leave the `RUN_SDB_ENGAGEMENT` end-to-end block unchanged.
- `NEWS.md` (modify): prepend a `0.4.0` section. Leave the `0.3.0`, `0.2.0`, and `0.1.0` sections unchanged.
- `DESCRIPTION` (modify): `Version: 0.4.0` only.
- `NAMESPACE`, `man/` (modify, regenerated by roxygen — do not hand-edit).

**Function Signatures**
None — no code interfaces change in this phase.

**Test Specs**
- `Rscript -e "testthat::test_dir('tests/testthat')"` → `FAIL 0`, and `PASS` at least `290` (276 pre-change, plus roughly 14 new assertions from PHASE-02 and PHASE-03 test files and the new golden assertions).
- `python -m pytest dashboard/tests` → `58 passed`.
- `Rscript tools/verify_refactor.R --invariants` → `INV-001` through `INV-006` all `[PASS]`, then `INVARIANTS PASS`.
- Immediately after the refreeze commit, `Rscript tools/verify_refactor.R` → `BYTE-IDENTITY PASS` (the freshly committed artifacts must reproduce themselves).
- `Rscript -e "cat(sum(read.csv('data/vietnam_loanbook.csv')\$loan_size_outstanding))"` → `2.502e+13`.

**Dependencies**
- PHASE-02 and PHASE-03 both complete.

**Exit Criteria**
- [x] `git status --porcelain` is empty after the refreeze commit.
- [x] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS` on the committed tree.
- [x] `Rscript tools/verify_refactor.R --invariants` prints `INVARIANTS PASS` including `[PASS] INV-006`.
- [x] Full R suite `FAIL 0`; full Python suite `58 passed`.
- [x] `DESCRIPTION` reads `Version: 0.4.0` and `NEWS.md` has a `0.4.0` section.
- [x] `dashboard/data/trisk/grid/*/borrower_results.parquet` are unmodified: `git diff --name-only -- dashboard/data/trisk/grid` returns empty output.
- [x] The commit message lists every drifting file with its cause.

**Phase Risks**
- **RISK-04-01:** `--full` reruns `scripts/generate_vietnam_data.R`, which also regenerates the ABCD, scenarios, and TRISK input CSVs under `data/`. If any of those change, `grid_input_fingerprint()` changes and the whole 243-cell grid regenerates for all three sectors (roughly 30 minutes) and would then need committing. Mitigation: before running `--full`, confirm that PHASE-02 touched only `make_loan()` and the two display expressions. After the run, immediately check `git diff --name-only -- data/` and confirm only `vietnam_loanbook.csv` appears. If a TRISK input file changed, revert and find the leak.
- **RISK-04-02:** The refreeze is the one commit in this wave that a reviewer cannot check by reading code alone. Mitigation: TASK-04-03's captured DRIFT list, plus the ASM-002 exit criterion from PHASE-02, make the expected diff enumerable in advance.
- **RISK-04-03:** `roxygen2::roxygenise()` may reformat unrelated `man/` pages if the installed roxygen2 version differs from the one that produced them (`RoxygenNote: 8.0.0` in `DESCRIPTION`). Mitigation: check `packageVersion("roxygen2")` first; if it is not 8.0.0, hand-add the eight `export()` lines to `NAMESPACE` instead and leave `man/` alone.

### PHASE-05 - Intake honors its published contract

**Goal**
Make `scripts/intake_validate_and_map.R` accept the sector codes and currencies
`intake/SCHEMA.md` advertises, and ensure that no row is ever removed from a
client's loanbook without that removal being visible and quantified.

**Tasks**
- [ ] TASK-05-01: Introduce a two-tier outcome model in `scripts/intake_validate_and_map.R`. Keep the existing `add_error()` for genuine schema violations that make a row unusable (missing counterparty name, non-numeric exposure, duplicate row). Add `add_warning(row, column, message, classification)` for conditions that leave the row usable but reduced in scope. **Errors drop the row; warnings never do.**
- [ ] TASK-05-02: Reclassify the out-of-scope sector-code condition (currently line ~146) from error to warning with classification `"sector_out_of_scope"`. The row is retained in `normalized_loanbook.csv` with `sector_classification_direct_loantaker` set to the normalized code and PACTA sector `"not in scope"`, so downstream exposure accounting can see it. This matches `intake/SCHEMA.md` line 51, which already says such codes are "classified as not in scope".
- [ ] TASK-05-03: Widen the sector mapping. Replace the six-entry `known_isic` vector (line ~137) and the six-row `vsic_to_pacta` tribble (line ~185) with a single source of truth containing, at minimum: `3510`, `35101`, `35102`, `35103`, `3511` → `power`; `2910`, `29101`, `29102` → `automotive`; `2394`, `23941`, `23942` → `cement`; `2410`, `24101`, `24102` → `steel`; `0510`, `05101` → `coal`; `0610`, `0620`, `06101` → `oil and gas`. Derive `known_isic` from that table rather than maintaining two lists. Zero-padding must not corrupt 5-digit VSIC codes — pad to 4 only when the code has fewer than 4 digits.
- [ ] TASK-05-04: Handle non-VND currency. Add an optional `inputs.fx_rate_usd_vnd` key to `.default_engagement_config()` in `R/engagement_config.R` (default `NULL`) and to `.validate_engagement_config()` (when present, must be a single positive finite number; when empty in any of the `NULL` / `character(0)` / `list()` shapes, treat as not configured — the same round-trip hazard the existing `raw_loanbook_csv` and `row_count_files` checks already guard against). Add a `--fx-rate-usd-vnd <number>` CLI flag to `scripts/intake_validate_and_map.R` and pass it through from `scripts/run_engagement.R`'s intake step when the config sets it.
- [ ] TASK-05-05: Implement the conversion. When a row's `currency` is `USD` and a rate is available, set `loan_size_outstanding = exposure_vnd * fx_rate_usd_vnd`, set `loan_size_outstanding_currency = "VND"`, and record a warning with classification `"fx_converted"`. When the currency is neither `VND` nor `USD`, record a warning with classification `"unsupported_currency"`, retain the row, and set exposure to `NA` so it is visibly excluded from money totals rather than silently counted at the wrong scale. When any non-VND row exists and no rate is configured, print a message naming `inputs.fx_rate_usd_vnd` and exit non-zero **after** writing all output files, so the operator gets the full diagnostic rather than a bare failure.
- [ ] TASK-05-06: Write `validation_warnings.csv` alongside the existing `validation_errors.csv`, with columns `row`, `column`, `classification`, `message`. Extend `validation_summary.txt` to report both counts and to break warnings down by classification.
- [ ] TASK-05-07: Reconcile `intake/SCHEMA.md` with the implementation in both directions. Document the two-tier error/warning model and the exact list of conditions in each tier; list every accepted sector code from TASK-05-03; state that USD is accepted only when `inputs.fx_rate_usd_vnd` is configured, and that conversion happens once at intake; and keep the "Units" subsection added in PHASE-02.
- [ ] TASK-05-08: Extend `tests/testthat/test_intake_fixture.R` with the cases below.

**File Changes**
- `scripts/intake_validate_and_map.R` (modify): the two-tier outcome model, the widened sector table, FX handling, the new warnings output. Leave the file-reading fallback (UTF-8 then latin1), the `--anonymize` pseudonym path, `normalize_vn_name()` usage, and the match-preview block unchanged.
- `R/engagement_config.R` (modify): add `fx_rate_usd_vnd` to `.default_engagement_config()`'s `inputs` list and a validation branch in `.validate_engagement_config()`. Add it to the existing `raw_loanbook_csv` skip in the "every input must exist" loop, since it is a number, not a path — **this is required, or the existence check will treat the rate as a missing file**.
- `scripts/run_engagement.R` (modify): in `build_step_list()`, append `--fx-rate-usd-vnd <value>` to `intake_args` when `cfg$inputs$fx_rate_usd_vnd` is non-empty. Leave every other step unchanged.
- `intake/SCHEMA.md` (modify): the validation-rules and sector-mapping sections.
- `tests/testthat/test_intake_fixture.R` (modify): append new cases.

**Function Signatures**
- `add_warning(row: integer, column: character, message: character, classification: character) -> NULL` — appends to the module-level warnings accumulator; called for side effect.
- `normalize_sector_code(code: character, code_system: character) -> character` — modify the existing function so it zero-pads only codes shorter than 4 digits, leaving 5-digit VSIC codes intact; returns `NA_character_` for codes that are not purely numeric after prefix stripping.
- `map_sector_code(norm_code: character) -> character` — returns the PACTA sector for a normalized code, or `"not in scope"` when unmapped. Replaces the `left_join` against `vsic_to_pacta` as the single lookup point.
- `convert_to_vnd(amount: numeric, currency: character, fx_rate_usd_vnd: numeric) -> numeric` — returns the amount in VND: unchanged for `"VND"`, `amount * fx_rate_usd_vnd` for `"USD"`, `NA_real_` for anything else. Errors if `currency` is `"USD"` and `fx_rate_usd_vnd` is `NULL` or non-positive.

**Test Specs**
- `normalize_sector_code("D3510", "VSIC")` → `"3510"`
- `normalize_sector_code("D35101", "VSIC")` → `"35101"` (**not** truncated and **not** re-padded)
- `normalize_sector_code("351", "VSIC")` → `"0351"`
- `normalize_sector_code("D35X1", "VSIC")` → `NA_character_`
- `map_sector_code("3510")` → `"power"`; `map_sector_code("35102")` → `"power"`; `map_sector_code("3511")` → `"power"`
- `map_sector_code("9999")` → `"not in scope"`
- `convert_to_vnd(1000, "VND", 26300)` → `1000`
- `convert_to_vnd(1000, "USD", 26300)` → `26300000`
- `convert_to_vnd(1000, "EUR", 26300)` → `NA_real_`
- `convert_to_vnd(1000, "USD", NULL)` → error mentioning `fx_rate_usd_vnd`
- Running the intake against `data/fixtures/unseen_bank_loanbook.csv` with `--fx-rate-usd-vnd 26300` → `normalized_loanbook.csv` has **at least 30** rows (up from 24), the seven previously-rejected `D3510` rows are present with PACTA sector `power`, and `validation_warnings.csv` contains at least seven rows with `classification == "sector_out_of_scope"` or `"power"` mappings as appropriate.
- Running the same intake **without** `--fx-rate-usd-vnd` on a fixture containing one USD row → the process exits non-zero, `validation_warnings.csv` exists and names the USD row, and `normalized_loanbook.csv` still exists with that row retained and `loan_size_outstanding` as `NA`.
- A row with a missing counterparty name → still a hard **error**, still excluded from `normalized_loanbook.csv`, still present in `validation_errors.csv`.
- `load_engagement_config()` on a config with `"fx_rate_usd_vnd": 26300` → returns `cfg$inputs$fx_rate_usd_vnd == 26300` and does **not** raise "input file(s) not found".
- `load_engagement_config()` on a config with `"fx_rate_usd_vnd": -5` → error mentioning `fx_rate_usd_vnd`.
- Round-trip test (the hazard that has bitten twice before): write a config with `fx_rate_usd_vnd` unset via `jsonlite::toJSON(cfg, auto_unbox = TRUE)`, read it back with `jsonlite::read_json(..., simplifyVector = TRUE)`, and pass it to `.validate_engagement_config()` → no error, whether the empty value round-trips as `NULL`, `list()`, or `character(0)`.

**Dependencies**
- PHASE-01. Independent of PHASE-02, PHASE-03, and PHASE-04.

**Exit Criteria**
- [ ] `Rscript -e "testthat::test_file('tests/testthat/test_intake_fixture.R')"` passes with zero failures.
- [ ] Re-running the SDB intake produces at least 30 normalized rows, up from 24, with the `D3510` rows mapped to `power`.
- [ ] `intake/SCHEMA.md` and `scripts/intake_validate_and_map.R` agree on every accepted sector code and on the currency policy — check by listing the codes in each and diffing them.
- [ ] `validation_warnings.csv` is written on every intake run, even when empty.
- [ ] No condition that `intake/SCHEMA.md` describes as a classification is implemented as a row-dropping error.
- [ ] Full R suite `FAIL 0`.

**Phase Risks**
- **RISK-05-01:** Widening the sector map changes SDB's normalized loanbook, which is a tracked golden fixture asserted at `nrow == 24L` and `ncol == 13L` in `tests/testthat/test_sdb_engagement.R` lines 46-49. That test will fail. Mitigation: this is expected. Re-pin `nrow` to the new count in the same commit, keep the `ncol == 13L` assertion (the normalized schema is unchanged), and regenerate `engagements/sdb-rehearsal/intake/normalized_loanbook.csv` plus the downstream SDB artifacts. Because PHASE-04's refreeze has already landed, this is a second, separate, smaller refreeze scoped to `engagements/sdb-rehearsal/` — that is acceptable and does not violate the batching rule, which governs the MCB public snapshot.
- **RISK-05-02:** Retaining out-of-scope rows means `normalized_loanbook.csv` now contains rows PACTA cannot match, which could change match-rate percentages or produce new warnings downstream. Mitigation: rows classified `"not in scope"` carry a sector value PACTA already handles (`pacta_prejoin_sectors` maps unknown codes to a non-PACTA sector), and `pacta_coverage()` already computes matched-versus-classified fractions. Verify by running the SDB engagement end-to-end and confirming it exits 0.
- **RISK-05-03:** Adding `fx_rate_usd_vnd` under `inputs` puts a number into a list whose every other element is a file path, and `.validate_engagement_config()` loops over `names(cfg$inputs)` calling `file.exists()`. Mitigation: TASK-05-04 explicitly requires adding it to the skip branch. Without this, every config that sets a rate fails validation with a confusing "input file(s) not found: 26300".

### PHASE-06 - Coverage and reconciliation report

**Goal**
Produce a durable, tracked, **money-denominated** artifact per engagement that
answers: what did the client send, what did we process, what could we not
process and why, and what fraction of processed exposure has asset-level (ABCD)
coverage. This is the artifact that makes "send us your loanbook and we will
tell you your coverage" a concrete offer.

**Tasks**
- [ ] TASK-06-01: Create `scripts/generate_coverage_report.R`, a CLI script following the same conventions as `scripts/generate_validation_report.R`: `source("R/engagement_config.R")`, accept `--config`, `--intake-dir`, and `--output`, and render a self-contained HTML file using `R/report_toolkit.R`'s `report_css()` and `write_html_report()`.
- [ ] TASK-06-02: Compute the reconciliation table. Read the raw submitted loanbook (the engagement's `inputs$raw_loanbook_csv`), `<intake-dir>/normalized_loanbook.csv`, `<intake-dir>/validation_errors.csv`, and `<intake-dir>/validation_warnings.csv`. Report, in both row counts and VND: total submitted; total normalized; total dropped by hard error, broken down by error column; total retained-with-warning, broken down by classification. Every money figure must render through `format_vnd_full()` and `format_vnd_bn()` from `R/format_money.R`.
- [ ] TASK-06-03: Compute ABCD coverage. Join the normalized loanbook's counterparty names against the engagement's `inputs$abcd_csv` using `normalize_vn_name()` from `R/matching_helpers.R`, and report the share of normalized exposure (in VND and as a percentage) whose counterparty resolves to an ABCD company, broken down by PACTA sector. Rows with no ABCD match are listed by name and exposure so an operator can see exactly which counterparties to chase.
- [ ] TASK-06-04: Write a machine-readable sidecar `coverage_metrics.json` next to the HTML, with keys `submitted_rows`, `submitted_vnd`, `normalized_rows`, `normalized_vnd`, `dropped_rows`, `dropped_vnd`, `warned_rows`, `warned_vnd`, `abcd_covered_vnd`, `abcd_coverage_pct`, and `by_sector` (an object keyed by PACTA sector). This is what a future executive-summary generator and the pipeline manifest will consume.
- [ ] TASK-06-05: Add the step to `scripts/run_engagement.R`'s `build_step_list()`. Insert it immediately after the existing `validation_report` step, inside the same `if (run_intake)` branch, named `coverage_report`, with args `--config <effective_config_path> --intake-dir <intake_dir> --output <reports_dir>/Coverage_Reconciliation_Report.html`.
- [ ] TASK-06-06: Track the SDB fixture. Add `!engagements/*/intake/validation_warnings.csv` and `!engagements/*/intake/coverage_metrics.json` to the `.gitignore` allow-list next to the existing `!engagements/*/intake/normalized_loanbook.csv` line, so the reconciliation numbers become a durable regression fixture. Keep the HTML itself ignored (it carries a generated timestamp) by leaving `engagements/*/reports/` ignored.
- [ ] TASK-06-07: Add `tests/testthat/test_coverage_report.R` asserting the arithmetic identities below against the SDB fixture.
- [ ] TASK-06-08: Document the new artifact in `README.md`'s "Running a client engagement" section and in `docs/outputs_layer.md`.

**File Changes**
- `scripts/generate_coverage_report.R` (create).
- `scripts/run_engagement.R` (modify): one new step in `build_step_list()`. Leave every other step, the intake-resolution logic, the guard rail, and the manifest-writing block unchanged.
- `.gitignore` (modify): two new negation lines in the per-engagement intake block.
- `tests/testthat/test_coverage_report.R` (create).
- `README.md`, `docs/outputs_layer.md` (modify): document the new artifact.
- `engagements/sdb-rehearsal/intake/validation_warnings.csv`, `engagements/sdb-rehearsal/intake/coverage_metrics.json` (create, generated — never hand-edited).

**Function Signatures**
- `build_reconciliation(raw_path: character, normalized_path: character, errors_path: character, warnings_path: character) -> list` — returns `list(rows = tbl, totals = list(submitted_rows, submitted_vnd, normalized_rows, normalized_vnd, dropped_rows, dropped_vnd, warned_rows, warned_vnd))`, where `rows` has one row per outcome category with columns `category`, `n_rows`, `exposure_vnd`, `pct_of_submitted_vnd`.
- `build_abcd_coverage(normalized: data.frame, abcd_path: character) -> list` — returns `list(by_sector = tbl, covered_vnd = numeric, coverage_pct = numeric, unmatched = tbl)`, where `by_sector` has columns `sector`, `exposure_vnd`, `covered_vnd`, `coverage_pct`, and `unmatched` has columns `name_direct_loantaker`, `exposure_vnd`.
- `write_coverage_metrics(reconciliation: list, coverage: list, path: character) -> NULL` — writes the JSON sidecar via `jsonlite::write_json(..., auto_unbox = TRUE, pretty = TRUE)`; called for side effect.

**Test Specs**
- Arithmetic identity, rows: `submitted_rows == normalized_rows + dropped_rows`. Warned rows are a subset of normalized rows and must **not** appear in this sum.
- Arithmetic identity, money: `abs(submitted_vnd - (normalized_vnd + dropped_vnd)) < 1` (VND, allowing floating-point slack). Rows whose exposure is `NA` because of `unsupported_currency` count toward `normalized_rows` but contribute `0` to `normalized_vnd`, and the report must state that explicitly rather than letting the identity silently fail.
- `pct_of_submitted_vnd` values sum to `100` within `0.01`.
- `build_abcd_coverage()` on a fixture where two of three counterparties match ABCD, with exposures `c(1e12, 2e12, 3e12)` and the unmatched one at `2e12` → `covered_vnd == 4e12`, `coverage_pct == 66.67` (tolerance `0.01`), `nrow(unmatched) == 1`.
- `build_abcd_coverage()` with an empty normalized loanbook → `covered_vnd == 0`, `coverage_pct == 0` (not `NaN`), `nrow(unmatched) == 0`.
- Vietnamese-name matching: a normalized loanbook counterparty `"Nhiet Dien Vinh Tan 1 JSC"` and an ABCD company `"Nhiệt Điện Vĩnh Tân 1 JSC"` → counted as covered, because both are compared after `normalize_vn_name()`.
- Running `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json` → exit `0`, and `engagements/sdb-rehearsal/reports/Coverage_Reconciliation_Report.html` and `engagements/sdb-rehearsal/intake/coverage_metrics.json` both exist.
- `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --dry-run` → the printed step list contains a line beginning `coverage_report:` positioned immediately after the `validation_report:` line.

**Dependencies**
- PHASE-05 (the report consumes `validation_warnings.csv`, which PHASE-05 creates).
- PHASE-02's `R/format_money.R` for all money rendering.

**Exit Criteria**
- [ ] `Rscript -e "testthat::test_file('tests/testthat/test_coverage_report.R')"` passes with zero failures.
- [ ] The SDB engagement produces `Coverage_Reconciliation_Report.html` and `coverage_metrics.json`, and the JSON's row and money identities hold.
- [ ] `engagements/sdb-rehearsal/intake/coverage_metrics.json` and `validation_warnings.csv` are tracked: `git ls-files engagements/sdb-rehearsal/intake/` lists all three files.
- [ ] `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --dry-run` still succeeds and does **not** include a `coverage_report` step, because `mcb-demo` does not configure a raw loanbook and therefore does not run intake.
- [ ] Full R suite `FAIL 0`; full Python suite `58 passed`.
- [ ] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS` — this phase must not perturb the MCB public snapshot at all.

**Phase Risks**
- **RISK-06-01:** Adding a step to `run_engagement.R` changes the step list, and `tests/testthat/test_step_runner.R` line 167 asserts `expect_equal(delegated_steps, direct_steps)` — that `scripts/pipeline_refresh.R`'s delegated step list matches a direct `run_engagement.R` invocation. Mitigation: the new step sits inside the `if (run_intake)` branch and `mcb-demo` configures no raw loanbook, so neither list changes and that assertion still holds. Re-read the whole file before editing and update any assertion that does move, in the same commit. MCB's `pipeline_manifest.json` is likewise unaffected, which is what the byte-identity exit criterion confirms.
- **RISK-06-02:** The report reads the raw submitted loanbook via `inputs$raw_loanbook_csv`, which is optional and may be unset. Mitigation: when it is unset, the reconciliation section renders "raw loanbook not configured — reconciliation unavailable" and the report still produces the ABCD-coverage section. Do not fail the step; a missing optional input is not an error.
- **RISK-06-03:** `coverage_metrics.json` is a tracked generated file, so it will show as drift on every rerun if it contains a timestamp. Mitigation: do **not** put a generated timestamp in the JSON sidecar; keep timestamps in the HTML only, which `tools/verify_refactor.R` already classifies as `timestamp-class` and ignores.

## Gotchas

- **The single most dangerous confusion in this plan:** `loan_size_outstanding` is currently in **millions of VND** for the MCB demo and in **true VND** for the Saigon Delta Bank fixture, through identical code with an identical `VND` currency label. Before changing any money code, check which engagement's data you are looking at. After PHASE-02 both are true VND and the ambiguity is gone.
- **`stress_priority_score` is not a severity.** It is `scales::rescale()` applied three times over the sector's own range, so the worst borrower in any sector is always exactly 100 regardless of how bad that borrower actually is. It is legitimate as a sort key (which is all the dashboard uses it for) and illegitimate as an input to a composite. PHASE-03 adds `stress_severity_score` for the latter and leaves the former alone.
- **Min-max is applied more than once to the same number.** `stress_priority_score` (rescale #1) feeds `normalise_01()` in `scripts/engagement_scoring.R` (rescale #2) and the min-max block in `R/prioritization_core.R` (rescale #3). Removing only one layer leaves the degeneracy intact. PHASE-03 must remove layers 2 and 3 and bypass layer 1 by reading `npv_change` directly.
- **`prioritize_sectors()` reads TRISK results from the published snapshot** (`cfg$paths$snapshot_dir/trisk/...`), not from `synthesis_output/trisk/`. It must run after the snapshot-copy step. If a scoring change appears to have no effect, the snapshot is stale — rerun `scripts/refresh_dashboard_data.R` before re-diagnosing.
- **`jsonlite` round-trip erases empty-value types.** `NULL` serializes to `{}` and `character(0)` serializes to `[]`, and **both** come back from `jsonlite::read_json(..., simplifyVector = TRUE)` as an empty `list()`. This has already caused two production bugs in this repo (`raw_loanbook_csv` and `row_count_files`). Any validation on an optional config field — including PHASE-05's `fx_rate_usd_vnd` — must gate on `length(x) == 0`, never on `is.null(x)` or `is.numeric(x)` alone. The bug appears only on the *second* generation of a config, so test the full `toJSON()` → `read_json()` round trip, not just `load_engagement_config()` on a hand-written file.
- **`.validate_engagement_config()` calls `file.exists()` on every element of `cfg$inputs`.** Adding a non-path value there without adding a skip branch produces the baffling error `input file(s) not found: 26300`.
- **Zero-padding corrupts 5-digit VSIC codes.** The existing `normalize_sector_code()` pads to 4 unconditionally. Vietnamese VSIC 2018 uses 5-digit sub-classes (`35101`), which must survive intact. Pad only when the code has fewer than 4 digits.
- **Caches must be keyed on inputs, not only on parameters.** The scenario grid learned this the hard way — it was keyed on lever values alone and silently served three-month-old results. `grid_input_fingerprint()` and `grid_cache_is_valid()` in `R/trisk_core.R` now hash the input files. Do not change `grid_contract_version` or the fingerprint inputs in this wave, or you trigger a 30-minute regeneration and a grid refreeze that is explicitly out of scope (ASM-005).
- **A test that reads a committed artifact guards the artifact, not the code.** `tests/testthat/test_sdb_engagement.R` learned this: its three fixture-content blocks are real but say nothing about whether `run_engagement.R` still produces them. The `RUN_SDB_ENGAGEMENT=1` block exists to close that, and CI sets it. Keep new golden assertions honest about which of the two they are.
- **`file.path(getwd(), x)` on an already-absolute `x` silently produces a nonexistent path** like `/repo/repo/data/x.csv`. R does not error; it fails much later with a confusing "file not found". Check whether a path is already absolute before joining it, and resolve exactly once.
- **PNG comparison is visual only.** PNG compression in this toolchain is not byte-deterministic, so `tools/verify_refactor.R` routes all `.png` files to an ignored bucket. Never treat a PNG diff as evidence of drift, and never rely on a PNG being byte-stable.
- **`synthesis_output/prioritization/interpretation_notes.md` is hand-maintained** despite living under an output directory. A pipeline rerun will not update it.
- **Percentage points versus percent.** Power and automotive alignment gaps are in **percentage points of technology market share**; cement and steel gaps are in **percent of the target emission intensity** (the `gap_pct` column). They share a numeric scale and share nothing else. This is why `## Specification` defines two separate anchor tables, and why the current code's single cross-family min-max is wrong.
- **Exposure share is a fraction in `[0, 1]`, not a percentage.** `severity_exposure(0.82)` is correct; `severity_exposure(82)` saturates to `1.0` and hides the bug.

## Verification Strategy

- **TEST-001:** `Rscript -e "testthat::test_dir('tests/testthat')"` → `[ FAIL 0 | ... ]` with `PASS` at least `290` after PHASE-04, and at least `305` after PHASE-06.
- **TEST-002:** `python -m pytest dashboard/tests` → `58 passed`. This count must not change; any change means a phase perturbed the dashboard contract, which no phase in this plan is meant to do.
- **TEST-003:** `Rscript tools/verify_refactor.R --invariants` → six `[PASS]` lines (`INV-001` through `INV-006`) followed by `INVARIANTS PASS`, exit `0`.
- **TEST-004:** `Rscript tools/verify_refactor.R` → `BYTE-IDENTITY PASS`, exit `0`. Required green at the end of PHASE-01, PHASE-04, and PHASE-06.
- **TEST-005:** Units check —
  ```sh
  Rscript -e "lb <- read.csv('data/vietnam_loanbook.csv'); stopifnot(sum(lb\$loan_size_outstanding) == 25020000000000, min(lb\$loan_size_outstanding) == 250000000000, nrow(lb) == 43); cat('UNITS OK\n')"
  ```
  → prints `UNITS OK`.
- **TEST-006:** Non-degeneracy check, the core regression guard for PHASE-03 —
  ```sh
  Rscript -e "p <- read.csv('synthesis_output/prioritization/sector_priority_ranking.csv')\$composite_score; e <- read.csv('output/engagement/engagement_priority.csv')\$composite_score; stopifnot(!any(p == 0 | p == 1), !any(e == 0 | e == 1)); cat('NO DEGENERATE SCORES\n')"
  ```
  → prints `NO DEGENERATE SCORES`.
- **TEST-007:** Ratio-invariance check for PHASE-02, run immediately after the rescale and before committing —
  ```sh
  git diff --name-only -- synthesis_output/vietnam/04_vn_ms_company.csv synthesis_output/vietnam/06_vn_ms_alignment_2030.csv synthesis_output/vietnam/06_vn_sda_alignment_2030.csv dashboard/data/trisk
  ```
  → empty output.
- **TEST-008:** Grid-untouched check —
  ```sh
  git diff --name-only -- dashboard/data/trisk/grid synthesis_output/trisk/grid
  ```
  → empty output, at the end of every phase.
- **TEST-009:** Intake widening check, after PHASE-05 —
  ```sh
  Rscript scripts/intake_validate_and_map.R --input data/fixtures/unseen_bank_loanbook.csv --output-dir /tmp/intake_check --fx-rate-usd-vnd 26300
  Rscript -e "n <- nrow(read.csv('/tmp/intake_check/normalized_loanbook.csv')); cat('rows=', n, '\n'); stopifnot(n >= 30)"
  ```
  → prints `rows=` followed by a value of at least 30 (24 before the change).
- **TEST-010:** Documentation-versus-code consistency for CI claims —
  ```sh
  grep -rn "verify_refactor" .github/ CLAUDE.md README.md
  ```
  → the `.github/` hits include both a bare `tools/verify_refactor.R` invocation and `--invariants` invocations, and neither `CLAUDE.md` nor `README.md` contains a statement contradicted by those hits.
- **MANUAL-001:** Open `docs/scoring_anchors.md` and confirm a reader with no code access could recompute MCB power's `alignment_score` of `0.60975` from `alignment_gap_raw = 14.39` using only that document. If they cannot, the document is incomplete.
- **MANUAL-002:** Open the generated `engagements/sdb-rehearsal/reports/Coverage_Reconciliation_Report.html` in a browser and confirm every money figure carries an explicit `VND` or `bn VND` unit, that the dropped-exposure section names each reason, and that the synthetic-data disclaimer is present in the footer.
- **MANUAL-003:** Run `python -m streamlit run dashboard/app.py`, then visit the TRISK Risk page and the Scenario Builder. Confirm both still render and sort correctly with `stress_severity_score` present as an additional column in `top_borrowers_alignment_trisk.csv`.
- **OBS-001:** After the first scheduled `refresh.yml` run following PHASE-01, confirm in the Actions log that the drift-classification step executed and reported `BYTE-IDENTITY PASS` before the commit step. If it reports drift on an unchanged codebase, that is a genuine nondeterminism in the pipeline and should be investigated rather than suppressed.
- **OBS-002:** Confirm the `byte-identity` CI job's wall-clock time is under 10 minutes. A sudden jump to 30-plus minutes means the scenario grid is regenerating, which indicates an unintended change to `grid_input_fingerprint()`'s inputs.

## Risks and Alternatives

- **RISK-001:** PHASE-02 and PHASE-03 both change committed numbers, and PHASE-04 commits them together. If the refreeze turns out to be wrong, both causes are entangled in one commit. Mitigation: PHASE-02 and PHASE-03 have independent, separately-verifiable exit criteria (TEST-005/TEST-007 for units, TEST-006 for scoring) that must pass before PHASE-04 begins, so entanglement is limited to the artifact commit and not to the diagnosis.
- **RISK-002:** The anchor breakpoints are a judgment call, and a bank's risk committee may disagree with them. Mitigation: they live in `docs/scoring_anchors.md` as data, not buried in code, and `R/severity_scoring.R` takes anchors as parameters so alternative tables can be supplied without touching the scoring logic. Disagreement about thresholds is a productive conversation; disagreement about whether "1.0" means anything is not.
- **RISK-003:** Widening the intake sector map admits counterparties that PACTA cannot match to ABCD, which will lower headline match-rate percentages even though more exposure is being correctly processed. Mitigation: PHASE-06's coverage report exists precisely to make this legible — a lower match rate over a larger, honest denominator is the correct number, and the report shows both.
- **RISK-004:** Rescaling the loanbook could be read as violating the repo law "VND is never rescaled". Mitigation: that law governs the **pipeline** not mangling money in transit; PHASE-02 changes what the **generator emits** and adds INV-006 to enforce that no pipeline stage rescales thereafter. If the law's author intends it to cover the generator too, drop PHASE-02's TASK-02-02 and TASK-02-03, keep everything else in the phase (the shared formatter, INV-006 recalibrated to the millions scale, and the prose corrections), and instead correct `plans/PROGRESS.md` and the pitch deck **downward** to ~USD 950 — which is the honest alternative, not a neutral one.
- **ALT-001:** *Percentile ranking against a fixed synthetic reference portfolio* was considered instead of anchored absolute bands. Rejected: a reference portfolio is one more artifact that must be kept fresh and defended, and it reintroduces the same "relative to what?" question the anchors exist to answer. Fixed anchors are auditable by a reader with a calculator.
- **ALT-002:** *Redefining `stress_priority_score` in place* rather than adding `stress_severity_score` was considered. Rejected: the dashboard uses it as a sort key in six places and the scenario-grid parquet stores it; redefining it would either force a 30-minute grid regeneration (out of scope per ASM-005) or leave the grid and the base run disagreeing — the exact defect the invariant checker was built to catch.
- **ALT-003:** *Editing all 43 loan literals to true VND* rather than multiplying once inside `make_loan()` was considered. Rejected: 43 hand edits invite a transcription error, and the existing section comments (`~7,020 bn VND`) stay accurate only under the millions reading. One named constant plus a renamed parameter documents the unit better than 43 longer numbers.
- **ALT-004:** *Adding byte-identity only to the weekly refresh, not to every push* was considered as a way to save CI minutes. Rejected: the entire point is to catch drift at the pull request, not after it has been auto-committed to the public snapshot. At roughly 3-4 minutes per run, the cost does not justify the delay in feedback.

## Suggested Next Step

Execute PHASE-05. The PHASE-04 refreeze has landed, so the intake contract
work can proceed on top of a stable, byte-identity-gated tree. PHASE-05 has
no dependency on PHASE-02 through PHASE-04 in code; its expected downstream
churn is a second, smaller refreeze scoped to `engagements/sdb-rehearsal/`
(see RISK-05-01), followed by PHASE-06's coverage report which consumes its
new `validation_warnings.csv`.
