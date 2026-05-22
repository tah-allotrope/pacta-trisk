---
title: "BIDV Sector Prioritization Module"
date: "2026-05-22"
status: "draft"
request: "GAP-03 from the BIDV gap analysis: build a sector prioritization scoring script that combines PACTA alignment gaps, TRISK stress-test priority scores, and portfolio exposure weights into a ranked sector priority list, demonstrated with the synthetic MCB portfolio as an illustrative BIDV example."
plan_type: "multi-phase"
research_inputs:
  - "research/future_planning_ideas.md"
  - "research/2026-04-08_integration-trisk-model-existing.md"
  - "reports/2026-05-22-bidv-framework-recommendation-gap-analysis.md"
---

# Plan: BIDV Sector Prioritization Module

## Objective
Build a reusable sector prioritization module that synthesizes PACTA alignment outputs, TRISK stress-test scores, and portfolio exposure data into a ranked sector priority list with transparent scoring rationale. Run the module against the existing MCB synthetic portfolio to produce an illustrative example for the BIDV framework recommendation report, with explicit placeholders for substituting BIDV's real portfolio data.

## Context Snapshot
- **Current state:** The repo produces sector-level alignment gaps (PACTA) and borrower-level stress-test priority scores (TRISK) independently. No script or module joins these outputs into a sector prioritization recommendation. The engagement scoring concept from `research/future_planning_ideas.md` (Idea 3) describes a borrower-level composite score (`0.5 × alignment_gap + 0.5 × trisk_priority_score`) but is not implemented and operates at borrower level, not sector level. The existing data surfaces are:
  - PACTA alignment gaps: `synthesis_output/vietnam/` contains market share and SDA alignment CSVs
  - TRISK priority scores: `dashboard/data/trisk/power/top_borrowers_alignment_trisk.csv`, `dashboard/data/trisk/cement/top_borrowers_alignment_trisk.csv`, `dashboard/data/trisk/steel/top_borrowers_alignment_trisk.csv`
  - Portfolio exposure: `data/vietnam_loanbook.csv` (43 loans, 25 trillion VND, sector weights documented in `plans/PROGRESS.md`)
- **Desired state:** A new R script `scripts/sector_prioritization.R` that reads existing pipeline outputs and produces: (a) `synthesis_output/prioritization/sector_priority_ranking.csv` — ranked sector list with composite scores and component breakdowns; (b) `synthesis_output/prioritization/sector_priority_detail.csv` — per-sector detail with alignment gaps, TRISK aggregates, and exposure figures; (c) `synthesis_output/prioritization/sector_priority_chart.png` — a visualization of the priority ranking suitable for report embedding. Additionally, a documentation file `docs/bidv_sector_prioritization_methodology.md` explaining the scoring approach.
- **Key repo surfaces:** `dashboard/data/trisk/*/top_borrowers_alignment_trisk.csv` (TRISK scores), `synthesis_output/vietnam/` (PACTA outputs), `data/vietnam_loanbook.csv` (exposure data), `scripts/pacta_vietnam_scenario.R` (alignment gap calculation reference), `research/future_planning_ideas.md` (engagement scoring design).
- **Out of scope:** Real BIDV data ingestion, borrower-level engagement scoring (deferred to GAP-07), modifications to the dashboard, modifications to existing PACTA or TRISK pipelines.

## Research Inputs
- `research/future_planning_ideas.md` — Idea 3 describes a borrower-level composite engagement priority score as `0.5 × normalized_alignment_gap + 0.5 × normalized_trisk_priority_score`. This plan adapts the concept to sector level by aggregating borrower scores within each sector and adding portfolio exposure weight as a third dimension. The 50/50 weighting is a starting point; the methodology document will make weights explicit and configurable.
- `research/2026-04-08_integration-trisk-model-existing.md` — Confirms that the recommended portfolio action use case for PACTA+TRISK is "exposure reduction, engagement prioritization, sector limits, and sensitivity analysis." Sector prioritization directly serves the first three of these use cases.
- `reports/2026-05-22-bidv-framework-recommendation-gap-analysis.md` — GAP-03 specification: requires a scoring script, a report section template, and an illustrative demonstration. Notes that the scoring must work even without real BIDV data.

