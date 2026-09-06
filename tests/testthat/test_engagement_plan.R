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

# --- plan_engagement_run(): resolve + filter --------------------------------

.test_cli <- function(...) {
  parse_engagement_cli(c("--config", "x.json", ...))
}

.test_cfg <- function(...) {
  cfg <- list(
    bank_slug = "test-bank",
    run_data_generation = FALSE,
    run_grid = FALSE,
    run_outputs = FALSE,
    run_refresh_audit = FALSE,
    run_vintage_comparison = FALSE,
    run_history = FALSE,
    run_financed_emissions = FALSE,
    run_sll_readiness = FALSE,
    run_targets = FALSE,
    trisk_sectors = c("power"),
    steps = character(0),
    inputs = list(raw_loanbook_csv = NULL, loanbook_csv = "data/vietnam_loanbook.csv"),
    paths = list(snapshot_dir = "engagements/test-bank/snapshot"),
    public_snapshot_allowed = FALSE
  )
  utils::modifyList(cfg, list(...))
}

test_that("plan_engagement_run resolves the registry step order for MCB", {
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  cfg <- load_engagement_config(file.path(root, "engagements", "mcb-demo", "engagement_config.json"))
  plan <- plan_engagement_run(cfg, .test_cli("--skip-intake"))

  names <- vapply(plan$steps, function(s) s$name, character(1))
  expect_equal(names, c(
    "pacta_vietnam_scenario", "trisk_prepare_inputs",
    "trisk_sector_demo_power", "trisk_sector_demo_cement", "trisk_sector_demo_steel",
    "trisk_scenario_grid", "sector_prioritization", "refresh_dashboard_data",
    "engagement_scoring", "financed_emissions", "sll_readiness", "generate_targets", "generate_engagement_letters", "generate_disclosure_pack",
    "refresh_audit", "record_history"
  ))
  expect_false(plan$run_intake)
})

test_that("plan_engagement_run applies cli$full to run_data_generation", {
  cfg <- .test_cfg()
  plan <- plan_engagement_run(cfg, .test_cli("--full"))

  expect_true(plan$cfg$run_data_generation)
  expect_equal(plan$steps[[1]]$name, "generate_vietnam_data")
})

test_that("plan_engagement_run resolves raw_loanbook with CLI winning over config", {
  cfg <- .test_cfg(inputs = list(raw_loanbook_csv = "data/cfg-raw.csv", loanbook_csv = "data/vietnam_loanbook.csv"))

  from_cli <- plan_engagement_run(cfg, .test_cli("--raw-loanbook", "data/cli-raw.csv"))
  expect_equal(from_cli$raw_loanbook, "data/cli-raw.csv")
  expect_true(from_cli$run_intake)

  from_cfg <- plan_engagement_run(cfg, .test_cli())
  expect_equal(from_cfg$raw_loanbook, "data/cfg-raw.csv")
  expect_true(from_cfg$run_intake)

  skipped <- plan_engagement_run(cfg, .test_cli("--skip-intake"))
  expect_true(!is.null(skipped$raw_loanbook))
  expect_false(skipped$run_intake)

  none <- plan_engagement_run(.test_cfg(), .test_cli())
  expect_null(none$raw_loanbook)
  expect_false(none$run_intake)
})

test_that("plan_engagement_run derives the intake dirs from bank_slug", {
  cfg <- .test_cfg(inputs = list(raw_loanbook_csv = "data/raw.csv", loanbook_csv = "data/vietnam_loanbook.csv"))
  plan <- plan_engagement_run(cfg, .test_cli())

  expect_equal(plan$intake_dir, file.path("engagements", "test-bank", "intake"))
  expect_equal(plan$effective_config_path, file.path("engagements", "test-bank", "engagement_config.resolved.json"))
})

test_that("plan_engagement_run filters by only_steps and resume_from", {
  cfg <- .test_cfg()
  plan <- plan_engagement_run(cfg, .test_cli("--only-step", "engagement_scoring"))
  expect_equal(
    vapply(plan$steps, function(s) s$name, character(1)),
    "engagement_scoring"
  )

  cfg2 <- .test_cfg()
  plan2 <- plan_engagement_run(cfg2, .test_cli(
    "--only-step", "pacta_vietnam_scenario",
    "--only-step", "engagement_scoring"
  ))
  expect_equal(
    vapply(plan2$steps, function(s) s$name, character(1)),
    c("pacta_vietnam_scenario", "engagement_scoring")
  )
})

test_that("plan_engagement_run errors on unknown --only-step, naming valid names", {
  cfg <- .test_cfg(trisk_sectors = character(0))

  err <- tryCatch(
    plan_engagement_run(cfg, .test_cli("--only-step", "nope")),
    error = function(e) conditionMessage(e)
  )
  expect_true(grepl("nope", err, fixed = TRUE))
  expect_true(grepl("pacta_vietnam_scenario", err, fixed = TRUE))
})

# --- plan_engagement_run(): by-name intake split ------------------------------

