# Active Context: PACTA Vietnam Project

> Last updated: 2026-03-20 (Session 6 — Vietnam-specific pipeline written, partially executed)

## Project Goal

Learn and run the **PACTA (Paris Agreement Capital Transition Assessment)** tool end-to-end as a complete beginner. Specifically:

1. Understand the PACTA ecosystem (`r2dii.data`, `r2dii.match`, `r2dii.analysis`)
2. Have a comprehensive beginner guide saved as markdown
3. Run a complete demo of the PACTA pipeline with results, visualizations, and interpretation
4. Generate a professional, shareable HTML report with embedded visualizations
5. Compare AI implementation against Staff's independent implementation and produce a comparison report
6. Synthesize a "best of both" production pipeline merging AI + Staff approaches into a single script and HTML report
7. Build a Vietnam-specific PACTA pipeline using synthetic Vietnamese bank data (MCB) and adapted scenarios (PDP8, NDC, NZE)

**Status: 1–6 COMPLETE. Step 7 IN PROGRESS (pipeline partially executed — see Session 6)**

---

## Project Structure

```
pacta-vietnam/
├── activeContext.md              # This file — project memory & state tracker
├── scripts/
│   ├── pacta_demo.R              # Original AI demo pipeline (532 lines, 6 phases)
│   ├── generate_report.R        # Original AI HTML report generator
│   └── pacta_synthesis.R        # ★ Synthesis pipeline: best-of-both (~690 lines, 8 sections + HTML)
├── compare/
│   ├── PACTA for Banks staff.Rmd  # Staff's independent Rmd implementation (Trang Tran)
│   ├── PACTA for Banks staff.html # Staff's rendered HTML output
│   ├── MathJax staff.js           # MathJax library bundled for staff HTML
│   ├── compare_report.R           # Comparison report generator (AI vs Staff)
│   └── output/                    # 13 side-by-side comparison charts (PNG)
│       ├── 01_match_comparison.png
│       ├── 02a_power_techmix_ai.png
│       ├── 02b_power_techmix_staff.png
│       ├── 03a_auto_techmix_ai.png
│       ├── 03b_auto_techmix_staff.png
│       ├── 04a_renew_traj_ai.png
│       ├── 04b_renew_traj_staff.png
│       ├── 05a_cement_ai.png
│       ├── 05b_cement_staff.png
│       ├── 06a_steel_ai.png
│       ├── 06b_steel_staff.png
│       ├── 07_coverage_pie_staff.png
│       └── 08_alignment_overview_ai.png
├── output/
│   ├── 01_loanbook_sample.csv   # Sample of loanbook input data (20 rows)
│   ├── 01_abcd_sample.csv       # Sample of ABCD asset data (20 rows)
│   ├── 02_matched_raw.csv       # 326 rows of raw fuzzy matches
│   ├── 02_matched_prioritized.csv  # 177 rows after prioritization
│   ├── 03_match_coverage_by_sector.png
│   ├── 04_market_share_targets_portfolio.csv  # 1,210 rows
│   ├── 04_market_share_targets_company.csv    # 37,349 rows
│   ├── 05_power_techmix.png
│   ├── 06_power_renewables_trajectory.png
│   ├── 07_power_coal_trajectory.png
│   ├── 08_automotive_techmix.png
│   ├── 09_automotive_ev_trajectory.png
│   ├── 10_sda_targets_portfolio.csv  # 220 rows
│   ├── 11_cement_emission_intensity.png
│   ├── 12_steel_emission_intensity.png
│   ├── 13_alignment_summary_market_share.csv
│   ├── 13_alignment_summary_sda.csv
│   └── 14_alignment_overview.png
├── docs/
│   └── PACTA_Beginner_Guide.md  # Comprehensive beginner guide (439 lines)
├── reports/
│   ├── PACTA_Alignment_Report.html     # AI demo report (312 KB)
│   ├── PACTA_Comparison_Report.html    # AI vs Staff comparison (321 KB)
│   └── PACTA_Synthesis_Report.html     # ★ Best-of-both synthesis report (345 KB)
├── synthesis_output/              # ★ Output from synthesis pipeline
│   ├── 01_matched_raw.csv         # 312 raw fuzzy matches (min_score=0.9)
│   ├── 01_review_needed.csv       # 23 matches with score < 1.0 for manual review
│   ├── 02_matched_prioritized.csv # 177 prioritized matches
│   ├── 03_coverage_pie.png        # Coverage pie chart (with "Not in Scope")
│   ├── 04_coverage_bar.png        # Coverage bar chart by sector
│   ├── 05_market_share_portfolio.csv  # 1,210 portfolio-level market share rows
│   ├── 05_market_share_company.csv    # 37,349 company-level rows
│   ├── 06_power_techmix.png       # r2dii.plot power technology mix
│   ├── 06_sda_portfolio.csv       # 220 SDA target rows
│   ├── 07_alignment_market_share.csv  # Market share alignment gaps
│   ├── 07_alignment_sda.csv       # SDA alignment gaps
│   ├── 07_auto_techmix.png        # r2dii.plot automotive technology mix
│   ├── 08_power_renewables_traj.png   # Renewables trajectory
│   ├── 09_power_coal_traj.png     # Coal trajectory
│   ├── 10_auto_ev_traj.png        # EV trajectory
│   ├── 11_auto_ice_traj.png       # ICE trajectory (new — from Staff)
│   ├── 12_cement_emission.png     # r2dii.plot cement emission intensity
│   ├── 13_steel_emission.png      # r2dii.plot steel emission intensity
│   └── 14_alignment_overview.png  # Multi-sector alignment overview (custom ggplot2)
├── data/                          # ★ Vietnam-specific synthetic input data (Session 6)
│   ├── generate_vietnam_data.R    # Generator script for all 5 Vietnam CSVs
│   ├── vietnam_loanbook.csv       # Synthetic MCB loanbook (VND, ISIC codes, Vietnamese names)
│   ├── vietnam_abcd.csv           # Vietnam ABCD: EVN, Vinacomin, VinFast, THACO, VICEM, Hoa Phat, etc.
│   ├── vietnam_scenario_ms.csv    # PDP8/NDC/NZE market share scenario pathways
│   ├── vietnam_scenario_co2.csv   # CO2 intensity scenarios for cement & steel
│   └── vietnam_region_isos.csv    # Vietnam region ISO mapping
├── plans/                         # ★ Implementation plans (Session 6)
│   └── vietnam_bank_pacta_scenario_plan.md  # Full blueprint (~700 lines): Vietnam context, data design, roadmap
├── scripts/
│   ├── debug_ms.R                 # ★ Diagnostic for market share region/metric debugging
│   └── pacta_vietnam_scenario.R   # ★ Vietnam pipeline for Mekong Commercial Bank (1352 lines)
├── synthesis_output/vietnam/      # ★ Partial outputs from Vietnam pipeline (Sections 1–9 only)
│   ├── 01_vn_matched_raw.csv
│   ├── 02_vn_matched_prioritized.csv
│   ├── 03_vn_coverage_pie.png
│   ├── 04_vn_ms_portfolio.csv
│   ├── 04_vn_ms_company.csv
│   ├── 05_vn_power_techmix.png
│   ├── 06_vn_coal_trajectory.png
│   ├── 07_vn_renewables_trajectory.png
│   ├── 08_vn_auto_techmix.png
│   └── 09_vn_ev_trajectory.png
│   (MISSING: SDA outputs, alignment gaps, alignment overview, HTML report)
└── .opencode/                    # OpenCode tool internals (do not edit)
```

