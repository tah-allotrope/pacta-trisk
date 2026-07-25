# ==============================================================================
# R/trisk_core.R
# Config-parameterized TRISK chain functions, decomposed from the former
# scripts/trisk_prepare_inputs.R, scripts/trisk_sector_demo.R, and
# scripts/trisk_scenario_grid.R monoliths (the merged "TRISK parameterize +
# decompose" pass — see CLAUDE.md and plans/2026-07-18-engagement-runway-
# completion-plan.md PHASE-01).
#
# Code was moved verbatim (ASM-002 of that plan): the only edits are (a)
# hardcoded path literals promoted to parameters whose defaults equal
# today's literals, and (b) top-level script variables promoted to function
# parameters/returns. No analysis logic changed. Every path parameter
# defaults to the exact string the original script used, so calling these
# functions with no engagement config reproduces today's MCB behavior
# byte-for-byte.
#
# scripts/trisk_prepare_inputs.R, scripts/trisk_sector_demo.R,
# scripts/trisk_scenario_grid.R, and scripts/trisk_run_adhoc.R source this
# file (after R/engagement_config.R and R/sector_registry.R) and call these
# functions; they also still `library()` the analysis stack before sourcing,
# so these functions resolve their free variables via the calling script's
# environment exactly as the original scripts did.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(fs)
  library(ggplot2)
  library(purrr)
  library(readr)
  library(scales)
  library(tibble)
  library(tidyr)
  library(arrow)
  library(jsonlite)
})
suppressPackageStartupMessages(library(trisk.model))

# ==============================================================================
# SECTION A: TRISK INPUT PREPARATION (from trisk_prepare_inputs.R)
# ==============================================================================

#' Validate that an ABCD data frame satisfies the intake/SCHEMA.md ABCD
#' contract (Wave 1 PHASE-03, C6 -- the demo's own ABCD previously failed
#' its own documented schema).
#'
#' @param abcd data.frame — asset-based company data to validate.
#' @param source_label character — label used in the error message to
#'   identify which ABCD source failed, default "ABCD".
#' @return invisible(TRUE) when the frame satisfies the contract; otherwise
#'   stop()s with every problem found, one per line.
#' @export
validate_abcd_schema <- function(abcd, source_label = "ABCD") {
  problems <- character(0)

  required_cols <- c(
    "company_id", "name_company", "lei", "sector", "technology",
    "production_unit", "year", "production", "emission_factor",
    "plant_location", "is_ultimate_owner", "emission_factor_unit",
    "data_source", "as_of_year"
  )
  missing_cols <- setdiff(required_cols, names(abcd))
  if (length(missing_cols) > 0) {
    problems <- c(problems, sprintf(
      "missing required column(s): %s", paste(missing_cols, collapse = ", ")
    ))
  }

  # Every remaining check needs its own column to exist -- skip a check
  # whose column is missing rather than erroring out of the validator.
  has_col <- function(col) col %in% names(abcd)

  if (has_col("year")) {
    year_int <- suppressWarnings(as.integer(abcd$year))
    if (any(is.na(year_int) & !is.na(abcd$year))) {
      problems <- c(problems, "year contains value(s) not coercible to integer")
    }
  }
  if (has_col("as_of_year")) {
    as_of_year_int <- suppressWarnings(as.integer(abcd$as_of_year))
    if (any(is.na(as_of_year_int) & !is.na(abcd$as_of_year))) {
      problems <- c(problems, "as_of_year contains value(s) not coercible to integer")
    }
  }

  if (has_col("production")) {
    production_num <- suppressWarnings(as.numeric(abcd$production))
    if (any(is.na(production_num) & !is.na(abcd$production))) {
      problems <- c(problems, "production contains value(s) not coercible to numeric")
    } else if (any(production_num < 0, na.rm = TRUE)) {
      problems <- c(problems, "production contains negative value(s)")
    }
  }

  if (has_col("company_id") &&
      any(is.na(abcd$company_id) | !nzchar(trimws(as.character(abcd$company_id))))) {
    problems <- c(problems, "company_id has empty or NA value(s)")
  }
  if (has_col("name_company") &&
      any(is.na(abcd$name_company) | !nzchar(trimws(as.character(abcd$name_company))))) {
    problems <- c(problems, "name_company has empty or NA value(s)")
  }

  if (has_col("is_ultimate_owner") && !is.logical(abcd$is_ultimate_owner)) {
    owner_chr <- toupper(trimws(as.character(abcd$is_ultimate_owner)))
    invalid <- !is.na(abcd$is_ultimate_owner) & !(owner_chr %in% c("TRUE", "FALSE"))
    if (any(invalid)) {
      problems <- c(problems, "is_ultimate_owner contains value(s) not logical or TRUE/FALSE")
    }
  }

  if (has_col("data_source") &&
      any(is.na(abcd$data_source) | !nzchar(trimws(as.character(abcd$data_source))))) {
    problems <- c(problems, "data_source has empty or NA value(s)")
  }

  if (length(problems) > 0) {
    stop(sprintf(
      "%s failed schema validation:\n- %s",
      source_label, paste(problems, collapse = "\n- ")
    ), call. = FALSE)
  }

  invisible(TRUE)
}

.trisk_input_sector_specs <- list(
  power = list(
    sector_local = "power",
    sector_trisk = "Power",
    scenario_source = "ms",
    geography = "Vietnam",
    technologies = tribble(
      ~technology_local, ~technology_trisk, ~technology_type, ~capacity_factor_demo, ~emission_factor_demo,
      "coalcap",       "CoalCap",       "carbontech",    0.70,                  0.95,
      "gascap",        "GasCap",        "carbontech",    0.55,                  0.45,
      "hydrocap",      "HydroCap",      "greentech",     0.45,                  0.02,
      "renewablescap", "RenewablesCap", "greentech",     0.30,                  0.01
    )
  ),
  cement = list(
    sector_local = "cement",
    sector_trisk = "Cement",
    scenario_source = "co2",
    geography = "Vietnam",
    technologies = tribble(
      ~technology_local,      ~technology_trisk,     ~technology_type, ~capacity_factor_demo, ~emission_factor_demo,
      "integrated facility", "IntegratedFacility", "carbontech",    1.00,                  NA_real_
    )
  ),
  steel = list(
    sector_local = "steel",
    sector_trisk = "Steel",
    scenario_source = "co2",
    geography = "Vietnam",
    technologies = tribble(
      ~technology_local, ~technology_trisk, ~technology_type, ~capacity_factor_demo, ~emission_factor_demo,
      "open_hearth",    "OpenHearth",     "carbontech",    1.00,                  NA_real_,
      "electric",       "ElectricArc",    "greentech",     1.00,                  NA_real_
    )
  )
)

.trisk_company_archetypes <- tribble(
  ~company_id,    ~company_name,                      ~archetype,                   ~pd,    ~net_profit_margin, ~debt_equity_ratio, ~volatility,
  "VN_ABCD_001", "EVN (Electricity of Vietnam)",   "state_owned_utility",       0.012,  0.085,              1.60,               0.22,
  "VN_ABCD_002", "Vinacomin Power JSC",            "state_affiliated_coal",     0.020,  0.070,              1.85,               0.26,
  "VN_ABCD_003", "International Power Mong Duong", "bot_coal_project",          0.024,  0.090,              2.40,               0.20,
  "VN_ABCD_004", "PVN Power Corporation",          "state_affiliated_gas",      0.015,  0.095,              1.45,               0.21,
  "VN_ABCD_005", "Nghi Son Power LLC",             "bot_coal_project",          0.023,  0.092,              2.30,               0.19,
  "VN_ABCD_006", "Dung Quat LNG Power Consortium", "lng_growth_platform",       0.028,  0.082,              2.10,               0.28,
  "VN_ABCD_007", "Vietnam Hydropower JSC",         "hydro_operator",            0.014,  0.110,              1.20,               0.18,
  "VN_ABCD_008", "Trung Nam Group",                "renewable_ipp",             0.021,  0.100,              2.00,               0.30,
  "VN_ABCD_009", "BIM Group",                      "renewable_ipp",             0.018,  0.102,              1.70,               0.27,
  "VN_ABCD_010", "Thanh Thanh Cong Group",         "renewable_ipp",             0.019,  0.098,              1.85,               0.29,
  "VN_ABCD_011", "Xuan Thien Group",               "renewable_ipp",             0.022,  0.094,              2.05,               0.31,
  "VN_ABCD_012", "T&T Group",                      "renewable_ipp",             0.017,  0.101,              1.65,               0.27,
  "VN_ABCD_013", "Gia Lai Electricity JSC",        "renewable_ipp",             0.020,  0.093,              1.75,               0.28,
  "VN_ABCD_020", "VICEM",                          "integrated_cement_leader",  0.026,  0.118,              1.90,               0.24,
  "VN_ABCD_021", "Holcim Group",                   "cement_multinational",      0.017,  0.145,              0.95,               0.19,
  "VN_ABCD_022", "Hoa Phat Group JSC",             "blast_furnace_steel",       0.024,  0.109,              1.55,               0.27,
  "VN_ABCD_023", "Pomina Group",                   "electric_arc_steel",        0.031,  0.082,              2.30,               0.33
)

.trisk_scenario_name_map <- c(
  pdp8_ndc = "VN_PDP8_BASELINE",
  nze_global = "VN_NZE_STRESS",
  steps = "VN_STEPS_BASELINE"
)

