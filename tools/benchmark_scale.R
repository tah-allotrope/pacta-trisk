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
  library(dplyr)
  library(tibble)
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
# normalize_sector_code() / map_sector_code(): the intake script guards its
# own main(), so sourcing it here reuses the mapping without running the CLI.
source("scripts/intake_validate_and_map.R")

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

  # match_name() timing -- the fuzzy-matching bottleneck named in
  # research/2026-08-19-...-brainstorm.md F-005.
  #
  # Wave 4 PHASE-05: this used to build a 5-column loanbook subset and an ABCD
  # with no `sector` column, so every call raised
  #   "Must have missing names: `sector_classification_direct_loantaker`"
  # which the tryCatch below swallowed into NA. Every match_seconds cell in
  # docs/scale_benchmark.csv was NA for that reason, not because matching was
  # slow. The normalized loanbook intake already emits is exactly r2dii-shaped
  # (same 13 columns as r2dii.data::loanbook_demo), so pass it through whole,
  # and build ABCD from the fixture's own abcd.csv with its sector codes mapped
  # to PACTA sectors -- giving a representative match rate rather than a
  # trivial 0%.
  normalized <- utils::read.csv(normalized_path, stringsAsFactors = FALSE)
  abcd_fixture <- utils::read.csv(fixture$abcd_path, stringsAsFactors = FALSE)
  abcd_for_match <- data.frame(
    company_id = abcd_fixture$company_id,
    name_company = abcd_fixture$name_company,
    sector = map_sector_code(
      vapply(
        seq_len(nrow(abcd_fixture)),
        function(i) normalize_sector_code(abcd_fixture$sector_code[i], "VSIC"),
        character(1)
      )
    ),
    stringsAsFactors = FALSE
  )
  # Rows whose code maps outside PACTA scope cannot match by construction.
  abcd_for_match <- abcd_for_match[abcd_for_match$sector != "not in scope", , drop = FALSE]

  # Mirror the production call exactly (R/pacta_core.R): the same VSIC->ISIC
  # classification extension and the same tuned fuzzy parameters. Without the
  # extension, r2dii rejects the pipeline's own ISIC codes as unknown and
  # matching returns zero rows, which would time a path the pipeline never
  # takes.
  vsic_to_pacta <- tibble::tribble(
    ~code_system, ~code,  ~sector,      ~borderline,
    "ISIC",       "3511", "power",       FALSE,
    "ISIC",       "2910", "automotive",  FALSE,
    "ISIC",       "2394", "cement",      FALSE,
    "ISIC",       "2410", "steel",       FALSE,
    "ISIC",       "0510", "coal",        FALSE,
    "ISIC",       "0610", "oil and gas", FALSE
  )
  sector_classification_ext <- dplyr::bind_rows(r2dii.data::sector_classifications, vsic_to_pacta)

  match_note <- ""
  t0_match <- Sys.time()
  matched <- tryCatch(
    match_name(
      normalized, abcd_for_match,
      by_sector = TRUE, min_score = 0.8, method = "jw", p = 0.1,
      sector_classification = sector_classification_ext
    ),
    error = function(e) {
      match_note <<- paste("match_name failed:", conditionMessage(e))
      NULL
    }
  )
  t_match <- as.numeric(difftime(Sys.time(), t0_match, units = "secs"))
  if (is.null(matched)) t_match <- NA_real_

  data.frame(
    n_loans = n_loans, n_counterparties = n_counterparties,
    fixture_seconds = round(t_fixture, 1), intake_seconds = round(t_intake, 1),
    match_seconds = if (is.na(t_match)) NA_real_ else round(t_match, 1),
    completed = TRUE,
    note = if (nzchar(match_note)) match_note else sprintf("match_rows=%d", if (is.null(matched)) 0L else nrow(matched)),
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
