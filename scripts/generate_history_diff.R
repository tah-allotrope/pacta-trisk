#!/usr/bin/env Rscript
# ==============================================================================
# generate_history_diff.R
# Wave 3 PHASE-04: renders an HTML report comparing the two most recent
# recorded runs for an engagement (history/<bank_slug>/), using
# R/run_history.R's history_diff(). Requires at least two recorded runs;
# exits with a clear message (not a cryptic error) when fewer exist.
#
# Usage: Rscript scripts/generate_history_diff.R --config <path> --output <path.html>
# ==============================================================================

source("R/engagement_config.R")
source("R/run_history.R")
source("R/report_toolkit.R")

args <- commandArgs(trailingOnly = TRUE)
get_flag <- function(args, name) {
  idx <- which(args == name)
  if (length(idx) == 0 || idx[[1]] >= length(args)) return(NULL)
  args[[idx[[1]] + 1]]
}

config_path <- get_flag(args, "--config")
output_path <- get_flag(args, "--output")
if (is.null(config_path) || is.null(output_path)) {
  stop("Usage: Rscript scripts/generate_history_diff.R --config <path> --output <path.html>", call. = FALSE)
}

cfg <- load_engagement_config(config_path)
runs <- history_runs(cfg$bank_slug)

if (length(runs) < 2) {
  cat(sprintf(
    "[SKIP] generate_history_diff.R: only %d recorded run(s) for '%s' -- need at least 2. Nothing written.\n",
    length(runs), cfg$bank_slug
  ))
  quit(status = 0)
}

run_a <- runs[[length(runs) - 1]]
run_b <- runs[[length(runs)]]

diff_priority <- tryCatch(
  history_diff(cfg$bank_slug, run_a, run_b, "engagement_priority.csv",
               key_cols = "name_abcd", value_cols = "composite_score"),
  error = function(e) data.frame()
)
diff_sector <- tryCatch(
  history_diff(cfg$bank_slug, run_a, run_b, "sector_priority_ranking.csv",
               key_cols = "sector", value_cols = "composite_score"),
  error = function(e) data.frame()
)

render_table <- function(df) {
  if (nrow(df) == 0) return("<p><em>No changes.</em></p>")
  header <- paste0("<tr>", paste(sprintf("<th>%s</th>", names(df)), collapse = ""), "</tr>")
  body_rows <- vapply(seq_len(nrow(df)), function(i) {
    cells <- vapply(df[i, ], function(v) if (is.numeric(v)) sprintf("%.6f", v) else as.character(v), character(1))
    paste0("<tr>", paste(sprintf("<td>%s</td>", cells), collapse = ""), "</tr>")
  }, character(1))
  paste0("<table>", header, paste(body_rows, collapse = ""), "</table>")
}

html <- paste0(
  "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Run History Diff</title>",
  report_css(),
  "</head><body><div class='container'>",
  sprintf("<h1>Run History Diff: %s</h1>", cfg$bank_name),
  sprintf("<p><strong>Comparing:</strong> %s &rarr; %s</p>", run_a, run_b),
  "<p style='color:#c53030;'><strong>All figures are illustrative, synthetic-portfolio outputs.</strong></p>",
  "<h2>Engagement priority (composite_score)</h2>", render_table(diff_priority),
  "<h2>Sector ranking (composite_score)</h2>", render_table(diff_sector),
  "</div></body></html>"
)

write_html_report(html, output_path)
cat(sprintf("[OK] Run history diff written: %s\n", output_path))
