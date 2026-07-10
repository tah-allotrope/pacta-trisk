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
      list(name = "generate_vietnam_data", script = "data/generate_vietnam_data.R", args = character()),
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

git_sha <- tryCatch(
  trimws(system("git rev-parse HEAD", intern = TRUE)),
  error = function(e) NA_character_
)
if (length(git_sha) == 0 || identical(git_sha, "")) git_sha <- NA_character_

count_rows <- function(path) {
  if (!file.exists(path)) return(NA_integer_)
  tryCatch(length(readLines(path)) - 1L, error = function(e) NA_integer_)
}

run_step <- function(step) {
  cat(sprintf("\n=== %s ===\n", step$name))
  t0 <- Sys.time()
  cmd <- c("Rscript", step$script, step$args)
  status <- system2("Rscript", args = c(step$script, step$args))
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  list(name = step$name, status = if (status == 0) "ok" else "failed", seconds = round(elapsed, 1))
}

step_results <- list()
for (step in steps) {
  result <- run_step(step)
  step_results[[length(step_results) + 1]] <- result
  if (result$status != "ok") {
    cat(sprintf("\n[FAILED] Step '%s' exited non-zero. Stopping pipeline.\n", result$name))
    break
  }
}

snapshot_files <- c(
  "dashboard/data/trisk/power/company_trajectories_latest.csv",
  "dashboard/data/trisk/cement/company_trajectories_latest.csv",
  "dashboard/data/trisk/steel/company_trajectories_latest.csv",
  "dashboard/data/trisk/power/npv_results_latest.csv",
  "dashboard/data/trisk/cement/npv_results_latest.csv",
  "dashboard/data/trisk/steel/npv_results_latest.csv"
)

manifest <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  git_sha = git_sha,
  steps = step_results,
  status = if (all(vapply(step_results, function(s) s$status == "ok", logical(1)))) "ok" else "failed",
  row_counts = setNames(as.list(vapply(snapshot_files, count_rows, integer(1))), snapshot_files)
)

manifest_path <- "dashboard/data/pipeline_manifest.json"
write(toJSON(manifest, auto_unbox = TRUE, pretty = TRUE), manifest_path)
cat(sprintf("\n[OK] Manifest written: %s\n", manifest_path))

if (!identical(manifest$status, "ok")) {
  quit(status = 1)
}

cat("\nPipeline refresh complete.\n")
