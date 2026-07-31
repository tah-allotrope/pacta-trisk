---
title: "Real-Data Readiness & Platform Hardening"
date: "2026-07-10"
status: "complete — bulk-corrected 2026-07-31 per directive: plan predates 2026-07-20 and is presumed fully implemented (NOT individually verified against git/code evidence)"
request: "Turn research/2026-07-10-real-data-readiness-and-hardening-brainstorm.md into a multi-phase implementation plan"
plan_type: "multi-phase"
research_inputs:
  - "research/2026-07-10-real-data-readiness-and-hardening-brainstorm.md"
  - "research/2026-07-04_bank-pilot-conversion-push-brainstorm.md"
---

# Plan: Real-Data Readiness & Platform Hardening

## Objective

Close the gap between what the pilot conversion pack (`pilot/`) promises to prospective Vietnamese banks and what the repo can demonstrably deliver: verify the never-executed refresh automation, put the snapshot and repo on a diet, add reproducibility rails (R lockfile + first R tests + Python CI), rehearse the real-data intake path end-to-end with a dirty synthetic fixture, and ship the private-instance and validation-report capabilities that the real-data phase proposal already commits to.

## Context Snapshot

- **Current state:** Demo-complete PACTA+TRISK platform for a synthetic Vietnamese bank ("Mekong Commercial Bank"). R pipeline (`scripts/*.R`) → snapshot (`dashboard/data/`) → public Streamlit app (7 pages, 3 env-gated). Commit `e14cd84` (2026-07-04) added the pilot sales pack, self-explore tour, anonymous analytics module, `scripts/pipeline_refresh.R` orchestrator, and `.github/workflows/refresh.yml` — but the orchestrator and workflow have **never been executed**, `dashboard/data/pipeline_manifest.json` does not exist (the "Data as of" badge renders "unknown"), and the analytics module is a no-op (no endpoint configured). `dashboard/data/` is ~108 MB, ~100 MB of which is 2,931 per-run grid CSVs the app never reads. There are zero R tests, no `renv.lock`, no root `README.md`, no test CI. The intake layer emits operator CSVs but no client-grade validation report; no private-instance deployment path or anonymization option exists despite both being promised in `pilot/real_data_phase_proposal.md`.
- **Desired state:** Refresh pipeline proven green locally and in GitHub Actions with a committed manifest and a live freshness badge; snapshot < 15 MB; root README + proprietary notice; `renv.lock` pinning R deps; golden-number `testthat` suite gating the auto-commit CI; `pytest` CI on push; a rehearsed intake → validation-report → normalized-loanbook flow on a deliberately dirty "unseen bank" fixture, with timings logged against the proposal's milestone table; an `--anonymize` intake option; a password-gate module + documented private-instance deploy recipe; a per-refresh audit report.
- **Key repo surfaces:** `scripts/pipeline_refresh.R`, `scripts/refresh_dashboard_data.R`, `scripts/trisk_sector_demo.R`, `scripts/intake_validate_and_map.R`, `.github/workflows/refresh.yml`, `scripts/ci/install_deps.R`, `dashboard/lib/` (`branding.py`, `analytics.py`, `loaders.py`), `dashboard/pages/2_TRISK_Risk.py`, `dashboard/data/` snapshot, `intake/SCHEMA.md`, `pilot/`, `plans/` status frontmatter.
- **Out of scope:** Real bank data ingestion (rehearsal uses synthetic fixtures only); methodology upgrades (automotive TRISK, borrower-level SDA for cement/steel, Dung Quat LNG zero-baseline fix, power 2025-NA backfill — deferred to a follow-on plan); git history rewrite / LFS migration; multi-tenant SaaS or real auth providers; dashboard Vietnamese i18n; `targets` pipeline migration; pricing content.

## Environment & Conventions

- **Stack:** R 4.5.2 (Windows local) driving the analytics pipeline via `Rscript`; Python 3.11+ with Streamlit 1.41+, pandas 2.2, plotly 5, pyarrow, openpyxl, pytest for the dashboard (`dashboard/requirements.txt`); GitHub Actions (ubuntu-latest, R set up via `r-lib/actions/setup-r@v2`, currently `r-version: "4.4"`).
- **Setup (Python):** `python -m pip install -r dashboard/requirements.txt`
- **Setup (R, local Windows):** packages already installed in the user library `C:\Users\tukum\AppData\Local\R\win-library\4.5`. Fresh machines: `Rscript scripts/ci/install_deps.R` (until PHASE-03 replaces this with `renv::restore()`).
- **Run pipeline (local Windows PowerShell):** `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/pipeline_refresh.R` — always run from the repo root; every R script resolves paths via `getwd()`.
- **Run app:** `python -m streamlit run dashboard/app.py --server.headless true` (from repo root).
- **Test (Python):** `python -m pytest dashboard/tests` — single test: `python -m pytest dashboard/tests/test_loaders.py::test_name -v`. Current baseline: 48+ passed (one known transient TRISK timeout flake under load; passes on re-run).
- **Test (R, created in PHASE-03):** `Rscript -e "testthat::test_dir('tests/testthat')"`
- **Conventions & traps:** All monetary values in the loanbook are VND (column `loan_size_outstanding`, currency column literal `VND`). Vietnamese names carry diacritics; matching normalizes via `stringi` ASCII transliteration. Intake CSVs read as UTF-8 with latin1 fallback. Dashboard data access goes exclusively through `dashboard/lib/loaders.py` functions wrapped in `@st.cache_data`. Env flags gate operator features: `BYOL_INTAKE=1` (page 6), `OUTPUTS_LAYER=1` (page 7), `TRISK_LIVE_RERUN=1` (page 5 live rerun; never set on Streamlit Cloud — no R runtime there), `R_RSCRIPT` (path to Rscript for the Python wrappers), `PILOT_ANALYTICS_ENDPOINT` (analytics ping URL).
- **Repo map:**
  - `scripts/` — all R pipeline stages + `pipeline_refresh.R` orchestrator + `ci/install_deps.R`
  - `data/` — synthetic inputs (`vietnam_loanbook.csv`, `vietnam_abcd.csv`, scenarios) + generator
  - `synthesis_output/` — pipeline outputs (PACTA `vietnam/`, TRISK `trisk/<sector>_demo/`, grid `trisk/grid/<sector>/`)
  - `dashboard/` — Streamlit app (`app.py`, `pages/`, `lib/`, `tests/`, frozen snapshot `data/`)
  - `intake/` — BYOL schema contract (`SCHEMA.md`), templates, output dir
  - `pilot/` — bank-agnostic conversion pack with `{{BANK_NAME}}` slots
  - `docs/`, `plans/`, `reports/`, `research/` — documentation, plan artifacts, rendered reports, briefs

