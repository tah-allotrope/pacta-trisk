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
    # Wave 3 PHASE-02 (DEC-005 backward compatibility): bumped only when a
    # breaking change to the config schema itself is introduced. A config
    # that declares a different schema_version fails validation loudly
    # instead of being silently misinterpreted.
    schema_version = 1L,
    bank_name = "Mekong Commercial Bank",
    bank_slug = "mcb-demo",
    inputs = list(
      loanbook_csv = "data/vietnam_loanbook.csv",
      abcd_csv = "data/vietnam_abcd.csv",
      scenario_ms_csv = "data/scenarios/pdp8-2023/vietnam_scenario_ms.csv",
      scenario_co2_csv = "data/scenarios/pdp8-2023/vietnam_scenario_co2.csv",
      region_isos_csv = "data/vietnam_region_isos.csv",
      # Wave 3 PHASE-03: names the scenario vintage directory (must equal the
      # parent directory of both scenario_ms_csv and scenario_co2_csv above,
      # checked in validation below and by INV-009). A name, not a path — it
      # is explicitly skipped (not file.exists()'d) in the "every input must
      # exist" validation, the same way fx_rate_usd_vnd is skipped.
      scenario_vintage = "pdp8-2023",
      # Optional: path to a raw (not-yet-normalized) loanbook. When set, and
      # no --raw-loanbook CLI flag is given, scripts/run_engagement.R uses
      # this as the intake source, so an engagement config can reproduce its
      # own run without an out-of-band flag. NULL means "no raw loanbook
      # configured" — omitted from the "every input must exist" validation.
      raw_loanbook_csv = NULL,
      # Wave 3 PHASE-06 (GTB DEC-005): optional relationship-signal overlay
      # for the SLL readiness screen, joined on name_abcd. NULL means "not
      # configured" -- the relationship dimension drops and remaining
      # weights renormalize (readiness_partial = TRUE). Same
      # empty-shape-skip pattern as raw_loanbook_csv.
      relationship_overlay_csv = NULL,
      # Optional: VND per 1 USD, for intake rows whose currency is USD
      # (Wave 2 PHASE-05, ASM-006). NULL means "not configured" -- a USD row
      # is then retained with exposure/credit limit set to NA and
      # scripts/intake_validate_and_map.R exits non-zero naming this key.
      # A number, not a path, so it is explicitly skipped (not file.exists()'d)
      # in the "every input must exist" validation below.
      fx_rate_usd_vnd = NULL
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
      disclosure_output_dir = "output/disclosure",
      prioritization_output_dir = "synthesis_output/prioritization",
      # Wave 3 PHASE-05.
      financed_emissions_output_dir = "output/financed_emissions"
    ),
    anonymize = FALSE,
    # Only mcb-demo's engagement_config.json sets this TRUE. The orchestrator
    # refuses to run any engagement whose snapshot_dir resolves to the public
    # dashboard/data unless this is explicitly TRUE, replacing the previous
    # bank_slug-string-comparison guard rail.
    public_snapshot_allowed = FALSE,
    # Wave 1 PHASE-05 (orchestrator convergence): these four keys let
    # scripts/run_engagement.R's single step list serve both the public MCB
    # refresh and every client engagement, replacing the second, divergent
    # scripts/pipeline_refresh.R step list. All default to today's
    # non-MCB engagement behavior (no data generation, no refresh audit,
    # letters/disclosure included); only mcb-demo's config overrides them.
    run_data_generation = FALSE,
    run_refresh_audit = FALSE,
    run_outputs = TRUE,
    row_count_files = character(0),
    # Wave 3 PHASE-02 (DEC-005): when non-empty, names the steps to run, in
    # order, overriding the boolean-flag translation in
    # R/step_registry.R::resolve_step_list() entirely. Empty (the default)
    # means "use the flag-driven behavior below, unchanged" -- every config
    # written before this phase keeps working without edits.
    steps = character(0),
    # Wave 3 PHASE-03: gates the optional compare_scenario_vintages step.
    # Default FALSE for every existing engagement; not enabled by this
    # phase for either mcb-demo or sdb-rehearsal.
    run_vintage_comparison = FALSE,
    # Wave 3 PHASE-04: gates the append-only result-history step
    # (scripts/record_run_history.R). Default FALSE; TRUE only for
    # mcb-demo (ASM-010) so history/ starts small and deliberate.
    run_history = FALSE,
    # Wave 3 PHASE-05: gates the PCAF financed-emissions step. Default
    # FALSE; enabled for both mcb-demo and sdb-rehearsal.
    run_financed_emissions = FALSE,
    # Wave 3 PHASE-06 (GTB DEC-003): gates the SLL readiness screen. Must
    # run after engagement_scoring AND refresh_dashboard_data (the same
    # ordering constraint engagement_scoring itself has, per ASM-004 of
    # research/2026-08-11_gtb-middle-tier-gap-closers-brainstorm.md).
    run_sll_readiness = FALSE,
    # Wave 3 PHASE-06 (GTB DEC-013): borrower composite score weights,
    # reachable through the config instead of only scripts/engagement_scoring.R's
    # own --w_align/--w_trisk CLI flags. Defaults reproduce that script's own
    # hardcoded defaults exactly, so every existing config's numbers are
    # unaffected until a config explicitly overrides them.
    scoring = list(weight_alignment = 0.5, weight_trisk = 0.5),
    # Wave 3 PHASE-02 (DEC-006): file names (matching entries in
    # reports/report_catalog.json) eligible for scripts/refresh_dashboard_data.R
    # to copy into this engagement's snapshot_dir/reports/. Only meaningful
    # for engagements with public_snapshot_allowed = TRUE; empty for every
    # other engagement, since only the public MCB snapshot has a Reports page.
    published_reports = character(0)
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

