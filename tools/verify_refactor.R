#!/usr/bin/env Rscript
# tools/verify_refactor.R
# Codifies the acceptance checks used by every pipeline refactor in this repo.
#
# Two independent modes:
#   1. Byte-identity (default): run the default-mode pipeline refresh, then
#      classify every tracked file `git diff` reports as changed into expected
#      churn, known volatility, or genuine drift. Genuine drift fails the check.
#      This answers "does run N+1 byte-match run N?" (reproducibility).
#   2. --invariants: check a short list of cross-artifact consistency rules
#      against the current working tree, without running anything. This
#      answers "does artifact A agree with artifact B?" (consistency) — a
#      question byte-identity is structurally blind to, because a cache that
#      never regenerates trivially reproduces itself forever.
#
# Usage:
#   Rscript tools/verify_refactor.R              # runs the default 7-step refresh
#   Rscript tools/verify_refactor.R --full        # runs the --full 10-step refresh
#   Rscript tools/verify_refactor.R --skip-refresh # classifies the current working
#                                                   # tree without running anything
#   Rscript tools/verify_refactor.R --invariants   # runs only the cross-artifact
#                                                   # invariant checks (INV-001..005),
#                                                   # never the pipeline refresh
#
# Why git diff and not md5sum: git applies core.autocrlf normalization, so a
# byte-identical-after-normalization file shows as unchanged in `git diff`
# even when raw md5sum would differ across Windows/Linux line endings.
#
# PHASE-04 of plans/2026-07-20-wave0-orchestrator-sdb-closers-plan.md emptied
# this vector after deterministic run IDs were implemented in
# write_trisk_demo_outputs() (R/trisk_core.R). The five listed files no longer
# carry per-invocation UUIDs; any future diff in them is genuine drift.
VOLATILE_BASENAMES <- character(0)

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

# ==============================================================================
# --invariants: cross-artifact consistency checks (INV-001..005)
#
# Each inv_*() function takes a repo root (and, where relevant, a snapshot
# directory) and returns list(id, ok, detail) — detail is a character vector
# of human-readable violation lines, empty when ok is TRUE.
# ==============================================================================

#' md5 digest of a file, or NA if the file does not exist.
#' @param path character — file path.
#' @return character(1) — lowercase md5 hex digest, or NA_character_.
.md5_of <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  unname(tools::md5sum(path))
}

#' Extract a `c(...)` literal assigned to `var_name` from an R source file.
#' Used to check sector-list literals that are local variables (not exported
#' functions), so they cannot be read by sourcing + calling.
#' @param path character — R source file to scan.
#' @param var_name character — the variable name, e.g. "supported_sectors".
#' @return character vector of the literal's values, or NULL if the
#'   assignment could not be found or parsed.
.extract_c_literal_from_file <- function(path, var_name) {
  if (!file.exists(path)) return(NULL)
  lines <- readLines(path, warn = FALSE)
  pattern <- sprintf("^\\s*%s\\s*<-\\s*c\\(", var_name)
  idx <- grep(pattern, lines)
  if (length(idx) == 0) return(NULL)
  expr_text <- sub(sprintf("^\\s*%s\\s*<-\\s*", var_name), "", lines[idx[[1]]])
  tryCatch(eval(parse(text = expr_text)), error = function(e) NULL)
}

#' Sector set from R/sector_registry.R's sector_registry().
#' @param root character — repo root.
#' @return character vector of sectors, or NULL if the file could not be sourced.
.get_registry_sectors <- function(root) {
  env <- new.env()
  tryCatch({
    source(file.path(root, "R", "sector_registry.R"), local = env)
    sort(unique(env$sector_registry()$sector))
  }, error = function(e) NULL)
}

#' Sector set from R/trisk_core.R's trisk_supported_sectors constant.
#' @param root character — repo root.
#' @return character vector of sectors, or NULL if the file could not be sourced.
.get_trisk_supported_sectors <- function(root) {
  env <- new.env()
  tryCatch({
    source(file.path(root, "R", "trisk_core.R"), local = env)
    sort(unique(env$trisk_supported_sectors))
  }, error = function(e) NULL)
}

