# ==============================================================================
# R/severity_scoring.R
# Absolute severity scoring from documented anchor tables (Wave 2 PHASE-03).
#
# Replaces min-max normalization (rank-relative: the top entity is always
# exactly 1.0, the bottom always exactly 0.0, and the meaning of any score in
# between depends on how many other entities happen to be in scope) with
# clamped piecewise-linear interpolation over a fixed, documented anchor
# table (absolute: a score of 0.61 means the same thing this refresh, next
# refresh, for MCB, and for any other bank).
#
# The four anchor tables (A1, A2, B, C) are specified verbatim in
# plans/2026-07-27-contracts-units-and-guardrails-plan.md ## Specification S2
# and documented for a non-code reader in docs/scoring_anchors.md, which is
# the single source of truth a reviewer can argue with without reading code.
#
# Base R plus stats::approx() only (CON-002 -- no new package dependency).
# ==============================================================================

#' Clamped piecewise-linear severity in [0, 1] from a five-point anchor table.
#'
#' Values beyond the last breakpoint saturate at the table's max y (normally
#' 1.00) rather than being extrapolated -- this is deliberate: an
#' unboundedly-bad input should read as "as bad as the scale can express",
#' not as some arbitrarily large number.
#'
#' @param x numeric — the raw metric being scored. Vectorized.
#' @param anchors_x numeric — breakpoint values of the metric, strictly ascending.
#' @param anchors_y numeric — severity values at each breakpoint, default
#'   c(0, 0.25, 0.5, 0.75, 1).
#' @return numeric in [0, 1], same length as x. NA_real_ where x is NA.
#' @export
severity_from_anchors <- function(x, anchors_x, anchors_y = c(0, 0.25, 0.5, 0.75, 1)) {
  if (length(anchors_x) != length(anchors_y)) {
    stop("severity_from_anchors: anchors_x and anchors_y must be the same length")
  }
  if (is.unsorted(anchors_x, strictly = TRUE)) {
    stop("severity_from_anchors: anchors_x must be strictly ascending")
  }

  lo <- min(anchors_x)
  hi <- max(anchors_x)
  x_clamped <- pmin(pmax(x, lo), hi)

  out <- stats::approx(x = anchors_x, y = anchors_y, xout = x_clamped, method = "linear")$y
  out[is.na(x)] <- NA_real_
  out
}

# --- Table A1: market-share alignment gap (power, automotive) ---------------
# Unit: percentage points of technology market share, absolute value.
.TABLE_A1_X <- c(0, 5, 10, 20, 40)
.TABLE_A1_Y <- c(0.00, 0.25, 0.50, 0.75, 1.00)

# --- Table A2: SDA emission-intensity gap (cement, steel) -------------------
# Unit: percent of the sector's 2030 target intensity, absolute value.
.TABLE_A2_X <- c(0, 2, 5, 10, 20)
.TABLE_A2_Y <- c(0.00, 0.25, 0.50, 0.75, 1.00)

# --- Table B: TRISK value-loss severity --------------------------------------
# Unit: fraction of baseline NPV lost (max(0, -npv_change)).
.TABLE_B_X <- c(0.00, 0.05, 0.15, 0.30, 0.60)
.TABLE_B_Y <- c(0.00, 0.25, 0.50, 0.75, 1.00)

# --- Table C: exposure-concentration severity --------------------------------
# Unit: fraction of the engagement's total Decision-263-relevant exposure.
.TABLE_C_X <- c(0.00, 0.05, 0.15, 0.30, 0.50)
.TABLE_C_Y <- c(0.00, 0.25, 0.50, 0.75, 1.00)

#' Severity for an alignment gap, using the sector-appropriate anchor table.
#'
#' @param gap numeric — the raw alignment gap. abs() is applied before scoring.
#' @param basis character — "market_share" (Table A1) or "sda_intensity"
#'   (Table A2); any other value is an error.
#' @return numeric in [0, 1].
#' @export
severity_alignment <- function(gap, basis) {
  if (identical(basis, "market_share")) {
    return(severity_from_anchors(abs(gap), .TABLE_A1_X, .TABLE_A1_Y))
  }
  if (identical(basis, "sda_intensity")) {
    return(severity_from_anchors(abs(gap), .TABLE_A2_X, .TABLE_A2_Y))
  }
  stop(sprintf("severity_alignment: unknown basis '%s' (expected 'market_share' or 'sda_intensity')", basis))
}

#' Severity for TRISK value loss, using Table B.
#'
#' @param npv_change numeric — fractional NPV change under a shock. A positive
#'   npv_change (value gain) scores 0.00; only max(0, -npv_change) is stress.
#' @return numeric in [0, 1]; NA_real_ when npv_change is NA.
#' @export
severity_trisk <- function(npv_change) {
  loss <- pmax(0, -npv_change)
  severity_from_anchors(loss, .TABLE_B_X, .TABLE_B_Y)
}

#' Severity for exposure concentration, using Table C.
#'
#' @param share numeric — fraction of total relevant exposure, in [0, 1]
#'   (not a percentage: severity_exposure(0.82) is correct, severity_exposure(82)
#'   silently saturates at 1.0).
#' @return numeric in [0, 1].
#' @export
severity_exposure <- function(share) {
  severity_from_anchors(share, .TABLE_C_X, .TABLE_C_Y)
}

#' The alignment-severity basis (table family) for a Decision-263 sector.
#'
#' @param sector character — a single sector name.
#' @return character(1) — "market_share" for power/automotive, "sda_intensity"
#'   for cement/steel; errors naming the sector otherwise.
#' @export
alignment_basis_for_sector <- function(sector) {
  if (sector %in% c("power", "automotive")) return("market_share")
  if (sector %in% c("cement", "steel")) return("sda_intensity")
  stop(sprintf("alignment_basis_for_sector: no alignment basis known for sector '%s'", sector))
}
