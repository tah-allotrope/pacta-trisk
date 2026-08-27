# ==============================================================================
# R/report_toolkit.R
# Shared helpers for the repo's hand-built self-contained HTML report
# generators (scripts/pacta_vietnam_scenario.R,
# scripts/generate_validation_report.R, and later report scripts).
#
# Only genuinely identical logic is centralized here. Each report's CSS and
# section markup remain bespoke per-report (a Vietnam-branded report and a
# generic PACTA report intentionally look different) — those stay local to
# each script. See report_css() below for the one exception: a documented
# starting-point palette for NEW reports, not a retrofit of existing ones.
# ==============================================================================

if (requireNamespace("base64enc", quietly = TRUE)) {
  suppressPackageStartupMessages(library(base64enc))
}

#' Encode a PNG file as a base64 data URI.
#'
#' Requires the base64enc package (pinned in renv.lock). Callers that must
#' degrade gracefully without it (see attic/generate_report.R, retired
#' Wave 3 PHASE-02) source this file and then override img_to_base64
#' themselves when requireNamespace("base64enc") is FALSE.
#'
#' @param path character — path to a PNG file.
#' @return character — a `data:image/png;base64,...` URI string.
#' @export
img_to_base64 <- function(path) {
  raw <- readBin(path, "raw", file.info(path)$size)
  b64 <- base64enc::base64encode(raw)
  paste0("data:image/png;base64,", b64)
}

#' Shared baseline CSS palette for new self-contained HTML reports.
#'
#' Existing reports (PACTA alignment / Vietnam / validation) each keep their
#' own bespoke CSS — this is a starting point for report generators written
#' after this module existed, not a shared stylesheet those retrofit to.
#'
#' @return character — a single `<style>...</style>` block.
#' @export
report_css <- function() {
  paste0(
    "<style>\n",
    "  :root {\n",
    "    --primary: #1a365d;\n",
    "    --accent: #2b6cb0;\n",
    "    --green: #276749;\n",
    "    --red: #c53030;\n",
    "    --orange: #c05621;\n",
    "    --bg: #f7fafc;\n",
    "    --card-bg: #ffffff;\n",
    "    --border: #e2e8f0;\n",
    "    --text: #2d3748;\n",
    "    --text-light: #718096;\n",
    "  }\n",
    "  * { margin: 0; padding: 0; box-sizing: border-box; }\n",
    "  body {\n",
    "    font-family: \"Segoe UI\", system-ui, -apple-system, sans-serif;\n",
    "    background: var(--bg); color: var(--text); line-height: 1.7;\n",
    "  }\n",
    "  .container { max-width: 960px; margin: 0 auto; padding: 2rem 1.5rem; }\n",
    "</style>\n"
  )
}

#' Write a self-contained HTML report to disk, creating the destination
#' directory if needed.
#'
#' @param html character — the full HTML document as a single string.
#' @param path character — destination file path.
#' @param use_bytes logical — passed to writeLines()'s useBytes argument;
#'   default TRUE matches the existing report generators.
#' @return invisible(character) — the path written.
#' @export
write_html_report <- function(html, path, use_bytes = TRUE) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  writeLines(html, path, useBytes = use_bytes)
  invisible(path)
}