## Research Inputs

- From `research/2026-07-10-real-data-readiness-and-hardening-brainstorm.md`:
  - Commit `e14cd84` shipped the pipeline orchestrator and weekly CI refresh **without ever running them**; `pipeline_manifest.json` is absent so the public app's freshness badge displays "Data as of: unknown" — an anti-credibility signal on a pilot app.
  - `dashboard/data/` is ~108 MB; ~100 MB is 2,931 per-run grid CSVs under `dashboard/data/trisk/grid/*/runs/` that the app provably never reads (it reads only `borrower_results.parquet`, `scenarios.csv`, `grid_meta.json` per sector).
  - The weekly CI auto-commits regenerated data to `main` (auto-deploying the public app) with **no tests gating it** — zero R tests exist and the Python suite never runs in CI; combined with no `renv.lock`, a CRAN release can silently change published numbers.
  - `pilot/real_data_phase_proposal.md` promises: a validation report returned to the bank, a private access-controlled dashboard instance, and an `{{ANONYMIZATION_APPROACH}}` — none implemented; a full dress rehearsal with an "unseen bank" dirty fixture is the highest-value single exercise.
  - `refresh_dashboard_data.R` logs `[MISS]` and continues on missing files — a partial upstream failure can silently publish a half-populated snapshot via the auto-committing CI.
  - Known golden numbers for regression tests: `output/engagement/engagement_priority.csv` has exactly 23 borrowers; top borrower "Nghi Son Power LLC" with composite_score 1.000, then "Vinacomin Power JSC" 0.998, "International Power Mong Duong" 0.996.
- From `research/2026-07-04_bank-pilot-conversion-push-brainstorm.md`:
  - DEC: hosting stays fully public on Streamlit Community Cloud for the *synthetic* pilot (no auth); real data enters only in the paid next phase — so the password gate built here activates only when `DEMO_PASSWORD` is configured on a private instance.
  - DEC: analytics must be anonymous and PII-free (already honored by `dashboard/lib/analytics.py`).
  - CON: R package restore in GitHub Actions is slow; CI needs aggressive caching keyed on a lockfile.

## Assumptions and Constraints

- **ASM-001:** Local Rscript path is `C:\Program Files\R\R-4.5.2\bin\Rscript.exe` and the working directory for every R invocation is the repo root — **BINDING DEFAULT:** use that path in PowerShell; on Linux/CI use plain `Rscript`.
- **ASM-002:** No GoatCounter (or similar) account exists yet — **BINDING DEFAULT:** do not block on external account creation; document the setup in `docs/streamlit-deploy.md` (register site code `pacta-trisk`, set `PILOT_ANALYTICS_ENDPOINT=https://pacta-trisk.goatcounter.com/count` in Streamlit Cloud secrets) and leave the env var unset in the repo.
- **ASM-003:** Git history is NOT rewritten (large blobs stay in history) — **BINDING DEFAULT:** run `git gc` once and stop tracking new bulk artifacts; LFS migration is out of scope.
- **ASM-004:** Licensing — **BINDING DEFAULT:** proprietary; create a `NOTICE.md` stating "© Allotrope VC. All rights reserved. Not licensed for redistribution." Do not add an OSS LICENSE. Upstream R packages (r2dii.*, trisk.model) keep their own licenses and are unaffected.
- **ASM-005:** Which stale plan frontmatter to flip to `completed` — **BINDING DEFAULT:** `plans/2026-07-04-bank-pilot-conversion-push-plan.md`, `plans/2026-05-02-interactive-scenario-builder-plan.md`, `plans/2026-05-19-byol-pilot-intake-plan.md`, `plans/2026-05-22-bidv-sector-prioritization-plan.md`, `plans/2026-04-25-pacta-trisk-bank-showcase-dashboard-plan.md` (all verified implemented in git history).
- **ASM-006:** Python linting — **BINDING DEFAULT:** CI runs pytest only; do not introduce ruff/formatters in this plan (avoids a churny reformat commit on a demo-stable codebase).
- **ASM-007:** The dress rehearsal's downstream stages (PACTA/TRISK on the fixture loanbook) — **BINDING DEFAULT:** run them in a disposable copy of the repo (plain `git clone` of the local repo into a temp directory, swap the loanbook file, run, record observations, delete). Do NOT parameterize `scripts/pacta_vietnam_scenario.R` with input/output arguments in this plan; that refactor is deferred.
- **ASM-008:** Grid snapshot contents — **BINDING DEFAULT:** `dashboard/data/trisk/grid/<sector>/` keeps exactly three files: `scenarios.csv`, `borrower_results.parquet`, `grid_meta.json`. Raw per-run CSVs remain only under `synthesis_output/trisk/grid/<sector>/runs/` and become gitignored.
- **ASM-009:** CI R version — **BINDING DEFAULT:** bump `.github/workflows/refresh.yml` to `r-version: "4.5"` to match the local 4.5.2 and the renv lockfile built from it.
- **ASM-010:** `gh` CLI is installed and authenticated against the `origin` GitHub repo for workflow dispatch — **BINDING DEFAULT:** if `gh` is unavailable, trigger the workflow from the GitHub UI (Actions → "Refresh pipeline data" → Run workflow) and treat the UI result as equivalent.
- **CON-001:** Everything bank-visible must keep synthetic/illustrative-data disclaimers intact; do not remove any existing disclaimer copy.
- **CON-002:** Streamlit Community Cloud has no R runtime; nothing in `dashboard/` may require R at render time unless env-gated off by default.
- **CON-003:** The weekly refresh workflow auto-commits to `main`; any test added to it must run BEFORE the commit step so a red run never publishes.
- **DEC-001:** The pilot app stays public and auth-free; the password gate ships dormant (activates only via `DEMO_PASSWORD` secret on a private instance).
- **DEC-002:** Analytics remains anonymous/PII-free; payload stays page-slug-only.

## Phase Summary

| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Activate & verify refresh automation; fail-loud snapshot; live freshness badge | None | Green local + CI pipeline runs, committed `pipeline_manifest.json`, hardened `refresh_dashboard_data.R` |
| PHASE-02 | Snapshot & repo diet; root front door; housekeeping | PHASE-01 | `dashboard/data/` < 15 MB, bounded ZIP export, root `README.md` + `NOTICE.md`, dead code removed, plan statuses fixed |
| PHASE-03 | Reproducibility rails: renv lockfile, first R tests, Python CI, full-rebuild orchestrator | PHASE-01 (PHASE-02 recommended first) | `renv.lock`, `tests/testthat/` suite, `.github/workflows/ci.yml`, tests gating refresh auto-commit, `--full` orchestrator mode |
| PHASE-04 | Real-data dress rehearsal: dirty fixture, client-grade validation report, anonymization option | PHASE-03 | `data/fixtures/unseen_bank_loanbook.csv`, `scripts/generate_validation_report.R`, `--anonymize` intake flag, `pilot/rehearsal_log.md` |
| PHASE-05 | Private-instance delivery + per-refresh audit artifact | PHASE-04 | `dashboard/lib/auth.py` password gate, `docs/private-instance-deploy.md`, `scripts/generate_refresh_audit.R` wired into the refresh pipeline |

