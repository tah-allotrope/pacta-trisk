#!/usr/bin/env Rscript
# generate_validation_report.R
# Generates a client-grade HTML validation report from intake outputs.
#
# Usage:
#   Rscript scripts/generate_validation_report.R \
#     --intake-dir intake/output \
#     --output reports/Intake_Validation_Report.html \
#     [--bank-name "Bank Name"]

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("R/report_toolkit.R")

args <- commandArgs(trailingOnly = TRUE)

get_arg <- function(flag, default = NULL) {
  idx <- which(args == flag)
  if (length(idx) > 0 && idx < length(args)) return(args[idx + 1])
  default
}

intake_dir  <- get_arg("--intake-dir")
output_path <- get_arg("--output", "reports/Intake_Validation_Report.html")
bank_name   <- get_arg("--bank-name", "Client Bank")

if (is.null(intake_dir)) {
  stop("Usage: Rscript scripts/generate_validation_report.R --intake-dir <dir> [--output <path>] [--bank-name <name>]")
}

required_files <- c(
  "validation_summary.txt",
  "validation_errors.csv",
  "normalized_loanbook.csv",
  "match_preview.csv"
)

for (f in required_files) {
  fp <- file.path(intake_dir, f)
  if (!file.exists(fp)) {
    stop(sprintf("Missing required input file: %s", fp))
  }
}

cat("Reading intake artifacts...\n")
summary_text <- readLines(file.path(intake_dir, "validation_summary.txt"), warn = FALSE)
errors <- read_csv(file.path(intake_dir, "validation_errors.csv"), show_col_types = FALSE)
loanbook <- read_csv(file.path(intake_dir, "normalized_loanbook.csv"), show_col_types = FALSE)
matches <- read_csv(file.path(intake_dir, "match_preview.csv"), show_col_types = FALSE)

n_total <- nrow(loanbook)
n_errors <- nrow(errors)
n_valid <- n_total - n_errors
pct_valid <- round(100 * n_valid / max(n_total, 1), 1)

error_types <- if (n_errors > 0) {
  errors %>% count(column, name = "count") %>% arrange(desc(count))
} else {
  tibble(column = character(), count = integer())
}

n_matched <- if (nrow(matches) > 0) sum(!matches$review_needed) else 0
n_review <- if (nrow(matches) > 0) sum(matches$review_needed) else 0
n_unmatched <- n_total - nrow(matches)

cat("Building HTML report...\n")

generated_at <- format(Sys.time(), "%Y-%m-%d %H:%M %Z")

error_rows_html <- ""
if (n_errors > 0) {
  rows <- head(errors, 50)
  error_rows_html <- paste0(
    "<tr><td>", rows$row, "</td><td><code>", rows$column, "</code></td><td>",
    gsub("<", "&lt;", gsub(">", "&gt;", rows$error)), "</td></tr>",
    collapse = "\n"
  )
}

match_rows_html <- ""
if (nrow(matches) > 0) {
  rows <- head(matches, 50)
  match_rows_html <- paste0(
    "<tr><td>", rows$input_counterparty, "</td><td>", rows$best_abcd_match,
    "</td><td>", sprintf("%.2f", rows$score), "</td><td>",
    ifelse(rows$review_needed, "Review", "OK"), "</td></tr>",
    collapse = "\n"
  )
}