## What Was Done (Chronological)

### Session 1–2: Research through Report Generation

| Phase | Description | Outcome |
|---|---|---|
| A. Research | Studied DeepWiki pages for r2dii.data/match/analysis + official PACTA cookbook | Synthesized into beginner guide |
| B. Guide | Created `PACTA_Beginner_Guide.md` | 368-line comprehensive reference |
| C. Environment | Installed R 4.5.2, all packages to user library | Working R environment |
| D. Demo | Wrote & ran `pacta_demo.R` (6 phases) | 12 plots + 10 CSVs (Phases 1–4 clean) |
| E. Bug Fix | Fixed SDA metric naming bug (demo vs real scenario names) | All 18 outputs clean |
| F. Discussion | Interpreted all results across 4 sectors | Full alignment verdict |
| G. Report | Built `generate_report.R` with base64 image embedding | Self-contained 312 KB HTML |

### Session 3: Cleanup & Reorganization

- Updated `activeContext.md` with all findings and final state
- Added "Gotchas & Lessons Learned" section to `PACTA_Beginner_Guide.md`
- Deleted redundant files (`nul` artifact, `pacta_fix_rerun.R`)
- Reorganized into `scripts/`, `output/`, `docs/`, `reports/` structure

### Session 4: AI vs Staff Comparison Report

- **Goal:** Compare the AI-generated PACTA demo (`scripts/pacta_demo.R`) against the staff's independent R Markdown implementation (`compare/PACTA for Banks staff.Rmd` by Trang Tran)
- **Approach:** Built `compare/compare_report.R` — a single R script that re-runs both matching and analysis pipelines side-by-side, generates 13 comparison charts, and produces a self-contained HTML report
- **Key activities:**
  - Reviewed staff's 542-line `.Rmd` covering methodology, data dictionaries, matching, tech mix, trajectories, and emission intensity
  - Identified 14 dimensions of methodological difference (matching strategy, visualization library, coverage analysis, etc.)
  - Installed and used `r2dii.plot` + `ggrepel` to reproduce staff's official PACTA chart style
  - Ran both pipelines: AI fuzzy matching (326 raw → 177 prioritized) vs Staff exact matching (289 raw → 177 prioritized)
  - Generated side-by-side charts for power, automotive, cement, and steel sectors
  - Computed quantitative alignment gaps from both pipelines
  - Produced 10-section comparison HTML report (321 KB) with embedded charts
- **Output:** `reports/PACTA_Comparison_Report.html` + 13 PNGs in `compare/output/`

### Session 5: Best-of-Both Synthesis Pipeline

