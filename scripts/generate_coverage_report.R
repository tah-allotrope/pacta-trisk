#!/usr/bin/env Rscript
# =============================================================================
# generate_coverage_report.R
# Coverage and Reconciliation Report (Wave 2 PHASE-06).
#
# Produces a durable, tracked, money-denominated artifact per engagement that
# answers: what did the client send, what did we process, what could we not
# process and why, and what fraction of processed exposure has asset-level
# (ABCD) coverage. This is the artifact that makes "send us your loanbook and
# we will tell you your coverage" a concrete offer.
#
# The report renders through R/report_toolkit.R (report_css(), write_html_report)
# and every money figure through R/format_money.R. A machine-readable sidecar
# coverage_metrics.json is written into the intake dir (tracked -- it carries
# no timestamp, per RISK-06-03) so a future executive-summary generator and the
# pipeline manifest can consume it.
#
# The three pure functions (build_reconciliation, build_abcd_coverage,
# write_coverage_metrics) are top-level and sourceable so
# tests/testthat/test_coverage_report.R can exercise them directly; the CLI
# pipeline lives in main() and only runs when executed as a script.
#
# Usage:
#   Rscript scripts/generate_coverage_report.R \
#     --config <engagement config> \
#     --intake-dir <intake output dir> \
#     --output <path to Coverage_Reconciliation_Report.html>
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("R/engagement_config.R")
source("R/report_toolkit.R")
source("R/matching_helpers.R")
source("R/format_money.R")
# Reuse the intake script's single source of truth for code -> PACTA sector
# (scripts/intake_validate_and_map.R, TASK-05-03). The guarded main() means
# sourcing only exposes the pure functions; nothing executes.
source("scripts/intake_validate_and_map.R")

# =============================================================================
# Pure, sourceable functions
# =============================================================================

#' Build the submitted / normalized / dropped reconciliation table.
#'
#' @param raw_path character|NULL — path to the raw submitted loanbook. NULL
#'   (optional input not configured) renders the reconciliation unavailable.
#' @param normalized_path character — <intake-dir>/normalized_loanbook.csv.
#' @param errors_path character — <intake-dir>/validation_errors.csv.
#' @param warnings_path character — <intake-dir>/validation_warnings.csv.
#' @return list(rows = data.frame, totals = list(...)).
#'   rows has one row per mutually-exclusive outcome category (normalized_clean,
#'   normalized_warned, dropped) with columns category, n_rows, exposure_vnd,
#'   pct_of_submitted_vnd (sums to 100). totals carries the plan's eight keys:
#'   submitted_rows, submitted_vnd, normalized_rows, normalized_vnd,
#'   dropped_rows, dropped_vnd, warned_rows, warned_vnd.
build_reconciliation <- function(raw_path, normalized_path, errors_path, warnings_path) {
  normalized <- read.csv(normalized_path, stringsAsFactors = FALSE)
  errors <- read.csv(errors_path, stringsAsFactors = FALSE)
  warnings <- read.csv(warnings_path, stringsAsFactors = FALSE)
  raw <- if (!is.null(raw_path) && file.exists(raw_path)) {
    read.csv(raw_path, stringsAsFactors = FALSE)
  } else {
    NULL
  }

  error_rows <- unique(errors$row)
  warning_rows <- unique(warnings$row)

  dropped_rows <- length(error_rows)
  warned_rows <- length(warning_rows)
  normalized_rows <- nrow(normalized)
  submitted_rows <- normalized_rows + dropped_rows

  # Money, whole VND. Rows whose exposure is NA (unsupported_currency /
  # fx_rate_missing without a configured rate) count toward normalized_rows but
  # contribute 0 to normalized_vnd -- the report states this explicitly.
  normalized_vnd <- sum(suppressWarnings(as.numeric(normalized$loan_size_outstanding)), na.rm = TRUE)
  dropped_vnd <- if (dropped_rows > 0 && !is.null(raw) && "exposure_vnd" %in% names(raw)) {
    sum(suppressWarnings(as.numeric(raw$exposure_vnd[error_rows])), na.rm = TRUE)
  } else {
    0
  }
  submitted_vnd <- normalized_vnd + dropped_vnd

  # warned rows are a subset of normalized rows; their id_loan encodes the
  # original input row (CL_L001, ...), which is what warnings$row refers to.
  warned_vnd <- 0
  if (warned_rows > 0 && "id_loan" %in% names(normalized)) {
    id_lookup <- setNames(
      suppressWarnings(as.numeric(normalized$loan_size_outstanding)),
      normalized$id_loan
    )
    warned_ids <- sprintf("CL_L%03d", warning_rows)
    warned_vnd <- sum(id_lookup[warned_ids], na.rm = TRUE)
  }

  clean_rows <- normalized_rows - warned_rows
  clean_vnd <- normalized_vnd - warned_vnd

  rows <- data.frame(
    category = c("normalized_clean", "normalized_warned", "dropped"),
    n_rows = c(clean_rows, warned_rows, dropped_rows),
    exposure_vnd = c(clean_vnd, warned_vnd, dropped_vnd),
    stringsAsFactors = FALSE
  )
  rows$pct_of_submitted_vnd <- if (submitted_vnd > 0) {
    rows$exposure_vnd / submitted_vnd * 100
  } else {
    0
  }

  list(
    rows = rows,
    totals = list(
      submitted_rows = submitted_rows,
      submitted_vnd = submitted_vnd,
      normalized_rows = normalized_rows,
      normalized_vnd = normalized_vnd,
      dropped_rows = dropped_rows,
      dropped_vnd = dropped_vnd,
      warned_rows = warned_rows,
      warned_vnd = warned_vnd
    )
  )
}

