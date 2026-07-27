# ==============================================================================
# R/format_money.R
# Shared VND money formatters (Wave 2 PHASE-02, U1).
#
# Every script that renders a VND figure for a human reader must go through
# one of the functions here, so a unit fix or a display-format change happens
# in one place instead of three (previously: scripts/generate_engagement_letters.R's
# format_vnd(), scripts/generate_disclosure_pack.R's fmt_vnd(), and
# R/prioritization_core.R's inline formatC() calls each had their own copy).
#
# All money columns in this repo (loan_size_outstanding, exposure_vnd, etc.)
# are whole VND — never thousands, never millions. See intake/SCHEMA.md's
# "Units" section for the client-facing statement of this contract.
# ==============================================================================

#' Format a whole-VND figure with comma thousands separators.
#'
#' @param x numeric — a money figure in whole VND.
#' @return character — e.g. "1,030,000,000,000 VND", or "Not available" for NA.
#' @export
format_vnd_full <- function(x) {
  if (is.na(x)) return("Not available")
  # format = "f", digits = 0 (not format = "d"): "d" coerces via as.integer(),
  # which overflows silently for VND figures in the trillions (> 2^31 - 1).
  paste0(formatC(x, format = "f", digits = 0, big.mark = ","), " VND")
}

#' Format a whole-VND figure in billions of VND.
#'
#' @param x numeric — a money figure in whole VND.
#' @param digits integer — decimal places, default 1.
#' @return character — e.g. "1,030.0 bn VND", or "Not available" for NA.
#' @export
format_vnd_bn <- function(x, digits = 1) {
  if (is.na(x)) return("Not available")
  paste0(formatC(x / 1e9, format = "f", digits = digits, big.mark = ","), " bn VND")
}

#' Convert a whole-VND figure to billions of VND as a plain number.
#'
#' For use in data frames and further computation, not display — see
#' format_vnd_bn() for a display string.
#'
#' @param x numeric — a money figure in whole VND.
#' @return numeric — x / 1e9, propagating NA.
#' @export
vnd_to_billion <- function(x) {
  x / 1e9
}
