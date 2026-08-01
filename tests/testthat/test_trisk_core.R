library(testthat)

root <- project_root()
source(file.path(root, "R", "engagement_config.R"))
source(file.path(root, "R", "sector_registry.R"))
source(file.path(root, "R", "format_money.R"))
source(file.path(root, "R", "severity_scoring.R"))
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
  # Wave 1 PHASE-04 (C7): each NGFS_* family now maps to its own carbon
  # price scenario name, so all three appear across the grid.
  expect_equal(
    sort(unique(grid$carbon_price_model)),
    sort(c(
      "increasing_carbon_tax_50",
      "increasing_carbon_tax_50_below2c",
      "increasing_carbon_tax_50_delayed"
    ))
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

# --- validate_abcd_schema() (Wave 1 PHASE-03, C6) -----------------------------

.valid_abcd_row <- function(overrides = list()) {
  row <- list(
    company_id = "VN_ABCD_001",
    name_company = "Test Co",
    lei = NA_character_,
    sector = "power",
    technology = "coalcap",
    production_unit = "MW",
    year = 2025L,
    production = 100,
    emission_factor = NA_real_,
    plant_location = "VN",
    is_ultimate_owner = TRUE,
    emission_factor_unit = NA_character_,
    data_source = "synthetic_demo",
    as_of_year = 2025L
  )
  row[names(overrides)] <- overrides
  as.data.frame(row, stringsAsFactors = FALSE)
}

test_that("validate_abcd_schema passes on the regenerated data/vietnam_abcd.csv", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))
  skip_if_not(file.exists("data/vietnam_abcd.csv"), "data/vietnam_abcd.csv not generated")

  abcd <- readr::read_csv("data/vietnam_abcd.csv", show_col_types = FALSE)
  expect_true(isTRUE(validate_abcd_schema(abcd)))
})

test_that("validate_abcd_schema reports every missing required column", {
  err <- tryCatch(
    validate_abcd_schema(data.frame(company_id = "X")),
    error = function(e) e
  )
  expect_true(inherits(err, "error"))
  expect_true(grepl("name_company", conditionMessage(err)))
  expect_true(grepl("as_of_year", conditionMessage(err)))
})

test_that("validate_abcd_schema rejects negative production", {
  df <- .valid_abcd_row(list(production = -5))
  expect_error(validate_abcd_schema(df), "production")
})

test_that("validate_abcd_schema rejects a non-integer year", {
  df <- .valid_abcd_row(list(year = "not-a-year"))
  expect_error(validate_abcd_schema(df), "year")
})

test_that("validate_abcd_schema rejects an empty data_source", {
  df <- .valid_abcd_row(list(data_source = ""))
  expect_error(validate_abcd_schema(df), "data_source")
})

test_that("validate_abcd_schema permits NA emission_factor and emission_factor_unit", {
  df <- .valid_abcd_row(list(emission_factor = NA_real_, emission_factor_unit = NA_character_))
  expect_true(isTRUE(validate_abcd_schema(df)))
})

# --- grid_input_fingerprint() / grid_cache_is_valid() (Wave 1 PHASE-04, C1) ---

.write_grid_input_fixture <- function(dir, assets_content = "a,b\n1,2") {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  writeLines(assets_content, file.path(dir, "assets.csv"))
  writeLines("x,y\n3,4", file.path(dir, "financial_features.csv"))
  writeLines("p,q\n5,6", file.path(dir, "ngfs_carbon_price.csv"))
  writeLines("m,n\n7,8", file.path(dir, "scenarios.csv"))
  dir
}

test_that("grid_input_fingerprint returns a stable 32-char hex digest", {
  fixture_dir <- .write_grid_input_fixture(file.path(tempdir(), paste0("gif_", as.integer(Sys.time()))))
  on.exit(unlink(fixture_dir, recursive = TRUE, force = TRUE))

  fp1 <- grid_input_fingerprint(fixture_dir)
  fp2 <- grid_input_fingerprint(fixture_dir)
  expect_equal(nchar(fp1), 32)
  expect_true(grepl("^[a-f0-9]{32}$", fp1))
  expect_equal(fp1, fp2)
})