#' INV-001: the scenario grid's base-parameter cell must agree with the base
#' (non-grid) TRISK run for every sector marked grid_available in the
#' published manifest. Catches a grid cache that has gone stale relative to
#' its own base run.
#' @param root character — repo root.
#' @param snapshot_dir character — snapshot directory relative to root,
#'   default "dashboard/data".
#' @param tolerance numeric — max allowed |grid - base| per metric, default 1e-6.
#' @return list(id = "INV-001", ok, detail).
inv_grid_matches_base_run <- function(root, snapshot_dir = "dashboard/data", tolerance = 1e-6) {
  manifest_path <- file.path(root, snapshot_dir, "trisk", "manifest.csv")
  detail <- character(0)
  if (!file.exists(manifest_path)) {
    return(list(id = "INV-001", ok = TRUE, detail = detail))
  }

  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
  sectors <- manifest$sector[manifest$grid_available == TRUE]

  # Mirrors build_scenario_id() in R/trisk_core.R for trisk_base_params():
  # shock_year=2028, discount_rate=0.08, risk_free_rate=0.03,
  # market_passthrough=0.25, carbon_price_family="NGFS_NetZero2050".
  base_scenario_id <- "s2028_d0.08_rf0.03_mp0.25_cNGFS_NetZero2050"

  for (sector in sectors) {
    grid_path <- file.path(root, snapshot_dir, "trisk", "grid", sector, "borrower_results.parquet")
    summary_path <- file.path(root, snapshot_dir, "trisk", sector, "company_summary.csv")
    if (!file.exists(grid_path) || !file.exists(summary_path)) {
      next
    }

    grid <- as.data.frame(arrow::read_parquet(grid_path))
    grid_base <- grid[grid$scenario_id == base_scenario_id, c("company_id", "npv_change_pct", "pd_change_pct"), drop = FALSE]

    summary <- utils::read.csv(summary_path, stringsAsFactors = FALSE)
    summary_base <- summary[, c("company_id", "npv_change", "pd_change"), drop = FALSE]

    grid_ids <- sort(unique(grid_base$company_id))
    summary_ids <- sort(unique(summary_base$company_id))

    only_in_summary <- setdiff(summary_ids, grid_ids)
    only_in_grid <- setdiff(grid_ids, summary_ids)
    if (length(only_in_summary) > 0 || length(only_in_grid) > 0) {
      detail <- c(detail, sprintf(
        "%s: company_id sets differ%s%s",
        sector,
        if (length(only_in_summary) > 0) sprintf(" — missing from grid: %s", paste(only_in_summary, collapse = ", ")) else "",
        if (length(only_in_grid) > 0) sprintf(" — missing from base run: %s", paste(only_in_grid, collapse = ", ")) else ""
      ))
    }

    common_ids <- intersect(grid_ids, summary_ids)
    for (cid in common_ids) {
      g <- grid_base[grid_base$company_id == cid, , drop = FALSE][1, ]
      s <- summary_base[summary_base$company_id == cid, , drop = FALSE][1, ]
      npv_diff <- abs(g$npv_change_pct - s$npv_change)
      pd_diff <- abs(g$pd_change_pct - s$pd_change)
      if (!is.na(npv_diff) && npv_diff > tolerance) {
        detail <- c(detail, sprintf(
          "%s/%s: grid npv_change_pct=%.6f vs base npv_change=%.6f (delta %.6f)",
          sector, cid, g$npv_change_pct, s$npv_change, npv_diff
        ))
      }
      if (!is.na(pd_diff) && pd_diff > tolerance) {
        detail <- c(detail, sprintf(
          "%s/%s: grid pd_change_pct=%.6f vs base pd_change=%.6f (delta %.6f)",
          sector, cid, g$pd_change_pct, s$pd_change, pd_diff
        ))
      }
    }
  }

  list(id = "INV-001", ok = length(detail) == 0, detail = detail)
}

#' INV-002: every file under data/scenarios/<vintage>/ must be the only copy
#' of its content — no byte-identical twin directly under data/. Catches
#' "versioning" that duplicated rather than moved a file.
#' @param root character — repo root.
#' @return list(id = "INV-002", ok, detail).
inv_scenario_vintage_single_source <- function(root) {
  scenarios_dir <- file.path(root, "data", "scenarios")
  detail <- character(0)
  if (!dir.exists(scenarios_dir)) {
    return(list(id = "INV-002", ok = TRUE, detail = detail))
  }

  vintage_files <- list.files(scenarios_dir, recursive = TRUE, full.names = TRUE)
  for (vf in vintage_files) {
    flat_path <- file.path(root, "data", basename(vf))
    if (!file.exists(flat_path)) next
    h_vintage <- .md5_of(vf)
    h_flat <- .md5_of(flat_path)
    if (!is.na(h_vintage) && !is.na(h_flat) && identical(h_vintage, h_flat)) {
      detail <- c(detail, sprintf("%s == %s (md5 %s)", flat_path, vf, h_vintage))
    }
  }

  list(id = "INV-002", ok = length(detail) == 0, detail = detail)
}