- **Goal:** Create a unified `scripts/pacta_synthesis.R` that merges the best elements from the AI demo and Staff implementations into a single production-quality pipeline and self-contained HTML report
- **Approach:** Single R script (~690 lines) with 8 pipeline sections + HTML generation, incorporating all 6 "Best of Both" recommendations from Session 4
- **Key activities:**
  - Read all four source files (`pacta_demo.R`, `generate_report.R`, `PACTA for Banks staff.Rmd`, `compare_report.R`) for synthesis
  - Wrote `scripts/pacta_synthesis.R` implementing:
    1. **Sector pre-join** before matching (Staff pattern) — enables mismatch validation
    2. **Fuzzy matching** with `min_score=0.9` + manual review flag for scores <1.0 + sector mismatch check
    3. **Coverage analysis** with pie chart + bar chart including "Not in Scope" category (Staff pattern)
    4. **Market share analysis** at portfolio and company levels with `r2dii.plot` techmix and trajectory charts (including ICE)
    5. **SDA analysis** for cement and steel with `r2dii.plot` emission intensity charts
    6. **Alignment gap calculation** — direction-aware, with both market share and SDA gaps
    7. **Multi-sector alignment overview chart** (custom ggplot2 faceted bar chart)
    8. **10-section HTML report** with methodology docs, data dictionary, KPI cards, and embedded charts
  - Executed the script successfully — no errors, only expected warnings (2 NA bars in power techmix, ggrepel label hints)
  - Verified output: 345 KB HTML with 11 base64-embedded charts, 10 h2 sections, 11 PNG charts + 8 CSVs in `synthesis_output/`
- **Results confirmed:**
  - 312 raw matches (vs 326 at default threshold, 289 exact) — 23 flagged for manual review
  - 177 prioritized matches (convergence confirmed)
  - Sector mismatch check: PASS
  - All alignment gaps match previous sessions (auto EV -0.5pp, hybrid -13.2pp, ICE +13.8pp, cement +76%, steel +37%)
  - Power sector still shows NA at 2025 for most technologies (demo data limitation)
- **Output:** `reports/PACTA_Synthesis_Report.html` + 19 files in `synthesis_output/` (11 PNGs + 8 CSVs)

### Session 6: Vietnam-Specific PACTA Pipeline (2026-03-20)

- **Goal:** Replace demo data with a Vietnam-realistic synthetic scenario — synthetic loanbook for "Mekong Commercial Bank (MCB)", Vietnam ABCD (EVN, Vinacomin, VinFast, THACO, VICEM, Hoa Phat, etc.), and adapted climate scenarios (PDP8, NDC, IEA NZE)
- **Key activities:**
  - Created `plans/vietnam_bank_pacta_scenario_plan.md` — comprehensive blueprint covering Vietnam energy context (PDP8, NDC, JETP), bank loanbook design, ABCD design, scenario adaptation, and 11-section implementation roadmap
  - Created `data/generate_vietnam_data.R` + 5 CSV files:
    - `vietnam_loanbook.csv` — synthetic MCB loanbook in VND with ISIC codes and Vietnamese company names (EVN subsidiaries, THACO, VinFast, VICEM, Hoa Phat, Vinacomin, etc.)
    - `vietnam_abcd.csv` — ABCD with Vietnamese company production data for power/auto/cement/steel/coal sectors
    - `vietnam_scenario_ms.csv` — market share pathways for PDP8, Vietnam NDC, and IEA NZE 2050
    - `vietnam_scenario_co2.csv` — CO2 intensity scenarios for cement and steel
    - `vietnam_region_isos.csv` — Vietnam region ISO mapping
  - Wrote `scripts/pacta_vietnam_scenario.R` (1352 lines): full pipeline with VSIC→ISIC→PACTA custom mapping, ASCII normalization for Vietnamese diacritics, `min_score=0.8` fuzzy matching, PDP8/NDC scenario alignment, bilingual Vietnamese/English HTML report targeting Vietnamese bank audience
  - Wrote `scripts/debug_ms.R` — diagnostic script to investigate market share `region`/`metric` output structure
- **Execution status: PARTIAL**
  - Pipeline ran through Section 9 (EV trajectory charts) — 10 files produced in `synthesis_output/vietnam/`
  - Pipeline stopped before completing: SDA analysis (cement/steel), alignment gap calculation, alignment overview chart, and HTML report (`reports/PACTA_Vietnam_Bank_Report.html`) were NOT produced
  - Root cause: likely a market share region/metric mismatch (debug_ms.R was written mid-session to diagnose)
- **Outstanding issue:** Need to run `debug_ms.R` output and fix the pipeline so it completes through HTML report generation

---

## Key Findings (Demo Portfolio)

| Sector | Method | Aligned? | Gap | Notes |
|---|---|---|---|---|
| Automotive — Electric | Market Share | NO | -0.5pp share | Minor gap, nearly aligned |
| Automotive — Hybrid | Market Share | NO | -13.2pp share | Major underproduction |
| Automotive — ICE | Market Share | NO | +13.8pp share | Overproduction vs target |
| Power | Market Share | Incomplete | N/A | Most tech has NA at 2025 |
| Cement | SDA | NO | +76% above target | Worst misalignment |
| Steel | SDA | NO | +37% above target | Only 4% match coverage |

**Verdict:** Demo portfolio is not Paris-aligned in any sector.

---

## Comparison Findings: AI vs Staff (Session 4)

### Quantitative Convergence

Both implementations reach the **same alignment verdict** despite different matching strategies. Key numbers:

| Metric | AI Approach | Staff Approach | Delta |
|---|---|---|---|
| Raw matches | 326 | 289 | +37 (fuzzy extras) |
| Prioritized matches | 177 | 177 | 0 |
| MS target rows | 1,210 | 1,210 | 0 |
| SDA target rows | 220 | 220 | 0 |
| Sectors misaligned | 4/4 | 4/4 | Same |

The fuzzy approach captures 37 additional raw matches (score < 1.0), but after prioritization both converge to 177. This confirms the demo dataset was designed for clean exact matching.

