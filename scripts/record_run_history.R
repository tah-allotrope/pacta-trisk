#!/usr/bin/env Rscript
# ==============================================================================
# record_run_history.R
# Wave 3 PHASE-04: thin pipeline-step wrapper around R/run_history.R's
# record_run_history(). Registered as the last step for engagements with
# run_history: true (only mcb-demo, initially -- see R/engagement_config.R).
#
# Usage: Rscript scripts/record_run_history.R --config <path>
# ==============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
})

source("R/engagement_config.R")
source("R/run_history.R")

cfg <- load_engagement_config(get_config_arg())

# The headline artifacts worth keeping across time -- deliberately not the
# full output tree (history/ would grow without bound otherwise). Extend
# this list, not the mechanism, when a new headline artifact exists (e.g.
# financed_emissions.csv in a later phase).
artifacts <- c(
  file.path(cfg$paths$engagement_output_dir, "engagement_priority.csv"),
  file.path(cfg$paths$prioritization_output_dir, "sector_priority_ranking.csv"),
  file.path(cfg$paths$pacta_output_dir, "06_vn_ms_alignment_2030.csv"),
  file.path(cfg$paths$pacta_output_dir, "06_vn_sda_alignment_2030.csv")
)

run_dir <- record_run_history(cfg, artifacts)
cat(sprintf("[OK] Run history recorded: %s\n", run_dir))