## Detailed Phases

### PHASE-01 - Activate & Verify Refresh Automation

**Goal**
Prove the July-4 automation actually works: run `pipeline_refresh.R` locally to green, make the snapshot copy fail loudly on missing files, commit a real manifest so the public app's freshness badge shows a date, then get the GitHub Actions workflow to a green run.

**Tasks**
- [ ] TASK-01-01: Remove the fragile library-load hack in `scripts/trisk_sector_demo.R` (lines ~22-23): replace `lib <- Sys.getenv("R_LIBS_USER")` + `library(trisk.model, lib.loc = lib)` with a plain `library(trisk.model)` (the user library is already on `.libPaths()` on Windows; on CI the package installs into the default library).
- [ ] TASK-01-02: Harden `scripts/refresh_dashboard_data.R`: collect every `[MISS]` into a character vector while still attempting all copies; after the manifest write, if any misses were for *required* artifacts, print the full list and `quit(status = 1)`. Required = all entries in `pacta_files`, all `trisk_sector_files` for each manifest sector, ≥ 1 PNG from `synthesis_output/vietnam`, ≥ 1 PNG per `synthesis_output/trisk/<sector>_demo/figures`, and the three grid files per sector. `report_files` are optional (warn only).
- [ ] TASK-01-03: Run the full pipeline locally from the repo root: `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/pipeline_refresh.R`. Fix any failures until the manifest reports `"status": "ok"` for all 7 steps. Expect a long run (the 243-scenario grid step dominates; the grid script has cache-skip behavior, so an unchanged grid is fast).
- [ ] TASK-01-04: Commit the resulting `dashboard/data/pipeline_manifest.json` (plus any refreshed snapshot deltas) so the badge works immediately, before CI ever runs.
- [ ] TASK-01-05: Verify the badge locally: run the app and confirm the caption on the landing page reads `Data as of: <ISO timestamp> (pipeline <7-char sha>)` instead of the "unknown" fallback.
- [ ] TASK-01-06: Bump `.github/workflows/refresh.yml` `r-version` from `"4.4"` to `"4.5"` (ASM-009). Trigger a run: `gh workflow run "Refresh pipeline data"` then `gh run watch` (or GitHub UI per ASM-010). Iterate on CI-only failures (likely: system deps, package install time-outs) until green. Keep the weekly cron.
- [ ] TASK-01-07: Document analytics activation (ASM-002): add a short "Enabling pilot analytics" subsection to `docs/streamlit-deploy.md` with the GoatCounter registration steps and the exact secret name `PILOT_ANALYTICS_ENDPOINT`. No code change — `dashboard/lib/analytics.py` already honors it.

**File Changes**
- `scripts/trisk_sector_demo.R` (modify): replace the two-line `R_LIBS_USER` load with `library(trisk.model)`; leave everything else (sector metadata, run logic) untouched.
- `scripts/refresh_dashboard_data.R` (modify): thread a `misses <- character(0)` accumulator through `copy_file` / `copy_png_group` / grid copy; add a `required` flag distinguishing `report_files`; fail with exit 1 listing missing required artifacts at the end. Leave the copy order and manifest tribble untouched.
- `.github/workflows/refresh.yml` (modify): `r-version: "4.5"`. Leave triggers, cache, commit step untouched (PHASE-03 edits the commit gating).
- `docs/streamlit-deploy.md` (modify): append the analytics-activation subsection.
- `dashboard/data/pipeline_manifest.json` (create, generated): produced by TASK-01-03, committed.

**Function Signatures**
- `copy_file(src: character, dest_dir: character, required: logical = TRUE) -> invisible(logical)` — copies one file; returns TRUE on success, records `src` in the module-level `misses` vector on failure (R script-level state, `<<-`).

**Test Specs**
- Delete (temporarily rename) `synthesis_output/trisk/power_demo/company_summary.csv`, run `Rscript scripts/refresh_dashboard_data.R` → exits non-zero and stderr/stdout lists that exact path under a "MISSING REQUIRED" header. Restore the file.
- Rename one entry of `report_files` → script completes with exit 0 and a `[MISS]` warning only.
- `Rscript scripts/pipeline_refresh.R` on a clean tree → `dashboard/data/pipeline_manifest.json` exists, `jq .status` = `"ok"`, `jq '.steps | length'` = `7`.

**Dependencies**
- Local R 4.5.2 with all pipeline packages installed (already true per repo docs); `gh` CLI or GitHub UI access (ASM-010).

**Exit Criteria**
- [ ] `Rscript scripts/pipeline_refresh.R` exits 0 locally; manifest status `ok`.
- [ ] Landing page badge shows a real timestamp (no "unknown").
- [ ] One green "Refresh pipeline data" run visible in GitHub Actions.
- [ ] Missing-required-file simulation exits non-zero.

**Phase Risks**
- **RISK-01-01:** CRAN install of the full stack (arrow, trisk.model, r2dii.*) on CI may exceed reasonable run time on a cache miss. Mitigation: the existing `actions/cache` restore-key keeps partial hits; PHASE-03's renv lockfile stabilizes the key. If a first run times out, re-run — the cache persists across failed runs.
- **RISK-01-02:** A local full refresh may regenerate numerically identical CSVs with reordered rows, producing a noisy diff. Mitigation: commit whatever the verified pipeline produces — that IS the new baseline; note it in the commit message.

### PHASE-02 - Snapshot & Repo Diet, Front Door, Housekeeping

**Goal**
Cut `dashboard/data/` from ~108 MB to < 15 MB by dropping never-read grid run CSVs, bound the ZIP export, add the missing root README and proprietary notice, and clear the small hygiene debts (dead code, stale plan statuses, committed scratch script).

