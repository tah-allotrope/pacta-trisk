# ==============================================================================
# R/sector_registry.R
# Single source of truth for TRISK sector metadata.
#
# Previously this metadata was hand-duplicated in two places:
#   - scripts/trisk_sector_demo.R (trisk_sector_meta list): title, subtitle,
#     scenario_geography, carbon_price_model, baseline_scenario,
#     target_scenario, company_aliases, plus trisk_base_params.
#   - scripts/refresh_dashboard_data.R (trisk_manifest tribble): sector,
#     label, folder, price_unit, pathway_unit, alignment_mode,
#     grid_available, disclaimer.
#
# All values below are copied verbatim from those two sources — this module
# moves data, it does not change any value.
# ==============================================================================

suppressPackageStartupMessages({
  library(tibble)
})

#' TRISK sector metadata registry.
#'
#' @return tibble — one row per sector (power, cement, steel) with the merged
#'   metadata columns from both formerly-duplicated sources.
#' @export
sector_registry <- function() {
  tibble::tibble(
    sector = c("power", "cement", "steel"),
    label = c("Power", "Cement", "Steel"),
    folder = c("power", "cement", "steel"),
    price_unit = c("USD/MWh-equivalent", "USD/unit-equivalent", "USD/unit-equivalent"),
    pathway_unit = c("MW", "tonnes", "tonnes"),
    alignment_mode = c("borrower_ms", "sector_sda", "sector_sda"),
    grid_available = c(FALSE, FALSE, FALSE),
    disclaimer = c(
      "Borrower-level PACTA market-share gaps are available for power.",
      "Cement currently uses sector-level SDA context, not borrower-specific alignment.",
      "Steel currently uses sector-level SDA context, not borrower-specific alignment."
    ),
    title = c("Power", "Cement", "Steel"),
    subtitle = c(
      "Firm-level transition-stress view for the Vietnam synthetic power book.",
      "Borrower stress view for Vietnam cement producers with sector-level SDA context.",
      "Borrower stress view for Vietnam steel producers with sector-level SDA context."
    ),
    scenario_geography = c("Vietnam", "Vietnam", "Vietnam"),
    carbon_price_model = c(
      "increasing_carbon_tax_50",
      "cement_intensity_transition",
      "steel_intensity_transition"
    ),
    baseline_scenario = c("VN_PDP8_BASELINE", "VN_PDP8_BASELINE", "VN_PDP8_BASELINE"),
    target_scenario = c("VN_NZE_STRESS", "VN_NZE_STRESS", "VN_NZE_STRESS"),
    alignment_mode_detail = c("company_ms", "sector_sda", "sector_sda"),
    company_aliases = list(
      c("PVN Power Corporation" = "PVN Power Corporation"),
      c("Holcim Group" = "Holcim Group", "VICEM" = "VICEM"),
      c("Hoa Phat Group JSC" = "Hoa Phat Group JSC", "Pomina Group" = "Pomina Group")
    )
  )
}

#' TRISK base run parameters (shock year, discount rate, etc).
#'
#' @return list — the 7 TRISK base parameters, values identical to the
#'   literals previously inlined in scripts/trisk_sector_demo.R.
#' @export
trisk_base_params <- function() {
  list(
    shock_year = 2028,
    discount_rate = 0.08,
    risk_free_rate = 0.03,
    growth_rate = 0.02,
    div_netprofit_prop_coef = 1,
    market_passthrough = 0.25,
    show_params_cols = TRUE
  )
}

#' Look up one sector's metadata as a named list, in the shape
#' scripts/trisk_sector_demo.R's `trisk_sector_meta[[sector]]` used to be.
#'
#' @param sector character — one of "power", "cement", "steel".
#' @return list — sector metadata with keys label, title, subtitle,
#'   scenario_geography, carbon_price_model, baseline_scenario,
#'   target_scenario, alignment_mode, company_aliases.
#' @export
sector_meta <- function(sector) {
  registry <- sector_registry()
  row <- registry[registry$sector == sector, ]
  if (nrow(row) == 0) {
    stop(sprintf("Unknown sector '%s'", sector), call. = FALSE)
  }
  list(
    label = row$folder[[1]],
    title = row$title[[1]],
    subtitle = row$subtitle[[1]],
    scenario_geography = row$scenario_geography[[1]],
    carbon_price_model = row$carbon_price_model[[1]],
    baseline_scenario = row$baseline_scenario[[1]],
    target_scenario = row$target_scenario[[1]],
    alignment_mode = row$alignment_mode_detail[[1]],
    company_aliases = row$company_aliases[[1]]
  )
}
