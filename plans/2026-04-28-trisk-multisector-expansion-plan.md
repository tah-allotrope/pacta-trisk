---
title: "TRISK Multi-Sector Expansion"
date: "2026-04-28"
status: "completed"
request: "multiphase for trisk expansion to other sectors idea found in the future planning ideas md"
plan_type: "multi-phase"
research_inputs:
  - "research/future_planning_ideas.md"
  - "research/2026-04-08_integration-trisk-model-existing.md"
---

# Plan: TRISK Multi-Sector Expansion

## Objective
Expand the current TRISK implementation from a power-only pilot into a multi-sector stress-test that also covers cement and steel, while preserving the existing power workflow as a regression baseline. The immediate outcome is a dashboard and artifact snapshot that lets a bank audience switch between `power`, `cement`, and `steel` TRISK views without leaving `dashboard/pages/2_TRISK_Risk.py`.

## Context Snapshot
- **Current state:** `scripts/trisk_prepare_inputs.R` and `scripts/trisk_power_demo.R` are hardcoded to `power` and write a single-sector artifact contract into `output/trisk_inputs/power_demo/`, `synthesis_output/trisk/power_demo/`, and `dashboard/data/trisk/`. The TRISK dashboard loader in `dashboard/lib/loaders.py` and page logic in `dashboard/pages/2_TRISK_Risk.py` assume one flat set of power-sector CSVs.
- **Desired state:** The repo can generate and snapshot TRISK inputs and outputs for `power`, `cement`, and `steel`, and the dashboard exposes a sector selector that swaps tables, charts, downloads, and caveats against the selected sector's frozen snapshot.
- **Key repo surfaces:** `scripts/trisk_prepare_inputs.R`, `scripts/trisk_power_demo.R`, `scripts/refresh_dashboard_data.R`, `dashboard/lib/loaders.py`, `dashboard/pages/2_TRISK_Risk.py`, `dashboard/data/README.md`, `dashboard/tests/test_smoke.py`, `data/vietnam_abcd.csv`, `data/vietnam_scenario_co2.csv`, `synthesis_output/vietnam/04_vn_ms_company.csv`, `synthesis_output/vietnam/06_vn_sda_alignment_2030.csv`.
- **Out of scope:** Automotive TRISK coverage, pipeline orchestration or scheduled refresh, engagement-page work, replacing `trisk.model` with a different interface, and recalibrating the synthetic Vietnam bank dataset beyond what is needed for cement and steel placeholders.

## Research Inputs
- `research/future_planning_ideas.md` - Sets the requested direction explicitly: expand beyond power into cement and steel, refresh the dashboard snapshot, and add a sector selector on the TRISK page. It also identifies the two concrete borrowers that matter most for the demo narrative: `VICEM` and `Hoa Phat Group JSC`.
- `research/2026-04-08_integration-trisk-model-existing.md` - Confirms that PACTA should remain the upstream alignment layer and TRISK the downstream stress layer, but the current repo has already standardized on the newer four-input `trisk.model` contract (`assets`, `financial_features`, `scenarios`, `ngfs_carbon_price`). It also highlights the main design risk for this expansion: cement and steel rely on SDA-style emission-intensity pathways instead of the power market-share pathways used today.

## Assumptions and Constraints
- **ASM-001:** The current repository should continue using the existing four-file `trisk.model::run_trisk()` input contract already implemented in `scripts/trisk_prepare_inputs.R`; this plan does not switch the repo back to the legacy six-CSV workflow discussed in earlier research.
- **ASM-002:** `data/vietnam_abcd.csv` already contains sufficient cement and steel rows to build a first demo for `VICEM`, `Holcim Group`, `Hoa Phat Group JSC`, and `Pomina Group`.
- **ASM-003:** `data/vietnam_scenario_co2.csv` is the authoritative scenario source for cement and steel in v1, and its emission-intensity pathways will be translated into the TRISK scenario inputs rather than replaced with new external scenario files.
- **CON-001:** `dashboard/lib/loaders.py` and `dashboard/pages/2_TRISK_Risk.py` currently assume a single flat file layout, so the snapshot contract and UI contract must be changed together in one implementation pass.
- **CON-002:** The repo currently exposes company-level power alignment data in `synthesis_output/vietnam/04_vn_ms_company.csv`, but only sector-level cement and steel SDA alignment data in `synthesis_output/vietnam/06_vn_sda_alignment_2030.csv`.
- **DEC-001:** Phase 1 multi-sector support covers `cement` and `steel` only; `automotive` remains deferred because the current repo does not yet define an automotive-specific TRISK scenario mapping.
- **DEC-002:** Preserve `scripts/trisk_power_demo.R` as a stable entrypoint for the current power pilot and treat its outputs as the regression baseline during refactoring.
- **DEC-003:** Standardize the dashboard snapshot as `dashboard/data/trisk/<sector>/...` plus a top-level `dashboard/data/trisk/manifest.csv` so the UI can discover sectors and display sector-specific caveats without filename guesswork.
- **DEC-004:** v1 for `cement` and `steel` may show borrower TRISK rankings with sector-level SDA context, but the UI and output labels must make clear that the SDA values are sector context rather than borrower-specific alignment scores.

