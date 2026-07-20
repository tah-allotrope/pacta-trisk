#!/usr/bin/env Rscript
# pipeline_refresh.R
# One-command orchestrator: reruns the TRISK chain end to end and republishes
# the dashboard data snapshot, writing a manifest so the dashboard can show
# a "Data as of" badge instead of the copy being a silent hand-edit.
#
# Usage: Rscript scripts/pipeline_refresh.R [--full]
#
# Default (no flag): runs the 7-step TRISK refresh chain.
# With --full: prepends data generation + PACTA, appends engagement scoring (10 steps).
#
# Fails fast: if any step errors, later steps do not run and the manifest
# records which step failed.

suppressPackageStartupMessages({
  library(jsonlite)
})

source("R/step_runner.R")

args <- commandArgs(trailingOnly = TRUE)
full_mode <- "--full" %in% args

steps <- list(
  list(name = "trisk_prepare_inputs", script = "scripts/trisk_prepare_inputs.R", args = character()),
  list(name = "trisk_power_demo", script = "scripts/trisk_power_demo.R", args = character()),
  list(name = "trisk_sector_demo_cement", script = "scripts/trisk_sector_demo.R", args = "cement"),
  list(name = "trisk_sector_demo_steel", script = "scripts/trisk_sector_demo.R", args = "steel"),
  list(name = "trisk_scenario_grid", script = "scripts/trisk_scenario_grid.R", args = character()),
  list(name = "sector_prioritization", script = "scripts/sector_prioritization.R", args = character()),
  list(name = "refresh_dashboard_data", script = "scripts/refresh_dashboard_data.R", args = character())
)

if (full_mode) {
  steps <- c(
    list(
      list(name = "generate_vietnam_data", script = "scripts/generate_vietnam_data.R", args = character()),
      list(name = "pacta_vietnam_scenario", script = "scripts/pacta_vietnam_scenario.R", args = character())
    ),
    steps,
    list(
      list(name = "engagement_scoring", script = "scripts/engagement_scoring.R", args = character()),
      list(name = "refresh_audit", script = "scripts/generate_refresh_audit.R", args = character())
    )
  )
} else {
  steps <- c(
    steps,
    list(
      list(name = "refresh_audit", script = "scripts/generate_refresh_audit.R", args = character())
    )
  )
}

step_results <- run_steps(steps)

snapshot_files <- c(
  "dashboard/data/trisk/power/company_trajectories_latest.csv",
  "dashboard/data/trisk/cement/company_trajectories_latest.csv",
  "dashboard/data/trisk/steel/company_trajectories_latest.csv",
  "dashboard/data/trisk/power/npv_results_latest.csv",
  "dashboard/data/trisk/cement/npv_results_latest.csv",
  "dashboard/data/trisk/steel/npv_results_latest.csv"
)

manifest_path <- "dashboard/data/pipeline_manifest.json"
write_pipeline_manifest(step_results, manifest_path, row_count_files = snapshot_files)
cat(sprintf("\n[OK] Manifest written: %s\n", manifest_path))

manifest_status <- if (all(vapply(step_results, function(s) s$status == "ok", logical(1)))) "ok" else "failed"
if (!identical(manifest_status, "ok")) {
  quit(status = 1)
}

cat("\nPipeline refresh complete.\n")