## Assumptions and Constraints
- **ASM-001:** Sector prioritization covers the three Decision 263 sectors: power (thermal), cement, and steel. Automotive is out of scope for the BIDV recommendation (not a Decision 263 sector).
- **ASM-002:** The composite priority score uses three equally weighted dimensions: (a) alignment gap severity (from PACTA), (b) transition stress severity (from TRISK), (c) portfolio exposure concentration (from loanbook). Equal weighting is the default; the script accepts weight parameters so BIDV can adjust.
- **ASM-003:** TRISK priority scores will be aggregated from borrower level to sector level using exposure-weighted averaging. This reflects BIDV's credit risk perspective — a sector with one large, highly stressed borrower is more urgent than a sector with many small, mildly stressed borrowers.
- **CON-001:** The script must consume only existing pipeline output files — no re-running of PACTA or TRISK pipelines. This ensures the prioritization module can run quickly as a post-processing step.
- **CON-002:** All scoring must be transparent and auditable. Every intermediate value must be traceable to a source file and row.
- **DEC-001:** The demonstration run uses the MCB synthetic portfolio. The output CSVs include a `data_source` column indicating "MCB_synthetic" to clearly distinguish from future BIDV runs.

## Phase Summary
| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Define scoring methodology and document it | None | `docs/bidv_sector_prioritization_methodology.md` |
| PHASE-02 | Build the sector prioritization R script | PHASE-01 | `scripts/sector_prioritization.R` |
| PHASE-03 | Run demonstration and produce outputs | PHASE-02 | `synthesis_output/prioritization/*.csv`, `synthesis_output/prioritization/*.png` |
| PHASE-04 | Verification and report-readiness check | PHASE-03 | Verified outputs, updated documentation |

## Detailed Phases

### PHASE-01 - Scoring Methodology
**Goal**
Define and document the three-dimensional sector prioritization scoring methodology, making the approach transparent, auditable, and configurable.

**Tasks**
- [ ] TASK-01-01: Define the three scoring dimensions with normalization rules:
  - **Alignment gap severity:** For market share sectors (power), use the maximum technology-level alignment gap percentage. For SDA sectors (cement, steel), use the emission intensity gap percentage vs. 2030 target. Normalize to [0, 1] using min-max scaling across sectors.
  - **Transition stress severity:** Aggregate TRISK borrower-level priority scores within each sector using exposure-weighted mean. Normalize to [0, 1] using min-max scaling across sectors.
  - **Portfolio exposure concentration:** Calculate each sector's share of total Decision 263-relevant portfolio exposure (VND). Normalize to [0, 1] — the sector with the highest share gets 1.0.
- [ ] TASK-01-02: Define the composite score formula: `composite = w_alignment × alignment_score + w_stress × stress_score + w_exposure × exposure_score` where default weights are `w_alignment = 0.35, w_stress = 0.35, w_exposure = 0.30`.
- [ ] TASK-01-03: Define the priority classification bands: Critical (composite ≥ 0.70), High (0.50–0.69), Medium (0.30–0.49), Low (< 0.30).
- [ ] TASK-01-04: Write `docs/bidv_sector_prioritization_methodology.md` documenting: dimensions, normalization rules, composite formula, classification bands, data sources, limitations, and configurable parameters.

**Files / Surfaces**
- `docs/bidv_sector_prioritization_methodology.md` - New: methodology documentation.
- `research/future_planning_ideas.md` - Read: engagement scoring design as starting point.

**Dependencies**
- None.

**Exit Criteria**
- [ ] Methodology document exists with all three dimensions defined, normalized, and justified.
- [ ] Composite formula is explicit and weights are configurable.
- [ ] Classification bands are defined with rationale.

**Phase Risks**
- **RISK-01-01:** Equal-ish weighting (0.35/0.35/0.30) may not reflect BIDV's actual risk appetite. Mitigation: the methodology document explicitly states these are illustrative defaults and recommends BIDV calibrate weights during implementation. The script accepts weight parameters.

