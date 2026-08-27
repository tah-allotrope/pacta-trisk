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

test_that("mcb-demo engagement_config.json matches the built-in defaults except deliberate Wave 3 additions", {
  # Historically this asserted full equality with load_engagement_config(NULL)
  # -- mcb-demo's config was a pure reproduction of the hardcoded defaults.
  # Wave 3 deliberately added two fields the bare defaults do not set:
  # inputs.fx_rate_usd_vnd (PHASE-05, so carbon_cost_exposure() can compute
  # for the public demo instead of returning NA throughout) and
  # inputs.scenario_vintage (PHASE-03, always set explicitly once the
  # vintage mechanism exists, even though it happens to equal the default
  # value "pdp8-2023"). Compare everything else for equality; assert the
  # two deliberate additions explicitly instead of excluding them silently.
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  cfg_default <- load_engagement_config(NULL)
  cfg_file <- load_engagement_config("engagements/mcb-demo/engagement_config.json")

  expect_equal(cfg_file$bank_name, cfg_default$bank_name)
  expect_equal(cfg_file$bank_slug, cfg_default$bank_slug)

  # Wave 3 0.5.0 refreeze: mcb-demo switched to pdp8-2025-adjusted vintage
  # (and its region_isos to the vintage-scoped file), while the bare default
  # stays on pdp8-2023. Those three paths plus scenario_vintage and fx_rate
  # are the deliberate, documented differences.
  inputs_file_minus_additions <- cfg_file$inputs
  inputs_file_minus_additions$fx_rate_usd_vnd <- NULL
  inputs_file_minus_additions$scenario_vintage <- NULL
  inputs_file_minus_additions$scenario_ms_csv <- NULL
  inputs_file_minus_additions$scenario_co2_csv <- NULL
  inputs_file_minus_additions$region_isos_csv <- NULL
  inputs_default_minus_additions <- cfg_default$inputs
  inputs_default_minus_additions$fx_rate_usd_vnd <- NULL
  inputs_default_minus_additions$scenario_vintage <- NULL
  inputs_default_minus_additions$scenario_ms_csv <- NULL
  inputs_default_minus_additions$scenario_co2_csv <- NULL
  inputs_default_minus_additions$region_isos_csv <- NULL
  expect_equal(inputs_file_minus_additions, inputs_default_minus_additions)
  expect_equal(cfg_file$inputs$fx_rate_usd_vnd, 26300)
  expect_equal(cfg_file$inputs$scenario_vintage, "pdp8-2025-adjusted")
  expect_equal(cfg_file$inputs$scenario_ms_csv, "data/scenarios/pdp8-2025-adjusted/vietnam_scenario_ms.csv")
  expect_equal(cfg_file$inputs$scenario_co2_csv, "data/scenarios/pdp8-2025-adjusted/vietnam_scenario_co2.csv")
  expect_equal(cfg_file$inputs$region_isos_csv, "data/scenarios/pdp8-2025-adjusted/vietnam_region_isos.csv")

  expect_equal(cfg_file$trisk_sectors, cfg_default$trisk_sectors)
  expect_equal(cfg_file$run_grid, cfg_default$run_grid)
  expect_equal(cfg_file$anonymize, cfg_default$anonymize)
  expect_equal(cfg_file$paths, cfg_default$paths)
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

test_that("fx_rate_usd_vnd is accepted as a number and is not treated as a missing input file", {
  # Wave 2 PHASE-05 (ASM-006): a number under `inputs` must be skipped by the
  # "every input must exist" loop or every config that sets a rate fails with
  # a confusing "input file(s) not found: 26300".
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp <- tempfile(fileext = ".json")
  writeLines(
    '{"bank_name":"T","bank_slug":"t","inputs":{"fx_rate_usd_vnd":26300}}',
    tmp
  )
  on.exit(unlink(tmp), add = TRUE)

  cfg <- load_engagement_config(tmp)
  expect_equal(cfg$inputs$fx_rate_usd_vnd, 26300)
})

test_that("a non-positive fx_rate_usd_vnd fails validation naming the key", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp <- tempfile(fileext = ".json")
  writeLines(
    '{"bank_name":"T","bank_slug":"t","inputs":{"fx_rate_usd_vnd":-5}}',
    tmp
  )
  on.exit(unlink(tmp), add = TRUE)

  expect_error(load_engagement_config(tmp), "fx_rate_usd_vnd")
})

test_that("fx_rate_usd_vnd survives the jsonlite toJSON/read_json round-trip in every empty shape", {
  # Wave 2 PHASE-05 Gotcha: NULL serializes to {}, character(0) to [] and both
  # come back as an empty list() -- a validation that checks is.null() alone
  # would fail on the *second* generation of a config. None of the empty shapes
  # may error.
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  for (empty_shape in list(
    NULL,
    character(0),
    list()
  )) {
    cfg <- .default_engagement_config()
    cfg$bank_name <- "T"
    cfg$bank_slug <- "t"
    cfg$inputs$fx_rate_usd_vnd <- empty_shape
    tmp <- tempfile(fileext = ".json")
    writeLines(jsonlite::toJSON(cfg, auto_unbox = TRUE), tmp)
    roundtripped <- jsonlite::read_json(tmp, simplifyVector = TRUE)
    on.exit(unlink(tmp), add = TRUE)

    expect_silent(.validate_engagement_config(roundtripped))
  }
})

test_that("sdb-rehearsal config carries an fx rate for its USD fixture rows", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  cfg <- load_engagement_config("engagements/sdb-rehearsal/engagement_config.json")
  expect_equal(cfg$inputs$fx_rate_usd_vnd, 26300)
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

# --- Wave 3 PHASE-02: schema_version and strict unknown-key rejection ---------

test_that("default config (no path) has schema_version 1", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  cfg <- load_engagement_config(NULL)
  expect_equal(cfg$schema_version, 1L)
})

test_that("a config with a different schema_version is rejected", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp <- tempfile(fileext = ".json")
  writeLines('{"schema_version":2,"bank_name":"X Bank","bank_slug":"x-bank"}', tmp)
  on.exit(unlink(tmp), add = TRUE)

  expect_error(load_engagement_config(tmp), "schema_version")
})

