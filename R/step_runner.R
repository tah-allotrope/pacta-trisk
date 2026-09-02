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
#' Wave 3 PHASE-02 (F-006): a failed step used to record only a status, with
#' no captured output, so diagnosing a CI failure meant re-reading console
#' scrollback. This still prints the step's live output to the console as
#' before, but ALSO captures it so the last lines are available in the return
#' value and, from there, in pipeline_manifest.json.
#'
#' Corrected in Wave 4 PHASE-02: console output is NOT live. An earlier version
#' of this comment claimed the step still streamed via `stdout = ""`; the code
#' captures to a temp file and echoes once the step returns. Ordering is
#' preserved, but a long-running step prints nothing until it finishes.
#'
#' @param step list(name, script, args) — step$name is a label for the
#'   manifest, step$script is the R script path, step$args is a character
#'   vector of CLI arguments passed to it.
#' @return list(name, status ("ok"|"failed"), seconds, error_excerpt) — the
#'   executed step's outcome, wall-clock duration, and (only when
#'   status == "failed") the last 20 lines of its combined stdout+stderr;
#'   NULL when the step succeeded.
run_step <- function(step) {
  cat(sprintf("\n=== %s ===\n", step$name))
  t0 <- Sys.time()

  log_path <- tempfile("step_output_")
  status <- system2(
    "Rscript", args = c(step$script, step$args),
    stdout = log_path, stderr = log_path
  )
  # Echo the captured log to the console so interactive/CI output is
  # unchanged from before this phase (system2(stdout = log_path) alone
  # would otherwise go silent on the console).
  if (file.exists(log_path)) {
    log_lines <- readLines(log_path, warn = FALSE)
    if (length(log_lines) > 0) cat(paste(log_lines, collapse = "\n"), "\n")
  } else {
    log_lines <- character(0)
  }

  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  ok <- identical(status, 0L) || identical(status, 0)
  error_excerpt <- if (!ok) utils::tail(log_lines, 20) else NULL
  unlink(log_path)

  list(
    name = step$name,
    status = if (ok) "ok" else "failed",
    seconds = round(elapsed, 1),
    error_excerpt = error_excerpt
  )
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
      # Wave 4 PHASE-02: only claim we are stopping when we actually are.
      if (stop_on_failure) {
        cat(sprintf("\n[FAILED] Step '%s' exited non-zero. Stopping pipeline.\n", result$name))
        break
      }
      cat(sprintf("\n[FAILED] Step '%s' exited non-zero. Continuing.\n", result$name))
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
#' @param partial logical(1) — TRUE when the run that produced `step_results`
#'   was filtered by --only-step or --resume-from and therefore does NOT
#'   describe a complete pipeline. Always written, so the field's absence
#'   identifies a manifest predating Wave 4 rather than a complete run.
#' @param filters list — when `partial` is TRUE, the filter that produced the
#'   run: `only_step` (character) and `resume_from` (character(1) or NA).
#' @return character (invisible) — the manifest_path written to.
#' @export
write_pipeline_manifest <- function(step_results, manifest_path, row_count_files = character(0), extra = list(),
                                    partial = FALSE, filters = list()) {
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
    # Wave 4 PHASE-02: a --only-step / --resume-from run used to overwrite the
    # full-run manifest with only the executed steps, and marked it in no way --
    # so a filtered run silently destroyed the provenance record and the refresh
    # audit rendered the remains as though they were a complete run.
    partial = isTRUE(partial),
    row_counts = setNames(as.list(vapply(row_count_files, count_rows, integer(1))), row_count_files)
  )
  if (isTRUE(partial)) {
    manifest$filters <- list(
      only_step = if (length(filters$only_step) > 0) as.character(filters$only_step) else character(0),
      resume_from = if (length(filters$resume_from) > 0 && !is.na(filters$resume_from[[1]])) {
        as.character(filters$resume_from[[1]])
      } else {
        NA_character_
      }
    )
  }
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