### PHASE-02 - Scoring Script
**Goal**
Build the R script that reads existing pipeline outputs, computes the three-dimensional sector priority scores, and writes structured CSV outputs.

**Tasks**
- [ ] TASK-02-01: Create `scripts/sector_prioritization.R` with the following structure:
  - Section 1: Configuration — input file paths, weight parameters (with defaults), output directory
  - Section 2: Load alignment data from `synthesis_output/vietnam/` — read market share alignment gaps for power, read SDA alignment gaps for cement and steel
  - Section 3: Load TRISK data from `dashboard/data/trisk/*/top_borrowers_alignment_trisk.csv` — read borrower-level priority scores for power, cement, steel
  - Section 4: Load exposure data from `data/vietnam_loanbook.csv` — calculate sector-level exposure weights for Decision 263 sectors
  - Section 5: Compute dimension scores — alignment gap severity, transition stress severity (exposure-weighted sector aggregation), exposure concentration
  - Section 6: Normalize scores to [0, 1] using min-max scaling
  - Section 7: Compute composite score and classify priority bands
  - Section 8: Write outputs to `synthesis_output/prioritization/`
  - Section 9: Generate sector priority chart (horizontal bar chart with composite score breakdown by dimension)

- [ ] TASK-02-02: Implement the alignment gap extraction logic:
  - For power: read `synthesis_output/vietnam/` alignment CSVs, find the maximum positive alignment gap across coal/gas technologies (positive gap = over-allocated vs. target = higher misalignment)
  - For cement: read the SDA alignment gap (emission intensity above 2030 target, documented as +76% in `activeContext.md`)
  - For steel: read the SDA alignment gap (emission intensity above 2030 target, documented as +37% in `activeContext.md`)
  - Handle the case where alignment gap CSVs may have different column structures for market share vs. SDA

- [ ] TASK-02-03: Implement the TRISK aggregation logic:
  - Read `top_borrowers_alignment_trisk.csv` for each sector
  - Join with loanbook exposure data on company/borrower name
  - Compute exposure-weighted mean priority score per sector
  - Handle missing TRISK data gracefully (if a sector has no TRISK output, flag it and use alignment + exposure only)

- [ ] TASK-02-04: Implement the exposure calculation logic:
  - Read `data/vietnam_loanbook.csv`
  - Map loans to Decision 263 sectors using the VSIC→PACTA mapping (reference `scripts/pacta_vietnam_scenario.R` lines 100–135)
  - Calculate sector exposure share as `sector_exposure / total_decision263_exposure`
  - The denominator is total Decision 263-relevant exposure, not total portfolio

- [ ] TASK-02-05: Implement the visualization:
  - Horizontal stacked bar chart with sectors on y-axis, composite score on x-axis
  - Three color-coded segments per bar: alignment (red-ish), stress (orange-ish), exposure (blue-ish)
  - Priority band labels on the right
  - Title: "Sector Transition Risk Priority — MCB Synthetic Portfolio"
  - Save as `synthesis_output/prioritization/sector_priority_chart.png`

- [ ] TASK-02-06: Implement the output writers:
  - `sector_priority_ranking.csv`: columns — `sector`, `composite_score`, `priority_band`, `alignment_score`, `stress_score`, `exposure_score`, `alignment_gap_raw`, `stress_score_raw`, `exposure_vnd`, `exposure_share`, `data_source`
  - `sector_priority_detail.csv`: columns — `sector`, `dimension`, `raw_value`, `normalized_score`, `weight`, `weighted_contribution`, `source_file`, `data_source`

**Files / Surfaces**
- `scripts/sector_prioritization.R` - New: the prioritization script.
- `synthesis_output/vietnam/` - Read: PACTA alignment gap CSVs.
- `dashboard/data/trisk/power/top_borrowers_alignment_trisk.csv` - Read: power TRISK scores.
- `dashboard/data/trisk/cement/top_borrowers_alignment_trisk.csv` - Read: cement TRISK scores.
- `dashboard/data/trisk/steel/top_borrowers_alignment_trisk.csv` - Read: steel TRISK scores.
- `data/vietnam_loanbook.csv` - Read: exposure data.
- `scripts/pacta_vietnam_scenario.R` - Read: reference for VSIC→PACTA sector mapping logic.

