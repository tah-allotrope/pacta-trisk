library(testthat)

root <- project_root()
source(file.path(root, "R", "sector_registry.R"))
source(file.path(root, "R", "target_setting.R"))

# Wave 4 PHASE-04. R/target_setting.R implements the S6 sector target registry
# from Wave 3 PHASE-06 -- the interim decarbonization targets a bank would put
# to its board -- and shipped with no test file at all, while its sibling
# specifications (financed emissions S2-S4, SLL readiness S5) each got one.

# --- sda_convergence_target() -------------------------------------------------

.scen <- function(years, values) {
  data.frame(year = years, emission_factor_value = values, stringsAsFactors = FALSE)
}

test_that("sda_convergence_target scales the baseline by the scenario's own ratio", {
  # Scenario halves between 2025 and 2030, so a portfolio at 0.80 converges to
  # 0.40 -- anchored on its own baseline, not on the scenario's absolute level.
  expect_equal(
    sda_convergence_target(0.80, 2025L, .scen(c(2025L, 2030L), c(1.00, 0.50)), 2030L),
    0.40
  )
})

test_that("sda_convergence_target returns NA for an NA baseline", {
  expect_true(is.na(
    sda_convergence_target(NA_real_, 2025L, .scen(c(2025L, 2030L), c(1.00, 0.50)), 2030L)
  ))
})

test_that("sda_convergence_target returns NA (never errors) for a zero-length baseline", {
  # Guarded deliberately: `is.na(numeric(0))` is logical(0), which is exactly
  # the shape that makes a naive `||` guard error out.
  expect_true(is.na(
    sda_convergence_target(numeric(0), 2025L, .scen(c(2025L, 2030L), c(1.00, 0.50)), 2030L)
  ))
})

test_that("sda_convergence_target returns NA when either scenario anchor is missing", {
  scen <- .scen(c(2025L, 2035L), c(1.00, 0.50))
  expect_true(is.na(sda_convergence_target(0.80, 2025L, scen, 2030L)))   # no target year
  expect_true(is.na(sda_convergence_target(0.80, 2020L, scen, 2035L)))   # no baseline year
})

test_that("sda_convergence_target guards against a zero scenario baseline", {
  expect_true(is.na(
    sda_convergence_target(0.80, 2025L, .scen(c(2025L, 2030L), c(0, 0.50)), 2030L)
  ))
})

test_that("sda_convergence_target rejects a scenario frame missing required columns", {
  expect_error(
    sda_convergence_target(0.80, 2025L, data.frame(year = 2025L, value = 1), 2030L),
    "year and emission_factor_value"
  )
})

# --- build_target_registry() --------------------------------------------------

.registry_inputs <- function() {
  sectors <- c("cement", "steel")
  list(
    sda_portfolio = data.frame(
      sector = rep(sectors, each = 1),
      year = 2025L,
      emission_factor_value = c(0.80, 1.60),
      emission_factor_metric = "projected",
      stringsAsFactors = FALSE
    ),
    ms_portfolio = data.frame(
      sector = "power", technology = "renewablescap", year = 2025L,
      technology_share = 0.25, metric = "projected", stringsAsFactors = FALSE
    ),
    scenario_co2 = data.frame(
      sector = rep(sectors, each = 2),
      year = rep(c(2025L, 2030L), times = 2),
      emission_factor_value = c(1.00, 0.50, 2.00, 1.00),
      scenario = "pdp8_ndc",
      stringsAsFactors = FALSE
    ),
    scenario_ms = data.frame(
      sector = "power", technology = "renewablescap",
      year = c(2025L, 2030L), smsp = c(0.25, 0.32),
      scenario = "pdp8_ndc", stringsAsFactors = FALSE
    )
  )
}