.intake_cfg <- function(...) {
  .test_cfg(
    inputs = list(raw_loanbook_csv = "data/raw.csv", loanbook_csv = "data/vietnam_loanbook.csv"),
    ...
  )
}

test_that("plan intake split is by name: generate_vietnam_data lands before intake", {
  plan <- plan_engagement_run(.intake_cfg(), .test_cli("--full"))

  expect_true(plan$run_intake)
  expect_true(plan$intake_present)
  expect_equal(
    vapply(plan$steps_before_intake, function(s) s$name, character(1)),
    "generate_vietnam_data"
  )
  expect_equal(plan$intake_step$name, "intake")
  expect_equal(plan$steps_after_intake[[1]]$name, "validation_report")
})

test_that("plan without data generation splits with empty before list", {
  plan <- plan_engagement_run(.intake_cfg(), .test_cli())

  expect_true(plan$intake_present)
  expect_equal(length(plan$steps_before_intake), 0)
  expect_equal(plan$intake_step$name, "intake")
  expect_equal(plan$intake_step$script, "scripts/intake_validate_and_map.R")
  expect_equal(plan$steps_after_intake[[1]]$name, "validation_report")
})

test_that("plan with run_intake FALSE has no intake split", {
  plan <- plan_engagement_run(.test_cfg(), .test_cli())

  expect_false(plan$run_intake)
  expect_false(plan$intake_present)
  expect_null(plan$intake_step)
  expect_equal(length(plan$steps_before_intake), 0)
  expect_equal(length(plan$steps_after_intake), 0)
})

test_that("plan filtered to a downstream step falls through to the plain branch", {
  plan <- plan_engagement_run(.intake_cfg(), .test_cli("--only-step", "engagement_scoring"))

  expect_true(plan$run_intake)
  expect_false(plan$intake_present)
  expect_null(plan$intake_step)
  expect_equal(
    vapply(plan$steps, function(s) s$name, character(1)),
    "engagement_scoring"
  )
})

# --- plan_engagement_run(): manifest path + partial policy --------------------

.public_cfg <- function(snapshot_dir, ...) {
  cfg <- .test_cfg(
    paths = list(snapshot_dir = snapshot_dir),
    public_snapshot_allowed = TRUE,
    ...
  )
  cfg
}

.write_manifest <- function(path, partial) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(jsonlite::toJSON(list(partial = partial), auto_unbox = TRUE), path)
  path
}

test_that("plan derives the manifest path from the public-snapshot flag", {
  public <- plan_engagement_run(.public_cfg("some/snapshot"), .test_cli())
  expect_equal(public$manifest_path, file.path("some/snapshot", "pipeline_manifest.json"))

  private <- plan_engagement_run(.test_cfg(), .test_cli())
  expect_equal(private$manifest_path, file.path("engagements", "test-bank", "pipeline_manifest.json"))
})

test_that("plan marks filtered runs partial and full runs complete", {
  expect_false(plan_engagement_run(.test_cfg(), .test_cli())$manifest_policy$run_is_partial)
  expect_true(plan_engagement_run(.test_cfg(), .test_cli("--only-step", "engagement_scoring"))$manifest_policy$run_is_partial)
  expect_true(plan_engagement_run(.test_cfg(), .test_cli("--resume-from", "engagement_scoring"))$manifest_policy$run_is_partial)
})

test_that("enforce_manifest_policy refuses to clobber a complete public manifest", {
  snap <- file.path(tempfile("snapshot_"))
  manifest_path <- file.path(snap, "pipeline_manifest.json")
  .write_manifest(manifest_path, partial = FALSE)

  plan <- plan_engagement_run(.public_cfg(snap), .test_cli("--only-step", "engagement_scoring"))

  expect_error(enforce_manifest_policy(plan, FALSE), "allow-partial-manifest")
  expect_silent(enforce_manifest_policy(plan, TRUE))
})

test_that("enforce_manifest_policy allows full runs and missing manifests", {
  snap <- file.path(tempfile("snapshot_"))

  full_plan <- plan_engagement_run(.public_cfg(snap), .test_cli())
  expect_silent(enforce_manifest_policy(full_plan, FALSE))

  missing_plan <- plan_engagement_run(.public_cfg(snap), .test_cli("--only-step", "engagement_scoring"))
  expect_silent(enforce_manifest_policy(missing_plan, FALSE))

  .write_manifest(file.path(snap, "pipeline_manifest.json"), partial = TRUE)
  partial_plan <- plan_engagement_run(.public_cfg(snap), .test_cli("--only-step", "engagement_scoring"))
  expect_silent(enforce_manifest_policy(partial_plan, FALSE))
})

test_that("enforce_manifest_policy allows partial runs for private engagements", {
  snap <- file.path(tempfile("snapshot_"))
  cfg <- .test_cfg(paths = list(snapshot_dir = snap), public_snapshot_allowed = FALSE)

  plan <- plan_engagement_run(cfg, .test_cli("--only-step", "engagement_scoring"))
  expect_silent(enforce_manifest_policy(plan, FALSE))
})
