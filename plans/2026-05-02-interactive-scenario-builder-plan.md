---
title: "Interactive Scenario & Stress Builder"
date: "2026-05-02"
status: "draft"
request: "Build a Scenario Builder page on the PACTA-TRISK Streamlit dashboard letting a banker drive shock_year, discount_rate, risk_free_rate, market_passthrough, and carbon-price scenario family live, with a precomputed grid path that works on Streamlit Cloud and an operator-only live-rerun path that calls scripts/trisk_sector_demo.R. Include side-by-side baseline vs scenario comparison, top movers in NPV/PD change, save-scenario feature, and exportable artifacts."
plan_type: "multi-phase"
research_inputs:
  - "research/2026-04-08_integration-trisk-model-existing.md"
  - "research/Baer_TRISK_2022_extracted.txt"
  - "research/PACTA for BANKS - TRISK overview.pptx.txt"
---

# Plan: Interactive Scenario & Stress Builder

## Objective
Convert the TRISK page from a read-only viewer into a banker-driveable scenario tool so prospects can move shock year, discount rate, risk-free rate, market passthrough, and carbon-price family during a live sales meeting and immediately see how their top-20 borrowers reorder. Ship two execution modes: a precomputed grid that works on Streamlit Community Cloud (where R is not available) and an opt-in live-rerun path for operator-hosted deployments. This is the conversion lever for Idea 2 in `plans/2026-05-02-commercial-demo-expansion-ideas.md`.

## Context Snapshot
- **Current state:** `dashboard/pages/2_TRISK_Risk.py` reads a frozen sector-aware snapshot under `dashboard/data/trisk/<sector>/` produced by `scripts/refresh_dashboard_data.R`. Sensitivity is precomputed one-at-a-time only (`sensitivity_results.csv`, one parameter changed per row group). `scripts/trisk_sector_demo.R` orchestrates `trisk.model::run_trisk()` for `power`, `cement`, `steel`. Public deployment is `pactavn.streamlit.app` with no R runtime.
- **Desired state:** New `dashboard/pages/5_Scenario_Builder.py` exposes sliders for the five levers plus a carbon-price family dropdown, draws results from a multi-dimensional precomputed grid in `dashboard/data/trisk/grid/` by default, optionally calls a thin live-rerun adapter behind an operator flag, shows baseline vs scenario side-by-side with top NPV/PD movers, and supports save / load / export of scenarios.
- **Key repo surfaces:** `dashboard/pages/2_TRISK_Risk.py`, `dashboard/lib/loaders.py`, `dashboard/lib/charts.py`, `dashboard/lib/branding.py`, `dashboard/data/trisk/manifest.csv`, `dashboard/data/trisk/<sector>/`, `scripts/trisk_sector_demo.R`, `scripts/trisk_prepare_inputs.R`, `scripts/refresh_dashboard_data.R`, `dashboard/tests/`, `docs/trisk_multisector_contract.md`.
- **Out of scope:** Adding new TRISK sectors (e.g. automotive); changing TRISK input data; multi-bank or multi-portfolio comparison; persistence of saved scenarios across users (single-session only); auth backend beyond a simple operator flag.

## Research Inputs
- `research/2026-04-08_integration-trisk-model-existing.md` - Confirms `trisk.model::run_trisk()` is the integration boundary and that the five exposed levers are the canonical TRISK parameters; tells us the live-rerun adapter must keep calling the same package entrypoint to stay schema-compatible with the existing snapshot contract.
- `research/Baer_TRISK_2022_extracted.txt` - Establishes that a meaningful demo grid only needs coarse step sizes (2-3 values per parameter) because Baer et al. show borrower ranking is robust to small numerical perturbations; this caps grid blow-up.
- `research/PACTA for BANKS - TRISK overview.pptx.txt` - Reinforces that the bank-facing narrative is "what changes when policy timing or strictness changes," not "what is the exact NPV"; supports designing the page around top-movers comparison rather than absolute values.

