# ==============================================================================
# R/report_fingerprint.R
# Wave 4 PHASE-01: normalize a generated HTML report so two runs of the same
# pipeline compare equal, and fingerprint the result.
#
# Before this module, tools/verify_refactor.R classified EVERY .html file as
# "timestamp-class" and therefore ignored it unconditionally -- the rationale
# ("HTML reports may differ only in the generated-timestamp text") was enforced
# by assumption, never by checking. This module makes that assumption
# checkable: strip the timestamp/date/SHA spans the report generators actually
# emit, then compare what is left.
#
# The substitution table below is derived from an exhaustive scan of
# `format(Sys.time()` and `format(Sys.Date()` across R/ and scripts/. When a
# generator adds a new timestamp format, extend this table -- do not add the
# report to an exclusion list.
#
# Deliberately NOT normalized: numbers, table cells, prose, base64 image
# payloads. A change in any of those is genuine drift and must fail the gate.
# ==============================================================================

#' Replace every generated timestamp, date and git SHA in an HTML document
#' with a fixed placeholder, so two runs of the same pipeline compare equal.
#'
#' Substitution order matters. ISO-8601 (with a `T` separator) is replaced
#' first, because a looser `YYYY-MM-DD HH:MM` pattern would otherwise consume
#' its date half. `HH:MM:SS` is replaced before `HH:MM`, for the same reason.
#'
#' @param html character — one or more HTML documents (or fragments).
#' @return character — same length as `html`, with volatile spans replaced by
#'   `<TIMESTAMP>`, `<DATE>` or `<SHA>` and CRLF normalized to LF.
#' @export
normalize_report_html <- function(html) {
  if (length(html) == 0) return(html)
  x <- as.character(html)

  # 0. Line endings first: a working-tree file on Windows may carry CRLF while
  #    the same blob from `git show` arrives as LF (CLAUDE.md's core.autocrlf
  #    trap). Without this the two never compare equal.
  x <- gsub("\r\n", "\n", x, fixed = TRUE)

  months <- paste(
    "January", "February", "March", "April", "May", "June", "July",
    "August", "September", "October", "November", "December",
    sep = "|"
  )

  # 1. ISO-8601, "%Y-%m-%dT%H:%M:%S%z" (R/step_runner.R, R/run_history.R) and
  #    "%Y-%m-%dT%H:%M:%SZ" (R/trisk_core.R's grid metadata). Must precede the
  #    space-separated patterns below.
  x <- gsub("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([+-][0-9]{4}|Z)?",
            "<TIMESTAMP>", x)

  # 2. "%Y-%m-%d %H:%M:%S" (scripts/generate_engagement_letters.R). Must
  #    precede pattern 3, which would otherwise match its "%H:%M" prefix and
  #    leave a stray ":SS".
  x <- gsub("[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}",
            "<TIMESTAMP>", x)

  # 3. "%Y-%m-%d %H:%M %Z" (scripts/generate_validation_report.R,
  #    scripts/generate_coverage_report.R, scripts/generate_wave3_summary.R).
  #    The zone is optional and single-token; the observed value in this repo's
  #    reports is "+07". A multi-word Windows zone name would leave a stable
  #    residue on both sides of the comparison, which still compares equal.
  x <- gsub("[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}( [A-Za-z+][A-Za-z0-9+:_-]*)?",
            "<TIMESTAMP>", x)

  # 4. "%d %B %Y" (scripts/generate_disclosure_pack.R,
  #    scripts/generate_engagement_letters.R's letter_date).
  x <- gsub(sprintf("[0-9]{1,2} (%s) [0-9]{4}", months), "<DATE>", x)

  # 5. "%B %d, %Y" (R/pacta_core.R, scripts/generate_bidv_report.R).
  x <- gsub(sprintf("(%s) [0-9]{1,2}, [0-9]{4}", months), "<DATE>", x)

  # 6. Git SHAs, full or abbreviated, as rendered by the refresh audit's
  #    "Commit: <sha>" line and the manifest's git_sha. Bounded to 7-40 hex
  #    chars on word boundaries so ordinary numbers are untouched.
  x <- gsub("\\b[0-9a-f]{7,40}\\b", "<SHA>", x)

  x
}

#' MD5 fingerprint of an HTML report's normalized content.
#'
#' Reads the file as raw bytes and treats it as UTF-8, so Vietnamese text in a
#' bilingual report round-trips unchanged regardless of the session locale.
#'
#' @param path character(1) — path to an HTML file.
#' @return character(1) — lowercase MD5 hex digest of the normalized content,
#'   or NA_character_ when the file does not exist.
#' @export
report_fingerprint <- function(path) {
  if (length(path) != 1 || is.na(path) || !file.exists(path)) return(NA_character_)
  txt <- .read_utf8(path)
  .md5_of_string(normalize_report_html(txt))
}

#' Read a file as a single UTF-8 string, bytes preserved.
#' @param path character(1) — file path.
#' @return character(1) — the file's contents.
#' @keywords internal
.read_utf8 <- function(path) {
  size <- file.info(path)$size
  if (is.na(size) || size == 0) return("")
  raw_bytes <- readBin(path, "raw", n = size)
  txt <- rawToChar(raw_bytes)
  Encoding(txt) <- "UTF-8"
  txt
}

#' MD5 digest of a character string, computed via a temporary file so no
#' package outside base R and tools is required (`digest` is not in renv.lock).
#' @param x character(1) — the string to digest.
#' @return character(1) — lowercase MD5 hex digest.
#' @keywords internal
.md5_of_string <- function(x) {
  tmp <- tempfile("report_fingerprint_")
  on.exit(unlink(tmp), add = TRUE)
  con <- file(tmp, open = "wb")
  writeBin(charToRaw(paste(x, collapse = "\n")), con)
  close(con)
  unname(tools::md5sum(tmp))
}