test_that("an unknown top-level config key is rejected, naming the key and accepted siblings", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp <- tempfile(fileext = ".json")
  writeLines('{"bank_name":"X Bank","bank_slug":"x-bank","trisk_sector":["power"]}', tmp)
  on.exit(unlink(tmp), add = TRUE)

  err <- tryCatch(load_engagement_config(tmp), error = function(e) conditionMessage(e))
  expect_true(grepl("unknown config key 'trisk_sector'", err, fixed = TRUE))
  expect_true(grepl("trisk_sectors", err, fixed = TRUE))
})

test_that("an unknown nested config key (inside inputs) is rejected with a dotted path", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp <- tempfile(fileext = ".json")
  writeLines('{"bank_name":"X Bank","bank_slug":"x-bank","inputs":{"loanbok_csv":"data/vietnam_loanbook.csv"}}', tmp)
  on.exit(unlink(tmp), add = TRUE)

  err <- tryCatch(load_engagement_config(tmp), error = function(e) conditionMessage(e))
  expect_true(grepl("unknown config key 'inputs.loanbok_csv'", err, fixed = TRUE))
})

test_that("engagements/mcb-demo/engagement_config.json and sdb-rehearsal's still load cleanly", {
  mcb_path <- file.path(root, "engagements", "mcb-demo", "engagement_config.json")
  sdb_path <- file.path(root, "engagements", "sdb-rehearsal", "engagement_config.json")
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  expect_silent(load_engagement_config(mcb_path))
  expect_silent(load_engagement_config(sdb_path))
})

test_that("steps and published_reports default to empty and accept a character vector", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  cfg <- load_engagement_config(NULL)
  expect_equal(cfg$steps, character(0))
  expect_equal(cfg$published_reports, character(0))

  tmp <- tempfile(fileext = ".json")
  writeLines(
    '{"bank_name":"X Bank","bank_slug":"x-bank","steps":["pacta_vietnam_scenario"],"published_reports":["Foo.html"]}',
    tmp
  )
  on.exit(unlink(tmp), add = TRUE)
  cfg2 <- load_engagement_config(tmp)
  expect_equal(cfg2$steps, "pacta_vietnam_scenario")
  expect_equal(cfg2$published_reports, "Foo.html")
})
