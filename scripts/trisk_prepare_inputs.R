# ==============================================================================
# trisk_prepare_inputs.R
# Build TRISK-ready input files for an engagement's synthetic Vietnam sectors.
#
# Outputs (default MCB mode only, see ASM-004 of the runway-completion plan):
#   data/vietnam_trisk_financial_features.csv
#   data/vietnam_trisk_company_mapping.csv
#   data/vietnam_trisk_assets_<sector>.csv
#   data/vietnam_trisk_scenarios_<sector>.csv
#   data/vietnam_trisk_ngfs_carbon_price_<sector>.csv
# Outputs (always, under cfg$paths$trisk_input_root):
#   <trisk_input_root>/<sector>_demo/{assets,scenarios,financial_features,ngfs_carbon_price}.csv
#
# Usage:
#   Rscript scripts/trisk_prepare_inputs.R [--config <path>]
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(tibble)
  library(tidyr)
})

source("R/engagement_config.R")
source("R/trisk_core.R")

cfg <- load_engagement_config(get_config_arg())

trisk_prepare_sector_inputs(cfg)
