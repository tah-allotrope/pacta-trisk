# ==============================================================================
# R/run_history.R
# Wave 3 PHASE-04: an append-only per-engagement result history, so a
# deliverable can express change over time (which every regulatory purpose
# this platform serves -- TCFD, IFRS S2, Decision 263 -- requires) instead
# of only ever showing the latest snapshot. Every run is written to its own
# never-overwritten directory under history/<bank_slug>/<run_id>/; nothing
# here mutates a prior run.
# ==============================================================================

#' A directory-safe run identifier: date (UTC) + short git sha + scenario
#' vintage, so history directories sort chronologically by name and carry
#' their own provenance in the name.
#'
#' @param git_sha character(1) — a full or short git commit sha.
#' @param scenario_vintage character(1) — e.g. "pdp8-2023".
#' @param timestamp POSIXct(1) — defaults to Sys.time(); the date component
#'   is taken in UTC so runs from different time zones sort consistently.
#' @return character(1) — "YYYYMMDD-<sha7>-<vintage>".
#' @export
make_run_id <- function(git_sha, scenario_vintage, timestamp = Sys.time()) {
  date_part <- format(timestamp, "%Y%m%d", tz = "UTC")
  sha7 <- substr(git_sha, 1, 7)
  sprintf("%s-%s-%s", date_part, sha7, scenario_vintage)
}

#' Copy a set of artifacts into a new, never-before-used history run
#' directory, alongside a manifest.json recording provenance.
#'
#' @param cfg list — the loaded engagement config; only bank_slug and
#'   inputs$scenario_vintage are read.
#' @param artifacts character — paths (relative to the working directory) to
#'   copy into the run directory. Missing paths are skipped with a message,
#'   not an error (a partial upstream run should not crash history
#'   recording).
#' @param history_root character(1) — default "history".
#' @param git_sha character(1) — defaults to the current HEAD via `git
#'   rev-parse HEAD`; pass explicitly in tests to avoid depending on repo
#'   state.
#' @return character(1) — the run directory written to (invisible).
#' @export
record_run_history <- function(cfg, artifacts, history_root = "history", git_sha = NULL) {
  if (is.null(git_sha)) {
    git_sha <- tryCatch(trimws(system("git rev-parse HEAD", intern = TRUE)), error = function(e) NA_character_)
    if (length(git_sha) == 0 || identical(git_sha, "")) git_sha <- NA_character_
  }

  run_id <- make_run_id(git_sha, cfg$inputs$scenario_vintage)
  run_dir <- file.path(history_root, cfg$bank_slug, run_id)

  if (dir.exists(run_dir)) {
    stop(sprintf(
      "record_run_history: run directory already exists (history is append-only, never overwritten): %s",
      run_dir
    ), call. = FALSE)
  }
  dir.create(run_dir, recursive = TRUE)

  copied <- character(0)
  for (path in artifacts) {
    if (!file.exists(path)) {
      message(sprintf("record_run_history: [SKIP] %s not found", path))
      next
    }
    file.copy(path, run_dir, overwrite = FALSE)
    copied <- c(copied, basename(path))
  }

  manifest <- list(
    run_id = run_id,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    git_sha = git_sha,
    scenario_vintage = cfg$inputs$scenario_vintage,
    bank_slug = cfg$bank_slug,
    artifacts = copied
  )
  writeLines(
    jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE),
    file.path(run_dir, "manifest.json")
  )

  invisible(run_dir)
}

#' List the run identifiers recorded for a bank, oldest first.
#' @param bank_slug character(1).
#' @param history_root character(1) — default "history".
#' @return character — run ids, sorted ascending (run ids sort
#'   chronologically by construction — see make_run_id()).
#' @export
history_runs <- function(bank_slug, history_root = "history") {
  bank_dir <- file.path(history_root, bank_slug)
  if (!dir.exists(bank_dir)) return(character(0))
  sort(list.dirs(bank_dir, full.names = FALSE, recursive = FALSE))
}

#' Diff one artifact between two recorded runs.
#'
#' @param bank_slug character(1).
#' @param run_a,run_b character(1) — run ids from history_runs().
#' @param artifact character(1) — the artifact's basename within each run
#'   directory (e.g. "engagement_priority.csv").
#' @param key_cols character — columns identifying a row across both runs.
#' @param value_cols character — numeric columns to diff.
#' @param history_root character(1) — default "history".
#' @return data.frame with `key_cols`, `<col>_a`/`<col>_b`/`<col>_delta` per
#'   value_cols, and `change_type` ("added"|"removed"|"changed"). Rows
#'   identical across both runs are omitted.
#' @export
history_diff <- function(bank_slug, run_a, run_b, artifact, key_cols, value_cols, history_root = "history") {
  path_a <- file.path(history_root, bank_slug, run_a, artifact)
  path_b <- file.path(history_root, bank_slug, run_b, artifact)
  a <- utils::read.csv(path_a, stringsAsFactors = FALSE)
  b <- utils::read.csv(path_b, stringsAsFactors = FALSE)

  a_key <- do.call(paste, c(a[key_cols], sep = ""))
  b_key <- do.call(paste, c(b[key_cols], sep = ""))

  merged <- merge(a, b, by = key_cols, suffixes = c("_a", "_b"), all = TRUE)
  merged_key <- do.call(paste, c(merged[key_cols], sep = ""))

  change_type <- ifelse(
    !(merged_key %in% a_key), "added",
    ifelse(!(merged_key %in% b_key), "removed", "changed")
  )

  out <- merged[key_cols]
  any_real_change <- rep(FALSE, nrow(merged))
  for (col in value_cols) {
    col_a <- merged[[paste0(col, "_a")]]
    col_b <- merged[[paste0(col, "_b")]]
    out[[paste0(col, "_a")]] <- col_a
    out[[paste0(col, "_b")]] <- col_b
    delta <- col_b - col_a
    out[[paste0(col, "_delta")]] <- delta
    any_real_change <- any_real_change | is.na(col_a) | is.na(col_b) | (!is.na(delta) & delta != 0)
  }
  out$change_type <- change_type

  keep <- any_real_change | change_type != "changed"
  out[keep, , drop = FALSE]
}