### Methodological Differences (14 dimensions)

| Dimension | AI | Staff | Better For |
|---|---|---|---|
| Report format | .R script + HTML generator | .Rmd (literate programming) | Staff: reproducibility |
| Matching | Default fuzzy (~0.8+) | Exact only (min_score=1) | AI: real-world data; Staff: demo |
| Sector pre-join | During coverage | Before matching | Staff: enables mismatch check |
| Mismatch validation | Not present | Validates sector_matched vs sector | Staff |
| Visualization | Custom ggplot2 | r2dii.plot + ggrepel labels | Staff: standardized & labeled |
| Coverage analysis | Bar chart only | Pie + bar with "Not in Scope" | Staff: more complete |
| Data labels | None on charts | ggrepel percentage/value labels | Staff |
| ICE trajectory | Not charted | Included | Staff |
| Company-level analysis | Yes (37K rows) | Not included | AI: borrower engagement |
| Alignment gap calc | Explicit + overview chart | Visual only | AI: quantitative rigor |
| CPS scenario | Included | Not included | AI: additional benchmark |
| Methodology docs | In report (post-hoc) | Inline with code | Staff: learning tool |
| PACTA references | None | 5 official links | Staff |
| Vietnam context | Not addressed | VSIC/NAICS notes, ABCD challenges | Staff |

### Recommended "Best of Both" Architecture

For the production version targeting Vietnamese bank data:

1. **Matching:** Fuzzy (min_score=0.9) with mandatory manual review of <1.0 matches (AI flexibility + Staff rigor)
2. **Visualization:** `r2dii.plot` for standardized charts + custom ggplot2 for alignment overview (Staff charts + AI summary)
3. **Report format:** R Markdown for the analytical notebook + standalone HTML for stakeholder distribution (both)
4. **Content:** Staff's methodology docs & data dictionary + AI's alignment gap calculations & KPI cards
5. **Coverage:** Staff's pie + bar with "Not in Scope" category
6. **Sector classification:** Pre-join before matching (Staff pattern) to enable mismatch validation

---

## Technical Gotchas Discovered

These are important for anyone running PACTA with the R packages:

### 1. User Library Required on Windows
R system library at `C:\Program Files\R\R-4.5.2\library` is not writable without admin. Must use:
```r
install.packages("pkg", lib = Sys.getenv("R_LIBS_USER"))
library(pkg, lib.loc = Sys.getenv("R_LIBS_USER"))
```

### 2. Demo Scenario Metric Naming Asymmetry (Critical)
The `pacta.loanbook` demo datasets use scenario source `demo_2020`. This produces **different** metric naming conventions for the two analysis methods:

- **Market Share** metrics: `projected`, `target_sds`, `target_cps`, `target_sps`, `corporate_economy`
  - Pattern: `target_<scenario_name>` (standard)
- **SDA** metrics: `projected`, `target_demo`, `adjusted_scenario_demo`, `corporate_economy`
  - Pattern: `target_<scenario_source_suffix>` (non-standard)

This asymmetry means scripts that hardcode `target_sds` for SDA will crash when using demo data. The fix: always inspect `unique(sda_targets$emission_factor_metric)` before filtering.

### 3. Power Sector NA Values at 2025
Several power technologies (gascap, hydrocap, nuclearcap, renewablescap) have `NA` production values at 2025 in the `projected` metric. This causes `pivot_wider` to produce NA columns and alignment calculations to fail silently. Real ABCD data typically has 5–10 year projections.

### 4. Steel Match Coverage ~4%
Most demo steel borrowers could not be linked to physical asset data. This makes steel alignment results unreliable. In production: manually review unmatched borrowers and add intermediate parent names.

### 5. ggplot2 Silent Scale Warnings
When filtering data to a subset of metrics but providing `scale_*_manual()` mappings for non-present levels, ggplot2 silently ignores unused mappings. This is safe but can hide the fact that expected data is missing from the plot.

---

## Environment Details

| Component | Detail |
|---|---|
| R version | 4.5.2 |
| Rscript path | `C:\Program Files\R\R-4.5.2\bin\Rscript.exe` |
| User library | `C:\Users\tukum\AppData\Local/R/win-library/4.5` |
| Key packages | pacta.loanbook, r2dii.plot, ggrepel, dplyr, readr, ggplot2, tidyr, scales, base64enc |
| Platform | Windows (win32) |

---

## Possible Next Steps

- [x] ~~Explore `r2dii.plot` package for standardized PACTA visualizations~~ (done in Session 4)
- [x] ~~Merge implementations: Create a unified pipeline combining best elements from AI + Staff~~ (done in Session 5: `scripts/pacta_synthesis.R`)
- [x] ~~Add ICE trajectory chart~~ (included in synthesis pipeline)
- [x] ~~Implement sector mismatch validation~~ (included in synthesis pipeline)
- [x] ~~Replace demo data with a real or simulated Vietnam bank loanbook~~ (done in Session 6: synthetic MCB dataset)
- [x] ~~Source IEA WEO or NGFS scenarios for production-grade pathways~~ (done in Session 6: PDP8/NDC/NZE scenarios)
- [x] ~~Prepare VSIC-to-PACTA sector mapping~~ (done in Session 6: VSIC→ISIC→PACTA mapping in `pacta_vietnam_scenario.R`)
- [ ] **⚠️ URGENT: Fix Vietnam pipeline completion** — run `debug_ms.R`, diagnose market share region/metric issue, and complete pipeline through HTML report (`reports/PACTA_Vietnam_Bank_Report.html`)
- [ ] Build R Markdown version: Convert `pacta_synthesis.R` into an `.Rmd` literate programming notebook for internal use
- [ ] Investigate ABCD data sources for Vietnamese companies (Asset Impact or self-prepared)
- [ ] Build a Shiny dashboard for interactive exploration
- [ ] Extend analysis to oil & gas and aviation sectors
- [ ] Set up quarterly re-run monitoring framework

