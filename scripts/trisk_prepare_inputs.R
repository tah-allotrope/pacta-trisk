# ==============================================================================
# trisk_prepare_inputs.R
# Build TRISK-ready input files for the synthetic Vietnam PACTA sectors.
#
# Outputs:
#   data/vietnam_trisk_financial_features.csv
#   data/vietnam_trisk_company_mapping.csv
#   data/vietnam_trisk_assets_<sector>.csv
#   data/vietnam_trisk_scenarios_<sector>.csv
#   data/vietnam_trisk_ngfs_carbon_price_<sector>.csv
#   output/trisk_inputs/<sector>_demo/{assets,scenarios,financial_features,ngfs_carbon_price}.csv
#
# Run from project root:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_prepare_inputs.R
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(readr)
  library(tibble)
  library(tidyr)
})

cat("========================================\n")
cat("Preparing TRISK multi-sector demo inputs\n")
cat("========================================\n\n")

required_files <- c(
  "data/vietnam_abcd.csv",
  "data/vietnam_scenario_ms.csv",
  "data/vietnam_scenario_co2.csv"
)

missing <- required_files[!file.exists(required_files)]
if (length(missing) > 0) {
  stop(sprintf(
    "Missing required files for TRISK input prep:\n  %s",
    paste(missing, collapse = "\n  ")
  ))
}

data_dir <- file.path(getwd(), "data")
output_dir <- file.path(getwd(), "output", "trisk_inputs")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

vietnam_abcd <- read_csv(file.path(data_dir, "vietnam_abcd.csv"), show_col_types = FALSE)
vietnam_scenario_ms <- read_csv(file.path(data_dir, "vietnam_scenario_ms.csv"), show_col_types = FALSE)
vietnam_scenario_co2 <- read_csv(file.path(data_dir, "vietnam_scenario_co2.csv"), show_col_types = FALSE)

sector_specs <- list(
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

company_archetypes <- tribble(
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

company_mapping <- company_archetypes %>%
  select(company_id, company_name, archetype)

financial_features <- company_archetypes %>%
  select(company_id, pd, net_profit_margin, debt_equity_ratio, volatility)

scenario_name_map <- c(
  pdp8_ndc = "VN_PDP8_BASELINE",
  nze_global = "VN_NZE_STRESS",
  steps = "VN_STEPS_BASELINE"
)

scenario_type_map <- c(
  VN_PDP8_BASELINE = "baseline",
  VN_NZE_STRESS = "target",
  VN_STEPS_BASELINE = "baseline"
)

write_csv(financial_features, file.path(data_dir, "vietnam_trisk_financial_features.csv"))
write_csv(company_mapping, file.path(data_dir, "vietnam_trisk_company_mapping.csv"))

build_assets <- function(spec) {
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

build_power_scenarios <- function(spec, assets) {
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
      scenario = recode(scenario, !!!scenario_name_map, .default = paste0("VN_", toupper(scenario))),
      scenario_type = recode(scenario, !!!scenario_type_map, .default = "baseline"),
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

build_co2_scenarios <- function(spec, assets) {
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
    filter(sector == spec$sector_local, scenario %in% names(scenario_name_map)) %>%
    mutate(
      scenario = recode(scenario, !!!scenario_name_map),
      scenario_type = recode(scenario, !!!scenario_type_map, .default = "baseline"),
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

build_carbon_price <- function(spec) {
  if (spec$sector_local == "power") {
    tibble(
      year = 2025:2030,
      model = "synthetic_vietnam_demo",
      scenario = "increasing_carbon_tax_50",
      scenario_geography = spec$geography,
      variable = "Price|Carbon",
      unit = "USD/t CO2",
      carbon_tax = c(0, 0, 0, 50, 52, 54.08)
    )
  } else if (spec$sector_local == "cement") {
    tibble(
      year = 2025:2030,
      model = "synthetic_vietnam_demo",
      scenario = "cement_intensity_transition",
      scenario_geography = spec$geography,
      variable = "Price|Carbon",
      unit = "USD/t CO2",
      carbon_tax = c(12, 18, 26, 34, 42, 50)
    )
  } else {
    tibble(
      year = 2025:2030,
      model = "synthetic_vietnam_demo",
      scenario = "steel_intensity_transition",
      scenario_geography = spec$geography,
      variable = "Price|Carbon",
      unit = "USD/t CO2",
      carbon_tax = c(10, 16, 24, 33, 42, 52)
    )
  }
}

build_sector_inputs <- function(spec, sector_name) {
  sector_input_dir <- file.path(output_dir, paste0(sector_name, "_demo"))
  dir.create(sector_input_dir, recursive = TRUE, showWarnings = FALSE)

  assets <- build_assets(spec)
  scenarios <- if (identical(spec$scenario_source, "ms")) {
    build_power_scenarios(spec, assets)
  } else {
    build_co2_scenarios(spec, assets)
  }
  carbon_price <- build_carbon_price(spec)

  write_csv(assets, file.path(data_dir, sprintf("vietnam_trisk_assets_%s.csv", sector_name)))
  write_csv(scenarios, file.path(data_dir, sprintf("vietnam_trisk_scenarios_%s.csv", sector_name)))
  write_csv(carbon_price, file.path(data_dir, sprintf("vietnam_trisk_ngfs_carbon_price_%s.csv", sector_name)))

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

sector_results <- imap(sector_specs, build_sector_inputs)

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
