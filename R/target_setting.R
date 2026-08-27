# ==============================================================================
# R/target_setting.R
# Wave 3 PHASE-06 (GTB DEC-005/006): sector target registry.
#
# PACTA alignment gaps are measured against a scenario benchmark (how far the
# portfolio is from the pathway). Sector interim targets are computed by
# convergence from the portfolio's own baseline -- FINALLY clarifying the
# duality that the two quantities share a name ("the PDP8 target") but not a
# meaning. This module sits downstream of pacta_core (DEC-009): it reads the
# already-computed synthesis_output/vietnam/05_vn_sda_portfolio.csv and the
# scenario CO2 / MS files, and does NOT call pacta_sda().
#
# R/pacta_core.R stays frozen; nothing here changes cement/steel alignment_gap
# that feeds severity anchors and every frozen artifact.
# ==============================================================================

#' Compute an SDA convergence target by scaling a portfolio baseline with a
#' scenario pathway's own ratio between baseline_year and target_year.
#'
#' Mirrors an SDA-type convergence where the portfolio is required to close
#' the same proportional gap the scenario itself implies, anchored on its
#' own current intensity rather than on the scenario's absolute intensity.
#'
#' @param baseline_value numeric(1) — portfolio emission intensity at
#'   baseline_year (e.g. from 05_vn_sda_portfolio.csv projected at 2025).
#' @param baseline_year integer(1) — baseline year, always 2025 in this plan.
#' @param scenario data.frame — must have columns year, emission_factor_value.
#'   Typically a subset of data/scenarios/<vintage>/vietnam_scenario_co2.csv
#'   filtered to one sector and one scenario (pdp8_ndc).
#' @param target_year integer(1) — desired target year (e.g. 2030).
#' @return numeric(1) — portfolio-anchored convergence target at target_year,
#'   or NA_real_ when either scenario anchor is missing or baseline is NA.
#' @export
sda_convergence_target <- function(baseline_value, baseline_year, scenario, target_year) {
  if (is.na(baseline_value) || length(baseline_value) != 1) return(NA_real_)
  if (!all(c("year", "emission_factor_value") %in% names(scenario))) {
    stop("sda_convergence_target: scenario data.frame must have columns year and emission_factor_value")
  }
  scen_base <- scenario$emission_factor_value[scenario$year == baseline_year]
  scen_tgt  <- scenario$emission_factor_value[scenario$year == target_year]
  if (length(scen_base) == 0 || length(scen_tgt) == 0) return(NA_real_)
  scen_base <- scen_base[1]
  scen_tgt  <- scen_tgt[1]
  if (is.na(scen_base) || is.na(scen_tgt) || scen_base == 0) return(NA_real_)
  baseline_value * (scen_tgt / scen_base)
}