**Tasks**
- [ ] TASK-02-01: Change the grid copy in `scripts/refresh_dashboard_data.R` (currently `copy_dir_contents(grid_src_root, grid_dest_root)`): copy only `scenarios.csv`, `borrower_results.parquet`, `grid_meta.json` per sector (ASM-008). The `grid_available` check already tests exactly these three files — leave it.
- [ ] TASK-02-02: Untrack the dead weight: `git rm -r --cached dashboard/data/trisk/grid/power/runs dashboard/data/trisk/grid/cement/runs dashboard/data/trisk/grid/steel/runs` (then delete the directories from disk), and add to `.gitignore`: `dashboard/data/trisk/grid/*/runs/` and `synthesis_output/trisk/grid/*/runs/`. Also `git rm -r --cached synthesis_output/trisk/grid/*/runs` if tracked. CRITICAL: because `.github/workflows/refresh.yml` runs `git add dashboard/data synthesis_output`, the ignore entries are what prevents CI from re-adding ~2,900 files next Monday.
- [ ] TASK-02-03: Bound the full-ZIP export in `dashboard/pages/2_TRISK_Risk.py`: rewrite `_build_full_zip()` to iterate the manifest's sector folders only (`TRISK_DIR / sector` for each sector in the loaded manifest, files only, non-recursive — mirroring `_build_sector_zip`) plus `TRISK_DIR / "manifest.csv"`, instead of `TRISK_DIR.rglob("*")` (which currently walks the entire grid tree).
- [ ] TASK-02-04: Create root `README.md`: what the platform is (PACTA alignment + TRISK stress testing for Vietnamese bank loanbooks, synthetic MCB showcase), an ASCII pipeline diagram (`data/generate_vietnam_data.R → scripts/pacta_vietnam_scenario.R → scripts/trisk_* → scripts/refresh_dashboard_data.R → dashboard/ → scripts/generate_* outputs`), synthetic-data posture, quick start (install deps, run pipeline, run app, run tests — exact commands from Environment & Conventions), directory map, links to `pilot/README.md`, `docs/`, `dashboard/README.md`, and the live app URL `https://pactavn.streamlit.app`.
- [ ] TASK-02-05: Create `NOTICE.md` per ASM-004.
- [ ] TASK-02-06: Housekeeping: delete `scripts/debug_ms.R`; in `dashboard/lib/charts.py` remove the unused `pd_change_heatmap` function and rename the `ALLotrope_COLORS` constant to `ALLOTROPE_COLORS` (update its references in the same file); in `dashboard/lib/loaders.py` remove the unused `image_catalog()` function (grep `image_catalog` across `dashboard/` first to confirm zero call sites).
- [ ] TASK-02-07: Flip `status:` frontmatter to `completed` in the five plan files listed in ASM-005 (edit only the `status:` line).
- [ ] TASK-02-08: Run `git gc` once (ASM-003).

**File Changes**
- `scripts/refresh_dashboard_data.R` (modify): grid copy narrowed to the three-file list; everything else untouched.
- `.gitignore` (modify): add the two `grid/*/runs/` patterns.
- `dashboard/pages/2_TRISK_Risk.py` (modify): `_build_full_zip` body only; keep both download buttons and `_build_sector_zip` as-is.
- `README.md` (create): root front door as specified in TASK-02-04.
- `NOTICE.md` (create): proprietary notice.
- `scripts/debug_ms.R` (delete).
- `dashboard/lib/charts.py` (modify): remove `pd_change_heatmap`, fix constant name.
- `dashboard/lib/loaders.py` (modify): remove `image_catalog()` if unreferenced.
- `plans/2026-07-04-bank-pilot-conversion-push-plan.md`, `plans/2026-05-02-interactive-scenario-builder-plan.md`, `plans/2026-05-19-byol-pilot-intake-plan.md`, `plans/2026-05-22-bidv-sector-prioritization-plan.md`, `plans/2026-04-25-pacta-trisk-bank-showcase-dashboard-plan.md` (modify): `status:` line only.

**Function Signatures**
- `_build_full_zip() -> bytes` — unchanged signature; now returns a ZIP containing only per-sector flat result files + `manifest.csv` (no `grid/` subtree).

**Test Specs**
- After TASK-02-01/02 and a re-run of `Rscript scripts/refresh_dashboard_data.R`: `dashboard/data/trisk/grid/power/` contains exactly 3 files; total `dashboard/data/` size < 15 MB (PowerShell: `"{0:N1} MB" -f ((Get-ChildItem dashboard/data -Recurse -File | Measure-Object Length -Sum).Sum / 1MB)`).
- `python -m pytest dashboard/tests` → all pass (loaders/grid tests read the parquet + scenarios.csv, which survive the diet).
- Unzip the full-snapshot download (drive via the app or call `_build_full_zip()` in a REPL) → archive lists no path starting with `grid/`.
- `git status` after TASK-02-02 → no `runs/` paths appear as untracked.

**Dependencies**
- PHASE-01 (a verified refresh run must exist so re-running the narrowed copy is trusted).

**Exit Criteria**
- [ ] `dashboard/data/` < 15 MB; app boots and all 5 public pages render.
- [ ] Root `README.md` and `NOTICE.md` exist.
- [ ] `python -m pytest dashboard/tests` green.
- [ ] Five plan files show `status: "completed"`.

**Phase Risks**
- **RISK-02-01:** Something undiscovered reads the run CSVs from the snapshot. Mitigation: `grep -rn "runs" dashboard/ --include="*.py"` before deletion; the exploration finding (app reads only parquet/scenarios/meta) is verified but re-confirm at execution time.

### PHASE-03 - Reproducibility Rails: renv, First R Tests, Python CI, Full Rebuild

**Goal**
Pin the R environment with a lockfile, add the first R regression tests (golden numbers + snapshot contract), run the Python suite in CI on every push, gate the weekly auto-commit refresh behind those tests, and extend the orchestrator so one command can rebuild the world.

**Tasks**
- [ ] TASK-03-01: Initialize renv from the repo root: `Rscript -e "install.packages('renv', repos='https://cloud.r-project.org'); renv::init(bare = TRUE)"`, then `Rscript -e "renv::install(readLines('scripts/ci/deps.txt'))"` is unnecessary — instead snapshot the already-working library: `Rscript -e "renv::snapshot(type = 'explicit')"` will need a DESCRIPTION; simplest robust route: `Rscript -e "renv::snapshot(packages = c('arrow','base64enc','dplyr','fs','ggplot2','ggrepel','jsonlite','pacta.loanbook','purrr','r2dii.analysis','r2dii.data','r2dii.match','r2dii.plot','readr','rlang','scales','stringi','tibble','tidyr','trisk.model','xfun','jsonlite','testthat'))"`. Commit `renv.lock`, `renv/activate.R`, `renv/settings.json`, `.Rprofile`. Verify `Rscript -e "renv::status()"` reports consistent.
- [ ] TASK-03-02: Update `.github/workflows/refresh.yml`: replace the `Install R dependencies` step (`Rscript scripts/ci/install_deps.R`) with `r-lib/actions/setup-renv@v2` (which restores from `renv.lock` with its own caching); change the cache key line to `hashFiles('renv.lock')` or drop the manual cache block in favor of setup-renv's. Keep `scripts/ci/install_deps.R` as a documented no-renv fallback.
- [ ] TASK-03-03: Create the R test suite under `tests/testthat/` (root level), runnable via `Rscript -e "testthat::test_dir('tests/testthat')"`:
  - `test_snapshot_contract.R` — for each sector in `dashboard/data/trisk/manifest.csv`: all 14 filenames from the `trisk_sector_files` list in `scripts/refresh_dashboard_data.R` exist in `dashboard/data/trisk/<sector>/`; the three grid files exist; `manifest.csv` has exactly 3 rows and `grid_available` is TRUE for all.
  - `test_golden_numbers.R` — `output/engagement/engagement_priority.csv` has exactly 23 rows; row 1 `company_name == "Nghi Son Power LLC"` with `composite_score` within 1e-6 of 1.0; rows 2-3 are `"Vinacomin Power JSC"` (0.998 ± 0.005) and `"International Power Mong Duong"` (0.996 ± 0.005); `dashboard/data/trisk/power/top_borrowers_alignment_trisk.csv` row 1 company is `"Nghi Son Power LLC"`.
  - `test_manifest_json.R` — `dashboard/data/pipeline_manifest.json` parses, `status == "ok"`, 7 steps, all `"ok"`.
  - At authoring time, open the committed CSVs and adjust any literal above that differs from the actual current values (the values cited come from the last verified run; the committed file is the source of truth). Freeze the verified literals into the tests.
