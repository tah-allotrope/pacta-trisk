#!/usr/bin/env Rscript
# ==============================================================================
# tools/benchmark_scale.R
# Wave 3 PHASE-04: measures how intake validation and fuzzy name matching
# scale with loanbook size and, independently, with distinct-counterparty
# count -- the two axes research/2026-08-26-...-brainstorm.md's N-006 named
# as the ones that matter (match_name() is quadratic-ish in distinct
# counterparties, not loan rows).
#
# Scope: this benchmarks intake (scripts/intake_validate_and_map.R, run as a
# subprocess so its own row-wise-pass cost shows up honestly) and
# r2dii.match::match_name() (in-process). It does NOT run the full PACTA/
# TRISK chain per configuration -- doing that for all nine grid cells was
# out of scope for the time available when this benchmark was built (see
# docs/scale_benchmark.md's "What was not measured" section). Measure first,
# optimize later, and say plainly what was not measured rather than guess.
#
# Usage:
#   Rscript tools/benchmark_scale.R [--timeout-seconds <n>] [--out <csv>]
#
# Writes one row per attempted (loans, counterparties) configuration to
# docs/scale_benchmark.csv, appending to any existing file (so a partial
# benchmark run can be resumed / extended without losing prior rows).
# ==============================================================================

suppressPackageStartupMessages({
  library(r2dii.match)
  library(r2dii.data)
})

args <- commandArgs(trailingOnly = TRUE)
get_flag <- function(args, name, default = NULL) {
  idx <- which(args == name)
  if (length(idx) == 0 || idx[[1]] >= length(args)) return(default)
  args[[idx[[1]] + 1]]
}

timeout_seconds <- as.numeric(get_flag(args, "--timeout-seconds", "3600"))
out_csv <- get_flag(args, "--out", "docs/scale_benchmark.csv")

source("tools/generate_scale_fixture.R")
source("R/matching_helpers.R")

LOAN_COUNTS <- c(1000L, 10000L, 50000L)
COUNTERPARTY_COUNTS <- c(200L, 1000L, 5000L)

sys_info <- Sys.info()
machine_desc <- sprintf(
  "%s %s, %d logical core(s), %s MB total RAM",
  sys_info[["sysname"]], sys_info[["release"]],
  parallel::detectCores(),
  tryCatch(round(as.numeric(system("wmic OS get TotalVisibleMemorySize", intern = TRUE)[2]) / 1024), error = function(e) NA)
)

#' Time one benchmark cell: generate the fixture, run intake as a
#' subprocess, then run match_name() in-process against an r2dii-shaped
#' ABCD table built from the fixture's own counterparties (so match rate is
#' representative rather than trivially 0% or 100%).
#' @return one-row data.frame; NA timing columns and
#'   completed = FALSE if the configuration did not finish within
#'   timeout_seconds.
benchmark_cell <- function(n_loans, n_counterparties, timeout_seconds) {
  cell_dir <- file.path("bench", sprintf("scale_%d_%d", n_loans, n_counterparties))
  unlink(cell_dir, recursive = TRUE, force = TRUE)

  t_fixture <- system.time(
    fixture <- generate_scale_fixture(n_loans, n_counterparties, seed = 1L, out_dir = cell_dir)
  )[["elapsed"]]

  intake_out <- file.path(cell_dir, "intake_output")
  t0 <- Sys.time()
  status <- tryCatch({
    system2(
      "Rscript",
      args = c("scripts/intake_validate_and_map.R", "--input", fixture$loanbook_path, "--output-dir", intake_out),
      timeout = timeout_seconds
    )
  }, error = function(e) NA_integer_)
  t_intake <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  if (is.na(status) || t_intake >= timeout_seconds) {
    return(data.frame(
      n_loans = n_loans, n_counterparties = n_counterparties,
      fixture_seconds = t_fixture, intake_seconds = NA_real_, match_seconds = NA_real_,
      completed = FALSE, note = "intake did not complete within timeout_seconds",
      stringsAsFactors = FALSE
    ))
  }

  normalized_path <- file.path(intake_out, "normalized_loanbook.csv")
  if (!file.exists(normalized_path)) {
    return(data.frame(
      n_loans = n_loans, n_counterparties = n_counterparties,
      fixture_seconds = t_fixture, intake_seconds = t_intake, match_seconds = NA_real_,
      completed = FALSE, note = "intake produced no normalized_loanbook.csv",
      stringsAsFactors = FALSE
    ))
  }

  # A minimal r2dii-shaped loanbook + ABCD pair, built from the fixture's own
  # counterparties, for match_name() timing (the fuzzy-matching bottleneck
  # named in research/2026-08-19-...-brainstorm.md F-005).
  normalized <- utils::read.csv(normalized_path, stringsAsFactors = FALSE)
  lb_for_match <- data.frame(
    id_loan = seq_len(nrow(normalized)),
    id_direct_loantaker = normalized$name_direct_loantaker,
    name_direct_loantaker = normalized$name_direct_loantaker,
    id_ultimate_parent = normalized$name_direct_loantaker,
    name_ultimate_parent = normalized$name_direct_loantaker,
    stringsAsFactors = FALSE
  )
  distinct_names <- unique(normalized$name_direct_loantaker)
  abcd_for_match <- data.frame(
    company_id = seq_along(distinct_names),
    name_company = distinct_names,
    stringsAsFactors = FALSE
  )

  t_match <- tryCatch(
    system.time(match_name(lb_for_match, abcd_for_match))[["elapsed"]],
    error = function(e) NA_real_
  )

  data.frame(
    n_loans = n_loans, n_counterparties = n_counterparties,
    fixture_seconds = round(t_fixture, 1), intake_seconds = round(t_intake, 1),
    match_seconds = round(t_match, 1), completed = TRUE, note = "",
    stringsAsFactors = FALSE
  )
}

results <- list()
for (n_loans in LOAN_COUNTS) {
  for (n_cp in COUNTERPARTY_COUNTS) {
    if (n_cp > n_loans) next  # counterparties cannot exceed loans
    cat(sprintf("\n=== Benchmarking %d loans x %d counterparties ===\n", n_loans, n_cp))
    row <- benchmark_cell(n_loans, n_cp, timeout_seconds)
    row$machine <- machine_desc
    row$measured_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    print(row)
    results[[length(results) + 1]] <- row
  }
}

out_df <- do.call(rbind, results)
dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
if (file.exists(out_csv)) {
  existing <- utils::read.csv(out_csv, stringsAsFactors = FALSE)
  out_df <- rbind(existing, out_df)
}
utils::write.csv(out_df, out_csv, row.names = FALSE)
cat(sprintf("\n[OK] Wrote %s (%d total rows)\n", out_csv, nrow(out_df)))
