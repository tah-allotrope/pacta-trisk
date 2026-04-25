#!/usr/bin/env Rscript
# refresh_dashboard_data.R
# One-shot copy/rename script to republish the dashboard data snapshot
# from current pipeline outputs. Run after any pipeline re-run.
# Usage: Rscript scripts/refresh_dashboard_data.R

source_files <- list(
  pacta = c(
    "synthesis_output/vietnam/02_vn_matched_prioritized.csv",
    "synthesis_output/vietnam/04_vn_ms_company.csv",
    "synthesis_output/vietnam/04_vn_ms_portfolio.csv",
    "synthesis_output/vietnam/05_vn_sda_portfolio.csv",
    "synthesis_output/vietnam/06_vn_ms_alignment_2030.csv",
    "synthesis_output/vietnam/06_vn_sda_alignment_2030.csv"
  ),
  trisk = c(
    "output/trisk_inputs/power_demo/assets.csv",
    "synthesis_output/trisk/power_demo/company_summary.csv",
    "synthesis_output/trisk/power_demo/company_trajectories_latest.csv",
    "output/trisk_inputs/power_demo/financial_features.csv",
    "output/trisk_inputs/power_demo/ngfs_carbon_price.csv",
    "synthesis_output/trisk/power_demo/npv_results_latest.csv",
    "synthesis_output/trisk/power_demo/pd_results_latest.csv",
    "synthesis_output/trisk/power_demo/pd_summary.csv",
    "synthesis_output/trisk/power_demo/run_catalog.csv",
    "output/trisk_inputs/power_demo/scenarios.csv",
    "synthesis_output/trisk/power_demo/sensitivity_results.csv",
    "synthesis_output/trisk/power_demo/sensitivity_summary.csv",
    "synthesis_output/trisk/power_demo/top_borrowers_alignment_trisk.csv"
  ),
  reports = c(
    "reports/PACTA_Vietnam_Bank_Report.html",
    "reports/PACTA_Alignment_Report.html",
    "reports/PACTA_Synthesis_Report.html",
    "reports/PACTA_Comparison_Report.html",
    "reports/2026-04-16-final-vietnam-bank-trisk-demo.html",
    "reports/2026-04-16-trisk-power-pilot.html",
    "reports/2026-04-16-pacta-baseline-stabilization.html"
  )
)

dest_dirs <- list(
  pacta = "dashboard/data/pacta",
  trisk = "dashboard/data/trisk",
  reports = "dashboard/data/reports"
)

copy_pngs <- list(
  pacta = list(src = "synthesis_output/vietnam", dest = "dashboard/data/pacta"),
  trisk = list(src = "synthesis_output/trisk/power_demo/figures", dest = "dashboard/data/trisk")
)

for (group in names(source_files)) {
  dest_dir <- dest_dirs[[group]]
  if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE)
  for (f in source_files[[group]]) {
    if (file.exists(f)) {
      file.copy(f, dest_dir, overwrite = TRUE)
      message(sprintf("  [OK] %s -> %s", f, dest_dir))
    } else {
      message(sprintf("  [MISS] %s not found", f))
    }
  }
}

for (group in names(copy_pngs)) {
  info <- copy_pngs[[group]]
  pngs <- list.files(info$src, pattern = "\\.png$", full.names = TRUE)
  for (f in pngs) {
    file.copy(f, info$dest, overwrite = TRUE)
    message(sprintf("  [OK] %s -> %s", f, info$dest))
  }
}

message("Dashboard data snapshot refreshed.")