.trisk_scenario_type_map <- c(
  VN_PDP8_BASELINE = "baseline",
  VN_NZE_STRESS = "target",
  VN_STEPS_BASELINE = "baseline"
)

#' Backfill a zero-baseline production/capacity trajectory.
#'
#' For assets whose earliest-year value is 0 (pre-commissioning), backfill
#' the leading zero years from the first non-zero year's value and tag those
#' rows with `baseline_note`. Assets whose trajectory is all-zero are
#' dropped entirely.
#'
#' @param assets tbl — one row per asset per year.
#' @param value_col character — the numeric column to backfill.
#' @param year_col character — the year column, default "year".
#' @return tbl — assets with leading zeros backfilled and a `baseline_note`
#'   character column added (NA on untouched rows); all-zero assets removed.
backfill_zero_baseline <- function(assets, value_col, year_col = "year") {
  if (nrow(assets) == 0) {
    assets$baseline_note <- character(0)
    return(assets)
  }

  group_cols <- setdiff(names(assets), c(value_col, year_col))

  assets %>%
    mutate(.row_order = row_number()) %>%
    group_by(across(all_of(group_cols[group_cols %in% names(assets)]))) %>%
    group_modify(function(.x, .y) {
      .x <- .x %>% arrange(.data[[year_col]])
      values <- .x[[value_col]]

      if (all(values == 0 | is.na(values))) {
        return(.x[0, , drop = FALSE])
      }

      first_nonzero_idx <- which(values != 0 & !is.na(values))[1]
      baseline_note <- rep(NA_character_, nrow(.x))

      if (!is.na(first_nonzero_idx) && first_nonzero_idx > 1) {
        fill_value <- values[first_nonzero_idx]
        values[seq_len(first_nonzero_idx - 1)] <- fill_value
        baseline_note[seq_len(first_nonzero_idx - 1)] <- "backfilled_first_operating_year"
      }

      .x[[value_col]] <- values
      .x$baseline_note <- baseline_note
      .x
    }) %>%
    ungroup() %>%
    arrange(.row_order) %>%
    select(-.row_order)
}

.trisk_build_assets <- function(spec, vietnam_abcd) {
  sector_rows <- vietnam_abcd %>%
    filter(sector == spec$sector_local) %>%
    inner_join(spec$technologies, by = c("technology" = "technology_local"))

  if (nrow(sector_rows) == 0) {
    stop(sprintf("No ABCD rows found for sector '%s'", spec$sector_local))
  }

  sector_rows %>%
    transmute(
      company_id = company_id,
      company_name = name_company,
      asset_id = paste(company_id, technology_trisk, year, sep = "_"),
      asset_name = paste(name_company, technology_trisk, year, sep = " :: "),
      country_iso2 = plant_location,
      production_year = year,
      sector = spec$sector_trisk,
      technology = technology_trisk,
      capacity = if_else(capacity_factor_demo > 0, production / capacity_factor_demo, production),
      capacity_factor = capacity_factor_demo,
      emission_factor = coalesce(emission_factor_demo, emission_factor),
      production_unit = production_unit,
      technology_type = technology_type
    )
}

.trisk_build_power_scenarios <- function(spec, assets, vietnam_scenario_ms) {
  baseline <- assets %>%
    transmute(
      sector_trisk = sector,
      technology_trisk = technology,
      year = production_year,
      baseline_production = capacity * capacity_factor,
      production_unit = production_unit
    ) %>%
    group_by(sector_trisk, technology_trisk, year, production_unit) %>%
    summarise(baseline_production = sum(baseline_production, na.rm = TRUE), .groups = "drop")

  vietnam_scenario_ms %>%
    filter(sector == spec$sector_local, technology %in% spec$technologies$technology_local) %>%
    inner_join(spec$technologies, by = c("technology" = "technology_local")) %>%
    inner_join(
      baseline,
      by = c(
        "technology_trisk" = "technology_trisk",
        "year" = "year"
      )
    ) %>%
    mutate(
      scenario = recode(scenario, !!!.trisk_scenario_name_map, .default = paste0("VN_", toupper(scenario))),
      scenario_type = recode(scenario, !!!.trisk_scenario_type_map, .default = "baseline"),
      scenario_geography = spec$geography,
      scenario_year = year,
      scenario_price = case_when(
        technology_trisk == "CoalCap" & scenario == "VN_PDP8_BASELINE" ~ 68 + 0.4 * (year - 2025),
        technology_trisk == "CoalCap" & scenario == "VN_NZE_STRESS" ~ 68 - 1.6 * (year - 2025),
        technology_trisk == "CoalCap" & scenario == "VN_STEPS_BASELINE" ~ 68 - 0.1 * (year - 2025),
        technology_trisk == "GasCap" & scenario == "VN_PDP8_BASELINE" ~ 60 + 0.6 * (year - 2025),
        technology_trisk == "GasCap" & scenario == "VN_NZE_STRESS" ~ 60 - 0.3 * (year - 2025),
        technology_trisk == "GasCap" & scenario == "VN_STEPS_BASELINE" ~ 60 + 0.1 * (year - 2025),
        technology_trisk == "HydroCap" & scenario == "VN_PDP8_BASELINE" ~ 56 + 0.1 * (year - 2025),
        technology_trisk == "HydroCap" & scenario == "VN_NZE_STRESS" ~ 56 + 0.2 * (year - 2025),
        technology_trisk == "HydroCap" & scenario == "VN_STEPS_BASELINE" ~ 56 + 0.1 * (year - 2025),
        technology_trisk == "RenewablesCap" & scenario == "VN_PDP8_BASELINE" ~ 52 + 0.2 * (year - 2025),
        technology_trisk == "RenewablesCap" & scenario == "VN_NZE_STRESS" ~ 52 + 0.8 * (year - 2025),
        technology_trisk == "RenewablesCap" & scenario == "VN_STEPS_BASELINE" ~ 52 + 0.4 * (year - 2025),
        TRUE ~ 55
      ),
      fair_share_raw = case_when(
        technology_type == "carbontech" ~ tmsr,
        technology_type == "greentech" ~ smsp,
        TRUE ~ 0
      ),
      scenario_pathway = baseline_production * (1 + fair_share_raw),
      scenario_capacity_factor = case_when(
        technology_trisk == "CoalCap" & scenario == "VN_PDP8_BASELINE" ~ pmax(0.48, 0.70 - 0.025 * (year - 2025)),
        technology_trisk == "CoalCap" & scenario == "VN_NZE_STRESS" ~ pmax(0.22, 0.70 - 0.080 * (year - 2025)),
        technology_trisk == "CoalCap" & scenario == "VN_STEPS_BASELINE" ~ pmax(0.38, 0.70 - 0.040 * (year - 2025)),
        technology_trisk == "GasCap" & scenario == "VN_PDP8_BASELINE" ~ pmin(0.62, 0.55 + 0.010 * (year - 2025)),
        technology_trisk == "GasCap" & scenario == "VN_NZE_STRESS" ~ pmax(0.42, 0.55 - 0.020 * (year - 2025)),
        technology_trisk == "GasCap" & scenario == "VN_STEPS_BASELINE" ~ pmax(0.48, 0.55 - 0.005 * (year - 2025)),
        technology_trisk == "HydroCap" ~ 0.45,
        technology_trisk == "RenewablesCap" & scenario == "VN_PDP8_BASELINE" ~ pmin(0.35, 0.30 + 0.006 * (year - 2025)),
        technology_trisk == "RenewablesCap" & scenario == "VN_NZE_STRESS" ~ pmin(0.38, 0.30 + 0.010 * (year - 2025)),
        technology_trisk == "RenewablesCap" & scenario == "VN_STEPS_BASELINE" ~ pmin(0.36, 0.30 + 0.007 * (year - 2025)),
        TRUE ~ 0.30
      )
    ) %>%
    transmute(
      scenario = scenario,
      scenario_type = scenario_type,
      scenario_geography = scenario_geography,
      sector = spec$sector_trisk,
      technology = technology_trisk,
      scenario_year = scenario_year,
      price_unit = "USD/MWh-equivalent",
      scenario_price = round(scenario_price, 4),
      pathway_unit = production_unit,
      scenario_pathway = round(scenario_pathway, 4),
      technology_type = technology_type,
      scenario_capacity_factor = round(scenario_capacity_factor, 4),
      country_iso2_list = NA_character_,
      scenario_provider = "synthetic_vietnam_demo"
    )
}