test_that("grid_input_fingerprint changes when an input file's content changes", {
  fixture_dir <- .write_grid_input_fixture(file.path(tempdir(), paste0("gif2_", as.integer(Sys.time()))))
  on.exit(unlink(fixture_dir, recursive = TRUE, force = TRUE))

  fp_before <- grid_input_fingerprint(fixture_dir)
  writeLines("a,b\n9,9", file.path(fixture_dir, "assets.csv"))
  fp_after <- grid_input_fingerprint(fixture_dir)

  expect_false(identical(fp_before, fp_after))
})

test_that("grid_input_fingerprint returns NA when an input file is missing", {
  fixture_dir <- file.path(tempdir(), paste0("gif3_", as.integer(Sys.time())))
  dir.create(fixture_dir, recursive = TRUE, showWarnings = FALSE)
  writeLines("a,b\n1,2", file.path(fixture_dir, "assets.csv"))
  writeLines("x,y\n3,4", file.path(fixture_dir, "financial_features.csv"))
  writeLines("m,n\n7,8", file.path(fixture_dir, "scenarios.csv"))
  on.exit(unlink(fixture_dir, recursive = TRUE, force = TRUE))
  # ngfs_carbon_price.csv intentionally absent

  expect_true(is.na(grid_input_fingerprint(fixture_dir)))
})

test_that("grid_cache_is_valid reports missing grid_meta.json", {
  grid_dir <- file.path(tempdir(), paste0("gcv1_", as.integer(Sys.time())))
  dir.create(grid_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(grid_dir, recursive = TRUE, force = TRUE))

  result <- grid_cache_is_valid(grid_dir, file.path(grid_dir, "input"), "v1", "2.6.1")
  expect_false(result$valid)
  expect_equal(result$reason, "no grid_meta.json")
})

test_that("grid_cache_is_valid passes when fingerprint, model, and contract all match", {
  grid_dir <- file.path(tempdir(), paste0("gcv2_", as.integer(Sys.time())))
  input_dir <- .write_grid_input_fixture(file.path(grid_dir, "input"))
  on.exit(unlink(grid_dir, recursive = TRUE, force = TRUE))

  fp <- grid_input_fingerprint(input_dir)
  jsonlite::write_json(
    list(input_fingerprint = fp, trisk_model_version = "2.6.1", grid_contract_version = "v1"),
    file.path(grid_dir, "grid_meta.json"),
    auto_unbox = TRUE
  )

  result <- grid_cache_is_valid(grid_dir, input_dir, "v1", "2.6.1")
  expect_true(result$valid)
  expect_equal(result$reason, "ok")
})

test_that("grid_cache_is_valid fails when the grid contract version changed", {
  grid_dir <- file.path(tempdir(), paste0("gcv3_", as.integer(Sys.time())))
  input_dir <- .write_grid_input_fixture(file.path(grid_dir, "input"))
  on.exit(unlink(grid_dir, recursive = TRUE, force = TRUE))

  fp <- grid_input_fingerprint(input_dir)
  jsonlite::write_json(
    list(input_fingerprint = fp, trisk_model_version = "2.6.1", grid_contract_version = "v0"),
    file.path(grid_dir, "grid_meta.json"),
    auto_unbox = TRUE
  )

  result <- grid_cache_is_valid(grid_dir, input_dir, "v1", "2.6.1")
  expect_false(result$valid)
  expect_equal(result$reason, "grid contract version changed")
})

# --- .trisk_build_carbon_price() (Wave 1 PHASE-04, C7) ------------------------

test_that(".trisk_build_carbon_price builds 3 scenarios x 6 years per sector, base values unchanged", {
  power_price <- .trisk_build_carbon_price(.trisk_input_sector_specs$power)
  expect_equal(nrow(power_price), 18)
  expect_equal(
    sort(unique(power_price$scenario)),
    sort(c(
      "increasing_carbon_tax_50",
      "increasing_carbon_tax_50_below2c",
      "increasing_carbon_tax_50_delayed"
    ))
  )
  base_rows <- power_price[power_price$scenario == "increasing_carbon_tax_50", ]
  expect_equal(base_rows$carbon_tax[order(base_rows$year)], c(0, 0, 0, 50, 52, 54.08))
})

# --- build_scenario_input_dir() (Wave 1 PHASE-04 follow-up, C1) --------------

