library(testthat)

root <- project_root()
source(file.path(root, "R", "run_history.R"))

.new_history_fixture_root <- function() {
  path <- file.path(tempdir(), paste0(
    "run_history_", as.integer(Sys.time()), "_", sample.int(1e6, 1)
  ))
  dir.create(path, recursive = TRUE)
  path
}

test_that("make_run_id builds a directory-safe id from date, sha, vintage", {
  ts <- as.POSIXct("2026-08-26 03:00:00", tz = "UTC")
  expect_equal(make_run_id("6170ae2f1a", "pdp8-2023", ts), "20260826-6170ae2-pdp8-2023")
})

test_that("make_run_id uses UTC for the date component regardless of local tz", {
  ts_utc_midnight <- as.POSIXct("2026-08-26 23:30:00", tz = "UTC")
  id <- make_run_id("abcdef0", "pdp8-2023", ts_utc_midnight)
  expect_true(startsWith(id, "20260826-"))
})

test_that("record_run_history copies named artifacts and writes manifest.json", {
  fixture_root <- .new_history_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  old_wd <- setwd(fixture_root)
  on.exit(setwd(old_wd), add = TRUE)

  dir.create("output")
  writeLines("name_abcd,composite_score\nA,0.5", file.path("output", "engagement_priority.csv"))

  cfg <- list(bank_slug = "mcb-demo", inputs = list(scenario_vintage = "pdp8-2023"))
  run_dir <- record_run_history(
    cfg, artifacts = file.path("output", "engagement_priority.csv"),
    history_root = "history", git_sha = "abc1234567"
  )

  expect_true(dir.exists(run_dir))
  expect_true(file.exists(file.path(run_dir, "engagement_priority.csv")))
  expect_true(file.exists(file.path(run_dir, "manifest.json")))

  manifest <- jsonlite::fromJSON(file.path(run_dir, "manifest.json"))
  expect_equal(manifest$bank_slug, "mcb-demo")
  expect_equal(manifest$scenario_vintage, "pdp8-2023")
  expect_equal(manifest$git_sha, "abc1234567")
  expect_equal(manifest$artifacts, "engagement_priority.csv")
})

test_that("record_run_history refuses to overwrite an existing run directory", {
  fixture_root <- .new_history_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  old_wd <- setwd(fixture_root)
  on.exit(setwd(old_wd), add = TRUE)

  dir.create("output")
  writeLines("a,b\n1,2", file.path("output", "f.csv"))
  cfg <- list(bank_slug = "acme", inputs = list(scenario_vintage = "pdp8-2023"))

  run_dir <- record_run_history(cfg, "output/f.csv", history_root = "history", git_sha = "deadbee")
  expect_error(
    record_run_history(cfg, "output/f.csv", history_root = "history", git_sha = "deadbee"),
    "append-only"
  )
})

test_that("record_run_history skips missing artifacts without erroring", {
  fixture_root <- .new_history_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  old_wd <- setwd(fixture_root)
  on.exit(setwd(old_wd), add = TRUE)

  cfg <- list(bank_slug = "acme2", inputs = list(scenario_vintage = "pdp8-2023"))
  run_dir <- suppressMessages(
    record_run_history(cfg, "does/not/exist.csv", history_root = "history", git_sha = "deadbee")
  )
  expect_true(dir.exists(run_dir))
  manifest <- jsonlite::fromJSON(file.path(run_dir, "manifest.json"))
  expect_equal(length(manifest$artifacts), 0)
})

test_that("history_runs returns sorted run ids, empty for an unknown bank", {
  fixture_root <- .new_history_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  old_wd <- setwd(fixture_root)
  on.exit(setwd(old_wd), add = TRUE)

  dir.create(file.path("history", "acme", "20260101-abc1234-pdp8-2023"), recursive = TRUE)
  dir.create(file.path("history", "acme", "20260201-def5678-pdp8-2023"), recursive = TRUE)

  expect_equal(
    history_runs("acme", history_root = "history"),
    c("20260101-abc1234-pdp8-2023", "20260201-def5678-pdp8-2023")
  )
  expect_equal(history_runs("no-such-bank", history_root = "history"), character(0))
})

test_that("history_diff reports added, removed, and changed rows; omits identical rows", {
  fixture_root <- .new_history_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  old_wd <- setwd(fixture_root)
  on.exit(setwd(old_wd), add = TRUE)

  dir.create(file.path("history", "acme", "run_a"), recursive = TRUE)
  dir.create(file.path("history", "acme", "run_b"), recursive = TRUE)

  writeLines(
    "name_abcd,composite_score\nBorrower A,0.50\nBorrower B,0.60\nBorrower C,0.70",
    file.path("history", "acme", "run_a", "engagement_priority.csv")
  )
  writeLines(
    "name_abcd,composite_score\nBorrower A,0.60\nBorrower B,0.60\nBorrower D,0.80",
    file.path("history", "acme", "run_b", "engagement_priority.csv")
  )

  diff <- history_diff(
    "acme", "run_a", "run_b", "engagement_priority.csv",
    key_cols = "name_abcd", value_cols = "composite_score", history_root = "history"
  )

  expect_equal(nrow(diff), 3)
  a_row <- diff[diff$name_abcd == "Borrower A", ]
  expect_equal(a_row$change_type, "changed")
  expect_equal(a_row$composite_score_delta, 0.10, tolerance = 1e-9)

  c_row <- diff[diff$name_abcd == "Borrower C", ]
  expect_equal(c_row$change_type, "removed")

  d_row <- diff[diff$name_abcd == "Borrower D", ]
  expect_equal(d_row$change_type, "added")

  expect_false("Borrower B" %in% diff$name_abcd)
})

test_that("history_diff returns zero rows when the two runs are identical", {
  fixture_root <- .new_history_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  old_wd <- setwd(fixture_root)
  on.exit(setwd(old_wd), add = TRUE)

  dir.create(file.path("history", "acme", "run_a"), recursive = TRUE)
  dir.create(file.path("history", "acme", "run_b"), recursive = TRUE)
  content <- "name_abcd,composite_score\nBorrower A,0.50\n"
  writeLines(content, file.path("history", "acme", "run_a", "engagement_priority.csv"))
  writeLines(content, file.path("history", "acme", "run_b", "engagement_priority.csv"))

  diff <- history_diff(
    "acme", "run_a", "run_b", "engagement_priority.csv",
    key_cols = "name_abcd", value_cols = "composite_score", history_root = "history"
  )
  expect_equal(nrow(diff), 0)
})

test_that("classify_path treats history/ paths as expected churn, not drift", {
  source(file.path(root, "tools", "verify_refactor.R"), local = (verify_env <- new.env()))
  expect_equal(verify_env$classify_path("history/mcb-demo/20260826-6170ae2-pdp8-2023/manifest.json"), "timestamp-class")
  expect_equal(verify_env$classify_path("history/mcb-demo/20260826-6170ae2-pdp8-2023/engagement_priority.csv"), "timestamp-class")
  expect_equal(verify_env$classify_path("R/pacta_core.R"), "drift")
})
