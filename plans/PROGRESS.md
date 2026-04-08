# PACTA Vietnam — Progress Report

> **As of:** 2026-03-21
> **Author:** Tung / Allotrope VC
> **Repo:** `pacta-vietnam`

---

## Project Overview

PACTA (Paris Agreement Capital Transition Assessment) climate transition analysis for a Vietnamese banking context. The project uses the `r2dii.*` / `pacta.loanbook` R package stack to assess how a synthetic mid-size Vietnamese commercial bank's loan portfolio aligns with Vietnam's national climate commitments and global Paris-aligned scenarios.

**Fictional bank:** Mekong Commercial Bank (MCB)
**Portfolio modelled:** 43 loans, ~25 trillion VND (~$1B USD), across 5 PACTA sectors
**Primary scenario:** Vietnam Power Development Plan 8 (PDP8, 2023)
**Comparison benchmarks:** IEA NZE (global), Vietnam NDC 2022 (conditional 43.5% target)
**Base year / horizon:** 2025 → 2030

---

## What Was Done (This Session)

### Planning
- Wrote `plans/vietnam_bank_pacta_scenario_plan.md` — 1,221-line end-to-end blueprint covering Vietnam energy context, loanbook design, ABCD data, scenario adaptation, pipeline code, expected results, visualisation specs, workarounds, and a 9-week roadmap.

### Synthetic Data Design (`data/generate_vietnam_data.R`)
- **Loanbook:** 43 loans, 25 trillion VND total. Named borrowers drawn from real Vietnamese companies (synthetic figures). Sector weights:

  | Sector | Weight | Exposure (bn VND) |
  |---|---|---|
  | Power — Coal | 28% | 7,000 |
  | Power — Gas | 12% | 3,000 |
  | Power — Hydro | 10% | 2,500 |
  | Power — Solar | 8% | 2,000 |
  | Power — Wind | 5% | 1,250 |
  | Automotive — ICE | 13% | 3,250 |
  | Automotive — EV | 4% | 1,000 |
  | Automotive — Hybrid | 1% | 250 |
  | Cement | 8% | 2,000 |
  | Steel | 6% | 1,500 |
  | Coal Mining | 5% | 1,250 |

- **Key borrowers:** EVN subsidiaries (Vinh Tan 1/4, Duyen Hai 1/3), Mong Duong 1/2, PVN Power plants (Nhon Trach, O Mon), Trung Nam Wind, BIM Solar, VinFast, THACO, VICEM, Hoa Phat, Pomina, TKV/Vinacomin, Dong Bac Coal.

- **ABCD (Asset-Based Company Data):** ~192 rows covering power plants (capacity by technology, 2025–2030), automotive OEM production (ICE/EV/hybrid, 2025–2030), cement emission intensity (2025–2030), steel emission intensity by route (BF/BOF vs EAF), coal mining production trajectory.

- **Scenarios:** Custom PDP8 market-share scenario (power + automotive) and CO2 intensity scenario (cement + steel) interpolated from PDP8 official targets; IEA NZE as secondary benchmark; region ISO mapping for `vn` → `vietnam` and `global`.

### Vietnam-Specific Workarounds Documented
- **VSIC → ISIC:** VSIC 2018 codes are structurally ISIC Rev.4; loanbook uses letter-prefixed codes (`D3511`, `C2910`, etc.) for `r2dii.data::sector_classifications` compatibility.
- **Diacritic normalisation:** `stringi::stri_trans_general(name, "Latin-ASCII")` applied to all company names before `match_name()` to prevent encoding-driven match failures.
- **BOT lock-in:** BOT coal plant ABCD shows flat capacity through PPA expiry year (~2035), then cliff-edge decline — not a smooth phase-down.
- **IEA data gap:** No Vietnam-specific IEA pathway exists; `region = "asia_pacific"` used for NZE benchmarking; PDP8 is primary domestic benchmark.
- **Coal mining method:** Market-share method (not SDA); compared against NGFS NZ2050 Asia-Pacific coal demand curve as a custom "production corridor" chart.