## Phase Summary
| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Lock the multi-sector data contract and sector mappings | None | Sector contract, folder layout, mapping rules, SDA context decision |
| PHASE-02 | Extend TRISK input preparation for cement and steel | PHASE-01 | Multi-sector input builder, sector input CSVs, sector input folders |
| PHASE-03 | Run and normalize sector TRISK outputs | PHASE-02 | Cement and steel TRISK result folders with the same artifact contract as power |
| PHASE-04 | Update snapshot publishing, loaders, and TRISK page UI | PHASE-03 | `dashboard/data/trisk/<sector>/`, manifest-driven loaders, sector selector UI |
| PHASE-05 | Verify, document, and hand off the expanded workflow | PHASE-04 | Passing smoke tests, local app verification, updated docs and operator commands |

## Detailed Phases

### PHASE-01 - Sector Contract and Mapping Rules
**Goal**
Define the exact sector-level data contract for the expansion so later code changes are deterministic, especially around technology mapping, directory layout, and how cement/steel alignment context is represented beside TRISK stress outputs.

**Tasks**
- [x] TASK-01-01: Inventory the cement and steel source rows in `data/vietnam_abcd.csv` and `data/vietnam_scenario_co2.csv`, and document the company IDs, technologies, units, years, and emission-factor fields that must flow into TRISK inputs.
- [x] TASK-01-02: Define a `sector_specs` mapping contract for `power`, `cement`, and `steel`, including local sector names, local technology names, TRISK-facing sector and technology labels, output units, and any sector-specific defaults such as capacity-factor handling or synthetic price anchors.
- [x] TASK-01-03: Lock the output folder contract: `output/trisk_inputs/<sector>_demo/`, `synthesis_output/trisk/<sector>_demo/`, and `dashboard/data/trisk/<sector>/`, plus `dashboard/data/trisk/manifest.csv` to describe sector labels, default sort field, unit labels, and caveat text.
- [x] TASK-01-04: Decide how cement and steel alignment context enters the TRISK ranking outputs, using `synthesis_output/vietnam/06_vn_sda_alignment_2030.csv` as the v1 source unless a new company-level SDA derivation is explicitly added.
- [x] TASK-01-05: Record the scenario translation rule from SDA emission-intensity pathways to the `scenarios.csv` fields consumed by `trisk.model`, including how `scenario_price`, `scenario_pathway`, and `scenario_capacity_factor` are populated for non-power sectors.

**Files / Surfaces**
- `data/vietnam_abcd.csv` - Source of company, sector, technology, production, unit, and emission-factor rows for the new sectors.
- `data/vietnam_scenario_co2.csv` - Source of cement and steel scenario trajectories that must be transformed into TRISK scenario inputs.
- `synthesis_output/vietnam/06_vn_sda_alignment_2030.csv` - Current sector-level SDA alignment context for cement and steel.
- `scripts/trisk_prepare_inputs.R` - The current single-sector assumptions live here and must be replaced with an explicit sector contract.

**Dependencies**
- None.

**Exit Criteria**
- [x] The implementation target is pinned to one folder layout and one manifest format for all sectors.
- [x] Technology mappings and scenario translation rules are written down well enough that another engineer can implement them without re-deciding sector semantics.
- [x] The cement/steel alignment-context rule is explicit: either sector-level SDA context is accepted for v1 or company-level SDA work is added to scope.

**Phase Risks**
- **RISK-01-01:** Cement and steel do not fit the power-specific assumptions currently baked into `scenario_price` and `scenario_capacity_factor`. Mitigation: require a written sector translation rule before changing any generator code.

### PHASE-02 - Multi-Sector Input Builder
**Goal**
Refactor the TRISK input builder so it can emit valid per-sector input packages for `power`, `cement`, and `steel` without duplicating the current script three times.

