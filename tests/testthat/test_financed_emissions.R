library(testthat)

root <- project_root()
source(file.path(root, "R", "financed_emissions.R"))

# --- attribution_factor -------------------------------------------------------

test_that("attribution_factor computes a simple ratio", {
  expect_equal(attribution_factor(500e9, 2000e9), 0.25)
})

test_that("attribution_factor clamps a ratio above 1 rather than exceeding it", {
  expect_equal(attribution_factor(3000e9, 2000e9), 1)
})

test_that("attribution_factor is NA when capital is zero or either input is NA", {
  expect_true(is.na(attribution_factor(500e9, 0)))
  expect_equal(attribution_factor(c(500e9, NA), c(2000e9, 2000e9)), c(0.25, NA_real_))
})

# --- borrower_emissions_power / borrower_emissions_intensity ------------------

test_that("borrower_emissions_power multiplies capacity x capacity factor x hours x emission factor", {
  # 1000 MW * 0.6 * 8760 h = 5,256,000 MWh; x 0.9 tCO2/MWh = 4,730,400 tCO2e
  expect_equal(borrower_emissions_power(1000, 0.6, 0.9), 4730400)
})

test_that("borrower_emissions_intensity multiplies production x emission factor", {
  expect_equal(borrower_emissions_intensity(2e6, 0.85), 1700000)
})

# --- pcaf_data_quality_score ---------------------------------------------------

test_that("pcaf_data_quality_score follows the documented rule order", {
  expect_equal(pcaf_data_quality_score("reported", "borrower", "reported"), 2L)
  expect_equal(pcaf_data_quality_score("reported", "technology", "reported"), 3L)
  expect_equal(pcaf_data_quality_score("derived", "technology", "reported"), 4L)
  expect_equal(pcaf_data_quality_score("derived", "technology", "sector_median"), 5L)
  # sector_median capital wins regardless of the other two inputs
  expect_equal(pcaf_data_quality_score("reported", "borrower", "sector_median"), 5L)
})

# --- financed_emissions: integration over a small fixture ---------------------

.small_abcd <- function() {
  data.frame(
    company_id = c("C1", "C1", "C2", "C3"),
    name_company = c("Power Co", "Power Co", "Cement Co", "Auto Co"),
    sector = c("power", "power", "cement", "automotive"),
    technology = c("coalcap", "renewablescap", "integrated", "electric"),
    production = c(1000, 200, 2e6, 50000),
    production_unit = c("MW", "MW", "tonnes", "units"),
    year = c(2025L, 2025L, 2025L, 2025L),
    emission_factor = c(NA, NA, 0.85, NA),
    stringsAsFactors = FALSE
  )
}
.small_capital <- function() {
  data.frame(
    company_id = c("C1", "C2", "C3"),
    name_company = c("Power Co", "Cement Co", "Auto Co"),
    sector = c("power", "cement", "automotive"),
    borrower_capital_vnd = c(2000e9, 1000e9, 500e9),
    borrower_capital_source = c("reported", "reported", "reported"),
    stringsAsFactors = FALSE
  )
}
.small_exposure <- function() {
  data.frame(
    name_company = c("Power Co", "Cement Co", "Auto Co"),
    outstanding_vnd = c(500e9, 200e9, 100e9),
    stringsAsFactors = FALSE
  )
}
.small_ef <- function() {
  data.frame(
    sector = c("power", "power"), technology = c("coalcap", "renewablescap"),
    emission_factor = c(0.9, 0.03), unit = "tCO2/MWh", source = "test", data_quality_score = 4L,
    stringsAsFactors = FALSE
  )
}
.small_cf <- function() {
  data.frame(
    sector = c("power", "power"), technology = c("coalcap", "renewablescap"),
    capacity_factor = c(0.6, 0.25), source = "test",
    stringsAsFactors = FALSE
  )
}

test_that("financed_emissions excludes automotive with a stated reason and NA figures", {
  fe <- financed_emissions(.small_abcd(), .small_capital(), .small_exposure(), .small_ef(), .small_cf())
  auto_row <- fe[fe$name_abcd == "Auto Co", ]
  expect_equal(auto_row$exclusion_reason, "scope_3_dominant_sector_out_of_scope")
  expect_true(is.na(auto_row$financed_emissions_tco2e))
  expect_true(is.na(auto_row$data_quality_score))
})

