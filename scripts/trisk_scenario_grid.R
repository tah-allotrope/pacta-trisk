#!/usr/bin/env Rscript
# ==============================================================================
# trisk_scenario_grid.R
# Build the precomputed multi-parameter TRISK scenario grid for the Scenario Builder.
#
# Usage:
#   Rscript scripts/trisk_scenario_grid.R
#   Rscript scripts/trisk_scenario_grid.R power
#   Rscript scripts/trisk_scenario_grid.R power --config engagements/<slug>/engagement_config.json
# ==============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(jsonlite)
  library(purrr)
  library(readr)
  library(tibble)
  library(tidyr)
})

source("R/engagement_config.R")
source("R/sector_registry.R")
source("R/severity_scoring.R")
source("R/trisk_core.R")

args <- commandArgs(trailingOnly = TRUE)

config_idx <- which(args == "--config")
positional_args <- if (length(config_idx) > 0) {
  args[-c(config_idx[[1]], config_idx[[1]] + 1)]
} else {
  args
}

cfg <- load_engagement_config(get_config_arg(args))

selected_sectors <- if (length(positional_args) == 0) {
  cfg$trisk_sectors
} else {
  unique(tolower(positional_args))
}

walk(selected_sectors, assert_supported_sector)

cat("========================================\n")
cat("Building TRISK scenario grid\n")
cat("========================================\n")

walk(selected_sectors, function(sector) trisk_run_grid(cfg, sector))

cat("\nScenario grid generation complete.\n")