**Dependencies**
- PHASE-01 methodology document (defines the scoring rules the script implements).

**Exit Criteria**
- [ ] `scripts/sector_prioritization.R` exists and runs without errors using existing pipeline outputs.
- [ ] Script produces `sector_priority_ranking.csv`, `sector_priority_detail.csv`, and `sector_priority_chart.png`.
- [ ] All three Decision 263 sectors (power, cement, steel) appear in the ranking output.
- [ ] Composite scores sum component contributions correctly (verifiable from detail CSV).

**Phase Risks**
- **RISK-02-01:** Alignment gap CSVs may have different formats between market share and SDA methods. Mitigation: read the actual CSV column headers before implementing extraction logic; add fallback logic for both known formats.
- **RISK-02-02:** TRISK `top_borrowers_alignment_trisk.csv` column names may differ across sectors. Mitigation: inspect all three sector files during implementation; use the common column subset.

### PHASE-03 - Demonstration Run
**Goal**
Execute the scoring script against the MCB synthetic portfolio and verify the outputs produce a coherent, interpretable sector prioritization that can be embedded in the BIDV framework recommendation report.

**Tasks**
- [ ] TASK-03-01: Run `scripts/sector_prioritization.R` with default weights against the existing MCB pipeline outputs.
- [ ] TASK-03-02: Verify the ranking output: confirm all three sectors are ranked, composite scores are between 0 and 1, priority bands are assigned, and the ranking order is plausible given known alignment gaps (cement +76% > steel +37% > power variable).
- [ ] TASK-03-03: Verify the detail output: confirm each sector has entries for all three dimensions, normalized scores are between 0 and 1, and weighted contributions sum to the composite score.
- [ ] TASK-03-04: Verify the chart: confirm the stacked bar chart renders with all three sectors, legend is readable, priority band labels are present, and the chart is suitable for embedding in an HTML report.
- [ ] TASK-03-05: Run a sensitivity check: re-run the script with alternative weights (e.g., `w_alignment = 0.50, w_stress = 0.25, w_exposure = 0.25`) and verify the ranking shifts as expected. Document the sensitivity in the outputs.
- [ ] TASK-03-06: Write a brief interpretation narrative (5-10 sentences) in `synthesis_output/prioritization/interpretation_notes.md` explaining the ranking results for the MCB portfolio, suitable for copy-pasting into the final report.

**Files / Surfaces**
- `synthesis_output/prioritization/sector_priority_ranking.csv` - New: ranking output.
- `synthesis_output/prioritization/sector_priority_detail.csv` - New: detail output.
- `synthesis_output/prioritization/sector_priority_chart.png` - New: visualization.
- `synthesis_output/prioritization/interpretation_notes.md` - New: narrative interpretation.

**Dependencies**
- PHASE-02 script must be complete and runnable.
- Existing pipeline outputs in `synthesis_output/vietnam/` and `dashboard/data/trisk/` must be present (they are — confirmed by repo file listing).

**Exit Criteria**
- [ ] All output files exist in `synthesis_output/prioritization/`.
- [ ] Ranking is plausible: cement or steel should rank highest given their large alignment gaps.
- [ ] Chart is publication-quality (readable at 800px width, no clipping, legend present).
- [ ] Sensitivity check shows ranking responds to weight changes.
- [ ] Interpretation narrative is written and factually consistent with the ranking data.

