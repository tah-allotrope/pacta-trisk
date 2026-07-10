#!/usr/bin/env Rscript
# install_deps.R
# Installs the R packages the TRISK pipeline chain needs. Everything is on
# CRAN except trisk.model, which is no longer available there and installs
# from the Theia-Finance-Labs GitHub repo pinned to the commit matching the
# verified local version (2.6.1).

cran_packages <- c(
  "arrow", "base64enc", "dplyr", "fs", "ggplot2", "ggrepel", "glue",
  "jsonlite", "magrittr", "pacta.loanbook", "purrr", "r2dii.analysis",
  "r2dii.data", "r2dii.match", "r2dii.plot", "readr", "remotes", "rlang",
  "scales", "stringi", "tibble", "tidyr", "uuid", "xfun", "zoo"
)

# trisk.model 2.6.1 — pinned commit on Theia-Finance-Labs/trisk.model@main.
trisk_model_ref <- "Theia-Finance-Labs/trisk.model@cf720666a10d5517135ca17b7b158ad0ca64824b"

# Prefer the repos configured by the environment (e.g. r-lib/actions
# setup-r with use-public-rspm installs fast Linux binaries from Posit
# Package Manager); fall back to CRAN cloud when nothing is configured.
repos <- getOption("repos")
if (is.null(repos) || length(repos) == 0 || identical(unname(repos["CRAN"]), "@CRAN@")) {
  repos <- c(CRAN = "https://cloud.r-project.org")
}

missing <- setdiff(cran_packages, rownames(installed.packages()))
if (length(missing) > 0) {
  install.packages(missing, repos = repos)
}

if (!"trisk.model" %in% rownames(installed.packages())) {
  remotes::install_github(trisk_model_ref, repos = repos, upgrade = "never")
}

still_missing <- setdiff(c(cran_packages, "trisk.model"), rownames(installed.packages()))
if (length(still_missing) > 0) {
  stop("Failed to install: ", paste(still_missing, collapse = ", "))
}

cat("All pipeline R dependencies installed.\n")
