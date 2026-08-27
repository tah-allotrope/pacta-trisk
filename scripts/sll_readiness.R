#!/usr/bin/env Rscript
# ==============================================================================
# sll_readiness.R
# Wave 3 PHASE-06: pipeline step wrapper for R/sll_readiness.R. Reads
# output/engagement/engagement_priority.csv (must run after
# engagement_scoring) and data/vietnam_abcd.csv; writes sll_readiness.csv
# and an HTML shortlist report to the engagement's reports directory.
#
# Usage: Rscript scripts/sll_readiness.R --config <path>
# ==============================================================================

source("R/engagement_config.R")
source("R/severity_scoring.R")
source("R/sll_readiness.R")
source("R/report_toolkit.R")

cfg <- load_engagement_config(get_config_arg())

priority_path <- file.path(cfg$paths$engagement_output_dir, "engagement_priority.csv")
if (!file.exists(priority_path)) {
  stop(sprintf(
    "sll_readiness.R: %s not found -- run engagement_scoring first.", priority_path
  ), call. = FALSE)
}
priority <- utils::read.csv(priority_path, stringsAsFactors = FALSE)
abcd <- utils::read.csv(cfg$inputs$abcd_csv, stringsAsFactors = FALSE)

overlay <- NULL
if (length(cfg$inputs$relationship_overlay_csv) > 0) {
  overlay <- utils::read.csv(cfg$inputs$relationship_overlay_csv, stringsAsFactors = FALSE)
}

readiness <- sll_readiness(priority, abcd, overlay)

out_path <- file.path(cfg$paths$engagement_output_dir, "sll_readiness.csv")
utils::write.csv(readiness, out_path, row.names = FALSE, na = "")

qualified <- readiness[readiness$readiness_band %in% c("Ready", "Near-ready"), , drop = FALSE]
table_html <- paste0(
  "<table><tr><th>Borrower</th><th>Sector</th><th>Exposure (VND)</th><th>Readiness</th><th>Band</th></tr>",
  paste(vapply(seq_len(nrow(qualified)), function(i) sprintf(
    "<tr><td>%s</td><td>%s</td><td>%s</td><td>%.3f</td><td>%s</td></tr>",
    qualified$name_abcd[i], qualified$sector[i],
    format(qualified$exposure_vnd[i], big.mark = ",", scientific = FALSE),
    qualified$readiness[i], qualified$readiness_band[i]
  ), character(1)), collapse = ""),
  "</table>"
)

partial_note <- if (any(readiness$readiness_partial)) {
  "<p><em>No relationship-signal overlay was configured for this engagement -- the relationship dimension was dropped and the remaining three weights renormalized (readiness_partial = TRUE for every row).</em></p>"
} else ""

i18n_lang_sll <- if (is.null(cfg$report_language) || length(cfg$report_language)==0) "en" else cfg$report_language
i18n_labels_sll <- tryCatch(load_report_labels(override_csv = if (length(cfg$paths$i18n_override_csv)>0) cfg$paths$i18n_override_csv else NULL), error=function(e) NULL)
html_title_sll <- report_label("sll_readiness_title", i18n_lang_sll, i18n_labels_sll)
html <- paste0(
  "<!DOCTYPE html><html><head><meta charset='utf-8'><title>", html_title_sll, "</title>",
  report_css(),
  "</head><body><div class='container'>",
  sprintf("<h1>%s: %s</h1>", html_title_sll, cfg$bank_name),
  "<p style='color:#c53030;'><strong>", report_label("synthetic_disclaimer", i18n_lang_sll, i18n_labels_sll), "</strong> ",
  "This tool ranks and bands a qualified pool; it does not select the final shortlist -- ",
  "the analyst records the selection rationale in the analyst_rationale column of sll_readiness.csv.</p>",
  partial_note,
  sprintf("<h2>Qualified pool (Ready / Near-ready): %d of %d borrowers</h2>", nrow(qualified), nrow(readiness)),
  table_html,
  "</div></body></html>"
)

# i18n table headers + bilingual note
if (i18n_lang_sll %in% c("vi", "bilingual") && !is.null(i18n_labels_sll)) {
  html <- gsub("<th>Borrower</th>", paste0("<th>", report_label("borrower", i18n_lang_sll, i18n_labels_sll), "</th>"), html, fixed = TRUE)
  html <- gsub("<th>Sector</th>", paste0("<th>", report_label("sector", i18n_lang_sll, i18n_labels_sll), "</th>"), html, fixed = TRUE)
  html <- gsub("<th>Exposure (VND)</th>", paste0("<th>", report_label("exposure_vnd", i18n_lang_sll, i18n_labels_sll), "</th>"), html, fixed = TRUE)
  html <- gsub("<th>Readiness</th>", paste0("<th>", report_label("readiness", i18n_lang_sll, i18n_labels_sll), "</th>"), html, fixed = TRUE)
  html <- gsub("<th>Band</th>", paste0("<th>", report_label("readiness_band", i18n_lang_sll, i18n_labels_sll), "</th>"), html, fixed = TRUE)
}
if (identical(i18n_lang_sll, "bilingual")) {
  html <- sub("<div class='container'>",
              "<div class='container'><div class=\"callout callout-info\">Section headings, table column labels and the synthetic-data disclaimer are shown as English / Vietnamese; analyst-written narrative remains English.</div>",
              html, fixed = TRUE)
}
write_html_report(html, file.path(cfg$paths$reports_dir, "SLL_Readiness_Shortlist.html"))
cat(sprintf(
  "[OK] SLL readiness written: %s (%d qualified of %d total borrowers)\n",
  out_path, nrow(qualified), nrow(readiness)
))