#' INV-003: every engagement's committed engagement_priority.csv must carry
#' its own bank_slug as data_source, never another engagement's. Catches
#' hardcoded provenance leaking into a client deliverable.
#' @param root character — repo root.
#' @return list(id = "INV-003", ok, detail).
inv_engagement_data_source <- function(root) {
  detail <- character(0)
  config_paths <- Sys.glob(file.path(root, "engagements", "*", "engagement_config.json"))

  for (config_path in config_paths) {
    cfg <- tryCatch(jsonlite::fromJSON(config_path, simplifyVector = TRUE), error = function(e) NULL)
    if (is.null(cfg) || is.null(cfg$bank_slug) || is.null(cfg$paths) || is.null(cfg$paths$engagement_output_dir)) {
      next
    }
    ep_path <- file.path(root, cfg$paths$engagement_output_dir, "engagement_priority.csv")
    if (!file.exists(ep_path)) next

    ep <- utils::read.csv(ep_path, stringsAsFactors = FALSE)
    if (!"data_source" %in% names(ep) || nrow(ep) == 0) next

    bad_values <- unique(ep$data_source[ep$data_source != cfg$bank_slug])
    if (length(bad_values) > 0) {
      detail <- c(detail, sprintf(
        "%s: expected data_source '%s', found '%s'",
        ep_path, cfg$bank_slug, paste(bad_values, collapse = "', '")
      ))
    }
  }

  list(id = "INV-003", ok = length(detail) == 0, detail = detail)
}

#' INV-004: the supported-sector list must agree across every place it is
#' hardcoded (R/sector_registry.R, R/engagement_config.R, R/trisk_core.R,
#' scripts/new_engagement.R). Catches drift when a sector is added in one
#' place and not the others.
#' @param root character — repo root.
#' @return list(id = "INV-004", ok, detail).
inv_sector_lists_agree <- function(root) {
  sources <- list(
    sector_registry = .get_registry_sectors(root),
    engagement_config = .extract_c_literal_from_file(file.path(root, "R", "engagement_config.R"), "supported_sectors"),
    trisk_core = .get_trisk_supported_sectors(root),
    new_engagement = .extract_c_literal_from_file(file.path(root, "scripts", "new_engagement.R"), "supported")
  )

  detail <- character(0)
  failed <- character(0)
  for (name in names(sources)) {
    if (is.null(sources[[name]])) {
      detail <- c(detail, sprintf("%s: literal could not be located/parsed", name))
      failed <- c(failed, name)
    }
  }
  if (length(failed) > 0) {
    return(list(id = "INV-004", ok = FALSE, detail = detail))
  }

  normalized <- lapply(sources, function(s) sort(unique(s)))
  ref <- normalized[[1]]
  all_equal <- all(vapply(normalized, function(s) identical(s, ref), logical(1)))
  if (!all_equal) {
    for (name in names(normalized)) {
      detail <- c(detail, sprintf("%s: %s", name, paste(normalized[[name]], collapse = ", ")))
    }
    return(list(id = "INV-004", ok = FALSE, detail = detail))
  }

  list(id = "INV-004", ok = TRUE, detail = character(0))
}

#' INV-005: every sector named in the published TRISK manifest must be a
#' known sector in sector_registry(). Catches a snapshot advertising a sector
#' the registry no longer knows about.
#' @param root character — repo root.
#' @param snapshot_dir character — snapshot directory relative to root,
#'   default "dashboard/data".
#' @return list(id = "INV-005", ok, detail).
inv_snapshot_manifest_sectors <- function(root, snapshot_dir = "dashboard/data") {
  manifest_path <- file.path(root, snapshot_dir, "trisk", "manifest.csv")
  if (!file.exists(manifest_path)) {
    return(list(id = "INV-005", ok = TRUE, detail = character(0)))
  }

  registry_sectors <- .get_registry_sectors(root)
  if (is.null(registry_sectors)) {
    return(list(id = "INV-005", ok = FALSE, detail = "sector_registry() could not be loaded"))
  }

  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
  missing <- setdiff(manifest$sector, registry_sectors)
  if (length(missing) > 0) {
    detail <- sprintf("manifest sector '%s' not in sector_registry()", missing)
    return(list(id = "INV-005", ok = FALSE, detail = detail))
  }

  list(id = "INV-005", ok = TRUE, detail = character(0))
}

