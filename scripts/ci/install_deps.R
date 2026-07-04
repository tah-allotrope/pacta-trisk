#!/usr/bin/env Rscript
# install_deps.R
# Installs the R packages the TRISK pipeline chain needs. All packages used
# by scripts/*.R (see docs/PACTA_Beginner_Guide.md) are on CRAN, including
# the RMI/2DII stack (pacta.loanbook, r2dii.*, trisk.model) -- no GitHub
# remotes required.

cran_packages <- c(
  "arrow", "base64enc", "dplyr", "fs", "ggplot2", "ggrepel", "jsonlite",
  "pacta.loanbook", "purrr", "r2dii.analysis", "r2dii.data", "r2dii.match",
  "r2dii.plot", "readr", "rlang", "scales", "stringi", "tibble", "tidyr",
  "trisk.model", "xfun"
)

missing <- setdiff(cran_packages, rownames(installed.packages()))
if (length(missing) > 0) {
  install.packages(missing, repos = "https://cloud.r-project.org")
}

cat("All pipeline R dependencies installed.\n")