- [ ] TASK-03-04: Create `.github/workflows/ci.yml`: on `push` and `pull_request`; job `python-tests`: ubuntu-latest, `actions/setup-python@v5` (python-version "3.12"), `pip install -r dashboard/requirements.txt`, `python -m pytest dashboard/tests`. Job `r-tests`: ubuntu-latest, setup-r 4.5 + setup-renv, `Rscript -e "testthat::test_dir('tests/testthat')"` (these tests only read committed files — no pipeline execution, so the job is fast once the renv cache is warm).
- [ ] TASK-03-05: Gate the refresh auto-commit (CON-003): in `.github/workflows/refresh.yml`, insert between "Run pipeline refresh" and "Commit refreshed snapshot": `- name: Regression-test refreshed outputs` / `run: Rscript -e "testthat::test_dir('tests/testthat')"`. A golden-number failure now blocks publication.
- [ ] TASK-03-06: Extend `scripts/pipeline_refresh.R` with a `--full` flag (parse via `commandArgs(trailingOnly = TRUE)`): when present, prepend steps `generate_vietnam_data` (`data/generate_vietnam_data.R`) and `pacta_vietnam_scenario` (`scripts/pacta_vietnam_scenario.R`) before the TRISK chain, and append `engagement_scoring` (`scripts/engagement_scoring.R`) AFTER `refresh_dashboard_data` (it reads `dashboard/data/trisk/<sector>/top_borrowers_alignment_trisk.csv`, so it must follow the snapshot copy). Default (no flag) behavior stays byte-identical to today. Update the header comment usage block.

**File Changes**
- `renv.lock`, `renv/activate.R`, `renv/settings.json`, `.Rprofile` (create): via renv init/snapshot.
- `.github/workflows/refresh.yml` (modify): setup-renv dependency step, test gate before commit step.
- `.github/workflows/ci.yml` (create): python-tests + r-tests jobs as specified.
- `tests/testthat/test_snapshot_contract.R`, `tests/testthat/test_golden_numbers.R`, `tests/testthat/test_manifest_json.R` (create).
- `scripts/pipeline_refresh.R` (modify): `--full` flag; existing step list and manifest writing untouched otherwise.

**Function Signatures**
- `None — no code interfaces change in this phase.` (Test files and workflow YAML only; the orchestrator flag is CLI-level.)

**Test Specs**
- `Rscript -e "testthat::test_dir('tests/testthat')"` on the committed tree → all pass, 0 failures.
- Corrupt one golden value (edit `output/engagement/engagement_priority.csv` row 1 composite_score to 0.5 in a scratch branch) → suite fails naming `test_golden_numbers`.
- `Rscript scripts/pipeline_refresh.R` (no flag) → exactly 7 steps in the manifest (unchanged). With `--full` → 10 steps, order: generate_vietnam_data, pacta_vietnam_scenario, trisk_prepare_inputs, trisk_power_demo, trisk_sector_demo_cement, trisk_sector_demo_steel, trisk_scenario_grid, sector_prioritization, refresh_dashboard_data, engagement_scoring.
- Push a branch → both `ci.yml` jobs green in Actions.

**Dependencies**
- PHASE-01 (manifest must exist for `test_manifest_json.R`); PHASE-02 recommended first (contract test expects the 3-file grid layout).

**Exit Criteria**
- [ ] `renv.lock` committed; `renv::status()` consistent locally.
- [ ] R suite green locally and in CI; Python suite green in CI.
- [ ] Refresh workflow shows the test step between pipeline run and commit.
- [ ] `--full` run completes locally end-to-end (allow 1-2 hours).

**Phase Risks**
- **RISK-03-01:** renv restore on CI compiles arrow/trisk.model from source and blows up run time. Mitigation: setup-renv uses the Posit Package Manager binary repo on Ubuntu by default via the RSPM env; if slow, add `RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.posit.co/cran/__linux__/jammy/latest`.
- **RISK-03-02:** Golden numbers drift legitimately when PHASE-01 recommitted a fresh baseline. Mitigation: TASK-03-03 explicitly reads literals from the committed CSVs at authoring time, not from this plan.

### PHASE-04 - Real-Data Dress Rehearsal: Dirty Fixture, Validation Report, Anonymization

**Goal**
Rehearse the promised real-data intake path end-to-end with a deliberately dirty "unseen bank" fixture, turn the intake outputs into a client-grade HTML validation report, add the anonymization option the proposal references, and log stage timings against the proposal's milestone table.

