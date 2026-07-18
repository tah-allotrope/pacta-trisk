library(testthat)

root <- project_root()
source(file.path(root, "R", "engagement_config.R"))
source(file.path(root, "R", "sector_registry.R"))
source(file.path(root, "R", "trisk_core.R"))
source(file.path(root, "R", "prioritization_core.R"))

test_that("build_scenario_id matches the committed grid's ID format", {
  expect_equal(
    build_scenario_id(2026L, 0.06, 0.02, 0.15, "NGFS_Below2C"),
    "s2026_d0.06_rf0.02_mp0.15_cNGFS_Below2C"
  )
  expect_equal(
    build_scenario_id(2028L, 0.08, 0.03, 0.25, "NGFS_NetZero2050"),
    "s2028_d0.08_rf0.03_mp0.25_cNGFS_NetZero2050"
  )
})

test_that("build_grid_label formats levers in the documented pipe-separated order", {
  expect_equal(
    build_grid_label(2026L, 0.06, 0.02, 0.15, "NGFS_Below2C"),
    "shock 2026 | disc 0.06 | rf 0.02 | pass 0.15 | NGFS_Below2C"
  )
})

test_that("build_sector_grid produces the full 3x3x3x3x3 = 243-row grid", {
  grid <- build_sector_grid("power")
  expect_equal(nrow(grid), 243)
  expect_equal(
    sort(unique(grid$carbon_price_model)),
    "increasing_carbon_tax_50"
  )
  expect_true(all(c("scenario_id", "sector", "grid_label") %in% names(grid)))
})

test_that("extend_yearly_inputs linearly extrapolates from the last two known years", {
  df <- tibble::tibble(
    group = c("a", "a", "a"),
    year = c(2025, 2026, 2027),
    value = c(10, 20, 30)
  )

  extended <- extend_yearly_inputs(
    df,
    group_cols = "group",
    year_col = "year",
    value_cols = "value",
    target_year = 2029
  )

  expect_equal(nrow(extended), 5)
  extended <- extended[order(extended$year), ]
  expect_equal(extended$value, c(10, 20, 30, 40, 50))
})

test_that("extend_yearly_inputs applies a lower bound when extrapolating", {
  df <- tibble::tibble(
    group = c("a", "a"),
    year = c(2025, 2026),
    value = c(10, 5)
  )

  extended <- extend_yearly_inputs(
    df,
    group_cols = "group",
    year_col = "year",
    value_cols = "value",
    target_year = 2028,
    lower_bounds = list(value = 0)
  )

  extended <- extended[order(extended$year), ]
  # unbounded extrapolation would go 10, 5, 0, -5; lower_bounds clamps at 0
  expect_equal(extended$value, c(10, 5, 0, 0))
})

test_that("extend_yearly_inputs is a no-op when data already reaches target_year", {
  df <- tibble::tibble(group = "a", year = 2025:2030, value = 1:6)
  extended <- extend_yearly_inputs(
    df, group_cols = "group", year_col = "year", value_cols = "value", target_year = 2028
  )
  expect_equal(nrow(extended), 6)
})

test_that("backfill_zero_baseline fills leading zero years from the first non-zero year", {
  assets <- tibble::tibble(
    company = c("X", "X", "X"),
    year = 2025:2027,
    capacity = c(0, 0, 500)
  )

  result <- backfill_zero_baseline(assets, "capacity")

  expect_equal(result$capacity, c(500, 500, 500))
  expect_equal(result$baseline_note, c("backfilled_first_operating_year", "backfilled_first_operating_year", NA_character_))
})

test_that("backfill_zero_baseline drops an asset whose trajectory is entirely zero", {
  assets <- tibble::tibble(
    company = c("X", "X", "X"),
    year = 2025:2027,
    capacity = c(0, 0, 0)
  )

  result <- backfill_zero_baseline(assets, "capacity")

  expect_equal(nrow(result), 0)
})

test_that("backfill_zero_baseline leaves an already-nonzero trajectory unchanged", {
  assets <- tibble::tibble(
    company = c("X", "X", "X"),
    year = 2025:2027,
    capacity = c(100, 200, 300)
  )

  result <- backfill_zero_baseline(assets, "capacity")

  expect_equal(result$capacity, c(100, 200, 300))
  expect_true(all(is.na(result$baseline_note)))
})

test_that("assert_supported_sector accepts power/cement/steel and rejects others", {
  expect_silent(assert_supported_sector("power"))
  expect_silent(assert_supported_sector("cement"))
  expect_silent(assert_supported_sector("steel"))
  expect_error(assert_supported_sector("automotive"))
})

test_that("resolve_trisk_paths defaults reproduce today's MCB literals", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  paths <- resolve_trisk_paths("power")
  expect_true(endsWith(paths$input_dir, file.path("output", "trisk_inputs", "power_demo")))
  expect_true(endsWith(paths$output_root, file.path("synthesis_output", "trisk", "power_demo")))
})

test_that("resolve_trisk_paths honors custom input/output roots", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp_output <- file.path(tempdir(), "custom_trisk_output")
  paths <- resolve_trisk_paths("power", output_root = tmp_output, input_root = "engagements/x/trisk_inputs")
  expect_true(endsWith(paths$input_dir, file.path("engagements", "x", "trisk_inputs", "power_demo")))
  expect_equal(paths$output_root, tmp_output)
})

test_that("classify_band matches the documented thresholds", {
  expect_equal(classify_band(0.0), "Low")
  expect_equal(classify_band(0.29), "Low")
  expect_equal(classify_band(0.30), "Medium")
  expect_equal(classify_band(0.49), "Medium")
  expect_equal(classify_band(0.50), "High")
  expect_equal(classify_band(0.69), "High")
  expect_equal(classify_band(0.70), "Critical")
  expect_equal(classify_band(1.0), "Critical")
})