---

## Session Plan: TRISK Demo Roadmap (2026-04-16)

**Goal:** Draft a detailed multi-phase markdown plan to showcase TRISK, optionally combined with PACTA, using synthetic but publicly anchored Vietnam market data in a demo final report for a prospective Vietnam bank.

### Planned Work

- [x] Review existing repo context, prior plans, and TRISK research brief
- [x] Review extracted TRISK paper notes for sequencing, scope, and caveats
- [ ] Draft a new multi-phase plan in `plans/vietnam_bank_trisk_demo_plan.md`
- [ ] Record review notes and key decisions in this file after drafting

### Planning Notes

- TRISK should be framed as a downstream stress-test layer, not a replacement for PACTA.
- The most credible first TRISK demo in this repo is power-sector first, because local synthetic Vietnam data and the Baer et al. proof of concept both fit power best.
- The existing repo already covers most PACTA-side ingredients; the main missing TRISK inputs are synthetic financial features, price curves, carbon price curves, and schema mapping.

### Review / Results

- [x] Created new planning artifact: `plans/vietnam_bank_trisk_demo_plan.md`
- [x] Anchored the plan in repo research, especially `research/2026-04-08_integration-trisk-model-existing.md` and `research/Baer_TRISK_2022_extracted.txt`
- [x] Chose a phased strategy: stabilize PACTA baseline first, then build a power-sector TRISK pilot, then integrate both into a bank-facing final report
- [x] Explicitly positioned TRISK as a downstream risk layer that complements PACTA alignment outputs
- [x] Documented the need for synthetic but publicly anchored financial features and transition-price assumptions before any TRISK demo run

---

## Implementation Update: TRISK Pilot (2026-04-16)

**Goal:** Implement the new TRISK demo plan with runnable artifacts, phase/final report outputs, and a real package-backed power-sector pilot where possible.

### What Was Completed

- Re-ran `scripts/pacta_vietnam_scenario.R` and confirmed the Vietnam PACTA baseline now completes end to end, including SDA outputs, alignment tables, charts, and `reports/PACTA_Vietnam_Bank_Report.html`
- Installed `trisk.model` 2.6.1 into the user R library and verified the package's actual folder-based input contract and runnable API
- Created `docs/TRISK_Demo_Assumptions.md` to document the synthetic financial, scenario, and carbon-price assumptions used in the pilot
- Created `scripts/trisk_prepare_inputs.R` to generate TRISK-ready Vietnam power demo inputs and export a runnable folder package to `output/trisk_inputs/power_demo`
- Created `scripts/trisk_power_demo.R` to run a real `trisk.model::run_trisk()` power-sector stress test and produce borrower-level summary outputs and figures in `synthesis_output/trisk/power_demo`

### Key Output Artifacts

- `data/vietnam_trisk_assets_power.csv`
- `data/vietnam_trisk_scenarios_power.csv`
- `data/vietnam_trisk_financial_features.csv`
- `data/vietnam_trisk_ngfs_carbon_price.csv`
- `output/trisk_inputs/power_demo/`
- `synthesis_output/trisk/power_demo/company_summary.csv`
- `synthesis_output/trisk/power_demo/top_borrowers_alignment_trisk.csv`
- `synthesis_output/trisk/power_demo/figures/01_npv_change_by_company.png`
- `synthesis_output/trisk/power_demo/figures/02_pd_change_by_company.png`
- `synthesis_output/trisk/power_demo/figures/03_priority_score_top10.png`

### Early Pilot Findings

- The package-backed TRISK pilot runs successfully for the Vietnam synthetic power portfolio using a baseline scenario `VN_PDP8_BASELINE` and a stress scenario `VN_NZE_STRESS`
- Highest modeled stress priority borrowers are coal-heavy entities: `Nghi Son Power LLC`, `Vinacomin Power JSC`, and `International Power Mong Duong`
- `EVN (Electricity of Vietnam)` remains materially exposed because of its coal share even though the portfolio also contains hydro and gas assets
- Renewable platforms (`Trung Nam Group`, `BIM Group`, `T&T Group`, `Thanh Thanh Cong Group`, `Xuan Thien Group`) show positive NPV change and negative PD change under the synthetic stress setup
- `Dung Quat LNG Power Consortium` currently yields zero baseline output in the pilot because its pre-commissioning years create a zero-value edge case under the current setup; this should be treated as a demo-model limitation and refined later

### Important Caveats

- The TRISK pilot is still synthetic and should be interpreted as a comparative transition-stress ranking tool, not a production credit model
- The current package-backed pilot only covers `power`, not the full multi-sector Vietnam book
- Carbon pricing is driven by the package's `increasing_carbon_tax_50` logic, which is useful for demo stress behavior but not Vietnam policy forecasting
- One package warning remains: 5 rows were removed during Merton-model compatibility checks in the PD stage; the run still completed and produced usable borrower-level outputs