**Tasks**
- [x] TASK-02-01: Replace the hardcoded `power_mapping` block in `scripts/trisk_prepare_inputs.R` with a shared sector-spec structure and sector-specific builder functions that can emit `assets`, `financial_features`, and `scenarios` for any supported sector.
- [x] TASK-02-02: Extend the synthetic borrower financial features to cover `VN_ABCD_020` through `VN_ABCD_023`, with transparent placeholder assumptions for `pd`, `net_profit_margin`, `debt_equity_ratio`, and `volatility`.
- [x] TASK-02-03: Generate sector-specific CSVs in `data/` such as `vietnam_trisk_assets_cement.csv`, `vietnam_trisk_assets_steel.csv`, `vietnam_trisk_scenarios_cement.csv`, and `vietnam_trisk_scenarios_steel.csv` alongside the existing power outputs.
- [x] TASK-02-04: Write runnable input folders to `output/trisk_inputs/cement_demo/` and `output/trisk_inputs/steel_demo/` using the same file names already consumed by `trisk.model::run_trisk()`.
- [x] TASK-02-05: Re-run the existing power input generation through the refactored code path and compare row counts, company counts, and scenario names against the current `power_demo` outputs to confirm no unintended regression.

**Files / Surfaces**
- `scripts/trisk_prepare_inputs.R` - Main input-builder refactor target.
- `data/vietnam_trisk_*` - Sector-specific generated inputs that should remain inspectable outside the run folders.
- `output/trisk_inputs/power_demo/`, `output/trisk_inputs/cement_demo/`, `output/trisk_inputs/steel_demo/` - Runnable TRISK input packages.
- `data/vietnam_scenario_co2.csv` - Cement and steel scenario source that must now be used directly by the builder.

**Dependencies**
- PHASE-01.

**Exit Criteria**
- [x] `scripts/trisk_prepare_inputs.R` produces complete `assets.csv`, `scenarios.csv`, `financial_features.csv`, and `ngfs_carbon_price.csv` for cement and steel as well as power.
- [x] New cement and steel input folders exist and are structurally consistent with the power folder.
- [x] Power input outputs remain stable enough to use as a regression baseline.

**Phase Risks**
- **RISK-02-01:** The sector refactor may accidentally break the existing power builder while adding cement and steel branches. Mitigation: compare power row counts and scenario labels before and after the refactor and treat any unexplained diff as a stop condition.

### PHASE-03 - Sector Runners and Output Normalization
**Goal**
Produce standardized TRISK result folders for cement and steel so the dashboard can switch sectors without special-case file handling.

**Tasks**
- [x] TASK-03-01: Extract the shared run logic from `scripts/trisk_power_demo.R` into a generic runner surface, preferably `scripts/trisk_sector_demo.R`, that accepts a sector and output root while preserving the current power run behavior.
- [x] TASK-03-02: Keep `scripts/trisk_power_demo.R` as a thin wrapper or compatibility entrypoint that calls the shared runner with `sector = "power"`.
- [x] TASK-03-03: Add cement and steel runs that write the same artifact set used today by power: `company_summary.csv`, `top_borrowers_alignment_trisk.csv`, `params_latest.csv`, `pd_summary.csv`, `npv_results_latest.csv`, `pd_results_latest.csv`, `company_trajectories_latest.csv`, `sensitivity_results.csv`, `sensitivity_summary.csv`, `run_catalog.csv`, and `figures/`.
- [x] TASK-03-04: Adjust the alignment-context join logic so power still uses company-level market-share alignment from `synthesis_output/vietnam/04_vn_ms_company.csv`, while cement and steel use the SDA alignment context available in `synthesis_output/vietnam/06_vn_sda_alignment_2030.csv` until a company-level SDA source exists.
- [x] TASK-03-05: Confirm the same sensitivity grid semantics across sectors for `shock_year`, `discount_rate`, `risk_free_rate`, and `market_passthrough`, even if the absolute values are interpreted differently by sector.

**Files / Surfaces**
- `scripts/trisk_power_demo.R` - Current power-only runner that should become a stable wrapper or baseline script.
- `scripts/trisk_sector_demo.R` - Recommended new shared runner surface.
- `synthesis_output/trisk/power_demo/`, `synthesis_output/trisk/cement_demo/`, `synthesis_output/trisk/steel_demo/` - Standardized sector output folders.
- `synthesis_output/vietnam/04_vn_ms_company.csv` and `synthesis_output/vietnam/06_vn_sda_alignment_2030.csv` - Alignment context sources used by the ranking outputs.

