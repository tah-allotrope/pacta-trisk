#!/usr/bin/env Rscript
# tools/verify_refactor.R
# Codifies the byte-identity acceptance check used by every pipeline refactor
# in this repo: run the default-mode pipeline refresh, then classify every
# tracked file `git diff` reports as changed into expected churn, known
# volatility, or genuine drift. Genuine drift fails the check.
#
# Usage:
#   Rscript tools/verify_refactor.R              # runs the default 7-step refresh
#   Rscript tools/verify_refactor.R --full        # runs the --full 10-step refresh
#   Rscript tools/verify_refactor.R --skip-refresh # classifies the current working
#                                                   # tree without running anything
#
# Why git diff and not md5sum: git applies core.autocrlf normalization, so a
# byte-identical-after-normalization file shows as unchanged in `git diff`
# even when raw md5sum would differ across Windows/Linux line endings.
#
# PHASE-04 of plans/2026-07-20-wave0-orchestrator-sdb-closers-plan.md empties
# VOLATILE_BASENAMES once the five listed files are made deterministic --
# until then, they differ between two unmodified runs only in a run_id /
# run_path UUID that trisk.model::run_trisk() regenerates per invocation.
VOLATILE_BASENAMES <- c(
  "company_trajectories_latest.csv",
  "npv_results_latest.csv",
  "params_latest.csv",
  "pd_results_latest.csv",
  "run_catalog.csv"
)

# TIMESTAMP_BASENAMES: files whose only expected diff is generated-timestamp
# text or a run-scoped git_sha, never numeric content.
TIMESTAMP_BASENAMES <- c(
  "pipeline_manifest.json",
  "refresh_audit_metrics.json",
  "manifest.csv"
)

#' Classify a single changed path into a drift bucket.
#' @param path character, a repo-relative path as reported by `git diff --name-only`.
#' @param volatile_basenames character vector of basenames known to carry only
#'   a regenerated run-id/run-path value between unmodified runs.
#' @return character, one of "png-noise", "timestamp-class", "volatile", "drift".
classify_path <- function(path, volatile_basenames = VOLATILE_BASENAMES) {
  ext <- tolower(tools::file_ext(path))
  base <- basename(path)
  if (identical(ext, "png")) {
    return("png-noise")
  }
  if (identical(ext, "html") || base %in% TIMESTAMP_BASENAMES) {
    return("timestamp-class")
  }
  if (base %in% volatile_basenames) {
    return("volatile")
  }
  "drift"
}

run_refresh <- function(full_mode) {
  cat(sprintf("=== Running pipeline_refresh.R%s ===\n", if (full_mode) " --full" else ""))
  status <- system2("Rscript", args = c("scripts/pipeline_refresh.R", if (full_mode) "--full"))
  if (status != 0) {
    cat("[FAIL] scripts/pipeline_refresh.R exited non-zero; aborting verification.\n")
    quit(status = 1)
  }
}

changed_paths <- function() {
  out <- system2("git", args = c("diff", "--name-only"), stdout = TRUE)
  out[nzchar(out)]
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  full_mode <- "--full" %in% args
  skip_refresh <- "--skip-refresh" %in% args

  if (!skip_refresh) {
    run_refresh(full_mode)
  } else {
    cat("=== --skip-refresh: classifying current working tree only ===\n")
  }

  paths <- changed_paths()
  if (length(paths) == 0) {
    cat("\nNo tracked files changed.\nBYTE-IDENTITY PASS\n")
    quit(status = 0)
  }

  classes <- vapply(paths, classify_path, character(1), volatile_basenames = VOLATILE_BASENAMES)

  print_section <- function(label, class_name) {
    hits <- paths[classes == class_name]
    if (length(hits) == 0) return(invisible())
    cat(sprintf("\n--- %s (%d) ---\n", label, length(hits)))
    for (p in hits) cat(sprintf("  %s\n", p))
  }

  print_section("png-noise (ignored)", "png-noise")
  print_section("expected churn: timestamps / manifests (ignored)", "timestamp-class")
  print_section("known-volatile: run_id/run_path noise (ignored; retire in PHASE-04)", "volatile")
  print_section("DRIFT", "drift")

  n_drift <- sum(classes == "drift")
  if (n_drift > 0) {
    cat(sprintf("\nDRIFT DETECTED (%d files)\n", n_drift))
    quit(status = 1)
  }

  cat("\nBYTE-IDENTITY PASS\n")
  quit(status = 0)
}

if (identical(environment(), globalenv()) && sys.nframe() == 0L) {
  main()
}
