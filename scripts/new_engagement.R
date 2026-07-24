#!/usr/bin/env Rscript
# =============================================================================
# new_engagement.R
# Scaffolds a new engagement config under engagements/<slug>/.
#
# Usage:
#   Rscript scripts/new_engagement.R --slug <slug> --name "<Bank Name>" \
#     [--sectors power,cement,steel] [--grid] [--anonymize]
#
# The slug must match ^[a-z0-9-]+$. If engagements/<slug>/ already exists,
# the script exits non-zero to prevent accidental overwrites.
#
# Inputs are copied from the MCB defaults (the synthetic demo inputs). The
# orchestrator can override the loanbook path via --raw-loanbook at run time.
# All output paths are rooted under engagements/<slug>/ so a run never writes
# into the public dashboard/data snapshot unless explicitly configured.
# =============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
})

source("R/engagement_config.R")

args <- commandArgs(trailingOnly = TRUE)

get_flag_value <- function(args, name, default = NULL) {
  idx <- which(args == name)
  if (length(idx) == 0 || idx[[1]] >= length(args)) return(default)
  args[[idx[[1]] + 1]]
}

has_flag <- function(args, name) name %in% args

slug <- get_flag_value(args, "--slug")
bank_name <- get_flag_value(args, "--name")
sectors_raw <- get_flag_value(args, "--sectors", "power,cement,steel")
run_grid <- has_flag(args, "--grid")
anonymize <- has_flag(args, "--anonymize")

if (is.null(slug) || is.null(bank_name)) {
  stop("Usage: Rscript scripts/new_engagement.R --slug <slug> --name \"<Bank Name>\" [--sectors power,cement,steel] [--grid] [--anonymize]", call. = FALSE)
}

if (!grepl("^[a-z0-9-]+$", slug)) {
  stop(sprintf("Invalid slug '%s' — must match ^[a-z0-9-]+$", slug), call. = FALSE)
}

engagement_dir <- file.path("engagements", slug)
if (dir.exists(engagement_dir)) {
  stop(sprintf("Engagement directory already exists: %s", engagement_dir), call. = FALSE)
}

defaults <- .default_engagement_config()

sectors <- strsplit(sectors_raw, ",")[[1]]
sectors <- trimws(sectors)
sectors <- sectors[nzchar(sectors)]

supported <- c("power", "cement", "steel")
unsupported <- setdiff(sectors, supported)
if (length(unsupported) > 0) {
  stop(sprintf("Unsupported sectors: %s (supported: %s)",
               paste(unsupported, collapse = ", "),
               paste(supported, collapse = ", ")), call. = FALSE)
}

root <- file.path("engagements", slug)
cfg <- list(
  bank_name = bank_name,
  bank_slug = slug,
  inputs = defaults$inputs,
  trisk_sectors = sectors,
  run_grid = run_grid,
  paths = list(
    pacta_output_dir = file.path(root, "output", "pacta"),
    trisk_output_root = file.path(root, "output", "trisk"),
    trisk_input_root = file.path(root, "output", "trisk_inputs"),
    snapshot_dir = file.path(root, "snapshot"),
    reports_dir = file.path(root, "reports"),
    engagement_output_dir = file.path(root, "output", "engagement"),
    letters_output_dir = file.path(root, "output", "engagement_letters"),
    disclosure_output_dir = file.path(root, "output", "disclosure"),
    prioritization_output_dir = file.path(root, "output", "prioritization")
  ),
  anonymize = anonymize,
  # Explicit and FALSE: a scaffolded engagement must never publish into the
  # public dashboard/data snapshot without a deliberate, hand-edited opt-in.
  public_snapshot_allowed = FALSE
)

dir.create(engagement_dir, recursive = TRUE, showWarnings = FALSE)
config_path <- file.path(engagement_dir, "engagement_config.json")
write(toJSON(cfg, auto_unbox = TRUE, pretty = TRUE), config_path)

cat(sprintf("Created engagement config: %s\n", config_path))
cat(sprintf("  Bank: %s (%s)\n", bank_name, slug))
cat(sprintf("  Sectors: %s\n", paste(sectors, collapse = ", ")))
cat(sprintf("  Grid: %s | Anonymize: %s\n", run_grid, anonymize))