### Pipeline Script (`scripts/pacta_vietnam_scenario.R`)
Written and executed. Covers: data loading → VSIC pre-join → `match_name()` + `prioritize()` → `target_market_share()` (power, automotive) → `target_sda()` (cement, steel) → alignment gap calculations → chart generation → HTML report skeleton.

### Outputs Already Generated
**`synthesis_output/vietnam/`** (Vietnam MCB pipeline, first-run results):
- `01_vn_matched_raw.csv` — all candidate matches from `match_name()`
- `02_vn_matched_prioritized.csv` — one match per loan after `prioritize()`
- `03_vn_coverage_pie.png` — portfolio coverage by sector
- `04_vn_ms_company.csv`, `04_vn_ms_portfolio.csv` — market share alignment targets
- `05_vn_power_techmix.png` — power technology mix: MCB projected vs PDP8 target
- `06_vn_coal_trajectory.png` — coal capacity trajectory vs PDP8 and NZE
- `07_vn_renewables_trajectory.png` — renewables buildout vs PDP8 target
- `08_vn_auto_techmix.png` — automotive technology mix (ICE/EV/hybrid)
- `09_vn_ev_trajectory.png` — EV production trajectory vs NDC target

**`reports/`** (earlier synthesis pipeline runs):
- `PACTA_Alignment_Report.html`, `PACTA_Synthesis_Report.html`, `PACTA_Comparison_Report.html` — HTML outputs from generic demo and synthesis pipelines (use r2dii demo data, not MCB data; useful for methodology reference).

**`compare/output/`**: 8 PNG charts comparing two earlier implementation approaches (AI vs staff); used to validate convergence.

---

## Current State of Repo

### What Exists and Is Functional

| File / Folder | Status | Notes |
|---|---|---|
| `data/generate_vietnam_data.R` | ✅ Complete | Generates all 5 input CSVs |
| `data/vietnam_loanbook.csv` | ✅ Generated | 43-loan MCB loanbook in VND |
| `data/vietnam_abcd.csv` | ✅ Generated | ~192 rows, 5 sectors |
| `data/vietnam_scenario_ms.csv` | ✅ Generated | PDP8 market-share scenario |
| `data/vietnam_scenario_co2.csv` | ✅ Generated | PDP8 CO2 intensity scenario |
| `data/vietnam_region_isos.csv` | ✅ Generated | VN ISO mapping |
| `scripts/pacta_demo.R` | ✅ Complete | Generic demo; all 14 outputs in `output/` |
| `scripts/pacta_synthesis.R` | ✅ Complete | Best-of-both demo; outputs in `synthesis_output/` |
| `scripts/pacta_vietnam_scenario.R` | ✅ Written, first run done | Vietnam MCB pipeline; 9 outputs in `synthesis_output/vietnam/` |
| `scripts/generate_report.R` | ✅ Present | HTML report generator |
| `scripts/debug_ms.R` | ✅ Present | Debugging helper |
| `docs/PACTA_Beginner_Guide.md` | ✅ Present | Background reading |

### What Still Needs to Be Built

| Item | Phase | Priority |
|---|---|---|
| Manual review of low-score matches (< 1.0) from `02_vn_matched_prioritized.csv` | Phase 2, Wk 5 | **High** — alignment results are only as good as match quality |
| `data/overrides.csv` — known name-variant correction table | Phase 2, Wk 3 | High |
| Cement/steel SDA outputs for Vietnam run (not yet in `synthesis_output/vietnam/`) | Phase 2, Wk 5 | High |
| Three-scenario comparison run (PDP8 + NDC + IEA NZE side-by-side) | Phase 2, Wk 6 | High |
| Multi-sector alignment overview chart (traffic-light heatmap) | Phase 3, Wk 7 | Medium |
| Borrower-level alignment heatmap (top 10 by exposure) | Phase 3, Wk 7 | Medium |
| VinFast sensitivity analysis (base vs conservative production plans) | Phase 3, Wk 9 | Medium |
| Final 12-section HTML report: `reports/PACTA_Vietnam_Bank_Report.html` | Phase 3, Wk 8–9 | High — key deliverable |
| Vietnamese-language interpretive text for report sections | Phase 3, Wk 8 | Medium |
| JETP coal retirement acceleration scenario (optional sensitivity) | Phase 3, Wk 9 | Low |

