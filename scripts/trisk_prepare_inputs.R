# ==============================================================================
# trisk_prepare_inputs.R
# Build TRISK-ready power-sector input files from the synthetic Vietnam PACTA data.
#
# Outputs:
#   data/vietnam_trisk_financial_features.csv
#   data/vietnam_trisk_assets_power.csv
#   data/vietnam_trisk_scenarios_power.csv
#   data/vietnam_trisk_ngfs_carbon_price.csv
#   data/vietnam_trisk_company_mapping.csv
#   output/trisk_inputs/power_demo/{assets,scenarios,financial_features,ngfs_carbon_price}.csv
#
# Run from project root:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_prepare_inputs.R
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})

cat("========================================\n")
cat("Preparing TRISK power demo inputs\n")
cat("========================================\n\n")

required_files <- c(
  "data/vietnam_abcd.csv",
  "data/vietnam_scenario_ms.csv"
)

missing <- required_files[!file.exists(required_files)]
if (length(missing) > 0) {
  stop(sprintf(
    "Missing required files for TRISK input prep:\n  %s",
    paste(missing, collapse = "\n  ")
  ))
}

data_dir <- file.path(getwd(), "data")
trisk_input_dir <- file.path(getwd(), "output", "trisk_inputs", "power_demo")
dir.create(trisk_input_dir, recursive = TRUE, showWarnings = FALSE)

vietnam_abcd <- read_csv(file.path(data_dir, "vietnam_abcd.csv"), show_col_types = FALSE)
vietnam_scenario_ms <- read_csv(file.path(data_dir, "vietnam_scenario_ms.csv"), show_col_types = FALSE)

# The installed trisk.model package expects Power sector naming conventions.
power_mapping <- tibble::tribble(
  ~sector_local, ~technology_local, ~sector_trisk, ~technology_trisk, ~technology_type, ~capacity_factor_demo, ~emission_factor_demo,
  "power",      "coalcap",        "Power",      "CoalCap",        "carbontech",    0.70,                  0.95,
  "power",      "gascap",         "Power",      "GasCap",         "carbontech",    0.55,                  0.45,
  "power",      "hydrocap",       "Power",      "HydroCap",       "greentech",     0.45,                  0.02,
  "power",      "renewablescap",  "Power",      "RenewablesCap",  "greentech",     0.30,                  0.01
)

company_archetypes <- tibble::tribble(
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
  "VN_ABCD_013", "Gia Lai Electricity JSC",        "renewable_ipp",             0.020,  0.093,              1.75,               0.28
)

company_mapping <- company_archetypes %>%
  select(company_id, company_name, archetype)

power_assets <- vietnam_abcd %>%
  filter(sector == "power") %>%
  inner_join(
    power_mapping,
    by = c("sector" = "sector_local", "technology" = "technology_local")
  ) %>%
  transmute(
    company_id = company_id,
    company_name = name_company,
    asset_id = paste(company_id, technology_trisk, sep = "_"),
    asset_name = paste(name_company, technology_trisk, sep = " :: "),
    country_iso2 = plant_location,
    production_year = year,
    sector = sector_trisk,
    technology = technology_trisk,
    capacity = if_else(capacity_factor_demo > 0, production / capacity_factor_demo, production),
    capacity_factor = capacity_factor_demo,
    emission_factor = emission_factor_demo,
    production_unit = production_unit,
    technology_type = technology_type
  )

power_tech_baseline <- power_assets %>%
  transmute(
    sector_trisk = sector,
    technology_trisk = technology,
    year = production_year,
    baseline_production = capacity * capacity_factor,
    production_unit = production_unit
  ) %>%
  group_by(sector_trisk, technology_trisk, year, production_unit) %>%
  summarise(
    baseline_production = sum(baseline_production, na.rm = TRUE),
    .groups = "drop"
  )