## Assumptions and Constraints
- **ASM-001:** Streamlit Community Cloud cannot run R; the public path must be served entirely from precomputed CSVs.
- **ASM-002:** A factorial grid of 3 shock years × 3 discount rates × 3 risk-free rates × 3 market-passthrough × 3 carbon-price families = 243 combinations × 3 sectors = 729 TRISK runs per snapshot is acceptable provided each sector takes a few seconds, given the existing single-machine generator already runs nine sensitivity cases per sector in under a minute.
- **ASM-003:** Carbon-price family expansion uses the existing `carbon_price_model` string passed to `run_trisk()`; no new NGFS curve files are required for v1 — we will reuse the three already wired through `scripts/trisk_prepare_inputs.R` plus add two named NGFS aliases that map to existing curves.
- **CON-001:** Public deployment must remain fully synthetic-watermarked; live-rerun mode must never be reachable from the public URL.
- **CON-002:** The dashboard is Python/Streamlit; R is only invoked from the operator-side adapter via subprocess.
- **DEC-001:** Sensitivity grid storage layout will be `dashboard/data/trisk/grid/<sector>/scenarios.csv` (one row per scenario combination) plus `dashboard/data/trisk/grid/<sector>/borrower_results.parquet` (one row per scenario × borrower) to keep page loads fast even at 243 combinations × ~10 borrowers per sector.
- **DEC-002:** Baseline of all comparisons is the existing `base` row already present in `sensitivity_results.csv`; the new grid extends rather than replaces.

## Phase Summary
| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Lock the scenario contract and grid schema | None | `docs/trisk_scenario_grid_contract.md`, sample manifest entry, parameter enumeration table |
| PHASE-02 | Generate the precomputed multi-parameter grid for all three sectors | PHASE-01 | `scripts/trisk_scenario_grid.R`, `synthesis_output/trisk/grid/<sector>/`, refreshed `dashboard/data/trisk/grid/` |
| PHASE-03 | Implement the Scenario Builder page (precomputed mode only) | PHASE-02 | `dashboard/pages/5_Scenario_Builder.py`, loader and chart helpers, save/load/export |
| PHASE-04 | Add the operator-only live-rerun adapter | PHASE-03 | `scripts/trisk_run_adhoc.R`, `dashboard/lib/live_rerun.py`, gated UI path, environment flag |
| PHASE-05 | Tests, docs, deployment refresh, demo rehearsal | PHASE-04 | New tests under `dashboard/tests/`, updated `dashboard/README.md`, `docs/streamlit-deploy.md`, `docs/demo-script.md`, phase report HTML |

## Detailed Phases

### PHASE-01 - Scenario Contract and Grid Schema
**Goal**
Pin down exactly which parameter values are in the demo grid, how scenarios are identified, and how the dashboard will reference them, so the generator and the page can be built in parallel against the same contract.

**Tasks**
- [ ] TASK-01-01: Enumerate the discrete values per lever — recommended defaults: `shock_year ∈ {2026, 2028, 2030}`, `discount_rate ∈ {0.06, 0.08, 0.10}`, `risk_free_rate ∈ {0.02, 0.03, 0.04}`, `market_passthrough ∈ {0.15, 0.25, 0.35}`, `carbon_price_family ∈ {NGFS_NetZero2050, NGFS_Below2C, NGFS_Delayed}`. Map each `carbon_price_family` to an existing `carbon_price_model` string for each sector.
- [ ] TASK-01-02: Define a deterministic `scenario_id` of the form `s{shock_year}_d{discount_rate}_rf{risk_free_rate}_mp{market_passthrough}_c{carbon_price_family}` to identify rows across CSVs and to be the URL query param.
- [ ] TASK-01-03: Write `docs/trisk_scenario_grid_contract.md` with the lever table, scenario ID format, output file layout for `dashboard/data/trisk/grid/<sector>/{scenarios.csv,borrower_results.parquet,grid_meta.json}`, and column-level schema for each artifact.
- [ ] TASK-01-04: Add a `grid_available` boolean column to `dashboard/data/trisk/manifest.csv` so the Scenario Builder page can refuse to load sectors that have not yet had a grid generated.
- [ ] TASK-01-05: Spike the carbon-price family mapping for cement and steel — confirm the existing `cement_intensity_transition` and `steel_intensity_transition` model strings can absorb the three NGFS aliases, or document a fallback that holds the model string fixed and shifts only the carbon price level.

