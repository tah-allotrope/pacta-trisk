#!/usr/bin/env Rscript
# =============================================================================
# run_engagement.R
# One-command orchestrator: executes the full delivery flow for a single
# engagement config -- intake (optional) -> validation report -> PACTA ->
# TRISK prepare -> TRISK per sector -> scenario grid (optional) ->
# prioritization -> snapshot -> scoring -> letters -> disclosure -- writing
# an engagement-scoped pipeline_manifest.json.
#
# Usage:
#   Rscript scripts/run_engagement.R --config engagements/<slug>/engagement_config.json [--raw-loanbook <path>] [--skip-intake] [--top-n <int>] [--dry-run]
#
# --raw-loanbook <path>: runs intake_validate_and_map.R against <path> first,
#   then all later steps use a resolved config whose inputs$loanbook_csv
#   points at the normalized output. Omit to run the pipeline against the
#   loanbook already named in the engagement config.
# --skip-intake: even with --raw-loanbook given, skip the intake + validation
#   report steps (useful for re-running downstream stages only).
# --top-n <int>: forwarded to generate_engagement_letters.R as --top_n.
# --dry-run: print the resolved step list (one "name: script args" line per
#   step) and exit 0 without executing or writing anything.
#
# Guard rail: refuses to run when the config's snapshot_dir is the public
# dashboard/data unless bank_slug is "mcb-demo" (prevents an engagement from
# overwriting the public snapshot).
# =============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
})

source("R/engagement_config.R")
source("R/step_runner.R")

args <- commandArgs(trailingOnly = TRUE)

get_flag_value <- function(args, name) {
  idx <- which(args == name)
  if (length(idx) == 0 || idx[[1]] >= length(args)) return(NULL)
  args[[idx[[1]] + 1]]
}

config_path <- get_flag_value(args, "--config")
if (is.null(config_path)) {
  stop(paste(
    "Usage: Rscript scripts/run_engagement.R --config <path>",
    "[--raw-loanbook <path>] [--skip-intake] [--top-n <int>] [--dry-run]"
  ), call. = FALSE)
}

raw_loanbook <- get_flag_value(args, "--raw-loanbook")
skip_intake  <- "--skip-intake" %in% args
top_n        <- get_flag_value(args, "--top-n")
dry_run      <- "--dry-run" %in% args

cfg <- load_engagement_config(config_path)

# --- Guard rail: never let a non-MCB engagement publish into the public
# snapshot directory. -------------------------------------------------------
if (identical(cfg$paths$snapshot_dir, "dashboard/data") && !identical(cfg$bank_slug, "mcb-demo")) {
  stop("Engagement snapshot_dir must not be the public dashboard/data", call. = FALSE)
}

run_intake <- !is.null(raw_loanbook) && !skip_intake
intake_dir <- file.path("engagements", cfg$bank_slug, "intake")
effective_config_path <- if (run_intake) {
  file.path("engagements", cfg$bank_slug, "engagement_config.resolved.json")
} else {
  config_path
}

# --- Build the ordered step list --------------------------------------------