html <- paste0('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Intake Validation Report — ', bank_name, '</title>
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
  .hero h1 { font-size: 2.2rem; font-weight: 700; margin-bottom: 0.5rem; }
  .hero .subtitle { font-size: 1.1rem; opacity: 0.9; font-weight: 300; }
  .hero .meta { margin-top: 1.2rem; font-size: 0.85rem; opacity: 0.7; }
  .container { max-width: 960px; margin: 0 auto; padding: 2rem 1.5rem; }
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
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
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
  .kpi-card .value { font-size: 1.8rem; font-weight: 700; color: var(--primary); }
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
  .badge {
    display: inline-block;
    padding: 0.15rem 0.6rem;
    border-radius: 12px;
    font-size: 0.78rem;
    font-weight: 600;
  }
  .badge-red { background: #fed7d7; color: var(--red); }
  .badge-green { background: #c6f6d5; color: var(--green); }
  .badge-gray { background: #e2e8f0; color: #4a5568; }
  .footer {
    text-align: center;
    padding: 2rem;
    color: var(--text-light);
    font-size: 0.8rem;
    border-top: 1px solid var(--border);
    margin-top: 2rem;
  }
  .checklist { list-style: none; padding: 0; }
  .checklist li { padding: 0.4rem 0; padding-left: 1.5rem; position: relative; }
  .checklist li::before { content: "\\2610"; position: absolute; left: 0; }
</style>
</head>
<body>

<div class="hero">
  <h1>Intake Validation Report</h1>
  <div class="subtitle">', bank_name, '</div>
  <div class="meta">Generated: ', generated_at, '</div>
</div>

<div class="container">

<div class="section">
  <h2>1. Summary</h2>
  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value">', n_total, '</div>
      <div class="label">Rows Received</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--green);">', n_valid, '</div>
      <div class="label">Rows Valid</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: ', ifelse(pct_valid >= 80, "var(--green)", "var(--red)"), ';">', pct_valid, '%</div>
      <div class="label">Exposure Validated</div>
    </div>
    <div class="kpi-card">
      <div class="value">', n_errors, '</div>
      <div class="label">Errors Found</div>
    </div>
  </div>
  ', if (n_errors == 0) '<div class="callout callout-success"><strong>All rows passed validation.</strong> No errors detected in the loanbook submission.</div>' else
     if (pct_valid >= 80) '<div class="callout callout-warning"><strong>Most rows passed validation.</strong> Review the errors below and resubmit corrected rows.</div>' else
     '<div class="callout" style="background:#fff5f5;border-left:4px solid var(--red);"><strong>Significant validation issues.</strong> Please correct the errors below and resubmit the loanbook.</div>', '
</div>

<div class="section">
  <h2>2. Validation Errors</h2>
  ', if (n_errors == 0) '<p>No validation errors found.</p>' else '
  <table>
    <tr><th>Row</th><th>Column</th><th>Error</th></tr>
    ', error_rows_html, '
  </table>
  <p style="font-size:0.85rem;color:var(--text-light);">Showing up to 50 of ', n_errors, ' errors.</p>
  ', '
</div>

<div class="section">
  <h2>3. Match Preview</h2>
  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value" style="color: var(--green);">', n_matched, '</div>
      <div class="label">Matched</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--orange);">', n_review, '</div>
      <div class="label">Review Needed</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--text-light);">', n_unmatched, '</div>
      <div class="label">Unmatched</div>
    </div>
  </div>
  ', if (nrow(matches) > 0) paste0('
  <table>
    <tr><th>Counterparty</th><th>Best ABCD Match</th><th>Score</th><th>Status</th></tr>
    ', match_rows_html, '
  </table>
  <p style="font-size:0.85rem;color:var(--text-light);">Showing up to 50 of ', nrow(matches), ' matches.</p>
  ') else '
  <p>No matches found. The ABCD database may not contain these counterparties, or the fuzzy matching threshold was not met.</p>
  ', '
</div>

<div class="section">
  <h2>4. Next Steps</h2>
  <ul class="checklist">
    <li>Correct validation errors and resubmit the loanbook</li>
    <li>Review fuzzy matches marked "Review" for accuracy</li>
    <li>Provide additional identifiers (LEI, tax ID) for unmatched counterparties</li>
    <li>Confirm sector classifications for "not in scope" entries</li>
    <li>Schedule a follow-up review once corrections are complete</li>
  </ul>
</div>

</div>

<div class="footer">
  Intake Validation Report — ', bank_name, ' — Generated ', generated_at, '<br>
  <strong>Confidential.</strong> This report contains synthetic or client data for demonstration purposes only.
</div>

</body>
</html>')

  # --- i18n (PHASE-07) ---
  # report_toolkit may not be sourced yet in this file; ensure functions are available.
  if (!exists("report_label")) source("R/report_toolkit.R")
  i18n_lang_v <- if (exists("cfg") && !is.null(cfg$report_language) && length(cfg$report_language) > 0) cfg$report_language else "en"
  # When called without --config, cfg is not defined above — load defaults
  if (!exists("cfg")) { source("R/engagement_config.R"); cfg <- load_engagement_config(NULL); i18n_lang_v <- cfg$report_language }
  i18n_labels_v <- tryCatch(
    load_report_labels(override_csv = if (!is.null(cfg$paths$i18n_override_csv) && length(cfg$paths$i18n_override_csv) > 0) cfg$paths$i18n_override_csv else NULL),
    error = function(e) NULL
  )
  if (!is.null(i18n_labels_v) && i18n_lang_v %in% c("vi", "bilingual")) {
    html <- gsub("Intake Validation Report", report_label("validation_report_title", i18n_lang_v, i18n_labels_v), html, fixed = TRUE)
    html <- gsub("Synthetic data — illustrative only", report_label("synthetic_disclaimer", i18n_lang_v, i18n_labels_v), html, fixed = TRUE)
    if (identical(i18n_lang_v, "bilingual")) {
      html <- sub("<div class=\"container\">",
                  paste0("<div class=\"container\"><div class=\"callout callout-info\">Section headings, table column labels and the synthetic-data disclaimer are shown as English / Vietnamese; analyst-written narrative remains English.</div>"),
                  html, fixed = TRUE)
    }
  } else if (identical(i18n_lang_v, "bilingual")) {
    html <- sub("<div class=\"container\">",
                "<div class=\"container\"><div class=\"callout callout-info\">Section headings, table column labels and the synthetic-data disclaimer are shown as English / Vietnamese; analyst-written narrative remains English.</div>",
                html, fixed = TRUE)
  }

write_html_report(html, output_path)
cat(sprintf("Report saved to: %s\n", normalizePath(output_path)))
cat(sprintf("File size: %.1f KB\n", file.info(output_path)$size / 1024))
