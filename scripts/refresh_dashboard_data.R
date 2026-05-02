#!/usr/bin/env Rscript
# refresh_dashboard_data.R
# Republish the dashboard data snapshot from current pipeline outputs.
# Usage: Rscript scripts/refresh_dashboard_data.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

clear_dir <- function(path) {
  if (dir.exists(path)) {
    unlink(list.files(path, full.names = TRUE, all.files = TRUE, no.. = TRUE), recursive = TRUE, force = TRUE)
  }
}

copy_file <- function(src, dest_dir) {
  if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  if (file.exists(src)) {
    file.copy(src, dest_dir, overwrite = TRUE)
    message(sprintf("  [OK] %s -> %s", src, dest_dir))
  } else {
    message(sprintf("  [MISS] %s not found", src))
  }
}

copy_png_group <- function(src_dir, dest_dir) {
  if (!dir.exists(src_dir)) {
    message(sprintf("  [MISS] %s not found", src_dir))
    return(invisible(NULL))
  }
  if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  pngs <- list.files(src_dir, pattern = "\\.png$", full.names = TRUE)
  for (f in pngs) {
    file.copy(f, dest_dir, overwrite = TRUE)
    message(sprintf("  [OK] %s -> %s", f, dest_dir))
  }
}

copy_dir_contents <- function(src_dir, dest_dir) {
  if (!dir.exists(src_dir)) {
    message(sprintf("  [MISS] %s not found", src_dir))
    return(FALSE)
  }

  if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  files <- list.files(src_dir, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  if (length(files) == 0) {
    message(sprintf("  [MISS] %s is empty", src_dir))
    return(FALSE)
  }

  file.copy(files, dest_dir, recursive = TRUE, overwrite = TRUE)
  message(sprintf("  [OK] %s -> %s", src_dir, dest_dir))
  TRUE
}

pacta_files <- c(
  "synthesis_output/vietnam/02_vn_matched_prioritized.csv",
  "synthesis_output/vietnam/04_vn_ms_company.csv",
  "synthesis_output/vietnam/04_vn_ms_portfolio.csv",
  "synthesis_output/vietnam/05_vn_sda_portfolio.csv",
  "synthesis_output/vietnam/06_vn_ms_alignment_2030.csv",
  "synthesis_output/vietnam/06_vn_sda_alignment_2030.csv"
)

report_files <- c(
  "reports/PACTA_Vietnam_Bank_Report.html",
  "reports/PACTA_Alignment_Report.html",
  "reports/PACTA_Synthesis_Report.html",
  "reports/PACTA_Comparison_Report.html",
  "reports/2026-04-16-final-vietnam-bank-trisk-demo.html",
  "reports/2026-04-16-trisk-power-pilot.html",
  "reports/2026-04-16-pacta-baseline-stabilization.html",
  "reports/2026-04-28-trisk-multisector-phases-1-2.html"
)

trisk_sector_files <- c(
  "assets.csv",
  "company_summary.csv",
  "company_trajectories_latest.csv",
  "financial_features.csv",
  "ngfs_carbon_price.csv",
  "npv_results_latest.csv",
  "params_latest.csv",
  "pd_results_latest.csv",
  "pd_summary.csv",
  "run_catalog.csv",
  "scenarios.csv",
  "sensitivity_results.csv",
  "sensitivity_summary.csv",
  "top_borrowers_alignment_trisk.csv"
)

trisk_manifest <- tribble(
  ~sector,  ~label,  ~folder,       ~price_unit,            ~pathway_unit, ~alignment_mode, ~grid_available, ~disclaimer,
  "power",  "Power",  "power",     "USD/MWh-equivalent", "MW",         "borrower_ms",  FALSE,            "Borrower-level PACTA market-share gaps are available for power.",
  "cement", "Cement", "cement",    "USD/unit-equivalent", "tonnes",     "sector_sda",   FALSE,            "Cement currently uses sector-level SDA context, not borrower-specific alignment.",
  "steel",  "Steel",  "steel",     "USD/unit-equivalent", "tonnes",     "sector_sda",   FALSE,            "Steel currently uses sector-level SDA context, not borrower-specific alignment."
)

for (f in pacta_files) {
  copy_file(f, "dashboard/data/pacta")
}

copy_png_group("synthesis_output/vietnam", "dashboard/data/pacta")

for (f in report_files) {
  copy_file(f, "dashboard/data/reports")
}

if (!dir.exists("dashboard/data/trisk")) dir.create("dashboard/data/trisk", recursive = TRUE)
clear_dir("dashboard/data/trisk")

grid_root <- file.path("dashboard", "data", "trisk", "grid")
dir.create(grid_root, recursive = TRUE, showWarnings = FALSE)

for (i in seq_len(nrow(trisk_manifest))) {
  sector <- trisk_manifest$sector[[i]]
  src_root <- file.path("synthesis_output", "trisk", paste0(sector, "_demo"))
  input_root <- file.path("output", "trisk_inputs", paste0(sector, "_demo"))
  dest_root <- file.path("dashboard", "data", "trisk", sector)
  if (!dir.exists(dest_root)) dir.create(dest_root, recursive = TRUE, showWarnings = FALSE)

  for (name in trisk_sector_files) {
    src <- if (name %in% c("assets.csv", "financial_features.csv", "ngfs_carbon_price.csv", "scenarios.csv")) {
      file.path(input_root, name)
    } else {
      file.path(src_root, name)
    }
    copy_file(src, dest_root)
  }

  copy_png_group(file.path(src_root, "figures"), dest_root)

  grid_src_root <- file.path("synthesis_output", "trisk", "grid", sector)
  grid_dest_root <- file.path(grid_root, sector)
  grid_present <- copy_dir_contents(grid_src_root, grid_dest_root)
  trisk_manifest$grid_available[[i]] <- isTRUE(grid_present) &&
    file.exists(file.path(grid_dest_root, "scenarios.csv")) &&
    file.exists(file.path(grid_dest_root, "borrower_results.parquet")) &&
    file.exists(file.path(grid_dest_root, "grid_meta.json"))
}

write_csv(trisk_manifest, file.path("dashboard", "data", "trisk", "manifest.csv"))
message("  [OK] dashboard/data/trisk/manifest.csv written")

message("Dashboard data snapshot refreshed.")
