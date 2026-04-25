# Dashboard Data Artifacts

> **Provenance:** All files are snapshots from the PACTA R pipeline (`scripts/pacta_vietnam_scenario.R`) and TRISK R pipeline (`scripts/trisk_power_demo.R`). Regenerate with `scripts/refresh_dashboard_data.R`.

## `pacta/` — PACTA Alignment Outputs (Vietnam MCB)

| File | Columns | Units | Provenance |
|---|---|---|---|
| `02_vn_matched_prioritized.csv` | `id_loan, id_2dii, name_direct_loantaker, sector, sector_abcd, score` | N/A (match quality) | `pacta_vietnam_scenario.R` §2 — `prioritize()` output |
| `04_vn_ms_company.csv` | `sector, technology, year, region, scenario_source, metric, production, technology_share, scope, percentage_of_initial_production_by_scope` | MW (power), vehicles (auto) | `pacta_vietnam_scenario.R` §4 — `target_market_share()` company level |
| `04_vn_ms_portfolio.csv` | Same columns as company-level | Same | `pacta_vietnam_scenario.R` §4 — `target_market_share()` portfolio level |
| `05_vn_sda_portfolio.csv` | `sector, year, region, scenario_source, emission_factor_metric, emission_factor_value` | tCO2/MWh (cement, steel) | `pacta_vietnam_scenario.R` §5 — `target_sda()` portfolio level |
| `06_vn_ms_alignment_2030.csv` | `sector, technology, scenario, projected_share, target_share, gap_pp` | Percentage points | `pacta_vietnam_scenario.R` §6 — alignment gap calc |
| `06_vn_sda_alignment_2030.csv` | `sector, scenario, projected_intensity, target_intensity, gap_pct` | % above/below target | `pacta_vietnam_scenario.R` §6 — SDA alignment gap |
| `05_vn_power_techmix.png` | Power technology mix bar chart | MW share | `pacta_vietnam_scenario.R` §4 |
| `06_vn_coal_trajectory.png` | Coal capacity trajectory | MW | `pacta_vietnam_scenario.R` §4 |
| `07_vn_renewables_trajectory.png` | Renewables buildout vs PDP8 | MW | `pacta_vietnam_scenario.R` §4 |
| `08_vn_auto_techmix.png` | Automotive technology mix | vehicles/year | `pacta_vietnam_scenario.R` §4 |
| `09_vn_ev_trajectory.png` | EV production trajectory | vehicles/year | `pacta_vietnam_scenario.R` §4 |
| `10_vn_cement_sda.png` | Cement emission intensity | tCO2/MWh | `pacta_vietnam_scenario.R` §5 |
| `11_vn_steel_sda.png` | Steel emission intensity | tCO2/MWh | `pacta_vietnam_scenario.R` §5 |
| `12_vn_alignment_overview.png` | Multi-sector alignment overview | Traffic-light | `pacta_vietnam_scenario.R` §7 |
| `13_vn_coal_stranded_risk.png` | Coal stranded risk chart | MW at risk | `pacta_vietnam_scenario.R` §7 |

## `trisk/` — TRISK Power-Sector Stress-Test Outputs

| File | Columns | Units | Provenance |
|---|---|---|---|
| `company_summary.csv` | `company_name, sector, technology, baseline_npv, stress_npv, npv_change_pct, pd_change, var_95` | VND, %, bp | `trisk_power_demo.R` — base run |
| `assets.csv` | `company_id, company_name, asset_id, sector, technology, capacity, capacity_factor, emission_factor` | MW, factor, tCO2/unit | `trisk_prepare_inputs.R` — power asset input snapshot |
| `financial_features.csv` | `company_id, pd, net_profit_margin, debt_equity_ratio, volatility` | ratio / decimal | `trisk_prepare_inputs.R` — synthetic borrower financial assumptions |
| `scenarios.csv` | `scenario, scenario_type, scenario_geography, sector, technology, scenario_year, scenario_price, scenario_pathway, scenario_capacity_factor` | USD/MWh-eq, MW | `trisk_prepare_inputs.R` — baseline and stress scenario inputs |
| `ngfs_carbon_price.csv` | `year, model, scenario, scenario_geography, variable, unit, carbon_tax` | USD/t CO2 | `trisk_prepare_inputs.R` — carbon tax input curve |
| `npv_results_latest.csv` | `company_id, company_name, scenario, year, npv` | VND | `trisk_power_demo.R` — NPV term structure |
| `pd_results_latest.csv` | `company_id, company_name, scenario, year, pd` | Decimal probability | `trisk_power_demo.R` — PD term structure |
| `pd_summary.csv` | `company_name, baseline_pd_1y, stress_pd_1y, delta_pd_1y, baseline_pd_5y, stress_pd_5y, delta_pd_5y` | bp | `trisk_power_demo.R` — PD summary |
| `sensitivity_results.csv` | `run_label, parameter_name, parameter_value, company_name, npv_change, pd_change, stress_priority_score, delta_priority_vs_base` | %, bp, score | `trisk_power_demo.R` — sensitivity analysis |
| `sensitivity_summary.csv` | `parameter_name, parameter_value, rank_stability, top_borrower, max_score_change` | Various | `trisk_power_demo.R` — sensitivity summary |
| `top_borrowers_alignment_trisk.csv` | `company_name, pacta_alignment_gap_pp, trisk_priority_score, combined_rank` | pp, score, rank | `trisk_power_demo.R` — PACTA + TRISK combined |
| `run_catalog.csv` | `run_label, parameter, value, timestamp, input_folder` | N/A | `trisk_power_demo.R` — run registry |
| `01_npv_change_by_company.png` | NPV change bar chart | % | `trisk_power_demo.R` — figure |
| `02_pd_change_by_company.png` | PD change bar chart | bp | `trisk_power_demo.R` — figure |
| `03_priority_score_top10.png` | Top 10 stress priority | Score | `trisk_power_demo.R` — figure |

## `reports/` — Static HTML Reports

| File | Description | Size |
|---|---|---|
| `PACTA_Vietnam_Bank_Report.html` | Full Vietnam MCB alignment report | ~1.2 MB |
| `PACTA_Alignment_Report.html` | Original AI demo alignment report | 312 KB |
| `PACTA_Synthesis_Report.html` | Best-of-both synthesis report | 345 KB |
| `PACTA_Comparison_Report.html` | AI vs Staff comparison report | 321 KB |
| `2026-04-16-final-vietnam-bank-trisk-demo.html` | Final TRISK demo report | ~1.5 MB |
| `2026-04-16-trisk-power-pilot.html` | TRISK power pilot report | ~1 MB |
| `2026-04-16-pacta-baseline-stabilization.html` | PACTA baseline report | ~800 KB |

## Notes

- All monetary values are in synthetic **Vietnamese Dong (VND)** unless otherwise noted
- All PACTA alignment gaps are calculated at the **2030 horizon** against PDP8 / IEA NZE / Vietnam NDC scenarios
- TRISK NPV/VaR/PD values are scenario-horizon shock summaries, **not** 1-year regulatory PDs
- Data is **synthetic** — for demo and methodology education only; does not represent real bank portfolio data
