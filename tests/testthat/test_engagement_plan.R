library(testthat)

root <- project_root()
source(file.path(root, "R", "engagement_config.R"))
source(file.path(root, "R", "step_registry.R"))
source(file.path(root, "R", "engagement_plan.R"))

# --- parse_engagement_cli() -------------------------------------------------

test_that("parse_engagement_cli parses the full flag set", {
  cli <- parse_engagement_cli(c(
    "--config", "engagements/mcb-demo/engagement_config.json",
    "--full",
    "--raw-loanbook", "data/raw.csv",
    "--top-n", "5",
    "--only-step", "pacta_vietnam_scenario",
    "--only-step", "engagement_scoring",
    "--resume-from", "trisk_prepare_inputs",
    "--allow-partial-manifest",
    "--dry-run"
  ))

  expect_equal(cli$config_path, "engagements/mcb-demo/engagement_config.json")
  expect_true(cli$full)
  expect_equal(cli$raw_loanbook, "data/raw.csv")
  expect_false(cli$skip_intake)
  expect_equal(cli$top_n, "5")
  expect_equal(cli$only_steps, c("pacta_vietnam_scenario", "engagement_scoring"))
  expect_equal(cli$resume_from, "trisk_prepare_inputs")
  expect_true(cli$allow_partial_manifest)
  expect_true(cli$dry_run)
})

test_that("parse_engagement_cli defaults match the no-flag script behavior", {
  cli <- parse_engagement_cli(c("--config", "engagements/mcb-demo/engagement_config.json"))

  expect_false(cli$full)
  expect_null(cli$raw_loanbook)
  expect_false(cli$skip_intake)
  expect_null(cli$top_n)
  expect_equal(cli$only_steps, character(0))
  expect_equal(cli$resume_from, NA_character_)
  expect_false(cli$allow_partial_manifest)
  expect_false(cli$dry_run)
})

test_that("parse_engagement_cli collects repeatable --only-step in argument order", {
  cli <- parse_engagement_cli(c(
    "--config", "x.json",
    "--only-step", "c", "--only-step", "a"
  ))

  expect_equal(cli$only_steps, c("c", "a"))
})

test_that("parse_engagement_cli errors without --config", {
  expect_error(parse_engagement_cli(c("--full", "--dry-run")), "--config")
})

test_that("parse_engagement_cli honors --skip-intake", {
  cli <- parse_engagement_cli(c("--config", "x.json", "--skip-intake"))

  expect_true(cli$skip_intake)
})