---

## Next Implementation Plan: TRISK Sensitivity Package (2026-04-16)

**Goal:** Strengthen the power-sector TRISK pilot by adding one-parameter-at-a-time sensitivity runs for the key model settings already identified in the plan.

### Planned Work

- [ ] Extend `scripts/trisk_power_demo.R` so the base run parameters are centralized and reusable
- [ ] Add one-at-a-time sensitivity runs for `shock_year`, `discount_rate`, `risk_free_rate`, and `market_passthrough`
- [ ] Export a borrower-level sensitivity table and a compact summary artifact in `synthesis_output/trisk/power_demo/`
- [ ] Re-run the power demo and verify the new outputs are generated cleanly
- [ ] Record the main sensitivity findings and any caveats here

### Why This Next

- Sensitivity analysis is already part of the approved TRISK roadmap and is the fastest way to improve demo credibility without destabilizing the working pilot
- It is lower-risk than reworking the LNG edge case immediately because the current zero-output behavior is documented, while sensitivity adds new decision-useful evidence around robustness

### Review / Results

- [x] Refactored `scripts/trisk_power_demo.R` so the base-case TRISK run parameters are centralized and reused across all runs
- [x] Added one-at-a-time sensitivity runs for `shock_year`, `discount_rate`, `risk_free_rate`, and `market_passthrough`
- [x] Verified the script now produces borrower-level sensitivity outputs: `sensitivity_results.csv`, `sensitivity_summary.csv`, and `run_catalog.csv`
- [x] Verified each sensitivity case writes to its own run directory under `synthesis_output/trisk/power_demo/runs/`
- [x] Confirmed the headline borrower ranking is stable across all tested sensitivities: `Nghi Son Power LLC` remains the top-ranked stressed borrower in every case
- [x] Confirmed `market_passthrough` is the most decision-relevant tested sensitivity for ranking shifts in this demo run, with the largest borrower-level score change observed for `PVN Power Corporation`
- [x] Confirmed `shock_year` changes move relative severity among mid-ranked names, especially `PVN Power Corporation` and `Vietnam Hydropower JSC`, without displacing the top coal names
- [ ] Remaining known issue: `Dung Quat LNG Power Consortium` still produces `NA` sensitivity outputs because the underlying zero-baseline edge case remains unresolved

---

## Phase 01: Host Selection and Data Contract (2026-04-26)

**Goal:** Lock hosting, define data contract, snapshot artifacts.

**Plan source:** `plans/2026-04-25-pacta-trisk-bank-showcase-dashboard-plan.md`

**Grill Me answers:**
- Public URL (no password gate), add prominent synthetic-data disclaimer
- TRISK sensitivity grid: batch run needed in PHASE-04
- Full scope, no fixed deadline
- Custom domain: `pactavn.streamlit.app`
- Aggregated views only (no raw loanbook rows)

**Completed:**
- [x] `docs/hosting-decision.md` — hosting comparison matrix, Streamlit Community Cloud recommended, `pactavn.streamlit.app` subdomain, Hugging Face Spaces fallback
- [x] `dashboard/data/pacta/` — 6 CSVs + 9 PNGs from `synthesis_output/vietnam/`
- [x] `dashboard/data/trisk/` — 10 CSVs + 3 PNGs from `synthesis_output/trisk/power_demo/`
- [x] `dashboard/data/reports/` — 7 HTML reports from `reports/`
- [x] `dashboard/data/README.md` — column-level provenance for every artifact
- [x] `scripts/refresh_dashboard_data.R` — one-shot copy script to republish snapshot
- [x] Total `dashboard/data/` size: ~2 MB (well under 100 MB limit)

**Next phase:** PHASE-02 — Streamlit app scaffold (`dashboard/app.py`, pages, loaders, theme).

---

## Phase 02-03: Streamlit Scaffold + PACTA Alignment (2026-04-26)

**Goal:** Build the dashboard shell and the first client-facing alignment page against the frozen `dashboard/data/` snapshot.

### Planned Work

- [x] Create `dashboard/app.py` landing page with public-demo framing and synthetic-data disclaimer
- [x] Create page stubs for `2_TRISK_Risk.py`, `3_Reports.py`, and `4_Methodology.py`
- [x] Create shared loaders and chart helpers in `dashboard/lib/`
- [x] Add Streamlit config, requirements, and dashboard README
- [x] Implement `dashboard/pages/1_PACTA_Alignment.py` with KPI cards, sector filter, interactive tables, static chart panels, and downloads
- [x] Add dashboard smoke/data-loader tests and run verification
- [x] Record results and remaining gaps here

### Review / Results

- [x] Added package-scoped dashboard modules: `dashboard/__init__.py`, `dashboard/lib/__init__.py`
- [x] Added reusable data loaders in `dashboard/lib/loaders.py` for PACTA, TRISK, markdown, bytes, and report file listing
- [x] Added Plotly helper wrappers in `dashboard/lib/charts.py`
- [x] Added shared demo banner and footer styling in `dashboard/lib/branding.py`
- [x] Added the main Streamlit shell in `dashboard/app.py`
- [x] Added the implemented PACTA page and three stub pages under `dashboard/pages/`
- [x] Added `dashboard/.streamlit/config.toml`, `dashboard/requirements.txt`, and `dashboard/README.md`
- [x] Added smoke/data-loader tests in `dashboard/tests/`
- [x] Verified with `python -m pytest dashboard/tests` -> `4 passed`
- [x] Verified app boot with `python -m streamlit run dashboard/app.py --server.headless true`