.trisk_build_co2_scenarios <- function(spec, assets, vietnam_scenario_co2) {
  baseline <- assets %>%
    transmute(
      technology = technology,
      year = production_year,
      baseline_weight = capacity,
      baseline_emission_factor = emission_factor,
      production_unit = production_unit,
      technology_type = technology_type
    ) %>%
    group_by(technology, year, production_unit, technology_type) %>%
    summarise(
      baseline_production = sum(baseline_weight, na.rm = TRUE),
      baseline_emission_factor = weighted.mean(baseline_emission_factor, baseline_weight, na.rm = TRUE),
      .groups = "drop"
    )

  baseline_intensity <- baseline %>%
    group_by(year) %>%
    summarise(
      baseline_emission_factor = weighted.mean(baseline_emission_factor, baseline_production, na.rm = TRUE),
      .groups = "drop"
    )

  vietnam_scenario_co2 %>%
    filter(sector == spec$sector_local, scenario %in% names(.trisk_scenario_name_map)) %>%
    mutate(
      scenario = recode(scenario, !!!.trisk_scenario_name_map),
      scenario_type = recode(scenario, !!!.trisk_scenario_type_map, .default = "baseline"),
      scenario_geography = spec$geography,
      scenario_year = year
    ) %>%
    inner_join(baseline_intensity, by = c("year" = "year")) %>%
    crossing(spec$technologies %>% select(technology_trisk, technology_type)) %>%
    inner_join(
      baseline %>% select(technology, year, baseline_production, production_unit),
      by = c("technology_trisk" = "technology", "year" = "year")
    ) %>%
    mutate(
      intensity_ratio = if_else(baseline_emission_factor > 0, emission_factor_value / baseline_emission_factor, 1),
      carbon_delta = pmax(0, baseline_emission_factor - emission_factor_value),
      scenario_price = case_when(
        spec$sector_local == "cement" & scenario == "VN_PDP8_BASELINE" ~ 78 + 2.2 * (year - 2025) + carbon_delta * 16,
        spec$sector_local == "cement" & scenario == "VN_NZE_STRESS" ~ 78 + 4.8 * (year - 2025) + carbon_delta * 38,
        spec$sector_local == "cement" & scenario == "VN_STEPS_BASELINE" ~ 78 + 1.4 * (year - 2025) + carbon_delta * 8,
        spec$sector_local == "steel" & scenario == "VN_PDP8_BASELINE" ~ 92 + 1.9 * (year - 2025) + carbon_delta * 14,
        spec$sector_local == "steel" & scenario == "VN_NZE_STRESS" ~ 92 + 3.9 * (year - 2025) + carbon_delta * 32,
        spec$sector_local == "steel" & scenario == "VN_STEPS_BASELINE" ~ 92 + 1.0 * (year - 2025) + carbon_delta * 7,
        TRUE ~ 80
      ),
      scenario_pathway = baseline_production * case_when(
        technology_type == "carbontech" ~ pmax(0.78, 1 - (1 - intensity_ratio) * 0.55),
        technology_type == "greentech" ~ pmin(1.28, 1 + (1 - intensity_ratio) * 0.90),
        TRUE ~ 1
      ),
      scenario_capacity_factor = case_when(
        technology_type == "carbontech" ~ pmax(0.72, 1 - (1 - intensity_ratio) * 0.35),
        technology_type == "greentech" ~ pmin(1.12, 1 + (1 - intensity_ratio) * 0.25),
        TRUE ~ 1
      )
    ) %>%
    transmute(
      scenario = scenario,
      scenario_type = scenario_type,
      scenario_geography = scenario_geography,
      sector = spec$sector_trisk,
      technology = technology_trisk,
      scenario_year = scenario_year,
      price_unit = "USD/unit-equivalent",
      scenario_price = round(scenario_price, 4),
      pathway_unit = production_unit,
      scenario_pathway = round(scenario_pathway, 4),
      technology_type = technology_type,
      scenario_capacity_factor = round(scenario_capacity_factor, 4),
      country_iso2_list = NA_character_,
      scenario_provider = "synthetic_vietnam_demo"
    )
}

#' Build the three-scenario carbon-price path for a sector.
#'
#' Three scenarios per sector -- the existing scenario name/values unchanged
#' as the "NetZero2050" (strict) variant, plus two new derived paths at 60%
#' and 30% of its carbon_tax, rounded to 2 decimals -- so the dashboard's
#' "Net Zero 2050 (strict) / Below 2C (moderate) / Delayed transition (mild)"
#' carbon-price family selector finally reflects distinct data (Wave 1
#' PHASE-04, C7/ASM-005). The base (non-grid) TRISK run always reads the
#' unchanged first scenario by name via sector_meta()$carbon_price_model, so
#' its numbers are unaffected by this change.
#'
#' @param spec list — one sector's entry from .trisk_input_sector_specs.
#' @return tbl — 18 rows (3 scenarios x 6 years) in the trisk.model carbon
#'   price schema.
.trisk_build_carbon_price <- function(spec) {
  if (spec$sector_local == "power") {
    base_name <- "increasing_carbon_tax_50"
    base_tax <- c(0, 0, 0, 50, 52, 54.08)
  } else if (spec$sector_local == "cement") {
    base_name <- "cement_intensity_transition"
    base_tax <- c(12, 18, 26, 34, 42, 50)
  } else {
    base_name <- "steel_intensity_transition"
    base_tax <- c(10, 16, 24, 33, 42, 52)
  }

  build_price_block <- function(scenario_name, carbon_tax) {
    tibble(
      year = 2025:2030,
      model = "synthetic_vietnam_demo",
      scenario = scenario_name,
      scenario_geography = spec$geography,
      variable = "Price|Carbon",
      unit = "USD/t CO2",
      carbon_tax = carbon_tax
    )
  }

  dplyr::bind_rows(
    build_price_block(base_name, base_tax),
    build_price_block(paste0(base_name, "_below2c"), round(base_tax * 0.60, 2)),
    build_price_block(paste0(base_name, "_delayed"), round(base_tax * 0.30, 2))
  )
}

#' Prepare TRISK-ready input files for the given engagement's sectors.
#'
#' Reads the engagement's ABCD + scenario CSVs and writes, for each sector in
#' scope, the four-file TRISK input package under
#' `cfg$paths$trisk_input_root/<sector>_demo/`. In default (MCB, no-config)
#' mode ONLY, also writes the legacy `data/vietnam_trisk_*.csv` side copies
#' (nothing else in the repo reads them — verified by grep).
#'
#' @param cfg list — engagement config from load_engagement_config().
#' @param sectors character — sectors to prepare, default cfg$trisk_sectors.
#' @return invisible(list) — one element per sector with
#'   list(sector, assets, scenarios, carbon_price, input_dir).
#' @export
trisk_prepare_sector_inputs <- function(cfg, sectors = cfg$trisk_sectors) {
  cat("========================================\n")
  cat("Preparing TRISK multi-sector demo inputs\n")
  cat("========================================\n\n")

  required_files <- c(
    cfg$inputs$abcd_csv,
    cfg$inputs$scenario_ms_csv,
    cfg$inputs$scenario_co2_csv
  )

  missing <- required_files[!file.exists(required_files)]
  if (length(missing) > 0) {
    stop(sprintf(
      "Missing required files for TRISK input prep:\n  %s",
      paste(missing, collapse = "\n  ")
    ))
  }

  output_dir <- file.path(getwd(), cfg$paths$trisk_input_root)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  vietnam_abcd <- read_csv(cfg$inputs$abcd_csv, show_col_types = FALSE)
  validate_abcd_schema(vietnam_abcd, source_label = cfg$inputs$abcd_csv)
  vietnam_scenario_ms <- read_csv(cfg$inputs$scenario_ms_csv, show_col_types = FALSE)
  vietnam_scenario_co2 <- read_csv(cfg$inputs$scenario_co2_csv, show_col_types = FALSE)

  is_default_mode <- identical(cfg$bank_slug, "mcb-demo")
  data_dir <- file.path(getwd(), "data")

  company_mapping <- .trisk_company_archetypes %>%
    select(company_id, company_name, archetype)

  financial_features <- .trisk_company_archetypes %>%
    select(company_id, pd, net_profit_margin, debt_equity_ratio, volatility)

  if (is_default_mode) {
    write_csv(financial_features, file.path(data_dir, "vietnam_trisk_financial_features.csv"))
    write_csv(company_mapping, file.path(data_dir, "vietnam_trisk_company_mapping.csv"))
  }

  build_sector_inputs <- function(spec, sector_name) {
    sector_input_dir <- file.path(output_dir, paste0(sector_name, "_demo"))
    dir.create(sector_input_dir, recursive = TRUE, showWarnings = FALSE)

    sector_rows <- vietnam_abcd %>%
      filter(sector == spec$sector_local) %>%
      inner_join(spec$technologies, by = c("technology" = "technology_local"))

    if (nrow(sector_rows) == 0) {
      cat(sprintf(
        "[NOTE] No ABCD rows for sector '%s' — skipping TRISK input preparation.\n",
        sector_name
      ))
      return(NULL)
    }

    assets <- .trisk_build_assets(spec, vietnam_abcd)
    assets <- backfill_zero_baseline(assets, "capacity", "production_year")
    scenarios <- if (identical(spec$scenario_source, "ms")) {
      .trisk_build_power_scenarios(spec, assets, vietnam_scenario_ms)
    } else {
      .trisk_build_co2_scenarios(spec, assets, vietnam_scenario_co2)
    }
    carbon_price <- .trisk_build_carbon_price(spec)

    if (is_default_mode) {
      write_csv(assets, file.path(data_dir, sprintf("vietnam_trisk_assets_%s.csv", sector_name)))
      write_csv(scenarios, file.path(data_dir, sprintf("vietnam_trisk_scenarios_%s.csv", sector_name)))
      write_csv(carbon_price, file.path(data_dir, sprintf("vietnam_trisk_ngfs_carbon_price_%s.csv", sector_name)))
    }

    write_csv(assets, file.path(sector_input_dir, "assets.csv"))
    write_csv(scenarios, file.path(sector_input_dir, "scenarios.csv"))
    write_csv(financial_features, file.path(sector_input_dir, "financial_features.csv"))
    write_csv(carbon_price, file.path(sector_input_dir, "ngfs_carbon_price.csv"))

    list(
      sector = sector_name,
      assets = assets,
      scenarios = scenarios,
      carbon_price = carbon_price,
      input_dir = sector_input_dir
    )
  }

  sector_results <- imap(.trisk_input_sector_specs[sectors], build_sector_inputs)
  sector_results <- sector_results[!vapply(sector_results, is.null, logical(1))]

  walk(sector_results, function(result) {
    cat(sprintf(
      "Prepared %s inputs: %d asset rows across %d companies, %d scenario rows, %d carbon price rows.\n",
      result$sector,
      nrow(result$assets),
      n_distinct(result$assets$company_id),
      nrow(result$scenarios),
      nrow(result$carbon_price)
    ))
    cat(sprintf("  Input package written to: %s\n", result$input_dir))
  })

  invisible(sector_results)
}