**Phase Risks**
- **RISK-03-01:** If alignment gap data is not available in the expected CSV format (e.g., the Vietnam pipeline didn't produce a clean alignment summary CSV), the script may fail. Mitigation: PHASE-02 should include fallback logic to compute alignment gaps from raw market share / SDA target CSVs if summary CSVs are missing.

### PHASE-04 - Verification and Report-Readiness
**Goal**
Confirm all outputs are internally consistent, methodology is documented, and the module is ready to be consumed by the report generator (GAP-04).

**Tasks**
- [ ] TASK-04-01: Cross-check the ranking CSV against the detail CSV — composite scores must match, no missing sectors.
- [ ] TASK-04-02: Cross-check the methodology document against the script — all formulas, weights, and normalization rules must be consistent.
- [ ] TASK-04-03: Verify that `sector_priority_chart.png` can be base64-encoded and embedded in an HTML report (consistent with the repo's existing report generation pattern in `scripts/generate_report.R`).
- [ ] TASK-04-04: Confirm the output directory structure is compatible with `scripts/refresh_dashboard_data.R` if the prioritization should be included in future dashboard snapshots.
- [ ] TASK-04-05: Update `docs/bidv_sector_prioritization_methodology.md` with the actual MCB demonstration results as an appendix.

**Files / Surfaces**
- `docs/bidv_sector_prioritization_methodology.md` - Update: add MCB results appendix.
- `synthesis_output/prioritization/*` - Read: verify all outputs.
- `scripts/generate_report.R` - Read: confirm chart embedding compatibility.

**Dependencies**
- PHASE-03 demonstration run complete.

**Exit Criteria**
- [ ] All cross-checks pass.
- [ ] Methodology document includes MCB results appendix.
- [ ] Chart is embeddable via base64 encoding.

**Phase Risks**
- **RISK-04-01:** Minimal risk at this stage — this is a verification phase.

## Verification Strategy
- **TEST-001:** Run `Rscript scripts/sector_prioritization.R` and confirm exit code 0 with no errors.
- **TEST-002:** Read `synthesis_output/prioritization/sector_priority_ranking.csv` and verify: 3 rows (one per sector), all numeric columns are finite, composite scores are in [0, 1], priority bands are one of {Critical, High, Medium, Low}.
- **MANUAL-001:** Visually inspect `sector_priority_chart.png` for readability, correct axis labels, and complete legend.
- **MANUAL-002:** Manually verify one sector's composite score by tracing through the detail CSV: raw value → normalized → weighted → summed.

## Risks and Alternatives
- **RISK-001:** The MCB synthetic portfolio has known data limitations — steel match coverage is ~4%, power has NA values at 2025 for some technologies. These will affect the prioritization scores. Mitigation: document these caveats in the interpretation notes and methodology appendix. Frame the MCB run as "illustrative methodology demonstration" not "BIDV's actual priority ranking."
- **ALT-001:** Alternative approach — skip the R script and compute prioritization manually in the report. Not chosen because: (a) a reusable script allows BIDV to re-run with their own data; (b) manual computation is error-prone and not auditable; (c) the script becomes a deliverable asset that demonstrates the recommended framework in action.

## Grill Me
1. **Q-001:** Should the sector prioritization include automotive, or strictly limit to the three Decision 263 sectors (thermal power, cement, steel)?
   - **Recommended default:** Strictly Decision 263 sectors only. Automotive is not covered by Decision 263 and including it dilutes the regulatory relevance of the prioritization.
   - **Why this matters:** Including automotive adds a fourth sector to the ranking but without regulatory urgency, which may confuse the BIDV audience about what requires immediate action.
   - **If answered differently:** Add automotive to the script's sector list. The PACTA data exists; the TRISK data does not (automotive is out of scope for TRISK). The script's missing-TRISK fallback logic would handle this.

2. **Q-002:** Should the default scoring weights favor alignment gap or stress-test severity?
   - **Recommended default:** Near-equal weighting (0.35/0.35/0.30) to avoid pre-judging BIDV's risk appetite. The methodology document recommends BIDV calibrate during implementation.
   - **Why this matters:** Heavily weighting alignment would rank cement first (largest gap); heavily weighting stress would rank power first (most borrower-level TRISK data); heavily weighting exposure would rank power first (largest exposure share).
   - **If answered differently:** Adjust the default weights in the script configuration section. No structural changes needed.

## Suggested Next Step
Accept the recommended defaults, then begin PHASE-01 to define and document the scoring methodology before writing any code.