### Remaining Gaps

- [ ] `2_TRISK_Risk.py` is still a stub; PHASE-04 remains to be implemented
- [ ] `3_Reports.py` and `4_Methodology.py` are still stubs; PHASE-05 remains to be implemented
- [ ] Public-mode decision superseded the old optional password-gate task in the original draft plan

---

## Phase 04-05: TRISK Risk + Reports / Methodology (2026-04-26)

**Goal:** Complete the client-facing dashboard narrative so the app can carry a viewer from alignment, to firm-level stress, to longer-form evidence and methodology.

### Planned Work

- [x] Extend `dashboard/data/README.md` and snapshot contents so TRISK input assumptions are available inside the frozen dashboard data contract
- [x] Implement `dashboard/pages/2_TRISK_Risk.py` with company ranking, scatter, sensitivity explorer, assumptions panel, and zip download
- [x] Implement `dashboard/pages/3_Reports.py` with inline HTML embeds and download buttons for the four priority reports
- [x] Implement `dashboard/pages/4_Methodology.py` with PACTA/TRISK framing, citations, and source-file access
- [x] Polish `dashboard/app.py`, shared branding, and README for the now-complete page set
- [x] Run tests and boot verification, then record results here

### Review / Results

- [x] Copied TRISK input snapshot files into `dashboard/data/trisk/`: `assets.csv`, `financial_features.csv`, `scenarios.csv`, `ngfs_carbon_price.csv`
- [x] Extended `dashboard/data/README.md` to document the TRISK input assumption files and actual output columns used by the dashboard
- [x] Extended `dashboard/lib/loaders.py` to expose TRISK inputs, company trajectories, and a reports catalog
- [x] Extended `dashboard/lib/charts.py` with a ranked horizontal bar helper for borrower ranking and sensitivity views
- [x] Updated `dashboard/lib/branding.py` and `dashboard/app.py` to complete the landing-page narrative, “What’s new” callout, and Allotrope-branded footer
- [x] Implemented `dashboard/pages/2_TRISK_Risk.py` with borrower ranking, NPV vs PD scatter, sensitivity filter panel, assumptions tables, and a zip download of all TRISK snapshot files
- [x] Implemented `dashboard/pages/3_Reports.py` with inline HTML embedding and download actions for the four priority reports
- [x] Implemented `dashboard/pages/4_Methodology.py` with PACTA/TRISK framing, research excerpts, and downloadable source PDF
- [x] Updated `dashboard/README.md` to reflect completed Phases 04 and 05
- [x] Updated `scripts/refresh_dashboard_data.R` so future dashboard snapshot refreshes include the TRISK input assumption files
- [x] Expanded dashboard tests to cover the TRISK, Reports, and Methodology pages
- [x] Verified with `python -m pytest dashboard/tests` -> `7 passed`
- [x] Verified app boot with `python -m streamlit run dashboard/app.py --server.headless true`

### Remaining Gaps

- [ ] Phase 06 deployment and rehearsal tasks still remain: Streamlit Cloud setup, custom subdomain, smoke checklist on deployed URL, and demo script

---

## Phase 01-02 Packaging + Report (2026-04-27)

**Goal:** Package the already-implemented Bank Showcase phases 01 and 02 into a clean artifact set, verify the frozen data contract and dashboard scaffold still work, generate a phase report, and publish the resulting commit.

### Planned Work

- [x] Re-audit the repo against `plans/2026-04-25-pacta-trisk-bank-showcase-dashboard-plan.md` for Phase 01 and Phase 02 scope
- [x] Confirm the required Phase 01 outputs still exist: hosting decision, dashboard snapshot, and refresh script
- [x] Confirm the required Phase 02 outputs still exist: Streamlit shell, pages, loaders, theme, README, and tests
- [x] Run verification for the dashboard scaffold and snapshot refresh path
- [x] Generate a phase report artifact for the packaged Phase 01-02 state
- [ ] Commit and push only the relevant files for this packaging pass

### Review / Results

- [x] Confirmed the underlying implementation already existed in prior commits: `f65562f` (Phase 01) and `982e567` (Phase 02-03 scaffold work)
- [x] Re-validated the core Phase 01 files: `docs/hosting-decision.md`, `dashboard/data/README.md`, `dashboard/data/`, and `scripts/refresh_dashboard_data.R`
- [x] Re-validated the core Phase 02 files: `dashboard/app.py`, `dashboard/pages/`, `dashboard/lib/`, `dashboard/.streamlit/config.toml`, `dashboard/requirements.txt`, and `dashboard/tests/`
- [x] Re-ran `python -m pytest dashboard/tests` -> `7 passed`
- [x] Re-ran `Rscript scripts/refresh_dashboard_data.R` and confirmed the snapshot was fully republished into `dashboard/data/`
- [x] Generated phase artifact `reports/2026-04-27-bank-showcase-phase-01-02.html`

---

## Phase 03-04 Packaging + Report (2026-04-27)

**Goal:** Package the already-implemented Bank Showcase phases 03 and 04, verify the live PACTA and TRISK dashboard pages still satisfy the plan intent, generate a phase report, and publish the resulting commit.

### Planned Work

