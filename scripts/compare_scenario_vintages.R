#!/usr/bin/env Rscript
# ==============================================================================
# compare_scenario_vintages.R
# Wave 3 PHASE-03: runs the PACTA alignment stage twice for the same
# engagement -- once per named scenario vintage -- and renders an HTML
# report showing how the portfolio-level alignment gap moved when the
# benchmark scenario changed (not when the portfolio itself changed). This
# is the first real exercise of the vintage-directory convention Wave 1
# built (data/scenarios/<vintage>/, policed by INV-002) and never gave a
# second tenant until Wave 3 PHASE-03 added data/scenarios/pdp8-2025-adjusted/.
#
# Usage:
#   Rscript scripts/compare_scenario_vintages.R --config <path> \
#     --vintage-a <name> --vintage-b <name> --output <path.html>
#
# Each named vintage must exist at data/scenarios/<name>/ with both
# vietnam_scenario_ms.csv and vietnam_scenario_co2.csv present (the same
# contract INV-009 checks). The base engagement config's own scenario
# selection is not used for anything except bank_name/loanbook/abcd -- the
# vintage comparison overrides inputs.scenario_vintage (and the two
# scenario CSV paths) explicitly for each of the two runs.
# ==============================================================================

suppressPackageStartupMessages({
  library(jsonlite)
})

source("R/engagement_config.R")
source("R/report_toolkit.R")

args <- commandArgs(trailingOnly = TRUE)

get_flag_value <- function(args, name) {
  idx <- which(args == name)
  if (length(idx) == 0 || idx[[1]] >= length(args)) return(NULL)
  args[[idx[[1]] + 1]]
}

config_path <- get_flag_value(args, "--config")
vintage_a <- get_flag_value(args, "--vintage-a")
vintage_b <- get_flag_value(args, "--vintage-b")
output_path <- get_flag_value(args, "--output")

if (is.null(config_path) || is.null(vintage_a) || is.null(vintage_b) || is.null(output_path)) {
  stop(paste(
    "Usage: Rscript scripts/compare_scenario_vintages.R --config <path>",
    "--vintage-a <name> --vintage-b <name> --output <path.html>"
  ), call. = FALSE)
}

base_cfg <- load_engagement_config(config_path)

#' Build a derived engagement config JSON pointed at one scenario vintage
#' and one scratch pacta_output_dir, and run the PACTA alignment stage
#' against it as a subprocess.
#'
#' @param base_cfg list — the loaded base engagement config.
#' @param vintage character(1) — a name under data/scenarios/.
#' @param out_dir character(1) — scratch directory for this run's PACTA outputs.
#' @return character(1) — out_dir, for chaining.
run_pacta_for_vintage <- function(base_cfg, vintage, out_dir) {
  vintage_dir <- file.path("data", "scenarios", vintage)
  if (!dir.exists(vintage_dir)) {
    stop(sprintf("compare_scenario_vintages.R: no such scenario vintage directory: %s", vintage_dir), call. = FALSE)
  }

  derived <- base_cfg
  derived$inputs$scenario_vintage <- vintage
  derived$inputs$scenario_ms_csv <- file.path(vintage_dir, "vietnam_scenario_ms.csv")
  derived$inputs$scenario_co2_csv <- file.path(vintage_dir, "vietnam_scenario_co2.csv")
  # A vintage other than the shared data/vietnam_region_isos.csv's own
  # pdp8_2023 rows needs a region_isos file whose `source` column includes
  # ITS scenario_source (see data/scenarios/pdp8-2025-adjusted/SOURCE.md --
  # target_market_share() silently drops any scenario row whose
  # scenario_source is not present in region_isos, with no error). Use the
  # vintage-scoped copy when the vintage directory ships one; fall back to
  # the base config's (shared) region_isos_csv otherwise -- this is exactly
  # right for "pdp8-2023" itself, which needs no scoped copy.
  vintage_region_isos <- file.path(vintage_dir, "vietnam_region_isos.csv")
  if (file.exists(vintage_region_isos)) {
    derived$inputs$region_isos_csv <- vintage_region_isos
  }
  derived$paths$pacta_output_dir <- out_dir
  # This is a read-only comparison run; never let it touch the public snapshot.
  derived$public_snapshot_allowed <- FALSE

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  tmp_config <- file.path(out_dir, "engagement_config.vintage_run.json")
  write(toJSON(derived, auto_unbox = TRUE, pretty = TRUE), tmp_config)

  cat(sprintf("\n=== Running PACTA for vintage '%s' ===\n", vintage))
  status <- system2("Rscript", args = c("scripts/pacta_vietnam_scenario.R", "--config", tmp_config))
  if (!identical(status, 0L) && !identical(status, 0)) {
    stop(sprintf("compare_scenario_vintages.R: pacta_vietnam_scenario.R failed for vintage '%s'", vintage), call. = FALSE)
  }
  out_dir
}