build_step_list <- function(cfg, effective_config_path, run_intake, raw_loanbook, intake_dir, top_n) {
  steps <- list()

  if (run_intake) {
    intake_args <- c("--input", raw_loanbook, "--output-dir", intake_dir)
    if (isTRUE(cfg$anonymize)) intake_args <- c(intake_args, "--anonymize")
    steps <- c(steps, list(list(
      name = "intake", script = "scripts/intake_validate_and_map.R", args = intake_args
    )))
    steps <- c(steps, list(list(
      name = "validation_report",
      script = "scripts/generate_validation_report.R",
      args = c(
        "--intake-dir", intake_dir,
        "--output", file.path(cfg$paths$reports_dir, "Intake_Validation_Report.html"),
        "--bank-name", cfg$bank_name
      )
    )))
  }

  steps <- c(steps, list(
    list(name = "pacta_vietnam_scenario", script = "scripts/pacta_vietnam_scenario.R", args = c("--config", effective_config_path)),
    list(name = "trisk_prepare_inputs", script = "scripts/trisk_prepare_inputs.R", args = c("--config", effective_config_path))
  ))

  # Power first, for continuity with the default pipeline's step naming.
  sectors <- cfg$trisk_sectors
  if ("power" %in% sectors) sectors <- c("power", setdiff(sectors, "power"))
  for (sector in sectors) {
    steps <- c(steps, list(list(
      name = sprintf("trisk_sector_demo_%s", sector),
      script = "scripts/trisk_sector_demo.R",
      args = c(sector, "--config", effective_config_path)
    )))
  }

  if (isTRUE(cfg$run_grid)) {
    steps <- c(steps, list(list(
      name = "trisk_scenario_grid", script = "scripts/trisk_scenario_grid.R", args = c("--config", effective_config_path)
    )))
  }

  steps <- c(steps, list(
    list(name = "sector_prioritization", script = "scripts/sector_prioritization.R", args = c("--config", effective_config_path)),
    list(name = "refresh_dashboard_data", script = "scripts/refresh_dashboard_data.R", args = c("--config", effective_config_path)),
    list(name = "engagement_scoring", script = "scripts/engagement_scoring.R", args = c("--config", effective_config_path))
  ))

  letters_args <- c("--config", effective_config_path)
  if (!is.null(top_n)) letters_args <- c(letters_args, "--top_n", top_n)
  steps <- c(steps, list(list(
    name = "generate_engagement_letters", script = "scripts/generate_engagement_letters.R", args = letters_args
  )))

  steps <- c(steps, list(list(
    name = "generate_disclosure_pack", script = "scripts/generate_disclosure_pack.R", args = c("--config", effective_config_path)
  )))

  steps
}

full_steps <- build_step_list(cfg, effective_config_path, run_intake, raw_loanbook, intake_dir, top_n)

# --- Banner ------------------------------------------------------------------

cat(sprintf(
  "Engagement: %s (%s)\nEffective config: %s\nLoanbook: %s\n\n",
  cfg$bank_name, cfg$bank_slug, effective_config_path,
  if (!is.null(raw_loanbook)) raw_loanbook else cfg$inputs$loanbook_csv
))

if (dry_run) {
  cat("--dry-run: resolved step list (nothing executed)\n\n")
  for (s in full_steps) {
    cat(sprintf("%s: %s %s\n", s$name, s$script, paste(s$args, collapse = " ")))
  }
  quit(status = 0)
}

# --- Execute -------------------------------------------------------------

if (run_intake) {
  intake_step <- full_steps[[1]]
  intake_result <- run_step(intake_step)
  if (intake_result$status != "ok") {
    step_results <- list(intake_result)
  } else {
    dir.create(dirname(effective_config_path), recursive = TRUE, showWarnings = FALSE)
    resolved_cfg <- cfg
    resolved_cfg$inputs$loanbook_csv <- file.path(intake_dir, "normalized_loanbook.csv")
    write(toJSON(resolved_cfg, auto_unbox = TRUE, pretty = TRUE), effective_config_path)
    remaining_steps <- full_steps[-1]
    step_results <- c(list(intake_result), run_steps(remaining_steps))
  }
} else {
  step_results <- run_steps(full_steps)
}

manifest_path <- file.path("engagements", cfg$bank_slug, "pipeline_manifest.json")
write_pipeline_manifest(
  step_results, manifest_path,
  row_count_files = character(0),
  extra = list(bank_slug = cfg$bank_slug, config_path = effective_config_path)
)
cat(sprintf("\n[OK] Manifest written: %s\n", manifest_path))

manifest_status <- if (all(vapply(step_results, function(s) s$status == "ok", logical(1)))) "ok" else "failed"
if (!identical(manifest_status, "ok")) {
  quit(status = 1)
}

cat("\nEngagement run complete.\n")
