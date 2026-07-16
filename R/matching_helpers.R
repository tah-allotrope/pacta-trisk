# ==============================================================================
# R/matching_helpers.R
# Shared Vietnamese-name normalization for PACTA fuzzy matching.
#
# Previously scripts/pacta_vietnam_scenario.R and scripts/intake_validate_and_map.R
# each called stringi::stri_trans_general(x, "Latin-ASCII") inline wherever a
# counterparty or ABCD company name needed diacritic-insensitive matching.
# This module centralizes that one call so both scripts (and any future
# engagement script) normalize names identically.
# ==============================================================================

suppressPackageStartupMessages({
  library(stringi)
})

#' ASCII-transliterate Vietnamese company/counterparty names for matching.
#'
#' Strips diacritics (e.g. "Nhiệt Điện Vĩnh Tân 1" -> "Nhiet Dien Vinh Tan 1")
#' so PACTA's match_name() can compare loanbook and ABCD names without
#' encoding-driven match failures. Vectorized.
#'
#' @param x character — one or more names.
#' @return character — the ASCII-transliterated names, same length as `x`.
#' @export
normalize_vn_name <- function(x) {
  stringi::stri_trans_general(x, "Latin-ASCII")
}