test_that("build_target_registry returns 9 rows and the 12 S6 columns in order", {
  i <- .registry_inputs()
  out <- build_target_registry(i$sda_portfolio, i$ms_portfolio, i$scenario_co2,
                               i$scenario_ms, "pdp8-2025-adjusted")
  expect_equal(nrow(out), 9L)
  expect_equal(names(out), c(
    "sector", "metric", "unit", "baseline_year", "baseline_value",
    "target_year", "target_value", "scope", "method",
    "scenario_vintage", "status", "source_artifact"
  ))
  expect_equal(sort(unique(out$sector)), c("cement", "power", "steel"))
  expect_equal(sort(unique(out$target_year)), c(2030L, 2035L, 2050L))
  expect_equal(unique(out$scenario_vintage), "pdp8-2025-adjusted")
})

test_that("build_target_registry proposes only 2030 and leaves later horizons unset", {
  i <- .registry_inputs()
  out <- build_target_registry(i$sda_portfolio, i$ms_portfolio, i$scenario_co2,
                               i$scenario_ms, "pdp8-2025-adjusted")
  y2030 <- out[out$target_year == 2030L, ]
  later <- out[out$target_year != 2030L, ]

  expect_true(all(y2030$status == "proposed"))
  expect_true(all(later$status == "not_set"))
  expect_true(all(is.na(later$target_value)))
  # Nothing is ever "adopted" -- that needs a committee decision, not a pipeline.
  expect_false(any(out$status == "adopted"))
})

test_that("build_target_registry uses SDA convergence for cement and steel", {
  i <- .registry_inputs()
  out <- build_target_registry(i$sda_portfolio, i$ms_portfolio, i$scenario_co2,
                               i$scenario_ms, "pdp8-2025-adjusted")
  cement <- out[out$sector == "cement" & out$target_year == 2030L, ]
  steel <- out[out$sector == "steel" & out$target_year == 2030L, ]

  expect_equal(cement$method, "sda_convergence")
  expect_equal(cement$unit, "tco2_per_tonne_cement")
  expect_equal(cement$scope, "1+2")
  expect_equal(cement$target_value, 0.40)   # 0.80 * (0.50 / 1.00)

  expect_equal(steel$unit, "tco2_per_tonne_crude_steel")
  expect_equal(steel$target_value, 0.80)    # 1.60 * (1.00 / 2.00)
})

test_that("build_target_registry uses the scenario market share for power", {
  i <- .registry_inputs()
  out <- build_target_registry(i$sda_portfolio, i$ms_portfolio, i$scenario_co2,
                               i$scenario_ms, "pdp8-2025-adjusted")
  power <- out[out$sector == "power" & out$target_year == 2030L, ]

  expect_equal(power$method, "market_share")
  expect_equal(power$scope, "n/a")
  expect_equal(power$unit, "share_of_sector_capacity")
  expect_equal(power$baseline_value, 0.25)
  expect_equal(power$target_value, 0.32)
})

test_that("build_target_registry falls back to the scenario baseline when the portfolio has no power row", {
  i <- .registry_inputs()
  empty_ms <- i$ms_portfolio[0, ]
  out <- build_target_registry(i$sda_portfolio, empty_ms, i$scenario_co2,
                               i$scenario_ms, "pdp8-2025-adjusted")
  power <- out[out$sector == "power" & out$target_year == 2030L, ]
  expect_equal(power$baseline_value, 0.25)   # from scenario_ms, illustrative
})

test_that("build_target_registry returns the documented column types", {
  i <- .registry_inputs()
  out <- build_target_registry(i$sda_portfolio, i$ms_portfolio, i$scenario_co2,
                               i$scenario_ms, "pdp8-2025-adjusted")
  expect_type(out$baseline_year, "integer")
  expect_type(out$target_year, "integer")
  expect_type(out$baseline_value, "double")
  expect_type(out$target_value, "double")
})

test_that("build_target_registry covers exactly the registry's sectors", {
  # Wave 4 PHASE-03 replaced a hardcoded c("power","cement","steel") here with
  # sector_registry()$sector, so the registry is the single source of truth.
  i <- .registry_inputs()
  out <- build_target_registry(i$sda_portfolio, i$ms_portfolio, i$scenario_co2,
                               i$scenario_ms, "pdp8-2025-adjusted")
  expect_setequal(unique(out$sector), sector_registry()$sector)
})