**Dependencies**
- PHASE-02.

**Exit Criteria**
- [x] Cement and steel TRISK runs complete and emit the same file contract as the existing power demo.
- [x] `scripts/trisk_power_demo.R` still works as a documented power-sector entrypoint.
- [x] The ranking outputs clearly distinguish borrower-level stress results from sector-level SDA context where borrower-level alignment is not available.

**Phase Risks**
- **RISK-03-01:** Repeating a sector-level SDA gap across borrowers could be mistaken for company-level alignment evidence. Mitigation: expose SDA context in separate columns and copy, and do not label it as a company-specific alignment score.

### PHASE-04 - Snapshot Publishing and TRISK Page UI
**Goal**
Publish the multi-sector outputs into the dashboard snapshot and update the loader and page contracts so the UI can switch sectors cleanly.

**Tasks**
- [x] TASK-04-01: Extend `scripts/refresh_dashboard_data.R` to copy each sector's TRISK files into `dashboard/data/trisk/<sector>/` and generate `dashboard/data/trisk/manifest.csv` describing available sectors, display labels, units, and disclaimers.
- [x] TASK-04-02: Refactor `dashboard/lib/loaders.py` so `load_trisk_tables()` can read a selected sector from the new snapshot layout instead of one global flat folder.
- [x] TASK-04-03: Update `dashboard/pages/2_TRISK_Risk.py` to add a sector selector, load the selected sector's tables, update metric labels and trajectory copy, and preserve `power` as the default selection.
- [x] TASK-04-04: Adjust the ZIP export and downloads so the user can export either the selected sector bundle or the manifest-aware full TRISK snapshot.
- [x] TASK-04-05: Update `dashboard/app.py` and `dashboard/data/README.md` to reflect that the TRISK tab now covers `power`, `cement`, and `steel` rather than only the power pilot.

**Files / Surfaces**
- `scripts/refresh_dashboard_data.R` - Snapshot publisher that must move from flat power-only copies to sector-aware copies.
- `dashboard/lib/loaders.py` - Loader contract that must become manifest-aware.
- `dashboard/pages/2_TRISK_Risk.py` - Main UI surface for the new selector and sector-aware charts.
- `dashboard/data/trisk/` and `dashboard/data/README.md` - Frozen snapshot contract consumed by the app and documented for operators.

**Dependencies**
- PHASE-03.

**Exit Criteria**
- [x] `dashboard/data/trisk/manifest.csv` exists and each listed sector folder contains a complete TRISK snapshot.
- [x] The TRISK page renders for `power`, `cement`, and `steel` without file-not-found errors.
- [x] The default `power` experience remains intact apart from the new sector selector and copy updates.

**Phase Risks**
- **RISK-04-01:** Changing the snapshot layout may break any code that still assumes flat `dashboard/data/trisk/*.csv` paths. Mitigation: isolate the layout change behind `dashboard/lib/loaders.py` and keep all direct file access out of page code.

### PHASE-05 - Verification, Documentation, and Handoff
**Goal**
Prove the multi-sector expansion works end to end, document the operator workflow, and leave a reproducible handoff path for future reruns.

**Tasks**
- [x] TASK-05-01: Run the input builder and all supported sector runs in sequence, then refresh the dashboard snapshot from those outputs.
- [x] TASK-05-02: Update or add dashboard tests so the app shell and TRISK page still render under the new manifest-driven loader contract.
- [x] TASK-05-03: Run local Streamlit smoke validation against `dashboard/app.py`, switching manually between `power`, `cement`, and `steel` in the TRISK page.
- [x] TASK-05-04: Update operator-facing docs with the exact rerun commands and any sector-specific caveats, including the fact that cement and steel currently use sector-level SDA context in the dashboard.
- [x] TASK-05-05: Capture a short review note summarizing data assumptions, known caveats, and any sectors intentionally left for a later phase.

**Files / Surfaces**
- `dashboard/tests/test_smoke.py` - Existing smoke harness that should keep protecting the app shell and TRISK page render path.
- `dashboard/README.md` and `dashboard/data/README.md` - Operator docs that must be updated to the new sector-aware run and snapshot model.
- `dashboard/app.py` - Final manual smoke target for local verification.
- `scripts/trisk_prepare_inputs.R`, `scripts/trisk_power_demo.R`, `scripts/trisk_sector_demo.R`, `scripts/refresh_dashboard_data.R` - Commands that must compose into one reproducible flow.

