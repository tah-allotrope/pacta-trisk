library(testthat)

root <- project_root()
source(file.path(root, "R", "step_runner.R"))

rscript_bin <- function() {
  candidates <- c(
    Sys.which("Rscript"),
    "C:/Program Files/R/R-4.5.2/bin/Rscript.exe"
  )
  candidates <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (length(candidates) == 0) return(NA_character_)
  candidates[[1]]
}

write_exit_fixture <- function(status) {
  path <- tempfile(fileext = ".R")
  writeLines(sprintf("quit(status = %d)", status), path)
  path
}

test_that("run_steps records a successful step with ok status and numeric seconds", {
  rscript <- rscript_bin()
  if (is.na(rscript)) skip("Rscript not found on PATH")

  ok_fixture <- write_exit_fixture(0)
  on.exit(unlink(ok_fixture))

  results <- run_steps(list(list(name = "ok", script = ok_fixture, args = character())))

  expect_length(results, 1)
  expect_equal(results[[1]]$name, "ok")
  expect_equal(results[[1]]$status, "ok")
  expect_true(is.numeric(results[[1]]$seconds))
})

test_that("run_steps stops after the first failure and does not run later steps", {
  rscript <- rscript_bin()
  if (is.na(rscript)) skip("Rscript not found on PATH")

  fail_fixture <- write_exit_fixture(1)
  ok_fixture <- write_exit_fixture(0)
  on.exit(unlink(c(fail_fixture, ok_fixture)))

  results <- run_steps(list(
    list(name = "fails", script = fail_fixture, args = character()),
    list(name = "never_runs", script = ok_fixture, args = character())
  ))

  expect_length(results, 1)
  expect_equal(results[[1]]$name, "fails")
  expect_equal(results[[1]]$status, "failed")
})

test_that("write_pipeline_manifest writes the expected JSON shape with extra fields merged in", {
  results <- list(
    list(name = "step_a", status = "ok", seconds = 1.2),
    list(name = "step_b", status = "ok", seconds = 0.4)
  )
  manifest_path <- tempfile(fileext = ".json")
  on.exit(unlink(manifest_path))

  write_pipeline_manifest(results, manifest_path, extra = list(bank_slug = "x"))

  manifest <- jsonlite::read_json(manifest_path)
  expect_true(all(c("generated_at", "git_sha", "steps", "status") %in% names(manifest)))
  expect_equal(manifest$bank_slug, "x")
  expect_equal(manifest$status, "ok")
})

test_that("write_pipeline_manifest reports status failed when any step failed", {
  results <- list(
    list(name = "step_a", status = "ok", seconds = 1.0),
    list(name = "step_b", status = "failed", seconds = 0.5)
  )
  manifest_path <- tempfile(fileext = ".json")
  on.exit(unlink(manifest_path))

  write_pipeline_manifest(results, manifest_path)

  manifest <- jsonlite::read_json(manifest_path)
  expect_equal(manifest$status, "failed")
})

test_that("committed pipeline_manifest.json still contains the mandatory default-mode step names in order", {
  manifest_path <- file.path(root, "dashboard", "data", "pipeline_manifest.json")
  skip_if_not(file.exists(manifest_path), "no committed pipeline_manifest.json to compare against")

  manifest <- jsonlite::read_json(manifest_path)
  step_names <- vapply(manifest$steps, function(s) s$name, character(1))

  # The 7-step default-mode chain (+ refresh_audit) must appear as an ordered
  # subsequence regardless of whether the committed manifest was produced by
  # a default or --full run (--full interleaves generate_vietnam_data,
  # pacta_vietnam_scenario, and engagement_scoring around this core).
  mandatory <- c(
    "trisk_prepare_inputs", "trisk_power_demo", "trisk_sector_demo_cement",
    "trisk_sector_demo_steel", "trisk_scenario_grid", "sector_prioritization",
    "refresh_dashboard_data", "refresh_audit"
  )
  matched_idx <- match(mandatory, step_names)
  expect_false(any(is.na(matched_idx)), info = "every mandatory step name must be present")
  expect_true(all(diff(matched_idx) > 0), info = "mandatory step names must appear in order")
})

test_that("run_engagement.R --dry-run for MCB prints the resolved step list without executing", {
  rscript <- rscript_bin()
  if (is.na(rscript)) skip("Rscript not found on PATH")

  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  config <- file.path(root, "engagements", "mcb-demo", "engagement_config.json")
  skip_if_not(file.exists(config), "mcb-demo engagement_config.json not present")

  out <- system2(
    rscript,
    args = c("scripts/run_engagement.R", "--config", config, "--skip-intake", "--dry-run"),
    stdout = TRUE, stderr = TRUE
  )
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L

  expect_equal(status, 0L)
  expect_true(any(grepl("^trisk_scenario_grid:", out)))
  expect_false(any(grepl("^intake:", out)))
  expect_false(any(grepl("^validation_report:", out)))
})

test_that("run_engagement.R guard rail blocks a non-MCB config pointing at dashboard/data", {
  rscript <- rscript_bin()
  if (is.na(rscript)) skip("Rscript not found on PATH")

  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  tmp_config <- tempfile(fileext = ".json")
  on.exit(unlink(tmp_config), add = TRUE)
  writeLines(jsonlite::toJSON(list(
    bank_name = "X Bank", bank_slug = "x-bank",
    inputs = list(
      loanbook_csv = "data/vietnam_loanbook.csv",
      abcd_csv = "data/vietnam_abcd.csv",
      scenario_ms_csv = "data/scenarios/pdp8-2023/vietnam_scenario_ms.csv",
      scenario_co2_csv = "data/scenarios/pdp8-2023/vietnam_scenario_co2.csv",
      region_isos_csv = "data/vietnam_region_isos.csv"
    )
  ), auto_unbox = TRUE), tmp_config)

  out <- system2(
    rscript,
    args = c("scripts/run_engagement.R", "--config", tmp_config, "--dry-run"),
    stdout = TRUE, stderr = TRUE
  )
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L

  expect_true(status != 0L)
  expect_true(any(grepl("snapshot_dir must not be the public dashboard/data", out)))
})