#' Build the sector target registry.
#'
#' One row per sector per target horizon, in the exact 12-column, S6-specified
#' order. Multi-horizon: 2030 is populated (status "proposed"), 2035 and 2050
#' are emitted with target_value NA and status "not_set". Nothing is ever
#' "adopted" — that would require a board/committee decision outside this
#' synthetic pipeline.
#'
#' @param sda_portfolio data.frame — 05_vn_sda_portfolio.csv shape (sector,
#'   year, emission_factor_value, emission_factor_metric == "projected").
#' @param ms_portfolio data.frame — 04_vn_ms_portfolio.csv shape (sector,
#'   technology, year, technology_share, metric == "projected").
#' @param scenario_co2 data.frame — vietnam_scenario_co2.csv shape
#'   (sector, year, emission_factor_value, scenario == "pdp8_ndc").
#' @param scenario_ms data.frame — vietnam_scenario_ms.csv shape (sector,
#'   technology, year, smsp, scenario == "pdp8_ndc").
#' @param scenario_vintage character(1) — engagement's inputs.scenario_vintage.
#' @param horizons integer — target years, default c(2030L, 2035L, 2050L).
#' @return data.frame — 9 rows (3 sectors * 3 horizons) with 12 S6 columns in
#'   S6 order: sector, metric, unit, baseline_year, baseline_value,
#'   target_year, target_value, scope, method, scenario_vintage, status,
#'   source_artifact.
#' @export
build_target_registry <- function(sda_portfolio, ms_portfolio, scenario_co2, scenario_ms,
                                  scenario_vintage, horizons = c(2030L, 2035L, 2050L)) {
  sectors <- c("power", "cement", "steel")
  rows <- list()
  for (sector in sectors) {
    # Baseline year is fixed per S6
    baseline_year <- 2025L

    if (sector %in% c("cement", "steel")) {
      # Baseline: portfolio's own emission intensity at 2025 (projected)
      b_row <- sda_portfolio[sda_portfolio$sector == sector &
                               sda_portfolio$year == baseline_year &
                               sda_portfolio$emission_factor_metric == "projected", , drop = FALSE]
      baseline_value <- if (nrow(b_row) > 0) b_row$emission_factor_value[1] else NA_real_
      metric <- "emission_intensity"
      unit <- if (sector == "cement") "tco2_per_tonne_cement" else "tco2_per_tonne_crude_steel"
      scope <- "1+2"
      method <- "sda_convergence"
      source_artifact <- "synthesis_output/vietnam/05_vn_sda_portfolio.csv"
      scen <- scenario_co2[scenario_co2$sector == sector & scenario_co2$scenario == "pdp8_ndc", , drop = FALSE]
    } else {
      # Power: baseline is portfolio's projected renewables share at 2025
      # (technology == "renewablescap", metric projected). When the portfolio
      # file carries no explicit power rows for that technology, fall back to
      # the scenario file's own smsp at 2025 as the illustrative baseline.
      b_row <- ms_portfolio[ms_portfolio$sector == "power" &
                              ms_portfolio$technology == "renewablescap" &
                              ms_portfolio$year == baseline_year &
                              ms_portfolio$metric == "projected", , drop = FALSE]
      baseline_value <- if (nrow(b_row) > 0) b_row$technology_share[1] else NA_real_
      if (is.na(baseline_value)) {
        # Fallback: scenario_ms baseline (illustrative, when ms_portfolio has no power baseline)
        fb <- scenario_ms[scenario_ms$sector == "power" &
                            scenario_ms$technology == "renewablescap" &
                            scenario_ms$year == baseline_year &
                            scenario_ms$scenario == "pdp8_ndc", , drop = FALSE]
        if (nrow(fb) > 0) baseline_value <- fb$smsp[1]
      }
      metric <- "technology_market_share"
      unit <- "share_of_sector_capacity"
      scope <- "n/a"
      method <- "market_share"
      source_artifact <- "synthesis_output/vietnam/04_vn_ms_portfolio.csv"
      scen <- scenario_ms[scenario_ms$sector == "power" &
                            scenario_ms$technology == "renewablescap" &
                            scenario_ms$scenario == "pdp8_ndc", , drop = FALSE]
    }

    for (h in horizons) {
      if (h == 2030L) {
        if (sector %in% c("cement", "steel")) {
          target_value <- sda_convergence_target(baseline_value, baseline_year, scen, h)
        } else {
          # Power: target is the scenario's market share at the horizon year
          # (method market_share, not convergence). If scenario data for that
          # horizon is missing, leave NA rather than fabricating.
          tgt_row <- scen[scen$year == h, , drop = FALSE]
          target_value <- if (nrow(tgt_row) > 0) {
            # scenario_ms uses smsp column for market share
            if ("smsp" %in% names(tgt_row)) tgt_row$smsp[1] else tgt_row$emission_factor_value[1]
          } else NA_real_
        }
        status <- "proposed"
      } else {
        target_value <- NA_real_
        status <- "not_set"
      }
      rows[[length(rows) + 1]] <- data.frame(
        sector = sector,
        metric = metric,
        unit = unit,
        baseline_year = baseline_year,
        baseline_value = baseline_value,
        target_year = h,
        target_value = target_value,
        scope = scope,
        method = method,
        scenario_vintage = scenario_vintage,
        status = status,
        source_artifact = source_artifact,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  # Ensure column order is exactly S6 and types are correct
  out <- out[, c("sector", "metric", "unit", "baseline_year", "baseline_value",
                 "target_year", "target_value", "scope", "method",
                 "scenario_vintage", "status", "source_artifact")]
  out$baseline_year <- as.integer(out$baseline_year)
  out$target_year <- as.integer(out$target_year)
  out$baseline_value <- as.numeric(out$baseline_value)
  out$target_value <- as.numeric(out$target_value)
  out
}
