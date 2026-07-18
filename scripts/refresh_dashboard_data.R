#!/usr/bin/env Rscript
# refresh_dashboard_data.R
# Republish the dashboard data snapshot from current pipeline outputs.
# Usage: Rscript scripts/refresh_dashboard_data.R [--config <path>]

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

source("R/engagement_config.R")
source("R/sector_registry.R")

cfg <- load_engagement_config(get_config_arg())

clear_dir <- function(path) {
  if (dir.exists(path)) {
    unlink(list.files(path, full.names = TRUE, all.files = TRUE, no.. = TRUE), recursive = TRUE, force = TRUE)
  }
}

# Required artifacts that fail to copy are collected here; the script exits
# non-zero at the end if any are missing, so a partial upstream run can never
# silently publish a half-populated snapshot.
misses_required <- character(0)

record_miss <- function(src, required) {
  message(sprintf("  [MISS] %s not found", src))
  if (required) {
    misses_required <<- c(misses_required, src)
  }
}

copy_file <- function(src, dest_dir, required = TRUE) {
  if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  if (file.exists(src)) {
    file.copy(src, dest_dir, overwrite = TRUE)
    message(sprintf("  [OK] %s -> %s", src, dest_dir))
    invisible(TRUE)
  } else {
    record_miss(src, required)
    invisible(FALSE)
  }
}

copy_png_group <- function(src_dir, dest_dir, required = TRUE) {
  if (!dir.exists(src_dir)) {
    record_miss(paste0(src_dir, " (directory)"), required)
    return(invisible(NULL))
  }
  if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  pngs <- list.files(src_dir, pattern = "\\.png$", full.names = TRUE)
  if (length(pngs) == 0) {
    record_miss(paste0(src_dir, " (no PNGs)"), required)
    return(invisible(NULL))
  }
  for (f in pngs) {
    file.copy(f, dest_dir, overwrite = TRUE)
    message(sprintf("  [OK] %s -> %s", f, dest_dir))
  }
}

pacta_files <- file.path(cfg$paths$pacta_output_dir, c(
  "02_vn_matched_prioritized.csv",
  "04_vn_ms_company.csv",
  "04_vn_ms_portfolio.csv",
  "05_vn_sda_portfolio.csv",
  "06_vn_ms_alignment_2030.csv",
  "06_vn_sda_alignment_2030.csv"
))

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

snapshot_dir <- cfg$paths$snapshot_dir

trisk_manifest <- sector_registry() %>%
  filter(sector %in% cfg$trisk_sectors) %>%
  select(sector, label, folder, price_unit, pathway_unit, alignment_mode, grid_available, disclaimer)

for (f in pacta_files) {
  copy_file(f, file.path(snapshot_dir, "pacta"))
}

copy_png_group(cfg$paths$pacta_output_dir, file.path(snapshot_dir, "pacta"))

# Reports are optional (warn only): a missing rendered report should not block
# the data snapshot from publishing.
for (f in report_files) {
  copy_file(f, file.path(snapshot_dir, "reports"), required = FALSE)
}

trisk_dest <- file.path(snapshot_dir, "trisk")
if (!dir.exists(trisk_dest)) dir.create(trisk_dest, recursive = TRUE)
clear_dir(trisk_dest)

grid_root <- file.path(trisk_dest, "grid")
dir.create(grid_root, recursive = TRUE, showWarnings = FALSE)

for (i in seq_len(nrow(trisk_manifest))) {
  sector <- trisk_manifest$sector[[i]]
  src_root <- file.path(cfg$paths$trisk_output_root, paste0(sector, "_demo"))
  input_root <- file.path(cfg$paths$trisk_input_root, paste0(sector, "_demo"))
  dest_root <- file.path(trisk_dest, sector)
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

  # The app reads only the consolidated grid artifacts; raw per-run CSVs under
  # runs/ stay in synthesis_output and are never published to the snapshot.
  grid_src_root <- file.path(cfg$paths$trisk_output_root, "grid", sector)
  grid_dest_root <- file.path(grid_root, sector)
  grid_file_names <- c("scenarios.csv", "borrower_results.parquet", "grid_meta.json")
  if (!dir.exists(grid_dest_root)) dir.create(grid_dest_root, recursive = TRUE, showWarnings = FALSE)
  for (name in grid_file_names) {
    copy_file(file.path(grid_src_root, name), grid_dest_root, required = cfg$run_grid)
  }
  grid_files <- file.path(grid_dest_root, grid_file_names)
  trisk_manifest$grid_available[[i]] <- all(file.exists(grid_files))
}

write_csv(trisk_manifest, file.path(trisk_dest, "manifest.csv"))
message(sprintf("  [OK] %s written", file.path(trisk_dest, "manifest.csv")))

if (length(misses_required) > 0) {
  message("\nMISSING REQUIRED artifacts — snapshot refresh FAILED:")
  for (m in unique(misses_required)) message(sprintf("  - %s", m))
  quit(status = 1)
}

message("Dashboard data snapshot refreshed.")