test_that("financed_emissions computes power emissions across multiple technology rows for one company", {
  fe <- financed_emissions(.small_abcd(), .small_capital(), .small_exposure(), .small_ef(), .small_cf())
  power_row <- fe[fe$name_abcd == "Power Co", ]
  # coal: 1000*0.6*8760*0.9 = 4,730,400 ; renewables: 200*0.25*8760*0.03 = 13,140
  expected_borrower_emissions <- 4730400 + 13140
  expect_equal(power_row$borrower_emissions_tco2e, expected_borrower_emissions)
  expect_equal(power_row$attribution_factor, 0.25)
  expect_equal(power_row$financed_emissions_tco2e, expected_borrower_emissions * 0.25)
  expect_true(is.na(power_row$exclusion_reason))
})

test_that("financed_emissions computes cement emissions directly from ABCD's own emission_factor", {
  fe <- financed_emissions(.small_abcd(), .small_capital(), .small_exposure(), .small_ef(), .small_cf())
  cement_row <- fe[fe$name_abcd == "Cement Co", ]
  expect_equal(cement_row$borrower_emissions_tco2e, 2e6 * 0.85)
  expect_equal(cement_row$data_quality_score, 2L)
})

# --- data_quality_summary -------------------------------------------------------

test_that("data_quality_summary's share_of_total sums to 1 over scored rows", {
  fe <- financed_emissions(.small_abcd(), .small_capital(), .small_exposure(), .small_ef(), .small_cf())
  summary_df <- data_quality_summary(fe)
  expect_equal(sum(summary_df$share_of_total), 1, tolerance = 1e-9)
  expect_true(all(summary_df$n_borrowers >= 1))
})

# --- carbon_cost_exposure -------------------------------------------------------

test_that("carbon_cost_exposure converts financed emissions to whole VND at the configured FX rate", {
  fe <- data.frame(
    name_abcd = "Power Co", sector = "power",
    financed_emissions_tco2e = 1000, stringsAsFactors = FALSE
  )
  carbon_price <- data.frame(year = c(2025L, 2026L), carbon_price_usd_per_tco2 = c(50, 55))

  out <- carbon_cost_exposure(fe, carbon_price, 26300)
  row_2025 <- out[out$year == 2025, ]
  expect_equal(row_2025$carbon_cost_vnd, 1000 * 50 * 26300)
})

test_that("carbon_cost_exposure is NA throughout when no FX rate is configured", {
  fe <- data.frame(
    name_abcd = "Power Co", sector = "power",
    financed_emissions_tco2e = 1000, stringsAsFactors = FALSE
  )
  carbon_price <- data.frame(year = 2025L, carbon_price_usd_per_tco2 = 50)

  out <- carbon_cost_exposure(fe, carbon_price, numeric(0))
  expect_true(all(is.na(out$carbon_cost_vnd)))
})

# --- data_source provenance (Wave 4 PHASE-03) ---------------------------------
# R/financed_emissions.R hardcoded data_source = "mcb-demo", so ANY engagement's
# generated inventory was stamped with the demo bank's slug regardless of whose
# loanbook it described.

.fe_min_inputs <- function() {
  list(
    abcd = data.frame(
      company_id = "C1", sector = "cement", technology = "integrated",
      year = 2025L, production = 100, emission_factor = 0.8, stringsAsFactors = FALSE
    ),
    capital = data.frame(
      company_id = "C1", name_company = "Acme", sector = "cement",
      borrower_capital_vnd = 1e12, borrower_capital_source = "reported",
      stringsAsFactors = FALSE
    ),
    loanbook = data.frame(name_company = "Acme", outstanding_vnd = 1e11, stringsAsFactors = FALSE),
    ef = data.frame(technology = character(0), emission_factor = numeric(0)),
    cf = data.frame(technology = character(0), capacity_factor = numeric(0))
  )
}

test_that("financed_emissions stamps the caller's data_source on every row", {
  i <- .fe_min_inputs()
  out <- financed_emissions(i$abcd, i$capital, i$loanbook, i$ef, i$cf,
                            data_source = "sdb-rehearsal")
  expect_equal(unique(out$data_source), "sdb-rehearsal")
})

test_that("financed_emissions defaults data_source to NA, never a bank slug", {
  i <- .fe_min_inputs()
  out <- financed_emissions(i$abcd, i$capital, i$loanbook, i$ef, i$cf)
  expect_true(all(is.na(out$data_source)))
  expect_false(any(out$data_source %in% "mcb-demo"))
})
