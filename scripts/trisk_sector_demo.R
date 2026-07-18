# ==============================================================================
# trisk_sector_demo.R
# Run a package-backed TRISK demo for a selected synthetic Vietnam sector.
#
# Usage:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_sector_demo.R power
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_sector_demo.R cement
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_sector_demo.R steel
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_sector_demo.R power --config engagements/<slug>/engagement_config.json
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

  config_idx <- which(args == "--config")
  positional_args <- if (length(config_idx) > 0) {
    args[-c(config_idx[[1]], config_idx[[1]] + 1)]
  } else {
    args
  }

  cfg <- load_engagement_config(get_config_arg(args))
  sector <- if (length(positional_args) >= 1) tolower(positional_args[[1]]) else "power"
  trisk_run_sector(cfg, sector)
}
