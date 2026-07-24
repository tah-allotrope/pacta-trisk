library(testthat)

root <- project_root()
source(file.path(root, "R", "engagement_config.R"))
source(file.path(root, "R", "sector_registry.R"))

test_that("default config (no path) reproduces MCB defaults", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  cfg <- load_engagement_config(NULL)

  expect_equal(cfg$inputs$loanbook_csv, "data/vietnam_loanbook.csv")
  expect_true(cfg$run_grid)
  expect_equal(cfg$trisk_sectors, c("power", "cement", "steel"))
  expect_equal(cfg$bank_name, "Mekong Commercial Bank")
  expect_equal(cfg$bank_slug, "mcb-demo")
  expect_equal(cfg$paths$prioritization_output_dir, "synthesis_output/prioritization")
})

test_that("mcb-demo engagement_config.json is identical to the built-in defaults", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  cfg_default <- load_engagement_config(NULL)
  cfg_file <- load_engagement_config("engagements/mcb-demo/engagement_config.json")

  expect_equal(cfg_file$bank_name, cfg_default$bank_name)
  expect_equal(cfg_file$bank_slug, cfg_default$bank_slug)
  expect_equal(cfg_file$inputs, cfg_default$inputs)
  expect_equal(cfg_file$trisk_sectors, cfg_default$trisk_sectors)
  expect_equal(cfg_file$run_grid, cfg_default$run_grid)
  expect_equal(cfg_file$paths, cfg_default$paths)
  expect_equal(cfg_file$anonymize, cfg_default$anonymize)
})

test_that("partial override config falls back to defaults for missing keys", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp <- tempfile(fileext = ".json")
  writeLines(
    '{"bank_name":"X Bank","bank_slug":"x-bank","paths":{"snapshot_dir":"engagements/x-bank/snapshot"}}',
    tmp
  )
  on.exit(unlink(tmp), add = TRUE)

  cfg <- load_engagement_config(tmp)

  expect_equal(cfg$bank_name, "X Bank")
  expect_equal(cfg$paths$snapshot_dir, "engagements/x-bank/snapshot")
  expect_equal(cfg$inputs$abcd_csv, "data/vietnam_abcd.csv")
})

test_that("missing input file fails validation with the offending path named", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp <- tempfile(fileext = ".json")
  writeLines(
    '{"bank_name":"X Bank","bank_slug":"x-bank","inputs":{"loanbook_csv":"does/not/exist.csv"}}',
    tmp
  )
  on.exit(unlink(tmp), add = TRUE)

  expect_error(load_engagement_config(tmp), "does/not/exist.csv")
})

test_that("invalid bank_slug fails validation", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp <- tempfile(fileext = ".json")
  writeLines('{"bank_name":"X Bank","bank_slug":"X Bank!"}', tmp)
  on.exit(unlink(tmp), add = TRUE)

  expect_error(load_engagement_config(tmp))
})

test_that("public_snapshot_allowed defaults to FALSE and mcb-demo opts in explicitly", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  expect_false(load_engagement_config(NULL)$public_snapshot_allowed)
  expect_true(load_engagement_config("engagements/mcb-demo/engagement_config.json")$public_snapshot_allowed)
})

test_that("sdb-rehearsal config carries its own raw_loanbook_csv for self-describing reruns", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  cfg <- load_engagement_config("engagements/sdb-rehearsal/engagement_config.json")
  expect_equal(cfg$inputs$raw_loanbook_csv, "data/fixtures/unseen_bank_loanbook.csv")
})

test_that("a non-existent raw_loanbook_csv fails validation with the offending path named", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp <- tempfile(fileext = ".json")
  writeLines(
    '{"bank_name":"T","bank_slug":"t","inputs":{"raw_loanbook_csv":"does/not/exist.csv"}}',
    tmp
  )
  on.exit(unlink(tmp), add = TRUE)

  expect_error(load_engagement_config(tmp), "does/not/exist.csv")
})

test_that("a non-logical public_snapshot_allowed fails validation", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp <- tempfile(fileext = ".json")
  writeLines('{"public_snapshot_allowed":"yes"}', tmp)
  on.exit(unlink(tmp), add = TRUE)

  expect_error(load_engagement_config(tmp), "public_snapshot_allowed")
})

test_that("get_config_arg extracts the --config value or returns NULL", {
  expect_equal(get_config_arg(c("--config", "a.json")), "a.json")
  expect_null(get_config_arg(character(0)))
  expect_null(get_config_arg(c("--other", "value")))
})

test_that("sector_registry has one row per supported sector with expected values", {
  registry <- sector_registry()

  expect_equal(nrow(registry), 3)
  expect_equal(
    registry$carbon_price_model,
    c("increasing_carbon_tax_50", "cement_intensity_transition", "steel_intensity_transition")
  )
  expect_equal(registry$sector, c("power", "cement", "steel"))
})

test_that("trisk_base_params returns the expected literals", {
  params <- trisk_base_params()

  expect_equal(params$shock_year, 2028)
  expect_equal(params$discount_rate, 0.08)
  expect_equal(params$risk_free_rate, 0.03)
  expect_equal(params$market_passthrough, 0.25)
})

test_that("sector_meta preserves the original alignment_mode equality-check values", {
  power_meta <- sector_meta("power")
  cement_meta <- sector_meta("cement")

  expect_equal(power_meta$alignment_mode, "company_ms")
  expect_equal(cement_meta$alignment_mode, "sector_sda")
  expect_equal(power_meta$title, "Power")
})
