# ==============================================================================
# R/sll_readiness.R
# Wave 3 PHASE-06 (GTB DEC-003/004/005/006): a sustainability-linked-loan
# (SLL) client-readiness screen, separate from the transition-risk borrower
# ranking in scripts/engagement_scoring.R. That ranking answers "who is
# most exposed to transition risk"; this answers "who can we plausibly
# structure an SLL with" -- a different question, scored on four
# dimensions: transition materiality, ticket size, data availability, and
# (when available) relationship signals.
#
# Purely additive: reads engagement_priority.csv as feedstock, sources
# R/severity_scoring.R for the anchor-table primitive so both scoring paths
# use the same methodology rather than two independently-hand-rolled ones.
# Ranks and bands a qualified pool; does NOT select the final shortlist --
# that is an analyst decision, recorded via the empty analyst_rationale
# column this module leaves for a human to fill in.
#
# Depends on R/severity_scoring.R's severity_from_anchors() being sourced
# first by the caller (this file does not source it itself, matching every
# other R/*_core.R module's convention in this repo).
# ==============================================================================

# Exposure-severity anchor table (Table SLL-1): fraction of the engagement's
# total exposure this borrower represents is NOT the metric here -- ticket
# size uses the borrower's own exposure_vnd in whole VND, since a bank's
# appetite for an SLL scales with absolute deal size, not portfolio share.
# Calibrated against the MCB synthetic book's own exposure range (250 bn -
# 5.77 tn VND per borrower) so exposure_severity actually spreads across
# [0, 1] on this portfolio, per Q-002's guidance to calibrate against the
# MCB book now and retune once a real loanbook exists.
SLL_EXPOSURE_ANCHORS_X <- c(2.5e11, 8e11, 1.5e12, 3e12, 5.77e12)

SLL_READINESS_WEIGHTS <- list(w_materiality = 0.30, w_exposure = 0.25, w_data = 0.25, w_relationship = 0.20)

#' SLL readiness composite score in [0, 1] for one or more borrowers.
#'
#' @param severity_alignment numeric — from engagement_priority.csv.
#' @param severity_trisk numeric — from engagement_priority.csv; may be NA
#'   (automotive has no TRISK coverage).
#' @param exposure_vnd numeric — borrower's own exposure, whole VND.
#' @param has_abcd_match logical — TRUE when the borrower resolves to an
#'   ABCD company (data-availability proxy).
#' @param relationship numeric — optional relationship-signal score in
#'   [0, 1] from the overlay CSV; NA when not configured (vectorized: pass a
#'   vector of NA of the right length to drop the dimension for every row).
#' @return numeric in [0, 1], same length as the inputs.
#' @export
sll_readiness_score <- function(severity_alignment, severity_trisk, exposure_vnd, has_abcd_match, relationship = NA_real_) {
  materiality <- ifelse(is.na(severity_trisk), severity_alignment, (severity_alignment + severity_trisk) / 2)
  exposure_severity <- severity_from_anchors(exposure_vnd, SLL_EXPOSURE_ANCHORS_X)
  data_availability <- ifelse(has_abcd_match, 1, 0)

  w <- SLL_READINESS_WEIGHTS
  has_relationship <- !is.na(relationship)

  numerator <- w$w_materiality * materiality + w$w_exposure * exposure_severity + w$w_data * data_availability
  denominator <- rep(w$w_materiality + w$w_exposure + w$w_data, length(materiality))
  numerator[has_relationship] <- numerator[has_relationship] + w$w_relationship * relationship[has_relationship]
  denominator[has_relationship] <- denominator[has_relationship] + w$w_relationship

  numerator / denominator
}

#' Band an SLL readiness score.
#'
#' Breakpoints calibrated against the MCB synthetic book (Q-002): with the
#' data_availability dimension near-constant at 1.0 for every already-ABCD-
#' matched borrower in this repo's fixtures, materiality and exposure
#' severity are the only dimensions that actually discriminate here, so the
#' documented 0.70/0.75/0.90/0.95-style generic breakpoints an unconstrained
#' portfolio might use would qualify nearly every borrower. These
#' breakpoints land the qualified pool (Ready + Near-ready) at roughly 5-8
#' of MCB's 23 borrowers, per Q-002's guidance -- retune once a real
#' loanbook exists and data_availability genuinely varies.
#'
#' @param readiness numeric in [0, 1].
#' @return character, one of "Ready", "Near-ready", "Developing", "Not ready".
#' @export
sll_readiness_band <- function(readiness) {
  ifelse(readiness >= 0.75, "Ready",
    ifelse(readiness >= 0.70, "Near-ready",
      ifelse(readiness >= 0.50, "Developing", "Not ready")))
}

#' Build the full SLL readiness table for an engagement.
#'
#' @param priority data.frame — engagement_priority.csv shape (must have
#'   name_abcd, sector, exposure_vnd, severity_alignment, severity_trisk).
#' @param abcd data.frame — must have name_company (used only to confirm an
#'   ABCD match exists; priority rows are already matched, so in practice
#'   every row has a match today -- this keeps the dimension meaningful if
#'   engagement_scoring.R ever starts including unmatched borrowers).
#' @param overlay data.frame|NULL — optional relationship overlay with
#'   columns name_abcd, relationship_score in [0, 1]. NULL means "not
#'   configured".
#' @return data.frame: name_abcd, sector, exposure_vnd, materiality,
#'   exposure_severity, data_availability, relationship, readiness,
#'   readiness_band, readiness_partial, analyst_rationale (empty string,
#'   for a human to fill in), sorted by readiness descending.
#' @export
sll_readiness <- function(priority, abcd, overlay = NULL) {
  has_match <- priority$name_abcd %in% abcd$name_company

  relationship <- rep(NA_real_, nrow(priority))
  if (!is.null(overlay) && nrow(overlay) > 0) {
    idx <- match(priority$name_abcd, overlay$name_abcd)
    relationship <- overlay$relationship_score[idx]
  }

  materiality_col <- ifelse(
    is.na(priority$severity_trisk), priority$severity_alignment,
    (priority$severity_alignment + priority$severity_trisk) / 2
  )
  exposure_severity_col <- severity_from_anchors(priority$exposure_vnd, SLL_EXPOSURE_ANCHORS_X)
  data_availability_col <- as.integer(has_match)

  readiness <- sll_readiness_score(
    priority$severity_alignment, priority$severity_trisk, priority$exposure_vnd, has_match, relationship
  )

  out <- data.frame(
    name_abcd = priority$name_abcd,
    sector = priority$sector,
    exposure_vnd = priority$exposure_vnd,
    materiality = materiality_col,
    exposure_severity = exposure_severity_col,
    data_availability = data_availability_col,
    relationship = relationship,
    readiness = readiness,
    readiness_band = sll_readiness_band(readiness),
    readiness_partial = is.na(relationship),
    analyst_rationale = "",
    stringsAsFactors = FALSE
  )
  out[order(-out$readiness), , drop = FALSE]
}