# ==============================================================================
# SECTION B: TRISK SECTOR RUN (from trisk_sector_demo.R)
# ==============================================================================

trisk_supported_sectors <- c("power", "cement", "steel")

trisk_sensitivity_specs <- tribble(
  ~run_label,                  ~parameter_name,       ~parameter_value, ~shock_year, ~discount_rate, ~risk_free_rate, ~market_passthrough,
  "base",                    "base",               "base",          2028,        0.08,           0.03,            0.25,
  "shock_year_2027",         "shock_year",         "2027",          2027,        0.08,           0.03,            0.25,
  "shock_year_2029",         "shock_year",         "2029",          2029,        0.08,           0.03,            0.25,
  "discount_rate_0.06",      "discount_rate",      "0.06",          2028,        0.06,           0.03,            0.25,
  "discount_rate_0.10",      "discount_rate",      "0.10",          2028,        0.10,           0.03,            0.25,
  "risk_free_rate_0.02",     "risk_free_rate",     "0.02",          2028,        0.08,           0.02,            0.25,
  "risk_free_rate_0.04",     "risk_free_rate",     "0.04",          2028,        0.08,           0.04,            0.25,
  "market_passthrough_0.15", "market_passthrough", "0.15",          2028,        0.08,           0.03,            0.15,
  "market_passthrough_0.35", "market_passthrough", "0.35",          2028,        0.08,           0.03,            0.35
)

#' Assert that a sector is one of the three TRISK-supported sectors.
#'
#' @param sector character.
#' @return invisible(TRUE), or stop() if unsupported.
assert_supported_sector <- function(sector) {
  if (!(sector %in% trisk_supported_sectors)) {
    stop(sprintf(
      "Unsupported sector '%s'. Supported sectors: %s",
      sector,
      paste(trisk_supported_sectors, collapse = ", ")
    ))
  }
}

#' Resolve a sector's TRISK input/output directories.
#'
#' @param sector character.
#' @param output_root character|NULL — explicit output dir, or NULL to
#'   derive from `trisk_output_root`.
#' @param input_root character — root of the prepared TRISK inputs, default
#'   "output/trisk_inputs" (today's literal).
#' @param trisk_output_root character — root of TRISK run outputs, default
#'   "synthesis_output/trisk" (today's literal); only used when output_root
#'   is NULL.
#' @return list(input_dir, output_root).
resolve_trisk_paths <- function(sector, output_root = NULL, input_root = "output/trisk_inputs", trisk_output_root = "synthesis_output/trisk") {
  input_dir <- file.path(getwd(), input_root, paste0(sector, "_demo"))
  if (is.null(output_root)) {
    output_root <- file.path(getwd(), trisk_output_root, paste0(sector, "_demo"))
  }

  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

  list(
    input_dir = input_dir,
    output_root = output_root
  )
}

assert_required_input_files <- function(input_dir) {
  required_input_files <- c(
    "assets.csv",
    "scenarios.csv",
    "financial_features.csv",
    "ngfs_carbon_price.csv"
  )

  missing <- required_input_files[!file.exists(file.path(input_dir, required_input_files))]
  if (length(missing) > 0) {
    stop(sprintf(
      "Missing TRISK input files. Run scripts/trisk_prepare_inputs.R first.\nMissing:\n  %s",
      paste(missing, collapse = "\n  ")
    ))
  }
}

#' Load PACTA alignment context for a TRISK sector's borrowers.
#'
#' @param sector character.
#' @param meta list — from sector_meta(sector).
#' @param input_dir character — the sector's prepared TRISK input dir.
#' @param pacta_output_dir character — root of PACTA outputs, default
#'   "synthesis_output/vietnam" (today's literal).
#' @return tbl — company-level alignment context.
load_alignment_context <- function(sector, meta, input_dir, pacta_output_dir = "synthesis_output/vietnam") {
  if (meta$alignment_mode == "company_ms") {
    ms_file <- file.path(getwd(), pacta_output_dir, "04_vn_ms_company.csv")
    if (!file.exists(ms_file)) {
      return(tibble(
        company_name = character(),
        mean_abs_alignment_gap_pp = numeric(),
        worst_alignment_gap_pp = numeric(),
        alignment_context = character()
      ))
    }
    power_alignment <- read_csv(ms_file, show_col_types = FALSE) %>%
      filter(
        sector == "power",
        scenario_source == "pdp8_2023",
        year == 2030,
        metric %in% c("projected", "target_pdp8_ndc")
      ) %>%
      select(name_abcd, technology, metric, technology_share) %>%
      group_by(name_abcd, technology, metric) %>%
      summarise(technology_share = mean(technology_share, na.rm = TRUE), .groups = "drop") %>%
      pivot_wider(names_from = metric, values_from = technology_share) %>%
      mutate(
        target_share = target_pdp8_ndc,
        projected_share = projected,
        alignment_gap_pp = (projected_share - target_share) * 100
      ) %>%
      filter(!is.na(alignment_gap_pp)) %>%
      group_by(name_abcd) %>%
      summarise(
        mean_abs_alignment_gap_pp = if_else(
          all(is.na(alignment_gap_pp)),
          0,
          mean(abs(alignment_gap_pp), na.rm = TRUE)
        ),
        worst_alignment_gap_pp = if_else(
          all(is.na(alignment_gap_pp)),
          0,
          alignment_gap_pp[which.max(abs(alignment_gap_pp))]
        ),
        alignment_context = "Borrower-level PACTA market-share gap",
        .groups = "drop"
      )

    if (nrow(power_alignment) == 0) {
      return(tibble(
        company_name = character(),
        mean_abs_alignment_gap_pp = numeric(),
        worst_alignment_gap_pp = numeric(),
        alignment_context = character()
      ))
    }
    return(power_alignment %>% rename(company_name = name_abcd))
  }

  sda_file <- file.path(getwd(), pacta_output_dir, "06_vn_sda_alignment_2030.csv")
  if (!file.exists(sda_file)) {
    return(tibble(
      company_name = character(),
      mean_abs_alignment_gap_pp = numeric(),
      worst_alignment_gap_pp = numeric(),
      alignment_context = character()
    ))
  }
  sda_alignment <- read_csv(sda_file, show_col_types = FALSE) %>%
    mutate(
      mean_abs_alignment_gap_pp = abs(gap_pct),
      worst_alignment_gap_pp = gap_pct,
      alignment_context = sprintf("Sector-level SDA gap (%s, 2030)", sector)
    ) %>%
    select(sector, mean_abs_alignment_gap_pp, worst_alignment_gap_pp, alignment_context)

  sector_gap <- sda_alignment %>% filter(sector == !!sector)
  if (nrow(sector_gap) == 0) {
    return(tibble(
      company_name = character(),
      mean_abs_alignment_gap_pp = numeric(),
      worst_alignment_gap_pp = numeric(),
      alignment_context = character()
    ))
  }

  assets <- read_csv(file.path(input_dir, "assets.csv"), show_col_types = FALSE)
  tibble(company_name = unique(assets$company_name)) %>%
    mutate(
      mean_abs_alignment_gap_pp = sector_gap$mean_abs_alignment_gap_pp[[1]],
      worst_alignment_gap_pp = sector_gap$worst_alignment_gap_pp[[1]],
      alignment_context = sector_gap$alignment_context[[1]]
    )
}

build_run_params <- function(meta, input_dir, output_path, overrides = list()) {
  modifyList(
    c(
      list(
        input_path = input_dir,
        output_path = output_path,
        baseline_scenario = meta$baseline_scenario,
        target_scenario = meta$target_scenario,
        scenario_geography = meta$scenario_geography,
        carbon_price_model = meta$carbon_price_model
      ),
      trisk_base_params()
    ),
    overrides
  )
}