**Dependencies**
- PHASE-04.

**Exit Criteria**
- [x] The documented rerun path regenerates multi-sector inputs, multi-sector outputs, and the dashboard snapshot without manual file copying.
- [x] Automated dashboard smoke tests pass.
- [x] Local app validation confirms the TRISK page can switch sectors and present the correct sector-specific files and caveats.

**Review / Results**
- [x] Re-ran the full multisector generation chain with `scripts/trisk_prepare_inputs.R`, `scripts/trisk_power_demo.R`, `scripts/trisk_sector_demo.R cement`, and `scripts/trisk_sector_demo.R steel`
- [x] Re-ran `scripts/refresh_dashboard_data.R` and confirmed `dashboard/data/trisk/manifest.csv` plus sector folders were republished from the latest outputs
- [x] Re-ran `python -m pytest dashboard/tests` -> `9 passed`
- [x] Verified `python -m streamlit run dashboard/app.py --server.headless true` locally and manually switched the TRISK page across `power`, `cement`, and `steel`
- [x] Confirmed sector-specific caveat copy and download labels render correctly for `power`, `cement`, and `steel`
- [x] Updated operator-facing docs in `dashboard/README.md`, `docs/demo-script.md`, and `docs/streamlit-deploy.md`
- [x] Final handoff note: `power` remains the borrower-level market-share baseline, while `cement` and `steel` remain v1 sector-level SDA-context demos; `automotive` stays intentionally deferred

**Phase Risks**
- **RISK-05-01:** The end-to-end multi-sector run may be slow enough that regressions are discovered late. Mitigation: validate each sector independently first, then run the full snapshot refresh and app smoke checks as the final gate.

## Verification Strategy
- **TEST-001:** Run `Rscript scripts/trisk_prepare_inputs.R` and verify that `output/trisk_inputs/power_demo/`, `output/trisk_inputs/cement_demo/`, and `output/trisk_inputs/steel_demo/` each contain `assets.csv`, `scenarios.csv`, `financial_features.csv`, and `ngfs_carbon_price.csv`.
- **TEST-002:** Run `Rscript scripts/trisk_power_demo.R` and the new shared sector runner for cement and steel, then verify each `synthesis_output/trisk/<sector>_demo/` folder contains the full standardized artifact set.
- **TEST-003:** Run `Rscript scripts/refresh_dashboard_data.R` and verify `dashboard/data/trisk/manifest.csv` plus sector-specific snapshot folders are republished from the latest results.
- **TEST-004:** Run `python -m pytest dashboard/tests/test_smoke.py` and any new loader-specific tests added for the manifest-driven TRISK contract.
- **MANUAL-001:** Run `python -m streamlit run dashboard/app.py --server.headless true` and confirm the TRISK page loads and switches correctly across `power`, `cement`, and `steel`.
- **MANUAL-002:** On the TRISK page, confirm that the selected-sector metrics, borrower table, trajectory chart, input panel, and download bundle all change with the selector and that cement/steel caveat text mentions SDA context explicitly.
- **OBS-001:** Capture row counts, company counts, and scenario labels for each sector after generation and treat any unexplained change in the power-sector baseline as a regression.

## Risks and Alternatives
- **RISK-001:** Cement and steel TRISK results may look less credible than power because their pricing and financial assumptions are more synthetic. Mitigation: keep all assumptions visible in the input panel and README, and describe the outputs as demo stress indicators rather than calibrated credit metrics.
- **RISK-002:** The current repo lacks company-level SDA outputs for cement and steel, which limits how strongly the dashboard can claim borrower-specific combined alignment and stress rankings. Mitigation: ship v1 with sector-level SDA context and reserve company-level SDA derivation for a follow-on plan if needed.
- **ALT-001:** Create separate `scripts/trisk_cement_demo.R` and `scripts/trisk_steel_demo.R` clones plus flat dashboard filenames for each sector. This was not chosen because it duplicates the current power sensitivity logic and makes the dashboard infer sector behavior from naming conventions instead of a manifest-backed data contract.

## Grill Me
No open clarification questions.

## Suggested Next Step
Implement PHASE-01 and PHASE-02 first by locking the sector contract in `scripts/trisk_prepare_inputs.R`, generating the new `cement` and `steel` TRISK input folders, and confirming that the `power` outputs still match the current baseline expectations.
