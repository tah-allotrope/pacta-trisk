#!/usr/bin/env Rscript
# ==============================================================================
# trisk_power_demo.R
# Compatibility wrapper for the shared sector-aware TRISK runner.
# Runs the Vietnam TRISK Power demo using the shared sector runner.
#
# Prerequisite:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_prepare_inputs.R
#
# Run from project root:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_power_demo.R
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_power_demo.R --config engagements/<slug>/engagement_config.json
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(fs)
  library(ggplot2)
  library(purrr)
  library(readr)
  library(scales)
  library(tibble)
  library(tidyr)
})

suppressPackageStartupMessages(library(trisk.model))

source("R/engagement_config.R")
source("R/sector_registry.R")
source("R/trisk_core.R")

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  cfg <- load_engagement_config(get_config_arg(args))
  trisk_run_sector(cfg, "power")
}