#' INV-006: every engagement's declared-VND loanbook must have a plausible
#' magnitude for whole VND, not thousands or millions of VND. Catches a data
#' generator that forgot to apply its own currency's scale (Wave 2 PHASE-02,
#' U1) — a corporate loan denominated in true VND is never a few hundred
#' thousand units, but a loanbook denominated in millions-of-VND while
#' labeled "VND" produces exactly that.
#' @param root character — repo root.
#' @param threshold numeric — minimum plausible median
#'   `loan_size_outstanding` for a VND-denominated loanbook, default 1e8
#'   (100 million VND, roughly USD 3,800 — comfortably below any real
#'   corporate loan floor but far above the 1e5-1e6 range a
#'   millions-denominated book produces).
#' @return list(id = "INV-006", ok, detail).
inv_loanbook_currency_scale <- function(root, threshold = 1e8) {
  detail <- character(0)
  config_paths <- Sys.glob(file.path(root, "engagements", "*", "engagement_config.json"))

  for (config_path in config_paths) {
    cfg <- tryCatch(jsonlite::fromJSON(config_path, simplifyVector = TRUE), error = function(e) NULL)
    if (is.null(cfg) || is.null(cfg$inputs) || length(cfg$inputs$loanbook_csv) == 0) {
      next
    }
    loanbook_path <- file.path(root, cfg$inputs$loanbook_csv)
    if (!file.exists(loanbook_path)) next

    lb <- tryCatch(utils::read.csv(loanbook_path, stringsAsFactors = FALSE), error = function(e) NULL)
    if (is.null(lb) || !all(c("loan_size_outstanding", "loan_size_outstanding_currency") %in% names(lb))) {
      next
    }

    vnd_rows <- lb[lb$loan_size_outstanding_currency == "VND", , drop = FALSE]
    if (nrow(vnd_rows) == 0) next

    med <- stats::median(vnd_rows$loan_size_outstanding, na.rm = TRUE)
    if (!is.na(med) && med < threshold) {
      detail <- c(detail, sprintf(
        "%s: median VND-currency loan_size_outstanding = %s, below plausible threshold %s",
        config_path,
        format(med, big.mark = ",", scientific = FALSE),
        format(threshold, big.mark = ",", scientific = FALSE)
      ))
    }
  }

  list(id = "INV-006", ok = length(detail) == 0, detail = detail)
}

#' Run every cross-artifact invariant and print a [PASS]/[FAIL] report.
#' @param root character — repo root.
#' @param snapshot_dir character — snapshot directory relative to root,
#'   default "dashboard/data".
#' @return logical(1) — TRUE iff every invariant passed.
run_invariants <- function(root, snapshot_dir = "dashboard/data") {
  results <- list(
    inv_grid_matches_base_run(root, snapshot_dir),
    inv_scenario_vintage_single_source(root),
    inv_engagement_data_source(root),
    inv_sector_lists_agree(root),
    inv_snapshot_manifest_sectors(root, snapshot_dir),
    inv_loanbook_currency_scale(root)
  )

  for (r in results) {
    cat(sprintf("[%s] %s\n", if (isTRUE(r$ok)) "PASS" else "FAIL", r$id))
    if (!isTRUE(r$ok) && length(r$detail) > 0) {
      for (d in r$detail) cat(sprintf("    %s\n", d))
    }
  }

  all(vapply(results, function(r) isTRUE(r$ok), logical(1)))
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
  invariants_mode <- "--invariants" %in% args

  if (invariants_mode) {
    ok <- run_invariants(getwd())
    if (ok) {
      cat("\nINVARIANTS PASS\n")
      quit(status = 0)
    } else {
      cat("\nINVARIANTS FAIL\n")
      quit(status = 1)
    }
  }

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