**Files / Surfaces**
- `docs/trisk_multisector_contract.md` - Reference baseline contract; the new doc must not contradict it.
- `dashboard/data/trisk/manifest.csv` - Schema extension for `grid_available`.
- `scripts/trisk_prepare_inputs.R` - Source of existing carbon price curves; do not edit, just reference.

**Dependencies**
- None.

**Exit Criteria**
- [ ] `docs/trisk_scenario_grid_contract.md` exists and is reviewed.
- [ ] One worked example scenario_id round-trips through documented parsing.
- [ ] Manifest schema change is committed with backward-compatible default `grid_available = false`.

**Phase Risks**
- **RISK-01-01:** Carbon price family is the loosest lever. Mitigation: keep v1 to three named families that already correspond to in-repo curves, defer "custom upload" to Idea 1.

### PHASE-02 - Precomputed Grid Generation
**Goal**
Produce the 243-cell × 3-sector grid of TRISK runs and publish it into the dashboard data snapshot, fast enough that a snapshot refresh stays under ~10 minutes on a developer laptop.

**Tasks**
- [ ] TASK-02-01: Create `scripts/trisk_scenario_grid.R` that imports the run helper from `scripts/trisk_sector_demo.R`, expands the contract grid into a tibble, runs each combination per sector, and writes `synthesis_output/trisk/grid/<sector>/scenarios.csv` and `synthesis_output/trisk/grid/<sector>/borrower_results.parquet` (use `arrow::write_parquet`).
- [ ] TASK-02-02: Add cache-skip behavior keyed on `scenario_id` so reruns only fill missing cells; emit a `grid_meta.json` with run timestamp, package version, and total runtime per sector.
- [ ] TASK-02-03: Add NPV change, PD change, and `stress_priority_score` per `(scenario_id, company_id)` to the borrower-results table; replicate the existing column shape in `sensitivity_results.csv` so downstream loaders can be reused.
- [ ] TASK-02-04: Extend `scripts/refresh_dashboard_data.R` to copy `synthesis_output/trisk/grid/<sector>/` into `dashboard/data/trisk/grid/<sector>/` and to flip `grid_available = true` in the manifest for sectors that produced a grid.
- [ ] TASK-02-05: Add `pyarrow` to `dashboard/requirements.txt` so the parquet artifact loads on Streamlit Cloud.
- [ ] TASK-02-06: Smoke-run the generator for `power` only first to validate runtime, then expand to `cement` and `steel`.

**Files / Surfaces**
- `scripts/trisk_scenario_grid.R` - New generator.
- `scripts/trisk_sector_demo.R` - Refactor lightly to expose its run helper, do not change behavior of existing entrypoints.
- `scripts/refresh_dashboard_data.R` - Snapshot refresh extension.
- `dashboard/data/trisk/grid/` - New snapshot folder.
- `dashboard/requirements.txt` - Add `pyarrow`.

**Dependencies**
- PHASE-01 contract.

**Exit Criteria**
- [ ] All three sectors produce a `scenarios.csv` with 243 rows.
- [ ] Borrower results parquet loads with `pandas.read_parquet` in under 1 s per sector.
- [ ] Snapshot refresh updates `manifest.csv` with `grid_available = true` for each sector.
- [ ] `grid_meta.json` reports total runtime per sector.

**Phase Risks**
- **RISK-02-01:** Total runtime exceeds the laptop budget. Mitigation: drop to 2 values per lever (32 cells) for v1 and document the reduced grid; leave the 3-value path behind a flag.
- **RISK-02-02:** `Dung Quat LNG Power Consortium` zero-baseline NA bug already documented in `activeContext.md` will propagate into the grid. Mitigation: filter or label NA rows in the loader, do not try to fix the underlying bug in this plan.

### PHASE-03 - Scenario Builder Page (Precomputed Mode)
**Goal**
Ship a Streamlit page that lets a banker pick a sector and lever values, see a side-by-side baseline vs scenario view with top NPV and PD movers, save the scenario in session, and export the result.

