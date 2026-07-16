# ==============================================================================
# R/engagement_config.R
# Engagement configuration loader.
#
# Every pipeline script that supports the config-driven engagement runway
# (`--config <path>`) sources this file and calls:
#
#   cfg <- load_engagement_config(get_config_arg())
#
# When no config path is given (the default, no-flag invocation), the loader
# returns a fixed set of defaults that reproduce today's synthetic Mekong
# Commercial Bank (MCB) paths exactly, so the public pipeline's observable
# behavior (paths written, CSV bytes, manifest shape) is unaffected by this
# file's existence.
# ==============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
})

# --- Defaults (== today's hardcoded MCB paths) -------------------------------

.default_engagement_config <- function() {
  list(
    bank_name = "Mekong Commercial Bank",
    bank_slug = "mcb-demo",
    inputs = list(
      loanbook_csv = "data/vietnam_loanbook.csv",
      abcd_csv = "data/vietnam_abcd.csv",
      scenario_ms_csv = "data/vietnam_scenario_ms.csv",
      scenario_co2_csv = "data/vietnam_scenario_co2.csv",
      region_isos_csv = "data/vietnam_region_isos.csv"
    ),
    trisk_sectors = c("power", "cement", "steel"),
    run_grid = TRUE,
    paths = list(
      pacta_output_dir = "synthesis_output/vietnam",
      trisk_output_root = "synthesis_output/trisk",
      trisk_input_root = "output/trisk_inputs",
      snapshot_dir = "dashboard/data",
      reports_dir = "reports",
      engagement_output_dir = "output/engagement",
      letters_output_dir = "output/engagement_letters",
      disclosure_output_dir = "output/disclosure"
    ),
    anonymize = FALSE
  )
}

# --- Recursive list merge (override wins, missing keys fall back) -----------

.merge_config_lists <- function(defaults, override) {
  if (is.null(override)) {
    return(defaults)
  }
  for (key in names(override)) {
    value <- override[[key]]
    if (is.list(value) && !is.null(defaults[[key]]) && is.list(defaults[[key]])) {
      defaults[[key]] <- .merge_config_lists(defaults[[key]], value)
    } else {
      defaults[[key]] <- value
    }
  }
  defaults
}

# --- Validation ---------------------------------------------------------------

.validate_engagement_config <- function(cfg) {
  problems <- character(0)

  if (is.null(cfg$bank_name) || !nzchar(trimws(cfg$bank_name))) {
    problems <- c(problems, "bank_name must be a non-empty string")
  }
  if (is.null(cfg$bank_slug) || !nzchar(trimws(cfg$bank_slug))) {
    problems <- c(problems, "bank_slug must be a non-empty string")
  } else if (!grepl("^[a-z0-9-]+$", cfg$bank_slug)) {
    problems <- c(problems, sprintf(
      "bank_slug '%s' is invalid — must match ^[a-z0-9-]+$", cfg$bank_slug
    ))
  }

  missing_inputs <- character(0)
  for (name in names(cfg$inputs)) {
    path <- cfg$inputs[[name]]
    if (is.null(path) || !file.exists(path)) {
      missing_inputs <- c(missing_inputs, path)
    }
  }
  if (length(missing_inputs) > 0) {
    problems <- c(problems, sprintf(
      "input file(s) not found:\n  %s",
      paste(missing_inputs, collapse = "\n  ")
    ))
  }

  supported_sectors <- c("power", "cement", "steel")
  unsupported <- setdiff(cfg$trisk_sectors, supported_sectors)
  if (length(unsupported) > 0) {
    problems <- c(problems, sprintf(
      "unsupported trisk_sectors: %s (supported: %s)",
      paste(unsupported, collapse = ", "),
      paste(supported_sectors, collapse = ", ")
    ))
  }

  if (length(problems) > 0) {
    stop(sprintf(
      "Invalid engagement config:\n- %s",
      paste(problems, collapse = "\n- ")
    ), call. = FALSE)
  }

  invisible(TRUE)
}

# --- Public API ---------------------------------------------------------------

#' Load an engagement configuration.
#'
#' @param config_path character|NULL — path to a JSON engagement config, or
#'   NULL to use the built-in MCB defaults untouched.
#' @return list — the fully-populated named config list.
#' @export
load_engagement_config <- function(config_path = NULL) {
  defaults <- .default_engagement_config()

  if (is.null(config_path)) {
    cfg <- defaults
  } else {
    if (!file.exists(config_path)) {
      stop(sprintf("Engagement config file not found: %s", config_path), call. = FALSE)
    }
    override <- jsonlite::read_json(config_path, simplifyVector = TRUE)
    cfg <- .merge_config_lists(defaults, override)
  }

  .validate_engagement_config(cfg)
  cfg
}

#' Extract the value following a `--config` flag from a CLI argument vector.
#'
#' @param args character — CLI arguments, defaults to
#'   commandArgs(trailingOnly = TRUE).
#' @return character|NULL — the config path, or NULL if the flag is absent.
#' @export
get_config_arg <- function(args = commandArgs(trailingOnly = TRUE)) {
  idx <- which(args == "--config")
  if (length(idx) == 0 || idx[[1]] >= length(args)) {
    return(NULL)
  }
  args[[idx[[1]] + 1]]
}
