#!/usr/bin/env Rscript
# ==============================================================================
# scripts/generate_targets.R
# Wave 3 PHASE-06: sector target registry generator. Reads the already-computed
# PACTA/SDA portfolio files and the engagement's own scenario vintage, calls
# R/target_setting.R::build_target_registry(), and writes target_registry.csv
# plus a self-contained HTML report. Does NOT call pacta_sda() (DEC-009) so
# cement/steel alignment_gap and every frozen artifact remain untouched.
#
# Purely additive: reads synthesis_output/vietnam/*, writes to the engagement's
# own engagement_output_dir and reports_dir, and carries the standard
# synthetic-data disclaimer.
#
# Usage: Rscript scripts/generate_targets.R --config <engagement_config.json>
# ==============================================================================

source("R/engagement_config.R")
source("R/sector_registry.R")  # build_target_registry() reads sector_registry()
source("R/target_setting.R")
source("R/report_toolkit.R")

cfg <- load_engagement_config(get_config_arg())

sda_path <- file.path(cfg$paths$pacta_output_dir, "05_vn_sda_portfolio.csv")
ms_path  <- file.path(cfg$paths$pacta_output_dir, "04_vn_ms_portfolio.csv")

if (!file.exists(sda_path)) {
  stop(sprintf("generate_targets.R: SDA portfolio not found: %s (run pacta_vietnam_scenario first)", sda_path), call. = FALSE)
}
if (!file.exists(ms_path)) {
  stop(sprintf("generate_targets.R: MS portfolio not found: %s", ms_path), call. = FALSE)
}
sda_portfolio <- utils::read.csv(sda_path, stringsAsFactors = FALSE)
ms_portfolio  <- utils::read.csv(ms_path, stringsAsFactors = FALSE)

scenario_co2 <- utils::read.csv(cfg$inputs$scenario_co2_csv, stringsAsFactors = FALSE)
scenario_ms  <- utils::read.csv(cfg$inputs$scenario_ms_csv, stringsAsFactors = FALSE)

registry <- build_target_registry(
  sda_portfolio = sda_portfolio,
  ms_portfolio  = ms_portfolio,
  scenario_co2  = scenario_co2,
  scenario_ms   = scenario_ms,
  scenario_vintage = cfg$inputs$scenario_vintage
)

out_dir <- cfg$paths$engagement_output_dir
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_csv <- file.path(out_dir, "target_registry.csv")
utils::write.csv(registry, out_csv, row.names = FALSE, na = "")
cat(sprintf("[OK] Target registry written: %s (%d rows)\n", out_csv, nrow(registry)))

# Build a compact HTML report for the Reports page
rows_html <- paste(vapply(seq_len(nrow(registry)), function(i) {
  r <- registry[i, ]
  bv <- if (is.na(r$baseline_value)) "n/a" else sprintf("%.4f", r$baseline_value)
  tv <- if (is.na(r$target_value)) "n/a" else sprintf("%.4f", r$target_value)
  sprintf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%d</td><td>%s</td><td>%d</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",
          r$sector, r$metric, r$unit, r$baseline_year, bv, r$target_year, tv,
          r$scope, r$method, r$scenario_vintage, r$status)
}, character(1)), collapse = "\n")

i18n_lang_t <- if (is.null(cfg$report_language) || length(cfg$report_language)==0) "en" else cfg$report_language
i18n_labels_t <- tryCatch(load_report_labels(override_csv = if (length(cfg$paths$i18n_override_csv)>0) cfg$paths$i18n_override_csv else NULL), error=function(e) NULL)
title_t <- report_label("target_registry_title", i18n_lang_t, i18n_labels_t)
html <- paste0(
  "<!DOCTYPE html><html><head><meta charset='utf-8'><title>", title_t, "</title>",
  report_css(),
  "</head><body><div class='container'>",
  sprintf("<h1>%s: %s</h1>", title_t, cfg$bank_name),
  "<p style='color:#c53030;'><strong>", report_label("synthetic_disclaimer", i18n_lang_t, i18n_labels_t), " (", report_label("target_registry_title", i18n_lang_t, i18n_labels_t), " — status \"", report_label("proposed", i18n_lang_t, i18n_labels_t), "\" vs \"", report_label("not_set", i18n_lang_t, i18n_labels_t), "\"). ",
  "No target is \"", report_label("adopted", i18n_lang_t, i18n_labels_t), "\" -- adoption requires a board/committee decision outside this pipeline.</strong></p>",
  "<p>PACTA alignment gaps are measured against the scenario benchmark (how far the portfolio is from the pathway), ",
  "while sector interim targets are computed by <em>convergence</em> from the portfolio's own 2025 baseline. ",
  "Financed emissions is a third, independent construct -- an inventory, not a gap or a target -- and should not be confused with either.</p>",
  if (identical(i18n_lang_t, "bilingual")) "<div class=\"callout callout-info\">Section headings, table column labels and the synthetic-data disclaimer are shown as English / Vietnamese; analyst-written narrative remains English.</div>" else "",
  "<table><tr><th>", report_label("sector", i18n_lang_t, i18n_labels_t),
  "</th><th>Metric</th><th>Unit</th><th>Baseline year</th><th>Baseline value</th>",
  "<th>Target year</th><th>Target value</th><th>Scope</th><th>Method</th><th>Scenario vintage</th><th>Status</th></tr>",
  rows_html,
  "</table>",
  "<p style='font-size:0.85rem;color:#718096;'>Baseline year 2025, horizon 2030 is populated; 2035 and 2050 are emitted with ",
  "target_value NA and status \"not_set\" (multi-horizon schema). Scenario vintage is the engagement's own ",
  "inputs.scenario_vintage.</p>",
  "</div></body></html>"
)

report_path <- file.path(cfg$paths$reports_dir, "Sector_Target_Registry.html")
write_html_report(html, report_path)
cat(sprintf("[OK] Target registry report written: %s\n", report_path))