- [x] Re-audit the repo against `plans/2026-04-25-pacta-trisk-bank-showcase-dashboard-plan.md` for Phase 03 and Phase 04 scope
- [x] Confirm the required Phase 03 outputs still exist in the implemented dashboard pages and helpers
- [x] Confirm the required Phase 04 outputs still exist in the implemented dashboard pages, helpers, and snapshot files
- [x] Run verification for the full dashboard page set and snapshot refresh path
- [x] Generate a phase report artifact for the packaged Phase 03-04 state
- [ ] Commit and push only the relevant files for this packaging pass

### Review / Results

- [x] Confirmed the underlying implementation already existed in prior commits: `982e567` (Phase 02-03) and `03752de` (Phase 04-05)
- [x] Re-validated the core Phase 03 files: `dashboard/pages/1_PACTA_Alignment.py`, `dashboard/lib/loaders.py`, `dashboard/lib/charts.py`, and the `dashboard/data/pacta/` snapshot
- [x] Re-validated the core Phase 04 files: `dashboard/pages/2_TRISK_Risk.py`, `dashboard/lib/loaders.py`, `dashboard/lib/charts.py`, and the `dashboard/data/trisk/` snapshot
- [x] Re-ran `python -m pytest dashboard/tests` -> `7 passed`
- [x] Re-ran `python -m streamlit run dashboard/app.py --server.headless true` and confirmed the app served successfully before the expected long-running process timeout
- [x] Re-ran `Rscript scripts/refresh_dashboard_data.R` and confirmed the PACTA/TRISK snapshot was fully republished into `dashboard/data/`
- [x] Generated phase artifact `reports/2026-04-27-bank-showcase-phase-03-04.html`

---

## TRISK Multisector Phases 01-02 (2026-04-28)

**Goal:** Accept the recommended defaults in the multisector expansion plan, lock the sector contract for `power`, `cement`, and `steel`, and implement the first two phases by refactoring the TRISK input builder to emit runnable sector packages.

### Planned Work

- [x] Update `plans/2026-04-28-trisk-multisector-expansion-plan.md` to accept the recommended defaults and clear the open questions
- [x] Document the phase-1 sector contract, mapping rules, output layout, and SDA translation logic
- [x] Refactor `scripts/trisk_prepare_inputs.R` from a power-only builder into a shared multi-sector input generator
- [x] Extend synthetic financial features to cover cement and steel borrowers
- [x] Generate and verify runnable input folders for `power`, `cement`, and `steel`
- [x] Generate a phase report artifact for the completed phases 01-02 work

### Review / Results

- [x] Added `docs/trisk_multisector_contract.md` to pin the sector contract, folder layout, technology mappings, and SDA-to-TRISK translation rules
- [x] Replaced the power-only mapping logic in `scripts/trisk_prepare_inputs.R` with a shared `sector_specs` contract and sector-aware builders for `assets`, `scenarios`, and carbon price curves
- [x] Extended `data/vietnam_trisk_financial_features.csv` generation to include `VN_ABCD_020` through `VN_ABCD_023`
- [x] Verified the generator with `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_prepare_inputs.R`
- [x] Confirmed generated runnable packages in `output/trisk_inputs/power_demo/`, `output/trisk_inputs/cement_demo/`, and `output/trisk_inputs/steel_demo/`
- [x] Resolved two verification issues during the phase: `purrr::imap()` argument order and cement/steel weighted-mean aggregation
- [x] Generated phase artifact `reports/2026-04-28-trisk-multisector-phases-1-2.html`

---

## TRISK Multisector Phases 03-04 (2026-04-29)

**Goal:** Implement the shared sector-aware TRISK runner, generate standardized cement and steel result folders, republish the dashboard snapshot into a manifest-backed multisector layout, and update the TRISK dashboard page to switch sectors cleanly.

### Planned Work

- [x] Extract the shared TRISK run logic into a reusable sector-aware script while preserving `scripts/trisk_power_demo.R` as a stable wrapper
- [x] Run and verify power, cement, and steel TRISK result folders with the same artifact contract
- [x] Refactor `scripts/refresh_dashboard_data.R` to publish sector folders plus `dashboard/data/trisk/manifest.csv`
- [x] Refactor the dashboard loaders and TRISK page to use the new sector-aware snapshot layout
- [x] Refresh the snapshot, run dashboard tests, and package a report artifact for the completed phases 03-04 work

### Review / Results

- [x] Added `scripts/trisk_sector_demo.R` as the shared package-backed runner for `power`, `cement`, and `steel`
- [x] Replaced `scripts/trisk_power_demo.R` with a thin compatibility wrapper that continues to run the power sector path
- [x] Generated and verified standardized result folders in `synthesis_output/trisk/power_demo/`, `synthesis_output/trisk/cement_demo/`, and `synthesis_output/trisk/steel_demo/`
- [x] Updated `scripts/refresh_dashboard_data.R` to publish `dashboard/data/trisk/<sector>/` plus `dashboard/data/trisk/manifest.csv`
- [x] Refactored `dashboard/lib/loaders.py` and `dashboard/pages/2_TRISK_Risk.py` for a manifest-backed sector selector and sector-specific ZIP exports
- [x] Updated `dashboard/app.py`, `dashboard/data/README.md`, `dashboard/tests/test_loaders.py`, and `dashboard/tests/test_smoke.py` for the new multisector TRISK contract
- [x] Verified the snapshot refresh with `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/refresh_dashboard_data.R`
- [x] Verified the dashboard with `python -m pytest dashboard/tests` -> `9 passed`