power_scenarios <- vietnam_scenario_ms %>%
  filter(sector == "power", technology %in% power_mapping$technology_local) %>%
  inner_join(
    power_mapping,
    by = c("sector" = "sector_local", "technology" = "technology_local")
  ) %>%
  inner_join(
    power_tech_baseline,
    by = c(
      "sector_trisk" = "sector_trisk",
      "technology_trisk" = "technology_trisk",
      "year" = "year"
    )
  ) %>%
  mutate(
    scenario = case_when(
      scenario == "pdp8_ndc" ~ "VN_PDP8_BASELINE",
      scenario == "nze_global" ~ "VN_NZE_STRESS",
      TRUE ~ paste0("VN_", toupper(scenario))
    ),
    scenario_type = case_when(
      scenario == "VN_PDP8_BASELINE" ~ "baseline",
      scenario == "VN_NZE_STRESS" ~ "target",
      TRUE ~ "baseline"
    ),
    scenario_geography = "Vietnam",
    scenario_year = year,
    scenario_price = case_when(
      technology_trisk == "CoalCap" & scenario == "VN_PDP8_BASELINE" ~ 68 + 0.4 * (year - 2025),
      technology_trisk == "CoalCap" & scenario == "VN_NZE_STRESS" ~ 68 - 1.6 * (year - 2025),
      technology_trisk == "GasCap" & scenario == "VN_PDP8_BASELINE" ~ 60 + 0.6 * (year - 2025),
      technology_trisk == "GasCap" & scenario == "VN_NZE_STRESS" ~ 60 - 0.3 * (year - 2025),
      technology_trisk == "HydroCap" & scenario == "VN_PDP8_BASELINE" ~ 56 + 0.1 * (year - 2025),
      technology_trisk == "HydroCap" & scenario == "VN_NZE_STRESS" ~ 56 + 0.2 * (year - 2025),
      technology_trisk == "RenewablesCap" & scenario == "VN_PDP8_BASELINE" ~ 52 + 0.2 * (year - 2025),
      technology_trisk == "RenewablesCap" & scenario == "VN_NZE_STRESS" ~ 52 + 0.8 * (year - 2025),
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
      technology_trisk == "GasCap" & scenario == "VN_PDP8_BASELINE" ~ pmin(0.62, 0.55 + 0.010 * (year - 2025)),
      technology_trisk == "GasCap" & scenario == "VN_NZE_STRESS" ~ pmax(0.42, 0.55 - 0.020 * (year - 2025)),
      technology_trisk == "HydroCap" ~ 0.45,
      technology_trisk == "RenewablesCap" & scenario == "VN_PDP8_BASELINE" ~ pmin(0.35, 0.30 + 0.006 * (year - 2025)),
      technology_trisk == "RenewablesCap" & scenario == "VN_NZE_STRESS" ~ pmin(0.38, 0.30 + 0.010 * (year - 2025)),
      TRUE ~ capacity_factor_demo
    ),
    country_iso2_list = NA_character_,
    scenario_provider = "synthetic_vietnam_demo"
  ) %>%
  transmute(
    scenario = scenario,
    scenario_type = scenario_type,
    scenario_geography = scenario_geography,
    sector = sector_trisk,
    technology = technology_trisk,
    scenario_year = scenario_year,
    price_unit = "USD/MWh-equivalent",
    scenario_price = round(scenario_price, 4),
    pathway_unit = production_unit,
    scenario_pathway = round(scenario_pathway, 4),
    technology_type = technology_type,
    scenario_capacity_factor = round(scenario_capacity_factor, 4),
    country_iso2_list = country_iso2_list,
    scenario_provider = scenario_provider
  )

carbon_price <- tibble(
  year = 2025:2030,
  model = "synthetic_vietnam_demo",
  scenario = "increasing_carbon_tax_50",
  scenario_geography = "Vietnam",
  variable = "Price|Carbon",
  unit = "USD/t CO2",
  carbon_tax = c(0, 0, 0, 50, 52, 54.08)
)

financial_features <- company_archetypes %>%
  select(company_id, pd, net_profit_margin, debt_equity_ratio, volatility)

write_csv(financial_features, file.path(data_dir, "vietnam_trisk_financial_features.csv"))
write_csv(power_assets, file.path(data_dir, "vietnam_trisk_assets_power.csv"))
write_csv(power_scenarios, file.path(data_dir, "vietnam_trisk_scenarios_power.csv"))
write_csv(carbon_price, file.path(data_dir, "vietnam_trisk_ngfs_carbon_price.csv"))
write_csv(company_mapping, file.path(data_dir, "vietnam_trisk_company_mapping.csv"))

write_csv(power_assets, file.path(trisk_input_dir, "assets.csv"))
write_csv(power_scenarios, file.path(trisk_input_dir, "scenarios.csv"))
write_csv(financial_features, file.path(trisk_input_dir, "financial_features.csv"))
write_csv(carbon_price, file.path(trisk_input_dir, "ngfs_carbon_price.csv"))

cat(sprintf("Prepared %d power asset rows across %d companies.\n", nrow(power_assets), n_distinct(power_assets$company_id)))
cat(sprintf("Prepared %d scenario rows across scenarios: %s\n",
            nrow(power_scenarios),
            paste(unique(power_scenarios$scenario), collapse = ", ")))
cat(sprintf("Prepared %d financial feature rows.\n", nrow(financial_features)))
cat(sprintf("Prepared %d carbon price rows.\n", nrow(carbon_price)))
cat(sprintf("TRISK input package written to: %s\n", trisk_input_dir))
