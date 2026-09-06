# ==============================================================================
# R/engagement_plan.R
# Deep planning module for the engagement orchestrator.
#
# scripts/run_engagement.R used to own CLI parsing, step_ctx construction,
# the resolve/filter call pair, the by-name intake split, the manifest path
# branch, and the partial-manifest refusal inline. Ordering policy therefore
# had no locality: the pure helpers in R/step_registry.R were unit-tested,
# but the wiring between them was only reachable through a subprocess.
# This module is the single seam for that policy: scripts/run_engagement.R
# parses, plans, then executes. Execution (subprocesses, manifest JSON
# shape) stays in R/step_runner.R.
# ==============================================================================

#' Extract the value following a single-occurrence flag.
#'
#' @param args character — CLI tokens.
#' @param name character(1) — the flag to look up.
#' @return character(1)|NULL — the following token, or NULL when absent.
.cli_flag_value <- function(args, name) {
  idx <- which(args == name)
  if (length(idx) == 0 || idx[[1]] >= length(args)) return(NULL)
  args[[idx[[1]] + 1]]
}

#' Collect every value following a repeatable flag.
#'
#' @param args character — CLI tokens.
#' @param name character — the flag to collect values for.
#' @return character — every value found, in argument order; empty if none.
.cli_flag_values <- function(args, name) {
  idx <- which(args == name)
  idx <- idx[idx < length(args)]
  if (length(idx) == 0) return(character(0))
  args[idx + 1]
}

#' Parse the orchestrator CLI into a plain data list.
#'
#' Moved verbatim from scripts/run_engagement.R's inline flag handling so
#' the flag shapes (repeatable --only-step, valued --resume-from) are
#' learned once, behind the planning seam, instead of at every call site.
#'
#' @param args character — CLI tokens, defaults to commandArgs(trailingOnly = TRUE).
#' @return named list with fields config_path character(1), full logical(1),
#'   raw_loanbook character(1)|NULL, skip_intake logical(1),
#'   top_n character(1)|NULL, only_steps character,
#'   resume_from character(1) (NA_character_ when unset),
#'   allow_partial_manifest logical(1), dry_run logical(1).
#' @export
parse_engagement_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  config_path <- .cli_flag_value(args, "--config")
  if (is.null(config_path)) {
    stop(paste(
      "Usage: Rscript scripts/run_engagement.R --config <path>",
      "[--full] [--raw-loanbook <path>] [--skip-intake] [--top-n <int>]",
      "[--only-step <name> [--only-step <name> ...]] [--resume-from <name>]",
      "[--allow-partial-manifest] [--dry-run]"
    ), call. = FALSE)
  }

  # %||% is base R (>= 4.4.0); R/engagement_config.R also defines a fallback.
  resume_from <- .cli_flag_value(args, "--resume-from")
  if (is.null(resume_from)) resume_from <- NA_character_

  list(
    config_path = config_path,
    full = "--full" %in% args,
    raw_loanbook = .cli_flag_value(args, "--raw-loanbook"),
    skip_intake = "--skip-intake" %in% args,
    top_n = .cli_flag_value(args, "--top-n"),
    only_steps = .cli_flag_values(args, "--only-step"),
    resume_from = resume_from,
    # Opt-in to overwriting a complete public manifest with a partial
    # (filtered) run's manifest.
    allow_partial_manifest = "--allow-partial-manifest" %in% args,
    dry_run = "--dry-run" %in% args
  )
}