.write_bsid_grid_fixture <- function(dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  # assets.csv always spans the base run's original 2025-2030 window,
  # regardless of any scenario's shock_year -- this is what build_grid_input_dir()
  # copies verbatim (never extended).
  write.csv(
    data.frame(company_id = "X", production_year = 2025:2030, capacity = 1:6),
    file.path(dir, "assets.csv"), row.names = FALSE
  )
  writeLines("x,y\n3,4", file.path(dir, "financial_features.csv"))
  write.csv(
    data.frame(scenario_year = 2025:2032, val = 1:8),
    file.path(dir, "scenarios.csv"), row.names = FALSE
  )
  write.csv(
    data.frame(year = 2025:2032, carbon_tax = 1:8),
    file.path(dir, "ngfs_carbon_price.csv"), row.names = FALSE
  )
  dir
}

test_that("build_scenario_input_dir truncates to shock_year + 2 when that exceeds the base window", {
  grid_input_dir <- .write_bsid_grid_fixture(file.path(tempdir(), paste0("bsid_grid_", as.integer(Sys.time()))))
  on.exit(unlink(grid_input_dir, recursive = TRUE, force = TRUE))

  scratch_dir <- file.path(tempdir(), paste0("bsid_scratch_", as.integer(Sys.time())))
  on.exit(unlink(scratch_dir, recursive = TRUE, force = TRUE), add = TRUE)

  # shock_year 2028 -> naive shock_year+2 = 2030, which equals the base
  # window ceiling anyway -- this is the case that reproduces the base run.
  result_dir <- build_scenario_input_dir(grid_input_dir, shock_year = 2028L, scratch_dir = scratch_dir)
  expect_equal(result_dir, scratch_dir)

  scenarios_out <- read.csv(file.path(scratch_dir, "scenarios.csv"))
  carbon_out <- read.csv(file.path(scratch_dir, "ngfs_carbon_price.csv"))
  expect_equal(max(scenarios_out$scenario_year), 2030L)
  expect_equal(max(carbon_out$year), 2030L)
  expect_true(file.exists(file.path(scratch_dir, "assets.csv")))
  expect_true(file.exists(file.path(scratch_dir, "financial_features.csv")))
})

test_that("build_scenario_input_dir uses a wider horizon for a later shock_year", {
  grid_input_dir <- .write_bsid_grid_fixture(file.path(tempdir(), paste0("bsid_grid2_", as.integer(Sys.time()))))
  on.exit(unlink(grid_input_dir, recursive = TRUE, force = TRUE))

  scratch_dir <- file.path(tempdir(), paste0("bsid_scratch2_", as.integer(Sys.time())))
  on.exit(unlink(scratch_dir, recursive = TRUE, force = TRUE), add = TRUE)

  build_scenario_input_dir(grid_input_dir, shock_year = 2030L, scratch_dir = scratch_dir)
  scenarios_out <- read.csv(file.path(scratch_dir, "scenarios.csv"))
  expect_equal(max(scenarios_out$scenario_year), 2032L)
})

test_that("build_scenario_input_dir never truncates below the base window (regression: early shock_year crash)", {
  # Wave 1 PHASE-04 follow-up: naively truncating to shock_year + 2 for an
  # early shock_year (e.g. 2026 -> 2028) truncated scenarios/carbon_price
  # BELOW assets.csv's own 2025-2030 range, which crashed
  # trisk.model:::extend_to_full_analysis_timeframe() on the very first grid
  # scenario during a real regeneration. The horizon must never go below
  # assets.csv's own max year.
  grid_input_dir <- .write_bsid_grid_fixture(file.path(tempdir(), paste0("bsid_grid3_", as.integer(Sys.time()))))
  on.exit(unlink(grid_input_dir, recursive = TRUE, force = TRUE))

  scratch_dir <- file.path(tempdir(), paste0("bsid_scratch3_", as.integer(Sys.time())))
  on.exit(unlink(scratch_dir, recursive = TRUE, force = TRUE), add = TRUE)

  build_scenario_input_dir(grid_input_dir, shock_year = 2026L, scratch_dir = scratch_dir)
  scenarios_out <- read.csv(file.path(scratch_dir, "scenarios.csv"))
  carbon_out <- read.csv(file.path(scratch_dir, "ngfs_carbon_price.csv"))
  # Naive shock_year + 2 would be 2028; the floor keeps it at 2030.
  expect_equal(max(scenarios_out$scenario_year), 2030L)
  expect_equal(max(carbon_out$year), 2030L)
})