summarize_trisk_run <- function(npv_results, pd_results, alignment_company) {
  pd_summary <- pd_results %>%
    group_by(company_id, company_name, sector) %>%
    summarise(
      pd_baseline = suppressWarnings(max(pd_baseline, na.rm = TRUE)),
      pd_shock = suppressWarnings(max(pd_shock, na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    mutate(
      pd_baseline = if_else(is.infinite(pd_baseline), NA_real_, pd_baseline),
      pd_shock = if_else(is.infinite(pd_shock), NA_real_, pd_shock),
      pd_change = pd_shock - pd_baseline
    )

  company_summary <- npv_results %>%
    group_by(company_id, company_name, sector) %>%
    summarise(
      assets = n_distinct(asset_id),
      npv_baseline = sum(net_present_value_baseline, na.rm = TRUE),
      npv_shock = sum(net_present_value_shock, na.rm = TRUE),
      npv_difference = sum(net_present_value_difference, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      npv_change = if_else(npv_baseline != 0, npv_difference / npv_baseline, NA_real_)
    ) %>%
    left_join(pd_summary, by = c("company_id", "company_name", "sector")) %>%
    arrange(npv_change)

  npv_range <- range(-company_summary$npv_change, na.rm = TRUE)
  pd_range <- range(company_summary$pd_change, na.rm = TRUE)

  prioritization <- company_summary %>%
    left_join(alignment_company, by = "company_name") %>%
    mutate(
      mean_abs_alignment_gap_pp = replace_na(mean_abs_alignment_gap_pp, 0),
      worst_alignment_gap_pp = replace_na(worst_alignment_gap_pp, 0),
      alignment_context = replace_na(alignment_context, "No alignment context available")
    )

  gap_range <- range(prioritization$mean_abs_alignment_gap_pp, na.rm = TRUE)

  prioritization <- prioritization %>%
    mutate(
      stress_priority_score = rescale(-npv_change, to = c(0, 100), from = npv_range) * 0.7 +
        rescale(pd_change, to = c(0, 100), from = pd_range) * 0.2 +
        rescale(mean_abs_alignment_gap_pp, to = c(0, 100), from = gap_range) * 0.1
    ) %>%
    arrange(desc(stress_priority_score))

  list(
    pd_summary = pd_summary,
    company_summary = company_summary,
    prioritization = prioritization
  )
}

execute_trisk_run <- function(sector, run_label, output_path, overrides = list(), meta = NULL, input_dir = NULL, alignment_company = NULL, pacta_output_dir = "synthesis_output/vietnam") {
  assert_supported_sector(sector)
  if (is.null(meta)) {
    meta <- sector_meta(sector)
  }

  paths <- resolve_trisk_paths(sector, output_root = dirname(output_path))
  if (is.null(input_dir)) {
    input_dir <- paths$input_dir
  }
  assert_required_input_files(input_dir)

  if (is.null(alignment_company)) {
    alignment_company <- load_alignment_context(sector, meta, input_dir, pacta_output_dir)
  }

  dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
  run_args <- build_run_params(meta, input_dir, output_path, overrides)
  run_path <- do.call(trisk.model::run_trisk, run_args)

  npv_results <- read_csv(file.path(run_path, "npv_results.csv"), show_col_types = FALSE)
  pd_results <- read_csv(file.path(run_path, "pd_results.csv"), show_col_types = FALSE)
  company_trajectories <- read_csv(file.path(run_path, "company_trajectories.csv"), show_col_types = FALSE)
  params <- read_csv(file.path(run_path, "params.csv"), show_col_types = FALSE)

  summaries <- summarize_trisk_run(npv_results, pd_results, alignment_company)

  list(
    run_label = run_label,
    run_path = run_path,
    params = params,
    npv_results = npv_results,
    pd_results = pd_results,
    company_trajectories = company_trajectories,
    pd_summary = summaries$pd_summary,
    company_summary = summaries$company_summary,
    prioritization = summaries$prioritization
  )
}

run_trisk_sensitivity_case <- function(run_label, parameter_name, parameter_value, shock_year, discount_rate, risk_free_rate, market_passthrough, sector, output_root, meta, input_dir, alignment_company, pacta_output_dir = "synthesis_output/vietnam") {
  run_output_dir <- file.path(output_root, "runs", run_label)
  result <- execute_trisk_run(
    sector = sector,
    run_label = run_label,
    output_path = run_output_dir,
    overrides = list(
      shock_year = shock_year,
      discount_rate = discount_rate,
      risk_free_rate = risk_free_rate,
      market_passthrough = market_passthrough
    ),
    meta = meta,
    input_dir = input_dir,
    alignment_company = alignment_company,
    pacta_output_dir = pacta_output_dir
  )

  c(
    result,
    list(
      parameter_name = parameter_name,
      parameter_value = parameter_value
    )
  )
}

write_trisk_demo_outputs <- function(sector, output_root, meta, run_results) {
  base_run <- run_results[["base"]]

  # Deterministic run IDs: trisk.model::run_trisk() generates a fresh UUID per
  # invocation, which makes the five *_latest.csv files differ byte-for-byte on
  # every run. Before writing our own CSVs, replace run_id with a stable
  # sector_label string (e.g. "power_base") and run_catalog$run_path with the
  # same scheme. All in-memory joins have already happened by this point.
  deterministic_run_id <- function(df, run_label) {
    if ("run_id" %in% names(df)) {
      df$run_id <- sprintf("%s_%s", sector, run_label)
    }
    df
  }

  write_csv(base_run$company_summary, file.path(output_root, "company_summary.csv"))
  write_csv(base_run$prioritization, file.path(output_root, "top_borrowers_alignment_trisk.csv"))
  write_csv(
    deterministic_run_id(base_run$params, "base"),
    file.path(output_root, "params_latest.csv")
  )
  write_csv(base_run$pd_summary, file.path(output_root, "pd_summary.csv"))
  write_csv(
    deterministic_run_id(base_run$npv_results, "base"),
    file.path(output_root, "npv_results_latest.csv")
  )
  write_csv(
    deterministic_run_id(base_run$pd_results, "base"),
    file.path(output_root, "pd_results_latest.csv")
  )
  write_csv(
    deterministic_run_id(base_run$company_trajectories, "base"),
    file.path(output_root, "company_trajectories_latest.csv")
  )

  sensitivity_results <- imap_dfr(run_results, function(result, result_run_label) {
    result$prioritization %>%
      transmute(
        run_label = result_run_label,
        parameter_name = result$parameter_name,
        parameter_value = result$parameter_value,
        company_id,
        company_name,
        sector,
        npv_change,
        pd_change,
        mean_abs_alignment_gap_pp,
        worst_alignment_gap_pp,
        alignment_context,
        stress_priority_score
      )
  })

  base_metrics <- sensitivity_results %>%
    filter(run_label == "base") %>%
    select(
      company_id,
      base_npv_change = npv_change,
      base_pd_change = pd_change,
      base_stress_priority_score = stress_priority_score
    )

  sensitivity_results <- sensitivity_results %>%
    left_join(base_metrics, by = "company_id") %>%
    mutate(
      delta_npv_change_vs_base = npv_change - base_npv_change,
      delta_pd_change_vs_base = pd_change - base_pd_change,
      delta_priority_vs_base = stress_priority_score - base_stress_priority_score
    )

  sensitivity_summary <- sensitivity_results %>%
    filter(run_label != "base") %>%
    group_by(run_label, parameter_name, parameter_value) %>%
    summarise(
      borrower_count = sum(!is.na(stress_priority_score)),
      average_npv_change = mean(npv_change, na.rm = TRUE),
      average_pd_change = mean(pd_change, na.rm = TRUE),
      average_priority_delta = mean(delta_priority_vs_base, na.rm = TRUE),
      max_priority_delta = max(delta_priority_vs_base, na.rm = TRUE),
      max_priority_delta_company = company_name[which.max(replace_na(delta_priority_vs_base, -Inf))],
      min_priority_delta = min(delta_priority_vs_base, na.rm = TRUE),
      min_priority_delta_company = company_name[which.min(replace_na(delta_priority_vs_base, Inf))],
      top_ranked_company = company_name[which.max(replace_na(stress_priority_score, -Inf))],
      .groups = "drop"
    )

  run_catalog <- tibble(
    run_label = map_chr(run_results, "run_label"),
    parameter_name = map_chr(run_results, "parameter_name"),
    parameter_value = map_chr(run_results, "parameter_value"),
    run_path = map_chr(run_results, "run_path")
  )
  run_catalog$run_path <- sprintf("%s_%s", sector, run_catalog$run_label)

  write_csv(sensitivity_results, file.path(output_root, "sensitivity_results.csv"))
  write_csv(sensitivity_summary, file.path(output_root, "sensitivity_summary.csv"))
  write_csv(run_catalog, file.path(output_root, "run_catalog.csv"))

  figures_dir <- file.path(output_root, "figures")
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

  p_npv <- base_run$company_summary %>%
    mutate(company_name = reorder(company_name, npv_change)) %>%
    ggplot(aes(x = company_name, y = npv_change, fill = npv_change < 0)) +
    geom_col(show.legend = FALSE) +
    coord_flip() +
    scale_fill_manual(values = c("TRUE" = "#c0392b", "FALSE" = "#27ae60")) +
    scale_y_continuous(labels = percent_format(accuracy = 1)) +
    labs(
      title = sprintf("Vietnam TRISK Pilot: NPV Change by %s Borrower", meta$title),
      subtitle = sprintf("Baseline: %s | Stress: %s | shock year 2028", meta$baseline_scenario, meta$target_scenario),
      x = NULL,
      y = "NPV change"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))

  ggsave(file.path(figures_dir, "01_npv_change_by_company.png"), p_npv, width = 10, height = 6, dpi = 150)

  p_pd <- base_run$pd_summary %>%
    mutate(company_name = reorder(company_name, pd_change)) %>%
    ggplot(aes(x = company_name, y = pd_change, fill = pd_change > 0)) +
    geom_col(show.legend = FALSE) +
    coord_flip() +
    scale_fill_manual(values = c("TRUE" = "#d35400", "FALSE" = "#2980b9")) +
    scale_y_continuous(labels = percent_format(accuracy = 0.1)) +
    labs(
      title = sprintf("Vietnam TRISK Pilot: PD Change by %s Borrower", meta$title),
      subtitle = "Stress-induced change in model PD summary",
      x = NULL,
      y = "PD change"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))

  ggsave(file.path(figures_dir, "02_pd_change_by_company.png"), p_pd, width = 10, height = 6, dpi = 150)

  p_priority <- base_run$prioritization %>%
    slice_max(order_by = stress_priority_score, n = 10, with_ties = FALSE) %>%
    mutate(company_name = reorder(company_name, stress_priority_score)) %>%
    ggplot(aes(x = company_name, y = stress_priority_score, fill = mean_abs_alignment_gap_pp)) +
    geom_col() +
    coord_flip() +
    scale_fill_gradient(low = "#74b9ff", high = "#e74c3c") +
    labs(
      title = sprintf("Vietnam TRISK Pilot: Top %s Borrower Priority Score", meta$title),
      subtitle = "Composite of NPV deterioration, PD change, and alignment context",
      x = NULL,
      y = "Priority score",
      fill = "Avg abs\nalignment gap (pp)"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))

  ggsave(file.path(figures_dir, "03_priority_score_top10.png"), p_priority, width = 10, height = 6, dpi = 150)

  list(
    base_run = base_run,
    sensitivity_results = sensitivity_results,
    sensitivity_summary = sensitivity_summary,
    run_catalog = run_catalog,
    figures_dir = figures_dir
  )
}

#' Run the base + sensitivity TRISK cases for one sector of an engagement.
#'
#' @param cfg list — engagement config from load_engagement_config().
#' @param sector character — one of "power", "cement", "steel".
#' @return invisible(list) — sector, meta, paths, alignment_company,
#'   run_results, written_outputs (same shape run_sector_demo() returned).
#' @export
trisk_run_sector <- function(cfg, sector) {
  sector <- tolower(sector)
  assert_supported_sector(sector)

  meta <- sector_meta(sector)

  cat("========================================\n")
  cat(sprintf("Running Vietnam TRISK %s demo\n", meta$title))
  cat("========================================\n\n")

  paths <- resolve_trisk_paths(
    sector,
    input_root = cfg$paths$trisk_input_root,
    trisk_output_root = cfg$paths$trisk_output_root
  )
  input_dir <- paths$input_dir
  output_root <- paths$output_root

  required_files <- file.path(input_dir, c(
    "assets.csv", "scenarios.csv", "financial_features.csv", "ngfs_carbon_price.csv"
  ))
  if (!all(file.exists(required_files))) {
    cat(sprintf(
      "[NOTE] Missing TRISK input files for sector '%s' — skipping.\n  Expected: %s\n\n",
      sector, input_dir
    ))
    return(invisible(list(sector = sector, skipped = TRUE, reason = "missing_input_files")))
  }

  alignment_company <- load_alignment_context(sector, meta, input_dir, cfg$paths$pacta_output_dir)
  if (nrow(alignment_company) == 0) {
    cat(sprintf(
      "[NOTE] No alignment context for sector '%s' — skipping TRISK run.\n\n",
      sector
    ))
    return(invisible(list(sector = sector, skipped = TRUE, reason = "empty_alignment_context")))
  }

  cat("Executing base and sensitivity TRISK runs...\n\n")

  run_results <- pmap(
    trisk_sensitivity_specs,
    run_trisk_sensitivity_case,
    sector = sector,
    output_root = output_root,
    meta = meta,
    input_dir = input_dir,
    alignment_company = alignment_company,
    pacta_output_dir = cfg$paths$pacta_output_dir
  )
  names(run_results) <- trisk_sensitivity_specs$run_label

  written_outputs <- write_trisk_demo_outputs(sector, output_root, meta, run_results)
  base_run <- written_outputs$base_run

  cat(sprintf("Base TRISK run folder: %s\n\n", base_run$run_path))
  cat("Top borrower stress summary:\n")
  print(as.data.frame(base_run$prioritization %>%
    select(company_name, npv_change, pd_change, mean_abs_alignment_gap_pp, alignment_context, stress_priority_score) %>%
    mutate(
      npv_change = round(npv_change, 4),
      pd_change = round(pd_change, 5),
      mean_abs_alignment_gap_pp = round(mean_abs_alignment_gap_pp, 2),
      stress_priority_score = round(stress_priority_score, 1)
    ) %>%
    head(10)))

  cat("\nSaved outputs:\n")
  cat(sprintf("  %s\n", file.path(output_root, "company_summary.csv")))
  cat(sprintf("  %s\n", file.path(output_root, "top_borrowers_alignment_trisk.csv")))
  cat(sprintf("  %s\n", file.path(output_root, "sensitivity_results.csv")))
  cat(sprintf("  %s\n", file.path(output_root, "sensitivity_summary.csv")))
  cat(sprintf("  %s\n", file.path(output_root, "run_catalog.csv")))
  cat(sprintf("  %s\n", written_outputs$figures_dir))

  invisible(list(
    sector = sector,
    meta = meta,
    paths = paths,
    alignment_company = alignment_company,
    run_results = run_results,
    written_outputs = written_outputs
  ))
}

# ==============================================================================
# SECTION C: TRISK SCENARIO GRID (from trisk_scenario_grid.R)
# ==============================================================================

# v2 (Wave 1 PHASE-04 follow-up): each grid cell's inputs are now truncated
# to its own shock_year + 2 horizon (build_scenario_input_dir()) instead of
# always using the shared package extended to the grid-wide max shock_year.
# This changes every cell's numeric output for the same nominal parameters
# (it is the fix for the base-cell-vs-base-run divergence, C1/INV-001), so
# the version bump is required to force existing caches to discard and
# regenerate -- grid_input_fingerprint() alone would not detect this change,
# since the shared input package's own bytes are unchanged.
grid_contract_version <- "v2"

grid_levers <- list(
  shock_year = c(2026L, 2028L, 2030L),
  discount_rate = c(0.06, 0.08, 0.10),
  risk_free_rate = c(0.02, 0.03, 0.04),
  market_passthrough = c(0.15, 0.25, 0.35),
  carbon_price_family = c("NGFS_NetZero2050", "NGFS_Below2C", "NGFS_Delayed")
)

# Each NGFS_* family now maps to its own distinct scenario name -- see
# .trisk_build_carbon_price() (Wave 1 PHASE-04, C7/ASM-005).
carbon_price_model_map <- list(
  power = c(
    NGFS_NetZero2050 = "increasing_carbon_tax_50",
    NGFS_Below2C = "increasing_carbon_tax_50_below2c",
    NGFS_Delayed = "increasing_carbon_tax_50_delayed"
  ),
  cement = c(
    NGFS_NetZero2050 = "cement_intensity_transition",
    NGFS_Below2C = "cement_intensity_transition_below2c",
    NGFS_Delayed = "cement_intensity_transition_delayed"
  ),
  steel = c(
    NGFS_NetZero2050 = "steel_intensity_transition",
    NGFS_Below2C = "steel_intensity_transition_below2c",
    NGFS_Delayed = "steel_intensity_transition_delayed"
  )
)

build_scenario_id <- function(shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family) {
  sprintf(
    "s%s_d%.2f_rf%.2f_mp%.2f_c%s",
    shock_year,
    discount_rate,
    risk_free_rate,
    market_passthrough,
    carbon_price_family
  )
}

build_grid_label <- function(shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family) {
  paste(
    sprintf("shock %s", shock_year),
    sprintf("disc %.2f", discount_rate),
    sprintf("rf %.2f", risk_free_rate),
    sprintf("pass %.2f", market_passthrough),
    carbon_price_family,
    sep = " | "
  )
}

build_sector_grid <- function(sector_name) {
  tibble(
    shock_year = grid_levers$shock_year
  ) %>%
    crossing(
      discount_rate = grid_levers$discount_rate,
      risk_free_rate = grid_levers$risk_free_rate,
      market_passthrough = grid_levers$market_passthrough,
      carbon_price_family = grid_levers$carbon_price_family
    ) %>%
    mutate(
      sector = sector_name,
      carbon_price_model = unname(carbon_price_model_map[[sector_name]][carbon_price_family]),
      scenario_id = pmap_chr(
        list(shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family),
        build_scenario_id
      ),
      grid_label = pmap_chr(
        list(shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family),
        build_grid_label
      )
    ) %>%
    select(
      scenario_id,
      sector,
      shock_year,
      discount_rate,
      risk_free_rate,
      market_passthrough,
      carbon_price_family,
      carbon_price_model,
      grid_label
    )
}

read_existing_grid <- function(grid_dir) {
  scenarios_path <- file.path(grid_dir, "scenarios.csv")
  borrower_path <- file.path(grid_dir, "borrower_results.parquet")

  scenarios <- if (file.exists(scenarios_path)) {
    read_csv(scenarios_path, show_col_types = FALSE)
  } else {
    tibble()
  }

  borrower_results <- if (file.exists(borrower_path)) {
    read_parquet(borrower_path) %>% as_tibble()
  } else {
    tibble()
  }

  list(
    scenarios = scenarios,
    borrower_results = borrower_results
  )
}

extend_yearly_inputs <- function(df, group_cols, year_col, value_cols, target_year, lower_bounds = list()) {
  year_sym <- rlang::sym(year_col)

  df %>%
    group_by(across(all_of(group_cols))) %>%
    group_modify(function(.x, .y) {
      data <- .x %>% arrange(!!year_sym)
      current_max_year <- max(data[[year_col]], na.rm = TRUE)

      if (current_max_year >= target_year) {
        return(data)
      }

      for (new_year in seq(current_max_year + 1, target_year)) {
        next_row <- data[nrow(data), , drop = FALSE]
        next_row[[year_col]] <- new_year

        for (col in value_cols) {
          values <- data[[col]]
          years <- data[[year_col]]
          non_na_idx <- which(!is.na(values))

          if (length(non_na_idx) >= 2) {
            last_two <- tail(non_na_idx, 2)
            delta <- values[last_two[2]] - values[last_two[1]]
            next_value <- values[last_two[2]] + delta * (new_year - years[last_two[2]])
          } else if (length(non_na_idx) == 1) {
            next_value <- values[non_na_idx]
          } else {
            next_value <- NA_real_
          }

          lower_bound <- lower_bounds[[col]]
          if (!is.null(lower_bound) && !is.na(next_value)) {
            next_value <- max(lower_bound, next_value)
          }

          next_row[[col]] <- next_value
        }

        data <- bind_rows(data, next_row)
      }

      data
    }) %>%
    ungroup()
}

build_grid_input_dir <- function(sector, source_input_dir, grid_dir) {
  grid_input_dir <- file.path(grid_dir, "input")
  dir.create(grid_input_dir, recursive = TRUE, showWarnings = FALSE)

  file.copy(file.path(source_input_dir, "assets.csv"), file.path(grid_input_dir, "assets.csv"), overwrite = TRUE)
  file.copy(file.path(source_input_dir, "financial_features.csv"), file.path(grid_input_dir, "financial_features.csv"), overwrite = TRUE)

  target_year <- max(grid_levers$shock_year) + 2L

  scenarios <- read_csv(file.path(source_input_dir, "scenarios.csv"), show_col_types = FALSE) %>%
    extend_yearly_inputs(
      group_cols = c("scenario", "scenario_type", "scenario_geography", "sector", "technology", "technology_type", "price_unit", "pathway_unit", "country_iso2_list", "scenario_provider"),
      year_col = "scenario_year",
      value_cols = c("scenario_price", "scenario_pathway", "scenario_capacity_factor"),
      target_year = target_year,
      lower_bounds = list(
        scenario_price = 0,
        scenario_pathway = 0,
        scenario_capacity_factor = 0
      )
    )

  carbon_price <- read_csv(file.path(source_input_dir, "ngfs_carbon_price.csv"), show_col_types = FALSE) %>%
    extend_yearly_inputs(
      group_cols = c("model", "scenario", "scenario_geography", "variable", "unit"),
      year_col = "year",
      value_cols = c("carbon_tax"),
      target_year = target_year,
      lower_bounds = list(carbon_tax = 0)
    )

  write_csv(scenarios, file.path(grid_input_dir, "scenarios.csv"))
  write_csv(carbon_price, file.path(grid_input_dir, "ngfs_carbon_price.csv"))

  grid_input_dir
}

#' Truncate the shared grid input package to one scenario's own horizon.
#'
#' build_grid_input_dir() extends scenarios.csv and ngfs_carbon_price.csv to
#' `max(grid_levers$shock_year) + 2` ONE TIME so every scenario in the grid
#' can share a single pre-built input package. That is correct only for
#' scenarios whose own shock_year equals the grid-wide max: a scenario with
#' an earlier shock_year still receives the full extended (2031-2032)
#' trailing rows, and trisk.model's NPV sums over every year present in the
#' scenario data — so those extra rows measurably change the result even
#' though the years within the run's own horizon are byte-identical.
#' Discovered empirically (Wave 1 PHASE-04 follow-up, still C1/INV-001):
#' after fixing the stale-cache defect, a fully fresh grid regeneration
#' still disagreed with the base (non-grid) run at identical parameters;
#' truncating to shock_year + 2 made the disagreement disappear to floating-
#' point noise (verified max abs diff 1.1e-16).
#'
#' The horizon is never truncated below assets.csv's own max year:
#' assets.csv is copied verbatim by build_grid_input_dir() (never extended),
#' so it always spans the base run's original window. Truncating
#' scenarios/carbon_price BELOW that window while assets.csv stays at its
#' full range creates an asset/scenario year mismatch that crashes inside
#' trisk.model:::extend_to_full_analysis_timeframe() (confirmed empirically
#' for an early shock_year truncated naively to shock_year + 2 alone). The
#' horizon is therefore `max(shock_year + 2, assets.csv's own max year)`.
#'
#' @param grid_input_dir character — the shared, already-extended grid input
#'   directory (from build_grid_input_dir()).
#' @param shock_year integer — this scenario's own shock_year.
#' @param scratch_dir character — directory to write the truncated copy to;
#'   created if it does not exist.
#' @return character — scratch_dir, ready to pass as execute_trisk_run()'s
#'   input_dir.
build_scenario_input_dir <- function(grid_input_dir, shock_year, scratch_dir) {
  dir.create(scratch_dir, recursive = TRUE, showWarnings = FALSE)

  file.copy(file.path(grid_input_dir, "assets.csv"), file.path(scratch_dir, "assets.csv"), overwrite = TRUE)
  file.copy(file.path(grid_input_dir, "financial_features.csv"), file.path(scratch_dir, "financial_features.csv"), overwrite = TRUE)

  assets <- read_csv(file.path(scratch_dir, "assets.csv"), show_col_types = FALSE)
  base_max_year <- max(assets$production_year, na.rm = TRUE)
  horizon <- max(as.integer(shock_year) + 2L, base_max_year)

  scenarios <- read_csv(file.path(grid_input_dir, "scenarios.csv"), show_col_types = FALSE) %>%
    filter(scenario_year <= horizon)
  write_csv(scenarios, file.path(scratch_dir, "scenarios.csv"))

  carbon_price <- read_csv(file.path(grid_input_dir, "ngfs_carbon_price.csv"), show_col_types = FALSE) %>%
    filter(year <= horizon)
  write_csv(carbon_price, file.path(scratch_dir, "ngfs_carbon_price.csv"))

  scratch_dir
}

#' md5 fingerprint of a grid sector's live input package.
#'
#' Hashes the four TRISK input files a grid depends on, in sorted-filename
#' order, so the digest is stable across platforms. Must be called AFTER
#' build_grid_input_dir() has refreshed grid_input_dir from the sector's
#' current input package -- computing it earlier fingerprints the previous
#' run's inputs (Wave 1 PHASE-04, Specification S2).
#'
#' @param grid_input_dir character — the grid's `input/` directory, as
#'   returned by build_grid_input_dir().
#' @return character(1) — a 32-character lowercase md5 hex digest over the
#'   four input files' own md5 digests concatenated in sorted-filename order
#'   (assets.csv, financial_features.csv, ngfs_carbon_price.csv,
#'   scenarios.csv); NA_character_ if any of the four is missing.
grid_input_fingerprint <- function(grid_input_dir) {
  filenames <- sort(c("assets.csv", "financial_features.csv", "ngfs_carbon_price.csv", "scenarios.csv"))
  paths <- file.path(grid_input_dir, filenames)
  if (!all(file.exists(paths))) {
    return(NA_character_)
  }
  # base R only (CON-001: no new pipeline dependency) -- md5 the four file
  # digests' concatenation by writing them to a scratch file and md5-summing
  # that, rather than pulling in the digest package for a single string hash.
  digests <- unname(tools::md5sum(paths))
  concat_path <- tempfile()
  on.exit(unlink(concat_path), add = TRUE)
  writeChar(paste(digests, collapse = ""), concat_path, eos = NULL)
  unname(tools::md5sum(concat_path))
}

#' Decide whether a grid's cached results may be reused.
#'
#' Cache reuse requires the recorded input fingerprint, trisk.model version,
#' and grid contract version to all match the current environment (Wave 1
#' PHASE-04, Specification S2). Any mismatch — or a missing/unreadable
#' grid_meta.json — invalidates the entire cache, not just the changed part.
#'
#' @param grid_dir character — the grid's output directory (holds
#'   grid_meta.json).
#' @param grid_input_dir character — the grid's `input/` directory.
#' @param contract_version character — the in-code grid_contract_version.
#' @param model_version character — the currently installed trisk.model
#'   version, typically `as.character(utils::packageVersion("trisk.model"))`.
#' @return list(valid = logical(1), reason = character(1)) — reason is one
#'   of "ok", "no grid_meta.json", "no input_fingerprint recorded",
#'   "input fingerprint changed", "trisk.model version changed",
#'   "grid contract version changed".
grid_cache_is_valid <- function(grid_dir, grid_input_dir, contract_version, model_version) {
  meta_path <- file.path(grid_dir, "grid_meta.json")
  if (!file.exists(meta_path)) {
    return(list(valid = FALSE, reason = "no grid_meta.json"))
  }

  meta <- tryCatch(
    jsonlite::read_json(meta_path, simplifyVector = TRUE),
    error = function(e) NULL
  )
  if (is.null(meta) || is.null(meta$input_fingerprint)) {
    return(list(valid = FALSE, reason = "no input_fingerprint recorded"))
  }

  current_fingerprint <- grid_input_fingerprint(grid_input_dir)
  if (!identical(meta$input_fingerprint, current_fingerprint)) {
    return(list(valid = FALSE, reason = "input fingerprint changed"))
  }
  if (!identical(meta$trisk_model_version, model_version)) {
    return(list(valid = FALSE, reason = "trisk.model version changed"))
  }
  if (!identical(meta$grid_contract_version, contract_version)) {
    return(list(valid = FALSE, reason = "grid contract version changed"))
  }

  list(valid = TRUE, reason = "ok")
}

find_cached_run_path <- function(run_output_dir) {
  if (!dir.exists(run_output_dir)) {
    return(NULL)
  }

  subdirs <- list.dirs(run_output_dir, recursive = FALSE, full.names = TRUE)
  if (length(subdirs) == 0) {
    return(NULL)
  }

  valid_subdirs <- subdirs[file.exists(file.path(subdirs, "npv_results.csv"))]
  if (length(valid_subdirs) == 0) {
    return(NULL)
  }

  valid_subdirs[which.max(file.info(valid_subdirs)$mtime)]
}

load_cached_run <- function(run_path, alignment_company, scenario_id, sector) {
  npv_results <- read_csv(file.path(run_path, "npv_results.csv"), show_col_types = FALSE)
  pd_results <- read_csv(file.path(run_path, "pd_results.csv"), show_col_types = FALSE)

  summaries <- summarize_trisk_run(npv_results, pd_results, alignment_company)

  build_borrower_results(
    summaries$prioritization,
    tibble(scenario_id = scenario_id, sector = sector)
  )
}

build_borrower_results <- function(prioritization, grid_row) {
  prioritization %>%
    mutate(
      scenario_id = grid_row$scenario_id,
      sector = grid_row$sector,
      rank_within_scenario = row_number(desc(stress_priority_score))
    ) %>%
    transmute(
      scenario_id,
      sector,
      company_id,
      company_name,
      npv_change_pct = npv_change,
      pd_change_pct = pd_change,
      stress_priority_score,
      delta_npv_change_vs_base = NA_real_,
      delta_pd_change_vs_base = NA_real_,
      rank_within_scenario,
      mean_abs_alignment_gap_pp,
      worst_alignment_gap_pp,
      alignment_context,
      npv_baseline,
      npv_shock,
      npv_difference,
      pd_baseline,
      pd_shock,
      pd_change,
      assets
    )
}

apply_base_deltas <- function(borrower_results, sector, trisk_output_root = "synthesis_output/trisk") {
  base_results_path <- file.path(getwd(), trisk_output_root, paste0(sector, "_demo"), "sensitivity_results.csv")
  base_results <- read_csv(base_results_path, show_col_types = FALSE) %>%
    filter(run_label == "base") %>%
    select(company_id, base_npv_change = npv_change, base_pd_change = pd_change)

  borrower_results %>%
    left_join(base_results, by = "company_id") %>%
    mutate(
      delta_npv_change_vs_base = npv_change_pct - base_npv_change,
      delta_pd_change_vs_base = pd_change_pct - base_pd_change
    ) %>%
    select(-base_npv_change, -base_pd_change)
}

#' Run (or extend from cache) the 243-cell TRISK scenario grid for one sector.
#'
#' @param cfg list — engagement config from load_engagement_config().
#' @param sector character — one of "power", "cement", "steel".
#' @return invisible(list) — sector, scenarios, borrower_results, grid_meta
#'   (same shape run_sector_grid() returned).
#' @export
trisk_run_grid <- function(cfg, sector) {
  assert_supported_sector(sector)
  meta <- sector_meta(sector)
  paths <- resolve_trisk_paths(
    sector,
    input_root = cfg$paths$trisk_input_root,
    trisk_output_root = cfg$paths$trisk_output_root
  )
  input_dir <- paths$input_dir

  assert_required_input_files(input_dir)
  alignment_company <- load_alignment_context(sector, meta, input_dir, cfg$paths$pacta_output_dir)

  grid_dir <- file.path(getwd(), cfg$paths$trisk_output_root, "grid", sector)
  runs_dir <- file.path(grid_dir, "runs")
  dir.create(runs_dir, recursive = TRUE, showWarnings = FALSE)
  grid_input_dir <- build_grid_input_dir(sector, input_dir, grid_dir)
  sector_grid <- build_sector_grid(sector)

  model_version <- as.character(utils::packageVersion("trisk.model"))
  cache_check <- grid_cache_is_valid(grid_dir, grid_input_dir, grid_contract_version, model_version)

  if (cache_check$valid) {
    existing <- read_existing_grid(grid_dir)
  } else {
    cat(sprintf(
      "[%s] grid cache invalidated: %s — regenerating all %d scenarios\n",
      sector, cache_check$reason, nrow(sector_grid)
    ))
    # The cache is fully discarded, not merged: find_cached_run_path() would
    # otherwise resurrect stale per-scenario runs/ directories one cell at a
    # time (Wave 1 PHASE-04, Specification S2).
    unlink(runs_dir, recursive = TRUE, force = TRUE)
    dir.create(runs_dir, recursive = TRUE, showWarnings = FALSE)
    existing <- list(scenarios = tibble(), borrower_results = tibble())
  }

  completed_ids <- if ("scenario_id" %in% names(existing$borrower_results)) {
    unique(existing$borrower_results$scenario_id)
  } else {
    character()
  }
  pending_grid <- sector_grid %>% filter(!(scenario_id %in% completed_ids))
  scenarios_path <- file.path(grid_dir, "scenarios.csv")
  borrower_path <- file.path(grid_dir, "borrower_results.parquet")
  meta_path <- file.path(grid_dir, "grid_meta.json")

  cat(sprintf("\n[%s] %d total scenarios, %d cached, %d pending.\n",
    sector,
    nrow(sector_grid),
    length(completed_ids),
    nrow(pending_grid)
  ))

  if (nrow(pending_grid) == 0 && nrow(existing$borrower_results) > 0 && file.exists(scenarios_path) && file.exists(borrower_path) && file.exists(meta_path)) {
    cat(sprintf("  [%s] grid already complete, skipping regeneration.\n", sector))
    return(invisible(list(
      sector = sector,
      scenarios = sector_grid,
      borrower_results = existing$borrower_results,
      grid_meta = jsonlite::read_json(meta_path, simplifyVector = TRUE)
    )))
  }

  started_at <- Sys.time()

  new_results <- pmap_dfr(pending_grid, function(scenario_id, sector, shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family, carbon_price_model, grid_label) {
    run_output_dir <- file.path(runs_dir, scenario_id)
    cached_run_path <- find_cached_run_path(run_output_dir)

    if (!is.null(cached_run_path)) {
      cat(sprintf("  [%s] reusing cached %s\n", sector, scenario_id))
      return(load_cached_run(cached_run_path, alignment_company, scenario_id, sector))
    }

    cat(sprintf("  [%s] running %s\n", sector, scenario_id))

    # Truncate the shared, pre-extended grid_input_dir to THIS scenario's own
    # shock_year + 2 horizon, so its inputs match what a standalone run at
    # the same shock_year would see (see build_scenario_input_dir()).
    scenario_input_dir <- build_scenario_input_dir(
      grid_input_dir, shock_year, file.path(run_output_dir, "input")
    )

    result <- execute_trisk_run(
      sector = sector,
      run_label = scenario_id,
      output_path = run_output_dir,
      overrides = list(
        shock_year = shock_year,
        discount_rate = discount_rate,
        risk_free_rate = risk_free_rate,
        market_passthrough = market_passthrough,
        carbon_price_model = carbon_price_model
      ),
      meta = modifyList(meta, list(carbon_price_model = carbon_price_model)),
      input_dir = scenario_input_dir,
      alignment_company = alignment_company,
      pacta_output_dir = cfg$paths$pacta_output_dir
    )

    build_borrower_results(
      result$prioritization,
      tibble(
        scenario_id = scenario_id,
        sector = sector,
        shock_year = shock_year,
        discount_rate = discount_rate,
        risk_free_rate = risk_free_rate,
        market_passthrough = market_passthrough,
        carbon_price_family = carbon_price_family,
        carbon_price_model = carbon_price_model,
        grid_label = grid_label
      )
    )
  })

  borrower_results <- bind_rows(existing$borrower_results, new_results) %>%
    distinct(scenario_id, company_id, .keep_all = TRUE) %>%
    arrange(scenario_id, desc(stress_priority_score), company_name)

  borrower_results <- apply_base_deltas(borrower_results, sector, cfg$paths$trisk_output_root)

  write_csv(sector_grid, scenarios_path)

  parquet_tmp_path <- file.path(grid_dir, "borrower_results.tmp.parquet")
  write_parquet(borrower_results, parquet_tmp_path)
  if (file.exists(borrower_path)) {
    unlink(borrower_path, force = TRUE)
  }
  file.rename(parquet_tmp_path, borrower_path)

  runtime_seconds <- as.numeric(difftime(Sys.time(), started_at, units = "secs"))
  grid_meta <- list(
    sector = sector,
    scenario_count = nrow(sector_grid),
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    runtime_seconds = round(runtime_seconds, 3),
    trisk_model_version = model_version,
    grid_contract_version = grid_contract_version,
    cached_scenarios = length(completed_ids),
    generated_scenarios = nrow(pending_grid),
    input_fingerprint = grid_input_fingerprint(grid_input_dir)
  )

  write_json(grid_meta, meta_path, auto_unbox = TRUE, pretty = TRUE)

  invisible(list(
    sector = sector,
    scenarios = sector_grid,
    borrower_results = borrower_results,
    grid_meta = grid_meta
  ))
}
