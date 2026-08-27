#!/usr/bin/env Rscript
# tools/render_pdf.R
# Wave 3 PHASE-07: HTML -> PDF renderer behind a requireNamespace() guard.
#
# HTML remains the canonical generated artifact (see docs/outputs_layer.md).
# This tool is never invoked from scripts/run_engagement.R and does not
# appear in R/step_registry.R -- it is an operator-side convenience for
# producing client-hand-off PDFs from the self-contained HTML reports.
#
# Usage:
#   Rscript tools/render_pdf.R <input.html> <output.pdf>
#   Rscript tools/render_pdf.R reports/BIDV_Framework_Recommendation_Report.html /tmp/out.pdf
#
# Prerequisite (any one):
#   install.packages("pagedown")  # preferred: pagedown::chrome_print()
#   # or
#   install.packages("chromote")  # fallback: chromote
#
# When no renderer is available, this script prints a clear, actionable
# message and exits non-zero naming the missing package and its install
# command -- it never raises an uncaught R error.

render_pdf <- function(html_path, pdf_path) {
  if (!file.exists(html_path)) {
    stop(sprintf("render_pdf: input HTML not found: %s", html_path), call. = FALSE)
  }
  if (requireNamespace("pagedown", quietly = TRUE)) {
    # pagedown::chrome_print handles self-contained HTML correctly; prefer it.
    pagedown::chrome_print(input = html_path, output = pdf_path, timeout = 60)
    return(invisible(pdf_path))
  }
  if (requireNamespace("chromote", quietly = TRUE)) {
    b <- chromote::ChromoteSession$new()
    on.exit(try(b$close(), silent = TRUE), add = TRUE)
    b$Page$navigate(paste0("file://", normalizePath(html_path, mustWork = TRUE)))
    Sys.sleep(2)
    b$Page$printToPDF(path = pdf_path)
    return(invisible(pdf_path))
  }
  msg <- paste0(
    "No PDF renderer available.\n",
    "  Install one of the following and retry:\n",
    "    install.packages(\"pagedown\")   # then pagedown::chrome_print() will be used\n",
    "    install.packages(\"chromote\")   # fallback renderer\n",
    "  Ensure Chrome/Chromium is installed for pagedown::chrome_print().\n",
    "  Original request: ", html_path, " -> ", pdf_path, "\n",
    "  HTML remains the canonical generated artifact (see docs/outputs_layer.md)."
  )
  stop(msg, call. = FALSE)
}

args <- commandArgs(trailingOnly = TRUE)
if (identical(environment(), globalenv()) && sys.nframe() == 0L) {
  if (length(args) < 2) {
    cat("Usage: Rscript tools/render_pdf.R <input.html> <output.pdf>\n")
    cat("  Converts a self-contained HTML report to PDF.\n")
    cat("  Requires pagedown or chromote + Chrome/Chromium (see file header).\n")
    quit(status = 1)
  }
  html_path <- args[1]
  pdf_path  <- args[2]
  tryCatch({
    render_pdf(html_path, pdf_path)
    cat(sprintf("[OK] PDF written: %s (from %s)\n", pdf_path, html_path))
    quit(status = 0)
  }, error = function(e) {
    cat(sprintf("ERROR: %s\n", conditionMessage(e)))
    quit(status = 1)
  })
}