**Tasks**
- [ ] TASK-04-01: Create `data/fixtures/unseen_bank_loanbook.csv` — 40 rows for the fictional "Saigon Delta Bank (SDB)", columns per `intake/SCHEMA.md` (`counterparty_name`, `exposure_vnd`, `sector_code`, `sector_code_system`, `credit_limit_vnd`, plus optional `lei`, `tax_id`, `parent_name`, `parent_id`, `currency`). Deliberate dirt: 2 rows with empty `credit_limit_vnd`; 3 rows with invalid VSIC codes (e.g. `Z9999`, `D35X1`, empty); 2 rows with `currency = "USD"`; 3 counterparty names absent from `data/vietnam_abcd.csv` (unmatchable); 1 exact duplicate row; 1 negative `exposure_vnd`. The remaining ~28 clean rows reuse ABCD company names (EVN subsidiaries, VinFast, THACO, VICEM, Hoa Phat, Vinacomin) with plausible VND exposures (1e11–5e12 range) so matching demonstrably succeeds. Vietnamese diacritics in at least 5 names.
- [ ] TASK-04-02: Add `--anonymize` to `scripts/intake_validate_and_map.R` (parse alongside existing `--input`/`--output-dir` via the existing `get_arg`; presence flag: `"--anonymize" %in% args`). When set: after normalization, replace `name_direct_loantaker`/`name_ultimate_parent` with stable pseudonyms `Counterparty 001`… (assigned in first-appearance order, parents and loantakers sharing one namespace keyed by original name), write the mapping to `<output-dir>/pseudonym_map.csv` (columns `pseudonym,original_name`), and pseudonymize `match_preview.csv` counterparty names the same way. Add `intake/output*/pseudonym_map.csv` to `.gitignore` (the map is operator-held). Document the flag in `intake/README.md` and reference it from `docs/intake_privacy.md` as the default `{{ANONYMIZATION_APPROACH}}`.
- [ ] TASK-04-03: Create `scripts/generate_validation_report.R` — CLI: `Rscript scripts/generate_validation_report.R --intake-dir intake/output --output reports/Intake_Validation_Report.html [--bank-name "Saigon Delta Bank"]`. Reads the four intake artifacts (`validation_summary.txt`, `validation_errors.csv`, `normalized_loanbook.csv`, `match_preview.csv`) and renders a self-contained branded HTML report (reuse the base64/inline-CSS pattern from `scripts/generate_report.R`, e.g. copy its `img_to_base64`/CSS scaffolding): sections = KPI cards (rows received / rows valid / % exposure validated / sectors in scope), error table grouped by error type with remediation ask per type, sector-mapping summary (VSIC→ISIC→PACTA counts, "not in scope" list), match-rate preview (matched / review-needed / unmatched with exposure share), next-steps checklist, synthetic/confidentiality footer. Pre-flight: exit 1 with a clear message if any input file is missing.
- [ ] TASK-04-04: Run the rehearsal, timing each stage (PowerShell `Measure-Command` or wall-clock): (a) `Rscript scripts/intake_validate_and_map.R --input data/fixtures/unseen_bank_loanbook.csv --output-dir intake/output_rehearsal`; (b) same with `--anonymize`; (c) `Rscript scripts/generate_validation_report.R --intake-dir intake/output_rehearsal --output reports/SDB_Intake_Validation_Report.html --bank-name "Saigon Delta Bank"`; (d) per ASM-007, in a disposable clone: overwrite `data/vietnam_loanbook.csv` with the rehearsal's `normalized_loanbook.csv`, run `Rscript scripts/pacta_vietnam_scenario.R`, record whether it completes and what breaks (observations only — fixes deferred).
- [ ] TASK-04-05: Write `pilot/rehearsal_log.md`: date, fixture description, per-stage wall-clock timings mapped to the milestone table in `pilot/real_data_phase_proposal.md` (Loanbook received → Validation report returned → Results delivered), every friction point found (with file/line where known), and a verdict on which proposal promises are now demonstrated vs still gapped.
- [ ] TASK-04-06: Extend `dashboard/tests/test_intake.py` mirror coverage on the R side is impractical (no R in ci.yml python job) — instead add `tests/testthat/test_intake_fixture.R`: runs the intake script on the fixture via `system2` and asserts on outputs (see Test Specs). Guard with `testthat::skip_if(Sys.which("Rscript") == "")` is unnecessary (always R) but DO wrap in `skip_on_ci()` if runtime exceeds ~60 s — measure first; the fixture is 40 rows, so it should run in seconds and stay CI-enabled.

**File Changes**
- `data/fixtures/unseen_bank_loanbook.csv` (create): 40-row dirty fixture per TASK-04-01.
- `scripts/intake_validate_and_map.R` (modify): `--anonymize` flag + pseudonym map emission; leave validation/mapping logic untouched.
- `scripts/generate_validation_report.R` (create): ~300-line report generator per TASK-04-03.
- `intake/README.md`, `docs/intake_privacy.md` (modify): document `--anonymize` as the default anonymization approach.
- `.gitignore` (modify): add `intake/output*/pseudonym_map.csv`.
- `pilot/rehearsal_log.md` (create): rehearsal record per TASK-04-05.
- `tests/testthat/test_intake_fixture.R` (create).
- `reports/SDB_Intake_Validation_Report.html` (create, generated): committed as a shareable example artifact.

**Function Signatures**
- `pseudonymize_names(names: character, map: tibble) -> list(names = character, map = tibble)` — R helper inside `intake_validate_and_map.R`; returns pseudonymized vector plus the (possibly extended) `pseudonym,original_name` mapping table.
- `render_validation_report(intake_dir: character, output_path: character, bank_name: character) -> invisible(character)` — main function of the new generator; returns the written file path.

**Test Specs**
- `test_intake_fixture.R`: run intake on the fixture → exit 0; `validation_errors.csv` contains ≥ 8 rows including at least one error each mentioning `credit_limit_vnd`, `sector_code`, `exposure_vnd` (negative), and duplicate; `normalized_loanbook.csv` has 13 columns and fewer rows than 40 (invalid rows excluded) with every `loan_size_outstanding_currency == "VND"`; with `--anonymize`, `normalized_loanbook.csv` contains zero names from a hardcoded list of 5 real fixture names (e.g. "VinFast", "Hoa Phat") and `pseudonym_map.csv` row count equals distinct original names.
- `generate_validation_report.R` with `--intake-dir` pointing at an empty dir → exit 1, message names the first missing file.
- Generated HTML: contains the string `Saigon Delta Bank`, ≥ 4 KPI values, and zero `{{` template residue; file size < 2 MB.

**Dependencies**
- PHASE-03 (testthat harness exists); `intake/SCHEMA.md` contract (stable).

**Exit Criteria**
- [ ] Rehearsal ran end-to-end; `pilot/rehearsal_log.md` committed with timings and friction list.
- [ ] `reports/SDB_Intake_Validation_Report.html` renders correctly in a browser.
- [ ] `--anonymize` produces zero real names in normalized output; map stays untracked (`git check-ignore intake/output_rehearsal/pseudonym_map.csv` succeeds).
- [ ] Full R + Python test suites green.

**Phase Risks**
- **RISK-04-01:** The disposable-clone downstream run (TASK-04-04d) fails because `pacta_vietnam_scenario.R` hardcodes assumptions beyond the loanbook file (e.g. expected sector mix). This is an acceptable outcome — the phase deliverable is the *observation log*, and confirmed gaps become the follow-on parameterization plan's backlog.
- **RISK-04-02:** Pseudonym stability across reruns (new rows shift numbering). Mitigation: numbering is per-run by design; document in `intake/README.md` that the map must be regenerated and re-held per delivery, never reused across extracts.