**Tasks**
- [ ] TASK-03-01: Create `dashboard/pages/5_Scenario_Builder.py` with sector selector (reusing manifest), five lever widgets (`st.select_slider` for numeric, `st.selectbox` for carbon family), and a "Reset to baseline" button.
- [ ] TASK-03-02: Add `load_trisk_grid(sector)` to `dashboard/lib/loaders.py` that reads `dashboard/data/trisk/grid/<sector>/borrower_results.parquet` and `scenarios.csv`, with `@st.cache_data` and a guard that errors gracefully when `grid_available = false`.
- [ ] TASK-03-03: Implement the lookup: given the five lever values, build `scenario_id` and slice the borrower table; baseline is the snapshot's existing `base` row (no scenario_id transform).
- [ ] TASK-03-04: Build the side-by-side comparison: two ranked horizontal bars (baseline vs scenario) for top-10 by `stress_priority_score`, plus a `delta` table showing rank changes.
- [ ] TASK-03-05: Build the top-movers panel: top 5 by absolute `delta_npv_change_vs_base` and top 5 by absolute `delta_pd_change_vs_base`, with sparkline-style markers via existing `dashboard/lib/charts.py` helpers.
- [ ] TASK-03-06: Implement save / load via `st.session_state["saved_scenarios"]` — list of `{label, scenario_id, levers}`; render as a small table with one-click reload.
- [ ] TASK-03-07: Implement export: download buttons for the current scenario as CSV (borrower table slice) and as JSON (lever values + scenario_id) under `download_scenario_<id>.csv`.
- [ ] TASK-03-08: Encode the active `scenario_id` into a query param so a banker can deep-link a result; restore from query param on load.
- [ ] TASK-03-09: Add the synthetic-data banner and the existing PD disclaimer copied from `2_TRISK_Risk.py`.

**Files / Surfaces**
- `dashboard/pages/5_Scenario_Builder.py` - New page.
- `dashboard/lib/loaders.py` - New loader.
- `dashboard/lib/charts.py` - Possibly add a paired ranked-bar helper.
- `dashboard/lib/branding.py` - Reuse banner/footer.
- `dashboard/app.py` - Add the new page to the landing-page narrative and "What's new" callout.

**Dependencies**
- PHASE-02 grid snapshot.

**Exit Criteria**
- [ ] Page loads cleanly for `power`, `cement`, `steel` against the snapshot.
- [ ] Moving any single lever updates the comparison view in under 500 ms.
- [ ] Save / load works within a session.
- [ ] Deep-link with `?scenario_id=...` restores the same view.
- [ ] CSV and JSON exports download as expected.

**Phase Risks**
- **RISK-03-01:** Slider snapping to discrete grid values can confuse users who expect continuous sliders. Mitigation: use `st.select_slider` with explicit allowed values and a tooltip explaining the grid is precomputed.

### PHASE-04 - Operator-Only Live Rerun Adapter
**Goal**
Allow a sales engineer running the dashboard locally or in a private deployment to step outside the precomputed grid and run an arbitrary parameter combination on demand, without exposing this path on the public Streamlit URL.

**Tasks**
- [ ] TASK-04-01: Add `scripts/trisk_run_adhoc.R` that accepts CLI flags `--sector --shock_year --discount_rate --risk_free_rate --market_passthrough --carbon_price_family` and writes a single-scenario borrower result CSV to a temp path printed on stdout.
- [ ] TASK-04-02: Add `dashboard/lib/live_rerun.py` that wraps the script as a subprocess, checks for an `R_RSCRIPT` env var (path to Rscript) and a `TRISK_LIVE_RERUN=1` flag, and returns a parsed pandas DataFrame.
- [ ] TASK-04-03: Add a "Live rerun (operator only)" expander in `5_Scenario_Builder.py` that is hidden when the env flag is unset; when visible, it offers a continuous slider for each lever and a "Run now" button that invokes the adapter and overlays the result onto the comparison view.
- [ ] TASK-04-04: Add a 30-second subprocess timeout, a clear error surface for missing R / missing package, and a single concurrency guard (`st.session_state["live_rerun_busy"]`).
- [ ] TASK-04-05: Document operator setup in `docs/streamlit-deploy.md`: Rscript install, `trisk.model` install, env var configuration, and an explicit warning that this path must not be enabled on the public deployment.