# A REPO-RELATIVE scratch path, not tempdir() -- lessons.md #2:
# file.path(getwd(), <already-absolute-path>) elsewhere in the pipeline
# (e.g. pacta_vietnam_scenario.R's output writers) double-joins an absolute
# pacta_output_dir onto getwd(), producing a broken path like
# "<repo>/C:/Users/.../Temp/...". A relative path under the repo avoids the
# whole class of bug. bench/ is gitignored (Wave 3 PHASE-04) and safe to
# treat as scratch space.
scratch_root <- file.path("bench", paste0("vintage_compare_", as.integer(Sys.time())))
dir_a <- run_pacta_for_vintage(base_cfg, vintage_a, file.path(scratch_root, "a"))
dir_b <- run_pacta_for_vintage(base_cfg, vintage_b, file.path(scratch_root, "b"))

#' Join two vintages' alignment tables and compute the share/gap delta.
#' @param path_a,path_b character(1) — the two runs' CSV path (same basename).
#' @param key_cols character — join key columns.
#' @param gap_col character(1) — the gap column to diff (share_gap_pp or gap_pct).
#' @return data.frame with key_cols, target_pdp8_a/b, gap_col_a/b, and a
#'   `<gap_col>_delta` column.
diff_alignment_table <- function(path_a, path_b, key_cols, gap_col) {
  a <- utils::read.csv(path_a, stringsAsFactors = FALSE)
  b <- utils::read.csv(path_b, stringsAsFactors = FALSE)
  merged <- merge(a, b, by = key_cols, suffixes = c("_a", "_b"))
  delta_col <- paste0(gap_col, "_delta")
  merged[[delta_col]] <- merged[[paste0(gap_col, "_b")]] - merged[[paste0(gap_col, "_a")]]
  merged[order(-abs(merged[[delta_col]])), ]
}

ms_diff <- diff_alignment_table(
  file.path(dir_a, "06_vn_ms_alignment_2030.csv"), file.path(dir_b, "06_vn_ms_alignment_2030.csv"),
  key_cols = c("sector", "technology"), gap_col = "share_gap_pp"
)
sda_diff <- diff_alignment_table(
  file.path(dir_a, "06_vn_sda_alignment_2030.csv"), file.path(dir_b, "06_vn_sda_alignment_2030.csv"),
  key_cols = "sector", gap_col = "gap_pct"
)

#' Render one diff table as an HTML <table>.
#' @param df data.frame — rows to render.
#' @param cols character — columns to include, in order.
#' @param labels character — matching header labels for `cols`.
#' @return character(1) — an HTML <table>...</table> string.
render_table <- function(df, cols, labels) {
  header <- paste0("<tr>", paste(sprintf("<th>%s</th>", labels), collapse = ""), "</tr>")
  body_rows <- vapply(seq_len(nrow(df)), function(i) {
    cells <- vapply(cols, function(col) {
      value <- df[[col]][i]
      if (is.numeric(value)) sprintf("%.4f", value) else as.character(value)
    }, character(1))
    paste0("<tr>", paste(sprintf("<td>%s</td>", cells), collapse = ""), "</tr>")
  }, character(1))
  paste0("<table>", header, paste(body_rows, collapse = ""), "</table>")
}

ms_table_html <- render_table(
  ms_diff, c("sector", "technology", "target_pdp8_a", "target_pdp8_b", "share_gap_pp_delta"),
  c("Sector", "Technology", sprintf("Target (%s)", vintage_a), sprintf("Target (%s)", vintage_b), "Gap delta (pp)")
)
sda_table_html <- render_table(
  sda_diff, c("sector", "target_pdp8_a", "target_pdp8_b", "gap_pct_delta"),
  c("Sector", sprintf("Target (%s)", vintage_a), sprintf("Target (%s)", vintage_b), "Gap delta (pp)")
)

html <- paste0(
  "<!DOCTYPE html><html><head><meta charset='utf-8'><title>Scenario Vintage Comparison</title>",
  report_css(),
  "</head><body><div class='container'>",
  sprintf("<h1>Scenario Vintage Comparison: %s vs %s</h1>", vintage_a, vintage_b),
  sprintf("<p><strong>Bank:</strong> %s</p>", base_cfg$bank_name),
  "<p style='color:#c53030;'><strong>All figures are illustrative, synthetic-portfolio outputs.</strong> ",
  "See data/scenarios/&lt;vintage&gt;/SOURCE.md for each vintage's provenance and caveats before any client-facing use.</p>",
  "<h2>Power / automotive market-share alignment gap (percentage points)</h2>",
  ms_table_html,
  "<h2>Cement / steel SDA alignment gap (percentage points)</h2>",
  sda_table_html,
  "</div></body></html>"
)

write_html_report(html, output_path)
cat(sprintf("\n[OK] Scenario vintage comparison written: %s\n", output_path))

unlink(scratch_root, recursive = TRUE, force = TRUE)