---

## Suggested Next Steps (Weeks 1–3 to First Results)

The pipeline has already run through Week 4 of the 9-week roadmap. The critical path to meaningful, reviewable results is:

**Week 1 (immediate): Validate match quality**
Review `synthesis_output/vietnam/02_vn_matched_prioritized.csv`. Check: (a) how many loans matched at score = 1.0 vs < 1.0; (b) whether all 11 sectors have at least one matched borrower; (c) whether EVN, VinFast, VICEM, and TKV matched correctly. For any failures, add corrected name pairs to `data/overrides.csv` and rerun `match_name()` with the override table.

**Week 2: Complete sector coverage (cement, steel, coal)**
The existing Vietnam run appears to have produced power and automotive outputs but may be missing cement/steel SDA and coal mining charts. Run the SDA section of `pacta_vietnam_scenario.R` in isolation, check `target_sda()` returns rows for cement and steel, and generate `10_vn_cement_emission.png` and `11_vn_steel_emission.png` in `synthesis_output/vietnam/`. Add a manual "coal production corridor" chart for TKV/Vinacomin vs NGFS NZ2050.

**Week 3: Three-scenario comparison and alignment summary**
Run `target_market_share()` and `target_sda()` with all three scenarios (PDP8, IEA NZE, NDC conditional) and produce the multi-sector alignment summary table (§8.6 of the plan). This is the single most useful output for briefing a bank's ESG team: a traffic-light table showing which sectors/technologies are aligned, borderline, or misaligned under each scenario. Save as `synthesis_output/vietnam/12_vn_alignment_summary.csv` and a corresponding overview chart.

After Week 3 the project will have: full sector coverage, validated matches, and a clear alignment verdict — enough to draft the executive summary and commission the final report.

The full 9-week roadmap detail is in `plans/vietnam_bank_pacta_scenario_plan.md §11`.

---

## Key Design Decisions to Confirm

Before a developer begins implementation (or before the Week 2/3 work above), the following choices should be validated by the project owner:

1. **PDP8 scenario interpolation method.** The `vietnam_scenario_ms.csv` uses linear interpolation between PDP8's 2025 and 2030 anchor points. If technology buildout is expected to be back-loaded (common for offshore wind), a concave curve would be more realistic. *Decision: linear (current) or non-linear interpolation?*

2. **Coal ABCD trajectory for BOT plants.** The plan calls for flat capacity through 2035 for BOT coal (Mong Duong 2, Nghi Son 2). Confirm this is the correct contractual expiry year to use; an incorrect year will distort the alignment calculation for the largest sector. *Decision: confirm PPA expiry year per plant.*

3. **IEA region for NZE benchmarking.** Currently using `region = "asia_pacific"`. If a Vietnam-specific IEA pathway becomes available (e.g., from the JETP Secretariat or IEA Vietnam country study), it should replace this. *Decision: `asia_pacific` acceptable as proxy, or hold for better data?*

4. **VinFast ABCD: base case vs conservative.** The plan provides two sets of EV production figures (200k/year by 2030 vs 100k/year). The current `vietnam_abcd.csv` uses one version. *Decision: which case to use as the primary run? (Recommend conservative given VinFast's recent production track record.)*

5. **Report language.** The plan specifies a Vietnamese-language-compatible report with bilingual labels. *Decision: full bilingual (Vietnamese/English), English-only with Vietnamese annotations, or English-only for this version?*

6. **Output format for developer handoff.** The plan's 9-week roadmap assumes an R developer continuing the work. If the final user is a bank ESG team with no R environment, an R Markdown / Quarto notebook or a pre-rendered static HTML may be preferable over raw `.R` scripts. *Decision: confirm expected handoff format.*

---

*See `plans/vietnam_bank_pacta_scenario_plan.md` for the full specification.*