### PHASE-05 - Private-Instance Delivery & Refresh Audit Artifact

**Goal**
Ship the dormant password gate and a documented, tested private-instance deployment recipe (fulfilling the proposal's "private, access-controlled dashboard instance"), and add a per-refresh audit report so every published number has an audit artifact behind it.

**Tasks**
- [ ] TASK-05-01: Create `dashboard/lib/auth.py`: `require_password()` reads the expected password from `st.secrets["DEMO_PASSWORD"]` if present else `os.environ.get("DEMO_PASSWORD")`; if neither is set → return immediately (public mode, DEC-001). If set and `st.session_state.get("auth_ok") is not True`: render a centered `st.text_input("Access password", type="password")`; on match set `st.session_state["auth_ok"] = True` and `st.rerun()`; on mismatch show `st.error` and `st.stop()`; on empty input just `st.stop()`. Wire it as the FIRST call inside `apply_page_frame()` in `dashboard/lib/branding.py` (after `st.set_page_config`, before analytics ping) so every page is gated by one line.
- [ ] TASK-05-02: Add `dashboard/tests/test_auth.py`: (1) no env/secret → `require_password` returns without rendering (AppTest on `dashboard/app.py` renders landing content); (2) `DEMO_PASSWORD=secret123` via monkeypatched env → AppTest render shows exactly one password input and no landing KPI content; (3) submitting the correct value grants access (AppTest: set input value, rerun, assert landing content present); (4) wrong value → error shown, content absent.
- [ ] TASK-05-03: Create `docs/private-instance-deploy.md`: step-by-step recipe — (1) create a private GitHub repo (or private fork/branch) `pacta-trisk-<bank-slug>`; (2) replace `dashboard/data/` with the client snapshot produced by the pipeline on the operator machine; (3) deploy on Streamlit Community Cloud from the private repo (private repos supported on the free tier for one private app; note the limit); (4) set secrets: `DEMO_PASSWORD` (generated, ≥ 16 chars), leave `PILOT_ANALYTICS_ENDPOINT` UNSET (no third-party pings with client-scoped data, DEC-002 posture); (5) never set `BYOL_INTAKE`/`OUTPUTS_LAYER`/`TRISK_LIVE_RERUN` on the cloud instance (CON-002); (6) smoke checklist (badge shows client snapshot date, password gate blocks incognito access, all 5 pages render); (7) teardown steps at engagement end (delete app, delete repo, confirm per the retention clause in `pilot/real_data_phase_proposal.md`).
- [ ] TASK-05-04: Rehearse the recipe once end-to-end using the PHASE-04 SDB fixture snapshot as the "client data" and record the result (date, URL pattern, gate verified, teardown done) in a "Rehearsal" appendix inside `docs/private-instance-deploy.md`.
- [ ] TASK-05-05: Create `scripts/generate_refresh_audit.R` — no CLI args; reads `dashboard/data/pipeline_manifest.json`, the previous audit's stored metrics (`reports/refresh_audit_metrics.json`, if present), and key outputs; writes `reports/pipeline_refresh_audit.html` (self-contained, reuse the report scaffolding) + updates `reports/refresh_audit_metrics.json`. Contents: run timestamp/sha/step timings from the manifest; md5 checksums of every `data/vietnam_*.csv` input (`tools::md5sum`); PACTA match coverage by sector (from `dashboard/data/pacta/02_vn_matched_prioritized.csv`); top-5 TRISK borrowers by `stress_priority_score` (from `dashboard/data/trisk/power/top_borrowers_alignment_trisk.csv`); engagement top-5 (from `output/engagement/engagement_priority.csv`); a "changed since last run" table diffing current vs previous `refresh_audit_metrics.json` values (row counts, top borrower, coverage %) with `NEW` markers when no previous file exists.
- [ ] TASK-05-06: Wire the audit in: append step `list(name = "refresh_audit", script = "scripts/generate_refresh_audit.R", args = character())` as the LAST step in `scripts/pipeline_refresh.R` (both default and `--full` modes), and extend the commit step in `.github/workflows/refresh.yml` to `git add dashboard/data synthesis_output reports/pipeline_refresh_audit.html reports/refresh_audit_metrics.json`.

**File Changes**
- `dashboard/lib/auth.py` (create): password gate per TASK-05-01.
- `dashboard/lib/branding.py` (modify): one `require_password()` call at the top of `apply_page_frame`; nothing else.
- `dashboard/tests/test_auth.py` (create): four scenarios per TASK-05-02.
- `docs/private-instance-deploy.md` (create): recipe + rehearsal appendix.
- `scripts/generate_refresh_audit.R` (create): audit generator per TASK-05-05.
- `scripts/pipeline_refresh.R` (modify): append the audit step.
- `.github/workflows/refresh.yml` (modify): extend the `git add` path list.

**Function Signatures**
- `require_password() -> None` — no-op when no `DEMO_PASSWORD` is configured; otherwise renders the gate and calls `st.stop()` until the session is authenticated.
- `write_refresh_audit(manifest_path: character = "dashboard/data/pipeline_manifest.json", out_html: character = "reports/pipeline_refresh_audit.html", metrics_path: character = "reports/refresh_audit_metrics.json") -> invisible(character)` — renders the audit HTML, persists current metrics JSON, returns the HTML path.

**Test Specs**
- `python -m pytest dashboard/tests/test_auth.py` → 4 passed; full suite still green with `DEMO_PASSWORD` unset in the test environment (public mode must be the default).
- `Rscript scripts/generate_refresh_audit.R` with no prior metrics file → exit 0, HTML contains "NEW" markers and the manifest sha; run again → "changed since last run" table shows zero-delta rows.
- `Rscript scripts/pipeline_refresh.R` → manifest now lists 8 steps (7 + refresh_audit), all `ok`.

**Dependencies**
- PHASE-04 (SDB fixture snapshot used for the private-instance rehearsal); PHASE-01 manifest.

**Exit Criteria**
- [ ] Public app behavior unchanged with no secret set; gate verified working on the rehearsal private instance.
- [ ] `docs/private-instance-deploy.md` rehearsal appendix filled in.
- [ ] Audit HTML generated by the weekly workflow and committed automatically on its next scheduled run.

**Phase Risks**
- **RISK-05-01:** Streamlit Community Cloud private-app limits (1 private app on free tier) conflict with running the public demo + a private instance simultaneously. Mitigation: document the limit and the fallback (second Streamlit account, or a $ paid tier / small VM) in the recipe; the rehearsal instance is torn down immediately after verification.
- **RISK-05-02:** Session-state password gate is not real security (no rate limiting, shared password). Mitigation: state this explicitly in `docs/private-instance-deploy.md` — it is an access curtain appropriate for aggregated synthetic/anonymized views only; anything more sensitive requires the engagement's own infrastructure. This caveat must also appear in the proposal walkthrough talking points (`pilot/session_scripts.md` — add one bullet).

## Gotchas

- **CI auto-commit loop:** the refresh workflow pushes with the default `GITHUB_TOKEN`, which does NOT trigger other workflows — adding `ci.yml` on push will not create a loop. Do not "fix" this by adding a PAT, or it will loop.
- **`clear_dir("dashboard/data/trisk")` wipes the whole TRISK snapshot on every refresh** (`refresh_dashboard_data.R:113-114`) — any file you expect to persist there (e.g. manifest.csv, grid files) must be re-copied by the script every run; never hand-place files in `dashboard/data/trisk/`.
- **R version skew:** local is 4.5.2, CI was 4.4 — PHASE-01 bumps CI to 4.5 (ASM-009). Build `renv.lock` AFTER the bump so the lockfile's R version matches CI.
- **`dashboard/tests/test_loaders.py` asserts exactly 243 grid scenarios for power** — if any grid regeneration changes lever ranges, this test fails spuriously. Don't change lever ranges in this plan.
- **Vietnamese encoding:** fixture and intake files must be UTF-8; the intake script falls back to latin1, which silently mangles diacritics — author the fixture in UTF-8 without BOM.
- **VND magnitudes:** exposures are raw VND (1e11–5e12 typical). Do not "helpfully" convert to millions anywhere; downstream scripts sum raw `loan_size_outstanding`.
- **Windows PowerShell 5.1 quirks:** no `&&` chaining; invoke R as `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" <script>`; write files other tools read with UTF-8 explicitly.
- **`pipeline_refresh.R` runs steps via `system2("Rscript", ...)`** — on Windows this requires `Rscript` on PATH even though the outer call used the full path. If step launches fail locally with "Rscript not found", add `C:\Program Files\R\R-4.5.2\bin` to PATH for the session: `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"`.
- **Demo scenario metric naming asymmetry** (historical trap, still true in the r2dii demo data): market-share metrics are `target_<scenario>` but SDA metrics are `target_demo`/`adjusted_scenario_demo` — never hardcode `target_sds` for SDA paths when touching PACTA outputs.
- **The engagement scoring script reads from `dashboard/data/trisk/`, not `synthesis_output/`** — it must run AFTER `refresh_dashboard_data.R` (ordering enforced in TASK-03-06).

## Verification Strategy

- **TEST-001 (PHASE-01):** `Rscript scripts/pipeline_refresh.R` → exit 0; `python -c "import json;m=json.load(open('dashboard/data/pipeline_manifest.json'));print(m['status'],len(m['steps']))"` → `ok 7` (8 after PHASE-05).
- **TEST-002 (PHASE-01):** temporarily rename `synthesis_output/trisk/power_demo/company_summary.csv`; `Rscript scripts/refresh_dashboard_data.R` → non-zero exit listing the path; restore.
- **TEST-003 (PHASE-02):** PowerShell `"{0:N1}" -f ((Get-ChildItem dashboard/data -Recurse -File | Measure-Object Length -Sum).Sum / 1MB)` → < 15.
- **TEST-004 (PHASE-02/03/04/05):** `python -m pytest dashboard/tests` → all pass, 0 failures.
- **TEST-005 (PHASE-03):** `Rscript -e "testthat::test_dir('tests/testthat')"` → all pass; `Rscript -e "renv::status()"` → "No issues found" (or equivalent consistent message).
- **TEST-006 (PHASE-03):** `gh run list --workflow ci.yml --limit 1` → `completed success`; `gh run list --workflow refresh.yml --limit 1` → `completed success`.
- **TEST-007 (PHASE-04):** `Rscript scripts/intake_validate_and_map.R --input data/fixtures/unseen_bank_loanbook.csv --output-dir intake/output_rehearsal --anonymize` → exit 0; `findstr /C:"VinFast" intake\output_rehearsal\normalized_loanbook.csv` → no matches (exit 1).
- **TEST-008 (PHASE-05):** `Rscript scripts/generate_refresh_audit.R` → exit 0; `reports/pipeline_refresh_audit.html` exists and contains the current manifest git sha (first 7 chars).
- **MANUAL-001 (PHASE-01):** open the running app landing page → "Data as of:" shows an ISO timestamp, not "unknown".
- **MANUAL-002 (PHASE-04):** open `reports/SDB_Intake_Validation_Report.html` in a browser → KPI cards render, error table groups the 5 planted error types, no raw `{{` tokens.
- **MANUAL-003 (PHASE-05):** deploy the rehearsal private instance, open in an incognito window → password prompt blocks all content; correct password reveals the landing page; tear down.
- **OBS-001:** after the next scheduled Monday 02:00 UTC run, confirm a bot commit `chore: automated pipeline refresh <date>` exists containing `pipeline_manifest.json` and (post-PHASE-05) the audit HTML, and that no `runs/` files were re-added.

## Risks and Alternatives

- **RISK-001:** The first real CI pipeline run exposes Linux-specific failures in R scripts that have only ever run on Windows (path case, locale, fonts for ggplot PNGs). Mitigation: PHASE-01 iterates on CI until green before anything else builds on it; system-lib install step already covers common native deps.
- **RISK-002:** Committing regenerated snapshots as the "new baseline" (PHASE-01) may shift golden numbers before the tests exist (PHASE-03). Mitigation: sequencing — tests are authored FROM the committed post-PHASE-01 files, not from historical values (RISK-03-02).
- **RISK-003:** Weekly auto-refresh + gating tests could leave the pilot app stale for weeks if a flaky failure blocks commits silently. Mitigation: the workflow failure emails the repo owner (GitHub default); the freshness badge shows staleness honestly; `workflow_dispatch` allows manual re-run.
- **ALT-001:** Migrate orchestration to the `targets` R package instead of extending `pipeline_refresh.R` — rejected for now: a rewrite of working orchestration with learning-curve risk, while the current sequential runner is adequate at this scale (revisit when refresh frequency or step count grows).
- **ALT-002:** Real auth (OAuth/streamlit-authenticator) instead of a shared-password gate — rejected: overkill for aggregated synthetic/anonymized pilot views; the engagement contract, not the demo app, is the security boundary for real data (explicitly documented in RISK-05-02).
- **ALT-003:** Git history rewrite + LFS to shrink the 81 MB object store — rejected (ASM-003): disruptive to the shared `origin/main`, and clone size is not currently blocking anyone; forward-looking untracking (PHASE-02) stops the growth.

## Suggested Next Step

Execute PHASE-01. Its exit criteria (green local pipeline, live badge, one green Actions run, fail-loud snapshot) are independently verifiable before PHASE-02 begins, and every later phase builds on the verified baseline it establishes.