#' Recursively find keys present in `cfg` but absent from `defaults` at the
#' same nesting level. Wave 3 PHASE-02 (F-006/DEC-005): .merge_config_lists()
#' copies any key from a JSON override into the merged config regardless of
#' whether it is recognized, so a typo like "trisk_sector" (singular) used to
#' validate clean and silently run the default sectors instead of erroring.
#' Only recurses into a sub-list when the DEFAULT value at that key is
#' itself a non-NULL list (so a scalar-default key, e.g. fx_rate_usd_vnd,
#' is checked for presence but never recursed into).
#' @param cfg list — a (sub)tree of the merged config.
#' @param defaults list — the matching (sub)tree of .default_engagement_config().
#' @param path character — dotted key path so far, for error messages.
#' @return character vector of human-readable problem lines, empty if none.
.find_unknown_keys <- function(cfg, defaults, path = "") {
  problems <- character(0)
  for (key in names(cfg)) {
    key_path <- if (nzchar(path)) paste0(path, ".", key) else key
    if (!(key %in% names(defaults))) {
      problems <- c(problems, sprintf(
        "unknown config key '%s' (accepted keys at this level: %s)",
        key_path, paste(names(defaults), collapse = ", ")
      ))
      next
    }
    val <- cfg[[key]]
    def_val <- defaults[[key]]
    if (is.list(val) && !is.null(def_val) && is.list(def_val)) {
      problems <- c(problems, .find_unknown_keys(val, def_val, key_path))
    }
  }
  problems
}