**Files / Surfaces**
- `scripts/trisk_run_adhoc.R` - New CLI runner.
- `dashboard/lib/live_rerun.py` - New module.
- `dashboard/pages/5_Scenario_Builder.py` - Conditional expander.
- `docs/streamlit-deploy.md` - Operator setup notes.

**Dependencies**
- PHASE-03 page baseline.

**Exit Criteria**
- [ ] With `TRISK_LIVE_RERUN=1` and Rscript on PATH, a custom scenario runs in under 30 s and renders.
- [ ] Without the env flag, the expander does not appear and the page behaves identically to PHASE-03.
- [ ] Public deployment continues to ignore the adapter.

**Phase Risks**
- **RISK-04-01:** Operator-only path is accidentally enabled in production. Mitigation: gate on env var, add a startup assertion that prints a banner when enabled, document the deployment posture in `docs/streamlit-deploy.md`, and add a CI check that the public deploy config does not set the flag.
- **RISK-04-02:** Subprocess hangs on Windows. Mitigation: enforce timeout, use `subprocess.run` with `shell=False` and absolute paths, surface stderr in the UI.

### PHASE-05 - Tests, Docs, Deployment Refresh, Demo Rehearsal
**Goal**
Lock the new feature behind tests, refresh the deployed snapshot, and produce a phase report so the work is shippable.

**Tasks**
- [ ] TASK-05-01: Add `dashboard/tests/test_scenario_builder.py` covering: loader returns correct schema, `scenario_id` parsing round-trip, baseline-vs-scenario delta computation, missing-grid sector errors gracefully, deep-link restore.
- [ ] TASK-05-02: Add a snapshot-shape test in `dashboard/tests/test_loaders.py` confirming `grid` files exist for every sector with `grid_available = true`.
- [ ] TASK-05-03: Run `python -m pytest dashboard/tests` and `python -m streamlit run dashboard/app.py --server.headless true` and capture results.
- [ ] TASK-05-04: Update `dashboard/README.md` with a Scenario Builder section, update `docs/demo-script.md` with the live-demo flow ("move shock year, point to top mover"), and update `docs/streamlit-deploy.md` with grid refresh commands.
- [ ] TASK-05-05: Refresh the snapshot end-to-end via `Rscript scripts/trisk_prepare_inputs.R`, `Rscript scripts/trisk_power_demo.R`, `Rscript scripts/trisk_sector_demo.R cement`, `Rscript scripts/trisk_sector_demo.R steel`, `Rscript scripts/trisk_scenario_grid.R`, `Rscript scripts/refresh_dashboard_data.R`.
- [ ] TASK-05-06: Generate `reports/2026-05-XX-scenario-builder.html` summarizing the feature, the grid contents, the live-rerun caveat, and the rehearsal outcome.

**Files / Surfaces**
- `dashboard/tests/` - New and extended tests.
- `dashboard/README.md`, `docs/demo-script.md`, `docs/streamlit-deploy.md` - Operator and demo docs.
- `reports/` - Phase report artifact.

**Dependencies**
- PHASE-04.

**Exit Criteria**
- [ ] All `dashboard/tests` pass.
- [ ] Streamlit smoke run reaches the new page without errors.
- [ ] Snapshot refresh is reproducible from a clean clone with documented commands.
- [ ] Phase report HTML committed.

**Phase Risks**
- **RISK-05-01:** Snapshot regeneration drifts borrower IDs due to upstream synthetic data changes. Mitigation: run `scripts/trisk_prepare_inputs.R` first and diff `assets.csv` against the prior snapshot before regenerating the grid.

