#!/usr/bin/env Rscript
# =============================================================================
# Sector Prioritization Module (GAP-03)
# =============================================================================
# Combines PACTA alignment gaps, TRISK stress-test scores, and portfolio
# exposure weights into a ranked sector priority list for Decision 263 sectors.
#
# Usage: Rscript scripts/sector_prioritization.R [--w_alignment 0.35] [--w_stress 0.35] [--w_exposure 0.30] [--config <path>]
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(tidyr)
  library(ggplot2)
})

source("R/engagement_config.R")
source("R/prioritization_core.R")

args <- commandArgs(trailingOnly = TRUE)

parse_arg <- function(args, name, default) {
  idx <- which(args == paste0("--", name))
  if (length(idx) > 0 && idx < length(args)) {
    return(as.numeric(args[idx + 1]))
  }
  default
}

cfg <- load_engagement_config(get_config_arg(args))

weights <- list(
  w_alignment = parse_arg(args, "w_alignment", 0.35),
  w_stress    = parse_arg(args, "w_stress",    0.35),
  w_exposure  = parse_arg(args, "w_exposure",  0.30)
)

prioritize_sectors(cfg, weights)