.validate_engagement_config <- function(cfg) {
  problems <- character(0)

  problems <- c(problems, .find_unknown_keys(cfg, .default_engagement_config()))

  if (!is.numeric(cfg$schema_version) || length(cfg$schema_version) != 1 ||
      !identical(as.integer(cfg$schema_version), 1L)) {
    problems <- c(problems, sprintf(
      "schema_version must be 1, got: %s",
      paste(cfg$schema_version, collapse = ", ")
    ))
  }

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
    # raw_loanbook_csv is optional — "not configured" means NULL when the
    # config came from R defaults, but jsonlite::toJSON() serializes a NULL
    # list element as {} and it comes back as an empty named list() on the
    # next read_json() roundtrip (e.g. run_engagement.R's resolved-config
    # write). Treat either shape as "not configured", not "missing". A
    # non-empty value is still validated for existence below.
    if (identical(name, "raw_loanbook_csv") && length(path) == 0) {
      next
    }
    if (identical(name, "relationship_overlay_csv") && length(path) == 0) {
      next
    }
    # fx_rate_usd_vnd is a NUMBER, not a path -- it must never reach
    # file.exists() below (Wave 2 PHASE-05 Gotcha: without this skip branch
    # every config that sets a rate fails validation with a confusing
    # "input file(s) not found: 26300"). Validated for shape separately below.
    if (identical(name, "fx_rate_usd_vnd")) {
      next
    }
    # scenario_vintage is a directory NAME, not a path -- same skip pattern
    # as fx_rate_usd_vnd above (Wave 3 PHASE-03).
    if (identical(name, "scenario_vintage")) {
      next
    }
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

  # fx_rate_usd_vnd: optional; same jsonlite empty-value round-trip hazard as
  # raw_loanbook_csv above (NULL / character(0) / list() all mean "not set").
  # When present, must be a single positive finite number.
  fx_rate <- cfg$inputs$fx_rate_usd_vnd
  if (length(fx_rate) > 0) {
    fx_rate_num <- suppressWarnings(as.numeric(fx_rate))
    if (length(fx_rate_num) != 1 || is.na(fx_rate_num) || !is.finite(fx_rate_num) || fx_rate_num <= 0) {
      problems <- c(problems, sprintf(
        "inputs.fx_rate_usd_vnd must be a single positive number, got: %s",
        paste(fx_rate, collapse = ", ")
      ))
    }
  }

  # scenario_vintage (Wave 3 PHASE-03): must be a non-empty
  # ^[a-z0-9-]+$ name matching the parent directory of BOTH scenario paths,
  # so the config's declared vintage can never silently disagree with what
  # it actually points at.
  vintage <- cfg$inputs$scenario_vintage
  if (is.null(vintage) || !nzchar(trimws(vintage))) {
    problems <- c(problems, "inputs.scenario_vintage must be a non-empty string")
  } else if (!grepl("^[a-z0-9-]+$", vintage)) {
    problems <- c(problems, sprintf(
      "inputs.scenario_vintage '%s' is invalid — must match ^[a-z0-9-]+$", vintage
    ))
  } else {
    ms_dir <- basename(dirname(cfg$inputs$scenario_ms_csv %||% ""))
    co2_dir <- basename(dirname(cfg$inputs$scenario_co2_csv %||% ""))
    if (!identical(ms_dir, vintage) || !identical(co2_dir, vintage)) {
      problems <- c(problems, sprintf(
        "inputs.scenario_vintage ('%s') must equal the parent directory of both scenario_ms_csv ('%s') and scenario_co2_csv ('%s')",
        vintage, cfg$inputs$scenario_ms_csv %||% "<unset>", cfg$inputs$scenario_co2_csv %||% "<unset>"
      ))
    }
  }

  # scoring.weight_alignment / weight_trisk (Wave 3 PHASE-06): must each be
  # a single non-negative finite number.
  for (weight_name in c("weight_alignment", "weight_trisk")) {
    w <- cfg$scoring[[weight_name]]
    w_num <- suppressWarnings(as.numeric(w))
    if (length(w_num) != 1 || is.na(w_num) || !is.finite(w_num) || w_num < 0) {
      problems <- c(problems, sprintf(
        "scoring.%s must be a single non-negative number, got: %s",
        weight_name, paste(w, collapse = ", ")
      ))
    }
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

  if (!is.logical(cfg$public_snapshot_allowed) ||
      length(cfg$public_snapshot_allowed) != 1 ||
      is.na(cfg$public_snapshot_allowed)) {
    problems <- c(problems, "public_snapshot_allowed must be a single TRUE/FALSE value")
  }

  for (flag_name in c("run_data_generation", "run_refresh_audit", "run_outputs", "run_vintage_comparison", "run_history", "run_financed_emissions", "run_sll_readiness")) {
    value <- cfg[[flag_name]]
    if (!is.logical(value) || length(value) != 1 || is.na(value)) {
      problems <- c(problems, sprintf("%s must be a single TRUE/FALSE value", flag_name))
    }
  }

  # Same jsonlite round-trip hazard as raw_loanbook_csv (Wave 1 PHASE-02):
  # an empty character vector serializes as `[]` and comes back as an empty
  # list(), not character(0), on the next read_json(). Accept either empty
  # shape; a non-empty value must be a genuine character vector.
  if (!(length(cfg$row_count_files) == 0 || is.character(cfg$row_count_files))) {
    problems <- c(problems, "row_count_files must be a character vector (may be empty)")
  }

  # Same jsonlite empty-shape hazard as row_count_files.
  if (!(length(cfg$steps) == 0 || is.character(cfg$steps))) {
    problems <- c(problems, "steps must be a character vector (may be empty)")
  }
  if (!(length(cfg$published_reports) == 0 || is.character(cfg$published_reports))) {
    problems <- c(problems, "published_reports must be a character vector (may be empty)")
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
