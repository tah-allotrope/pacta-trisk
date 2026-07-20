# ==============================================================================
# R/step_runner.R
# Shared step-execution and manifest-writing logic, extracted verbatim from
# scripts/pipeline_refresh.R so both the default MCB refresh and
# scripts/run_engagement.R (any bank) run steps and write manifests through
# one code path. No logic changed from the original pipeline_refresh.R
# implementation — see CLAUDE.md for the byte-identical-MCB-CSV refactor
# acceptance bar this extraction is held to; verify with
# `Rscript tools/verify_refactor.R`.
# ==============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
})

#' Count data rows in a CSV (excludes the header row).
#'
#' @param path character — path to a CSV file.
#' @return integer — row count, or NA_integer_ if the file is missing or unreadable.
count_rows <- function(path) {
  if (!file.exists(path)) return(NA_integer_)
  tryCatch(length(readLines(path)) - 1L, error = function(e) NA_integer_)
}

#' Run one pipeline step as an Rscript subprocess.
#'
#' @param step list(name, script, args) — step$name is a label for the
#'   manifest, step$script is the R script path, step$args is a character
#'   vector of CLI arguments passed to it.
#' @return list(name, status ("ok"|"failed"), seconds) — the executed step's
#'   outcome and wall-clock duration.
run_step <- function(step) {
  cat(sprintf("\n=== %s ===\n", step$name))
  t0 <- Sys.time()
  status <- system2("Rscript", args = c(step$script, step$args))
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  list(name = step$name, status = if (status == 0) "ok" else "failed", seconds = round(elapsed, 1))
}

#' Execute a list of pipeline steps in order, stopping at the first failure.
#'
#' @param steps list of list(name, script, args) — the step list to run, in order.
#' @param stop_on_failure logical — when TRUE (the default), no further steps
#'   run after the first non-zero exit.
#' @return list of list(name, status ("ok"|"failed"), seconds) — one entry
#'   per step actually executed (shorter than `steps` when a failure stopped
#'   the run early).
#' @export
run_steps <- function(steps, stop_on_failure = TRUE) {
  step_results <- list()
  for (step in steps) {
    result <- run_step(step)
    step_results[[length(step_results) + 1]] <- result
    if (result$status != "ok") {
      cat(sprintf("\n[FAILED] Step '%s' exited non-zero. Stopping pipeline.\n", result$name))
      if (stop_on_failure) break
    }
  }
  step_results
}

#' Write a pipeline manifest JSON in the repo's established shape.
#'
#' @param step_results list — output of run_steps(): list of list(name, status, seconds).
#' @param manifest_path character — file path to write the manifest JSON to.
#' @param row_count_files character — paths whose data-row counts are recorded
#'   under `row_counts` in the manifest; defaults to none.
#' @param extra list — additional top-level fields merged into the manifest
#'   (e.g. bank_slug, config_path); defaults to none.
#' @return character (invisible) — the manifest_path written to.
#' @export
write_pipeline_manifest <- function(step_results, manifest_path, row_count_files = character(0), extra = list()) {
  git_sha <- tryCatch(
    trimws(system("git rev-parse HEAD", intern = TRUE)),
    error = function(e) NA_character_
  )
  if (length(git_sha) == 0 || identical(git_sha, "")) git_sha <- NA_character_

  manifest <- list(
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    git_sha = git_sha,
    steps = step_results,
    status = if (all(vapply(step_results, function(s) s$status == "ok", logical(1)))) "ok" else "failed",
    row_counts = setNames(as.list(vapply(row_count_files, count_rows, integer(1))), row_count_files)
  )
  manifest <- .merge_manifest_extra(manifest, extra)

  dir.create(dirname(manifest_path), recursive = TRUE, showWarnings = FALSE)
  write(toJSON(manifest, auto_unbox = TRUE, pretty = TRUE), manifest_path)
  invisible(manifest_path)
}

.merge_manifest_extra <- function(manifest, extra) {
  for (key in names(extra)) {
    manifest[[key]] <- extra[[key]]
  }
  manifest
}
