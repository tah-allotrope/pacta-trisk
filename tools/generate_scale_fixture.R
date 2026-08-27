#!/usr/bin/env Rscript
# ==============================================================================
# tools/generate_scale_fixture.R
# Wave 3 PHASE-04: a SEEDED synthetic loanbook generator for scale
# benchmarking. scripts/generate_vietnam_data.R (the real MCB data source)
# is a 751-line transcript with zero RNG calls -- deliberately, because
# byte-identity depends on it being deterministic without a seed. This is a
# SEPARATE tool, never sourced by any pipeline step, that:
#   - writes ONLY to the path given on the command line (never to data/)
#   - is fully deterministic given the same --seed (same seed -> byte-
#     identical output, so a benchmark run is itself reproducible)
#
# Usage:
#   Rscript tools/generate_scale_fixture.R --loans <n> --counterparties <n> \
#     --seed <int> --out <dir>
#
# Writes <out>/loanbook.csv (intake/SCHEMA.md's required + currency columns)
# and <out>/abcd.csv (a matching asset-based-company-data fixture, one row
# per counterparty, for match-rate realism in a full-chain benchmark).
# ==============================================================================

suppressPackageStartupMessages({
  library(stringi)
})

get_flag <- function(args, name) {
  idx <- which(args == name)
  if (length(idx) == 0 || idx[[1]] >= length(args)) return(NULL)
  args[[idx[[1]] + 1]]
}

#' Generate a seeded synthetic BYOL-shaped loanbook and matching ABCD fixture.
#'
#' @param n_loans integer(1) — number of loan rows.
#' @param n_counterparties integer(1) — number of distinct borrowers, each
#'   assigned one or more of the n_loans rows.
#' @param seed integer(1) — RNG seed; identical arguments produce
#'   byte-identical output.
#' @param out_dir character(1) — destination directory, created if absent.
#' @return list(loanbook_path, abcd_path, n_loans, n_counterparties, seed).
#' @export
generate_scale_fixture <- function(n_loans, n_counterparties, seed, out_dir) {
  set.seed(seed)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  # Twenty accepted sector codes (intake_validate_and_map.R's
  # .sector_code_map) grouped by PACTA sector, so the fixture's match/intake
  # coverage is representative rather than uniform-random over sector codes
  # most of which map to "not in scope".
  sector_codes <- c(
    "3510", "35101", "35102", "35103", "3511",   # power
    "2910", "29101", "29102",                     # automotive
    "2394", "23941", "23942",                     # cement
    "2410", "24101", "24102"                      # steel
  )

  # Counterparty names: ASCII-safe generated strings, never real company
  # names -- this fixture is local-only benchmarking scratch space, not
  # something that should ever look like real client data if accidentally
  # retained.
  counterparty_ids <- sprintf("BENCH_CP_%06d", seq_len(n_counterparties))
  counterparty_names <- sprintf("Synthetic Borrower %06d JSC", seq_len(n_counterparties))
  counterparty_sector <- sample(sector_codes, n_counterparties, replace = TRUE)

  loan_counterparty_idx <- sample(seq_len(n_counterparties), n_loans, replace = TRUE)
  # Whole-VND exposure in the intake/SCHEMA.md-documented plausible range
  # (INV-006's threshold is 1e8; corporate loans here span 1e9-5e12).
  exposure_vnd <- round(exp(runif(n_loans, log(1e9), log(5e12))))
  credit_limit_vnd <- round(exposure_vnd * runif(n_loans, 1.05, 1.4))

  loanbook <- data.frame(
    counterparty_name = counterparty_names[loan_counterparty_idx],
    exposure_vnd = exposure_vnd,
    sector_code = counterparty_sector[loan_counterparty_idx],
    sector_code_system = "VSIC",
    credit_limit_vnd = credit_limit_vnd,
    currency = "VND",
    lei = NA_character_,
    tax_id = NA_character_,
    parent_name = NA_character_,
    parent_id = NA_character_,
    stringsAsFactors = FALSE
  )

  abcd <- data.frame(
    company_id = counterparty_ids,
    name_company = counterparty_names,
    sector_code = counterparty_sector,
    stringsAsFactors = FALSE
  )

  loanbook_path <- file.path(out_dir, "loanbook.csv")
  abcd_path <- file.path(out_dir, "abcd.csv")
  utils::write.csv(loanbook, loanbook_path, row.names = FALSE, na = "")
  utils::write.csv(abcd, abcd_path, row.names = FALSE, na = "")

  list(
    loanbook_path = loanbook_path, abcd_path = abcd_path,
    n_loans = n_loans, n_counterparties = n_counterparties, seed = seed
  )
}

if (identical(environment(), globalenv()) && sys.nframe() == 0L) {
  .cli_args <- commandArgs(trailingOnly = TRUE)
  n_loans <- as.integer(get_flag(.cli_args, "--loans"))
  n_counterparties <- as.integer(get_flag(.cli_args, "--counterparties"))
  seed <- as.integer(get_flag(.cli_args, "--seed"))
  out_dir <- get_flag(.cli_args, "--out")

  if (any(vapply(list(n_loans, n_counterparties, seed, out_dir), is.null, logical(1)))) {
    stop(paste(
      "Usage: Rscript tools/generate_scale_fixture.R --loans <n>",
      "--counterparties <n> --seed <int> --out <dir>"
    ), call. = FALSE)
  }
  if (n_counterparties > n_loans) {
    stop("generate_scale_fixture.R: --counterparties cannot exceed --loans", call. = FALSE)
  }

  result <- generate_scale_fixture(n_loans, n_counterparties, seed, out_dir)
  cat(sprintf(
    "[OK] Wrote %d loans across %d counterparties (seed %d) to %s\n",
    result$n_loans, result$n_counterparties, result$seed, out_dir
  ))
}