## Verification Strategy
- **TEST-001:** `python -m pytest dashboard/tests` — must pass with the existing 9 tests plus the new scenario builder tests.
- **TEST-002:** Add a unit test for `scenario_id` parse/build round-trip in `dashboard/tests/test_scenario_builder.py`.
- **MANUAL-001:** Run `python -m streamlit run dashboard/app.py --server.headless true` and walk the demo script: open Scenario Builder, change `shock_year` from 2028 to 2026, confirm at least one top-10 ranking change, save the scenario, reload the page from the deep link, export CSV.
- **MANUAL-002:** With `TRISK_LIVE_RERUN=1` set locally, run a custom scenario outside the grid and confirm the result overlay matches the precomputed grid for the closest grid cell within tolerance.
- **OBS-001:** Add a structured log line per live rerun (sector, scenario_id, runtime ms) to `dashboard/lib/live_rerun.py` so operator deployments can audit usage.
- **OBS-002:** Add a startup print in `dashboard/app.py` when `TRISK_LIVE_RERUN` is enabled so the operator can confirm posture from the Streamlit logs.

## Risks and Alternatives
- **RISK-001:** Grid blow-up if a future request adds a sixth lever. Mitigation: the contract already names the five canonical levers; any additional lever requires a fresh plan and a downsample of existing levers.
- **RISK-002:** Public users mistake the precomputed grid for live computation and ask for values between grid points. Mitigation: a small "Snapped to grid" pill next to each slider and a one-line copy explanation under the carbon-price selector.
- **ALT-001:** Skip the precomputed grid and require live R for all interactivity. Rejected because Streamlit Cloud cannot run R, which would mean abandoning the public demo URL — the single highest-leverage marketing surface.
- **ALT-002:** Use a coarse 2-value grid (32 cells) only. Rejected for v1 because 3-value grids are still tractable in runtime budget and 2-value grids leave too many "no change observed" cells in demos.

## Grill Me
1. **Q-001:** Should `carbon_price_family` in v1 be three NGFS-named aliases over existing repo curves, or do we need to ingest fresh NGFS Phase V curve files before launch?
   - **Recommended default:** Three NGFS-named aliases mapped onto the existing `cement_intensity_transition`, `steel_intensity_transition`, and `increasing_carbon_tax_50` curves; defer real NGFS ingestion to a follow-up.
   - **Why this matters:** Determines whether PHASE-01 needs an additional data-ingestion sub-phase and whether `dashboard/data/trisk/grid/` includes new carbon curve files.
   - **If answered differently:** Add a sub-phase under PHASE-01 to ingest, validate, and snapshot real NGFS curves; grid generation runtime grows; the docs/methodology copy must change to claim NGFS rather than illustrative curves.
2. **Q-002:** Should the operator-only live-rerun path be in v1 at all, or split to a follow-up?
   - **Recommended default:** Keep PHASE-04 in scope but ship behind the env flag so the public path is fully decoupled.
   - **Why this matters:** PHASE-04 is the largest non-precomputed surface; cutting it shortens delivery and reduces deployment risk.
   - **If answered differently:** Drop PHASE-04, fold its docs into a follow-up plan, and reduce PHASE-05 verification to precomputed-only.
3. **Q-003:** Is single-session save/load adequate, or do we need cross-session persistence (e.g. `dashboard/data/saved_scenarios/<user>.json`)?
   - **Recommended default:** Single-session via `st.session_state` for v1.
   - **Why this matters:** Cross-session persistence implies a notion of user identity, which the dashboard does not currently have.
   - **If answered differently:** Adds an auth dependency and a writable storage path; pushes scope toward Idea 1's intake/auth work and changes deployment posture.
4. **Q-004:** Are 3-value lever discretizations acceptable for the demo, or do bankers expect finer granularity?
   - **Recommended default:** 3 values per lever for v1 (243 cells).
   - **Why this matters:** Drives PHASE-02 runtime and the precomputed grid size.
   - **If answered differently:** 5-value grids push to 3,125 cells per sector and require either downsampling, parallelization, or a hybrid lookup-plus-live-rerun strategy.

## Suggested Next Step
Answer the Grill Me questions, update the plan in place if any defaults change, then begin PHASE-01 by writing `docs/trisk_scenario_grid_contract.md` and the manifest schema extension.
