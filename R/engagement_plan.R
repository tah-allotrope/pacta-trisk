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

#' Plan one engagement run: resolve the ordered step list and derive run paths.
#'
#' Owns the --full application, raw-loanbook resolution, run_intake
#' derivation, intake directories, step_ctx construction, the
#' resolve_step_list() + filter_step_list() call pair, the by-name intake
#' split, and the manifest path + partial-run derivation. The guard rail,
#' manifest refusal effect, resolved-config write, and banner move in the
#' final step.
#'
#' @param cfg list — validated engagement config (load_engagement_config() output).
#' @param cli list — parse_engagement_cli() output.
#' @return named list with fields cfg (with cli$full applied), cli,
#'   raw_loanbook character(1)|NULL, run_intake logical(1),
#'   intake_dir character(1), effective_config_path character(1),
#'   step_ctx list, steps list of list(name, script, args),
#'   intake_present logical(1), steps_before_intake list,
#'   intake_step list|NULL, steps_after_intake list,
#'   manifest_path character(1),
#'   manifest_policy list(run_is_partial logical(1),
#'     only_step character, resume_from character(1)).
#' @export
plan_engagement_run <- function(cfg, cli) {
  if (isTRUE(cli$full)) {
    cfg$run_data_generation <- TRUE
  }

  # A CLI --raw-loanbook flag wins; otherwise fall back to the config's own
  # inputs$raw_loanbook_csv (verbatim from scripts/run_engagement.R).
  # %||% is base R (>= 4.4.0).
  raw_loanbook <- cli$raw_loanbook %||% cfg$inputs$raw_loanbook_csv

  run_intake <- !is.null(raw_loanbook) && !isTRUE(cli$skip_intake)
  intake_dir <- file.path("engagements", cfg$bank_slug, "intake")
  effective_config_path <- if (run_intake) {
    file.path("engagements", cfg$bank_slug, "engagement_config.resolved.json")
  } else {
    cli$config_path
  }

  step_ctx <- list(
    effective_config_path = effective_config_path,
    run_intake = run_intake,
    raw_loanbook = raw_loanbook,
    intake_dir = intake_dir,
    top_n = cli$top_n
  )
  steps <- resolve_step_list(cfg, step_ctx)
  steps <- filter_step_list(steps, only = cli$only_steps, resume_from = cli$resume_from)

  # Locate "intake" by name, not by position: run_data_generation may have
  # prepended a generate_vietnam_data step ahead of it (verbatim from
  # scripts/run_engagement.R).
  intake_present <- any(vapply(steps, function(s) identical(s$name, "intake"), logical(1)))
  if (intake_present) {
    intake_idx <- which(vapply(steps, function(s) identical(s$name, "intake"), logical(1)))[[1]]
    steps_before_intake <- if (intake_idx > 1) steps[seq_len(intake_idx - 1)] else list()
    intake_step <- steps[[intake_idx]]
    steps_after_intake <- steps[-seq_len(intake_idx)]
  } else {
    steps_before_intake <- list()
    intake_step <- NULL
    steps_after_intake <- list()
  }

  # Public engagements (mcb-demo) write the manifest alongside the public
  # snapshot; every other engagement keeps its manifest under its own
  # engagements/<slug>/ tree (verbatim from scripts/run_engagement.R).
  manifest_path <- if (isTRUE(cfg$public_snapshot_allowed)) {
    file.path(cfg$paths$snapshot_dir, "pipeline_manifest.json")
  } else {
    file.path("engagements", cfg$bank_slug, "pipeline_manifest.json")
  }
  # A --only-step / --resume-from run produces a manifest that describes
  # only the steps it ran (verbatim from scripts/run_engagement.R).
  run_is_partial <- length(cli$only_steps) > 0 || (!is.na(cli$resume_from) && nzchar(cli$resume_from))

  list(
    cfg = cfg,
    cli = cli,
    raw_loanbook = raw_loanbook,
    run_intake = run_intake,
    intake_dir = intake_dir,
    effective_config_path = effective_config_path,
    step_ctx = step_ctx,
    steps = steps,
    intake_present = intake_present,
    steps_before_intake = steps_before_intake,
    intake_step = intake_step,
    steps_after_intake = steps_after_intake,
    manifest_path = manifest_path,
    manifest_policy = list(
      run_is_partial = run_is_partial,
      only_step = cli$only_steps,
      resume_from = cli$resume_from
    )
  )
}

#' Enforce the manifest policy decided by plan_engagement_run().
#'
#' A filtered run's manifest describes only the steps it ran. Writing that
#' over a complete PUBLIC manifest silently destroys the provenance record,
#' so the orchestrator refuses without an explicit opt-in (verbatim from
#' scripts/run_engagement.R). Filesystem reads and the refusal stop() live
#' here, at the edge; the decision inputs live in the plan.
#'
#' @param plan list — plan_engagement_run() output.
#' @param allow_partial_manifest logical(1) — cli$allow_partial_manifest.
#' @return invisible TRUE; calls stop() only when a filtered run would
#'   clobber a complete public manifest without the opt-in flag.
#' @export
enforce_manifest_policy <- function(plan, allow_partial_manifest) {
  policy <- plan$manifest_policy
  if (!isTRUE(policy$run_is_partial)) return(invisible(TRUE))
  if (!isTRUE(plan$cfg$public_snapshot_allowed)) return(invisible(TRUE))
  if (isTRUE(allow_partial_manifest)) return(invisible(TRUE))

  manifest_path <- plan$manifest_path
  if (!file.exists(manifest_path)) return(invisible(TRUE))
  existing <- tryCatch(
    jsonlite::fromJSON(manifest_path, simplifyVector = TRUE),
    error = function(e) NULL
  )
  existing_is_complete <- !is.null(existing) && !isTRUE(existing$partial)
  if (existing_is_complete) {
    stop(sprintf(paste0(
      "Refusing to overwrite the complete public manifest at %s with a partial run.\n",
      "  This run was filtered by %s.\n",
      "  Re-run without --only-step/--resume-from, or pass --allow-partial-manifest ",
      "to accept a partial provenance record."
    ), manifest_path, paste(c(
      if (length(policy$only_step) > 0) sprintf("--only-step %s", paste(policy$only_step, collapse = ", ")),
      if (!is.na(policy$resume_from) && nzchar(policy$resume_from)) sprintf("--resume-from %s", policy$resume_from)
    ), collapse = " and ")), call. = FALSE)
  }
  invisible(TRUE)
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
