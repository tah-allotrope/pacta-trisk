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

# --- i18n overlay (Wave 3 PHASE-07) ---------------------------------------

# In-memory cache so repeated report_label() calls in one run do not re-read
# the CSV from disk. Keyed on c(base_csv, override_csv) paste-collapsed.
.i18n_cache <- new.env(parent = emptyenv())

#' Load the report label table, applying an optional per-engagement override.
#'
#' @param base_csv character(1) — path to templates/i18n/labels.csv.
#' @param override_csv character(1)|NULL — optional per-engagement override
#'   CSV at cfg$paths$i18n_override_csv; when configured, any row whose
#'   token matches a base row replaces that base row.
#' @return data.frame with columns token, en, vi.
#' @export
load_report_labels <- function(base_csv = "templates/i18n/labels.csv", override_csv = NULL) {
  if (!file.exists(base_csv)) {
    stop(sprintf("load_report_labels: base label file not found: %s", base_csv), call. = FALSE)
  }
  labels <- utils::read.csv(base_csv, stringsAsFactors = FALSE, encoding = "UTF-8")
  required <- c("token", "en", "vi")
  missing <- setdiff(required, names(labels))
  if (length(missing) > 0) {
    stop(sprintf("load_report_labels: base CSV missing required columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  # Simple cache key
  cache_key <- paste(c(base_csv, if (is.null(override_csv) || length(override_csv) == 0) "NULL" else override_csv), collapse = "|")
  if (exists(cache_key, envir = .i18n_cache, inherits = FALSE)) {
    return(get(cache_key, envir = .i18n_cache, inherits = FALSE))
  }
  if (!is.null(override_csv) && length(override_csv) > 0 && nzchar(trimws(as.character(override_csv[[1]])))) {
    if (!file.exists(override_csv)) {
      warning(sprintf("load_report_labels: override CSV not found, ignoring: %s", override_csv))
    } else {
      ov <- utils::read.csv(override_csv, stringsAsFactors = FALSE, encoding = "UTF-8")
      if (!all(required %in% names(ov))) {
        warning(sprintf("load_report_labels: override CSV missing required columns, ignoring: %s", override_csv))
      } else {
        for (i in seq_len(nrow(ov))) {
          tok <- ov$token[i]
          idx <- which(labels$token == tok)
          if (length(idx) > 0) {
            labels[idx, ] <- ov[i, ]
          } else {
            labels <- rbind(labels, ov[i, , drop = FALSE])
          }
        }
      }
    }
  }
  assign(cache_key, labels, envir = .i18n_cache)
  labels
}

# Tracks which missing-token warnings have been emitted this run so each token
# warns at most once (per spec: "one warning per missing token per run").
.i18n_warned <- new.env(parent = emptyenv())

#' Lookup a report label, with bilingual support.
#'
#' @param token character(1) — label key, e.g. "synthetic_disclaimer".
#' @param lang character(1) — "en", "vi", or "bilingual" (default "en").
#' @param labels data.frame|NULL — optional pre-loaded table from
#'   load_report_labels(); when NULL, the default base file is loaded.
#' @return character(1) — the label (or token itself when missing, with a
#'   single warning per token per run).
#' @export
report_label <- function(token, lang = "en", labels = NULL) {
  if (is.null(labels)) {
    labels <- tryCatch(load_report_labels(), error = function(e) NULL)
  }
  if (is.null(labels) || !all(c("token", "en", "vi") %in% names(labels))) {
    return(token)
  }
  row <- labels[labels$token == token, , drop = FALSE]
  if (nrow(row) == 0) {
    if (!exists(token, envir = .i18n_warned, inherits = FALSE)) {
      warning(sprintf("report_label: missing token '%s' (lang=%s)", token, lang))
      assign(token, TRUE, envir = .i18n_warned)
    }
    return(token)
  }
  en <- row$en[1]
  vi <- row$vi[1]
  if (identical(lang, "bilingual")) {
    return(paste0(en, " / ", vi))
  }
  if (identical(lang, "vi")) {
    return(vi)
  }
  en
}