#' Compute ABCD asset-level coverage of the normalized loanbook.
#'
#' @param normalized data.frame — the normalized loanbook, with columns
#'   name_direct_loantaker, loan_size_outstanding, and
#'   sector_classification_direct_loantaker.
#' @param abcd_path character — path to the ABCD CSV.
#' @return list(by_sector = data.frame, covered_vnd = numeric,
#'   coverage_pct = numeric, unmatched = data.frame).
build_abcd_coverage <- function(normalized, abcd_path) {
  abcd <- read.csv(abcd_path, stringsAsFactors = FALSE)
  abcd_names <- normalize_vn_name(as.character(abcd$name_company))
  norm_names <- normalize_vn_name(as.character(normalized$name_direct_loantaker))
  covered <- norm_names %in% abcd_names

  exposure <- suppressWarnings(as.numeric(normalized$loan_size_outstanding))
  covered_vnd <- sum(exposure[covered], na.rm = TRUE)
  total_vnd <- sum(exposure, na.rm = TRUE)
  coverage_pct <- if (total_vnd == 0) 0 else covered_vnd / total_vnd * 100

  sectors <- map_sector_code(as.character(normalized$sector_classification_direct_loantaker))
  by_sector <- data.frame(
    sector = sectors,
    exposure_vnd = exposure,
    covered_vnd = ifelse(covered, exposure, 0),
    stringsAsFactors = FALSE
  ) %>%
    dplyr::group_by(sector) %>%
    dplyr::summarise(
      exposure_vnd = sum(exposure_vnd, na.rm = TRUE),
      covered_vnd = sum(covered_vnd, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::mutate(coverage_pct = ifelse(exposure_vnd > 0, covered_vnd / exposure_vnd * 100, 0)) %>%
    dplyr::arrange(dplyr::desc(exposure_vnd))

  unmatched <- data.frame(
    name_direct_loantaker = normalized$name_direct_loantaker[!covered],
    exposure_vnd = exposure[!covered],
    stringsAsFactors = FALSE
  ) %>%
    dplyr::arrange(dplyr::desc(exposure_vnd))

  list(
    by_sector = by_sector,
    covered_vnd = covered_vnd,
    coverage_pct = coverage_pct,
    unmatched = unmatched
  )
}

#' Write the machine-readable coverage_metrics.json sidecar.
#'
#' No timestamp (RISK-06-03) so the tracked file is byte-stable across runs.
#'
#' @param reconciliation list — output of build_reconciliation().
#' @param coverage list — output of build_abcd_coverage().
#' @param path character — destination JSON path.
#' @return invisible(NULL), called for side effect.
write_coverage_metrics <- function(reconciliation, coverage, path) {
  t <- reconciliation$totals
  by_sector_list <- list()
  for (i in seq_len(nrow(coverage$by_sector))) {
    r <- coverage$by_sector[i, ]
    by_sector_list[[r$sector]] <- list(
      exposure_vnd = r$exposure_vnd,
      covered_vnd = r$covered_vnd,
      coverage_pct = r$coverage_pct
    )
  }
  payload <- list(
    submitted_rows = t$submitted_rows,
    submitted_vnd = t$submitted_vnd,
    normalized_rows = t$normalized_rows,
    normalized_vnd = t$normalized_vnd,
    dropped_rows = t$dropped_rows,
    dropped_vnd = t$dropped_vnd,
    warned_rows = t$warned_rows,
    warned_vnd = t$warned_vnd,
    abcd_covered_vnd = coverage$covered_vnd,
    abcd_coverage_pct = coverage$coverage_pct,
    by_sector = by_sector_list
  )
  jsonlite::write_json(payload, path, auto_unbox = TRUE, pretty = TRUE)
  invisible(NULL)
}

# =============================================================================
# CLI pipeline
# =============================================================================

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  get_arg <- function(flag, default = NULL) {
    idx <- which(args == flag)
    if (length(idx) > 0 && idx < length(args)) return(args[idx + 1])
    default
  }

  config_path <- get_arg("--config")
  intake_dir  <- get_arg("--intake-dir")
  output_path <- get_arg("--output", "reports/Coverage_Reconciliation_Report.html")

  if (is.null(config_path) || is.null(intake_dir)) {
    stop("Usage: Rscript scripts/generate_coverage_report.R --config <path> --intake-dir <dir> [--output <path>]")
  }

  cfg <- load_engagement_config(config_path)

  normalized_path <- file.path(intake_dir, "normalized_loanbook.csv")
  errors_path     <- file.path(intake_dir, "validation_errors.csv")
  warnings_path   <- file.path(intake_dir, "validation_warnings.csv")

  for (f in c(normalized_path, errors_path, warnings_path)) {
    if (!file.exists(f)) {
      stop(sprintf("Missing required intake file: %s", f))
    }
  }

  raw_path <- if (length(cfg$inputs$raw_loanbook_csv) > 0) cfg$inputs$raw_loanbook_csv else NULL
  normalized <- read.csv(normalized_path, stringsAsFactors = FALSE)
  errors <- read.csv(errors_path, stringsAsFactors = FALSE)
  warnings <- read.csv(warnings_path, stringsAsFactors = FALSE)

  cat("Reading intake artifacts...\n")
  reconciliation <- build_reconciliation(raw_path, normalized_path, errors_path, warnings_path)
  coverage <- build_abcd_coverage(normalized, cfg$inputs$abcd_csv)

  metrics_path <- file.path(intake_dir, "coverage_metrics.json")
  write_coverage_metrics(reconciliation, coverage, metrics_path)
  cat(sprintf("  Written: %s\n", metrics_path))

  t <- reconciliation$totals
  n_na_exposure <- sum(is.na(normalized$loan_size_outstanding))

  cat("Building HTML report...\n")
  generated_at <- format(Sys.time(), "%Y-%m-%d %H:%M %Z")

  # --- Table fragments --------------------------------------------------------

  rec_rows_html <- paste0(
    vapply(seq_len(nrow(reconciliation$rows)), function(i) {
      r <- reconciliation$rows[i, ]
      sprintf(
        "<tr><td><code>%s</code></td><td>%d</td><td>%s</td><td>%s</td><td>%.2f%%</td></tr>",
        r$category, r$n_rows,
        format_vnd_full(r$exposure_vnd),
        format_vnd_bn(r$exposure_vnd),
        r$pct_of_submitted_vnd
      )
    }, character(1)),
    collapse = "\n"
  )

  # Dropped money by error column: sum raw exposure of the rows carrying each
  # error column, matched against the raw file's exposure_vnd.
  if (nrow(errors) > 0) {
    raw_for_drop <- if (!is.null(raw_path) && file.exists(raw_path)) {
      read.csv(raw_path, stringsAsFactors = FALSE)
    } else {
      NULL
    }
    error_detail <- errors %>%
      mutate(exp = if (!is.null(raw_for_drop) && "exposure_vnd" %in% names(raw_for_drop)) {
        suppressWarnings(as.numeric(raw_for_drop$exposure_vnd[row]))
      } else {
        NA_real_
      }) %>%
      group_by(column) %>%
      summarise(count = dplyr::n(), vnd = sum(exp, na.rm = TRUE), .groups = "drop") %>%
      arrange(desc(vnd))
    error_cols_html <- paste0(
      vapply(seq_len(nrow(error_detail)), function(i) {
        r <- error_detail[i, ]
        sprintf(
          "<tr><td><code>%s</code></td><td>%d</td><td>%s</td><td>%s</td></tr>",
          r$column, r$count,
          format_vnd_full(r$vnd),
          format_vnd_bn(r$vnd)
        )
      }, character(1)),
      collapse = "\n"
    )
  }

  warn_class_html <- if (nrow(warnings) > 0) {
    warnings %>%
      count(classification, name = "count") %>%
      arrange(desc(count)) %>%
      {
        paste0(
          sprintf(
            "<tr><td><code>%s</code></td><td>%d</td></tr>",
            .$classification, .$count
          ),
          collapse = "\n"
        )
      }
  } else {
    "<tr><td colspan=\"2\">No warnings.</td></tr>"
  }

  abcd_sector_html <- if (nrow(coverage$by_sector) > 0) {
    paste0(
      vapply(seq_len(nrow(coverage$by_sector)), function(i) {
        r <- coverage$by_sector[i, ]
        sprintf(
          "<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td>%.2f%%</td></tr>",
          r$sector,
          format_vnd_full(r$exposure_vnd),
          format_vnd_full(r$covered_vnd),
          r$coverage_pct
        )
      }, character(1)),
      collapse = "\n"
    )
  } else {
    "<tr><td colspan=\"4\">No rows to cover.</td></tr>"
  }

  unmatched_html <- if (nrow(coverage$unmatched) > 0) {
    head(coverage$unmatched, 25) %>%
      {
        paste0(
          vapply(seq_len(nrow(.)), function(i) {
            r <- .[i, ]
            sprintf(
              "<tr><td>%s</td><td>%s</td><td>%s</td></tr>",
              r$name_direct_loantaker,
              format_vnd_full(r$exposure_vnd),
              format_vnd_bn(r$exposure_vnd)
            )
          }, character(1)),
          collapse = "\n"
        )
      }
  } else {
    "<tr><td colspan=\"3\">Every normalized counterparty resolves to an ABCD company.</td></tr>"
  }

  na_exposure_note <- ""
  if (n_na_exposure > 0) {
    na_exposure_note <- paste0(
      "<div class=\"callout callout-warning\"><strong>",
      n_na_exposure,
      " normalized row(s) carry NA exposure</strong> (unsupported currency or a USD row with no configured ",
      "<code>inputs.fx_rate_usd_vnd</code>). They count toward normalized_rows but contribute 0 VND to ",
      "normalized_vnd -- the arithmetic identities below hold because submitted_vnd is likewise the ",
      "VND-basis total of everything that entered the money ledger.</div>"
    )
  }

  html <- paste0('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Coverage & Reconciliation Report — ', htmltools_escape(cfg$bank_name), '</title>
<style>
  :root {
    --primary: #1a365d;
    --accent: #2b6cb0;
    --green: #276749;
    --red: #c53030;
    --orange: #c05621;
    --bg: #f7fafc;
    --card-bg: #ffffff;
    --border: #e2e8f0;
    --text: #2d3748;
    --text-light: #718096;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.7;
  }
  .hero {
    background: linear-gradient(135deg, var(--primary) 0%, var(--accent) 100%);
    color: white;
    padding: 3rem 2rem;
    text-align: center;
  }
  .hero h1 { font-size: 2rem; font-weight: 700; margin-bottom: 0.5rem; }
  .hero .subtitle { font-size: 1.1rem; opacity: 0.9; font-weight: 300; }
  .hero .meta { margin-top: 1.2rem; font-size: 0.85rem; opacity: 0.7; }
  .container { max-width: 1000px; margin: 0 auto; padding: 2rem 1.5rem; }
  .section {
    background: var(--card-bg);
    border-radius: 8px;
    padding: 2rem;
    margin-bottom: 2rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  }
  .section h2 {
    color: var(--primary);
    font-size: 1.4rem;
    margin-bottom: 0.3rem;
    padding-bottom: 0.6rem;
    border-bottom: 2px solid var(--border);
  }
  .kpi-row {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
    gap: 1rem;
    margin: 1.5rem 0;
  }
  .kpi-card {
    background: #f7fafc;
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1.2rem;
    text-align: center;
  }
  .kpi-card .value { font-size: 1.5rem; font-weight: 700; color: var(--primary); }
  .kpi-card .label { font-size: 0.8rem; color: var(--text-light); margin-top: 0.3rem; }
  table {
    width: 100%;
    border-collapse: collapse;
    margin: 1rem 0;
    font-size: 0.9rem;
  }
  th {
    background: var(--primary);
    color: white;
    padding: 0.7rem 1rem;
    text-align: left;
    font-weight: 600;
  }
  td { padding: 0.6rem 1rem; border-bottom: 1px solid var(--border); }
  tr:nth-child(even) { background: #f7fafc; }
  .callout {
    padding: 1rem 1.2rem;
    border-radius: 6px;
    margin: 1rem 0;
    font-size: 0.92rem;
  }
  .callout-warning { background: #fffbeb; border-left: 4px solid var(--orange); }
  .callout-info { background: #ebf8ff; border-left: 4px solid var(--accent); }
  .callout-success { background: #f0fff4; border-left: 4px solid var(--green); }
  .footer {
    text-align: center;
    padding: 2rem;
    color: var(--text-light);
    font-size: 0.8rem;
    border-top: 1px solid var(--border);
    margin-top: 2rem;
  }
</style>
</head>
<body>

<div class="hero">
  <h1>Coverage &amp; Reconciliation Report</h1>
  <div class="subtitle">', htmltools_escape(cfg$bank_name), '</div>
  <div class="meta">Generated: ', generated_at, '</div>
</div>

<div class="container">

<div class="section">
  <h2>1. Reconciliation — Submitted vs Processed vs Dropped</h2>
  ', if (is.null(raw_path)) {
    '<div class="callout callout-info">Raw loanbook not configured for this engagement — reconciliation unavailable. The ABCD coverage section below still applies to the processed loanbook.</div>'
  } else {
    paste0('
  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value">', t$submitted_rows, '</div>
      <div class="label">Rows Submitted</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--green);">', t$normalized_rows, '</div>
      <div class="label">Rows Normalized</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">', t$dropped_rows, '</div>
      <div class="label">Rows Dropped</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--orange);">', t$warned_rows, '</div>
      <div class="label">Rows Retained with Warning</div>
    </div>
  </div>

  <table>
    <tr><th>Outcome</th><th>Rows</th><th>Exposure (VND)</th><th>Exposure (bn VND)</th><th>% of Submitted VND</th></tr>
    ', rec_rows_html, '
  </table>

  <div class="callout callout-info">
    <strong>Identities:</strong> rows: <code>submitted (', t$submitted_rows, ') == normalized (', t$normalized_rows, ') + dropped (', t$dropped_rows, ')</code>.
    Money: <code>submitted (', format_vnd_full(t$submitted_vnd), ') == normalized (', format_vnd_full(t$normalized_vnd), ') + dropped (', format_vnd_full(t$dropped_vnd), ')</code>.
    Retained-with-warning rows are a subset of normalized rows.
  </div>
  ', na_exposure_note, '
  ')
  }, '
</div>

<div class="section">
  <h2>2. Dropped by Hard Error</h2>
  <table>
    <tr><th>Error Column</th><th>Rows</th><th>Exposure (VND)</th><th>Exposure (bn VND)</th></tr>
    ', error_cols_html, '
  </table>
</div>

<div class="section">
  <h2>3. Retained Rows by Warning Classification</h2>
  <table>
    <tr><th>Classification</th><th>Rows</th></tr>
    ', warn_class_html, '
  </table>
</div>

<div class="section">
  <h2>4. ABCD Asset-Level Coverage</h2>
  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value" style="color: var(--green);">', sprintf("%.1f%%", coverage$coverage_pct), '</div>
      <div class="label">Covered Exposure Share</div>
    </div>
    <div class="kpi-card">
      <div class="value">', format_vnd_bn(coverage$covered_vnd), '</div>
      <div class="label">Covered Exposure</div>
    </div>
    <div class="kpi-card">
      <div class="value">', nrow(coverage$unmatched), '</div>
      <div class="label">Unmatched Counterparties</div>
    </div>
  </div>

  <h3 style="margin-top:1rem;">By Sector</h3>
  <table>
    <tr><th>PACTA Sector</th><th>Exposure (VND)</th><th>Covered (VND)</th><th>Coverage %</th></tr>
    ', abcd_sector_html, '
  </table>

  <h3 style="margin-top:1rem;">Unmatched Counterparties (to chase)</h3>
  <table>
    <tr><th>Name</th><th>Exposure (VND)</th><th>Exposure (bn VND)</th></tr>
    ', unmatched_html, '
  </table>
  <p style="font-size:0.85rem;color:var(--text-light);margin-top:0.5rem;">Names are matched to ABCD after diacritic normalization (normalize_vn_name). Showing up to 25 unmatched rows.</p>
</div>

</div>

<div class="footer">
  Coverage &amp; Reconciliation Report — ', htmltools_escape(cfg$bank_name), ' — Generated ', generated_at, '<br>
  <strong>Synthetic / illustrative data.</strong> This report is generated from synthetic data for demonstration
  purposes only and does not represent any real institution, client, or exposure.
</div>

</body>
</html>')

  write_html_report(html, output_path)
  cat(sprintf("Report saved to: %s\n", normalizePath(output_path)))
  cat(sprintf("File size: %.1f KB\n", file.info(output_path)$size / 1024))
}

#' Escape text for safe interpolation into the HTML report.
#' @param x character — raw text.
#' @return character — HTML-escaped.
htmltools_escape <- function(x) {
  if (is.null(x)) return("")
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

if (identical(environment(), globalenv()) && sys.nframe() == 0L) {
  main()
}
