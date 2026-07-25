# tests/testthat/test_sdb_engagement.R
# Frozen golden assertions for the synthetic Saigon Delta Bank (SDB) rehearsal.
# These literals are taken from the committed artifacts under
# engagements/sdb-rehearsal/ after the Wave 1 PHASE-06 refreeze.

context("SDB engagement golden fixtures")

sdb_dir <- file.path(project_root(), "engagements", "sdb-rehearsal")
normalized_loanbook_path <- file.path(sdb_dir, "intake", "normalized_loanbook.csv")
engagement_priority_path <- file.path(sdb_dir, "output", "engagement", "engagement_priority.csv")
manifest_path <- file.path(sdb_dir, "pipeline_manifest.json")

# Wave 1 PHASE-06 (C3-CI): the three test_that() blocks below read committed
# artifacts and therefore guard the ARTIFACTS, not the CODE that produces
# them -- a regression in run_engagement.R could go undetected forever if
# nobody happened to regenerate engagements/sdb-rehearsal/ by hand. This
# block closes that gap by actually executing the orchestrator end to end.
# Skipped by default (it takes several minutes) -- set RUN_SDB_ENGAGEMENT=1
# to run it locally or in CI. When it runs and succeeds, it overwrites the
# very artifacts the tests below read, so a real regression fails loudly
# right here instead of silently validating stale output.
test_that("run_engagement.R executes the full SDB engagement end to end", {
  skip_if_not(identical(Sys.getenv("RUN_SDB_ENGAGEMENT"), "1"),
              "set RUN_SDB_ENGAGEMENT=1 to run the full SDB engagement (takes several minutes)")

  root <- project_root()
  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  rscript <- Sys.which("Rscript")
  if (!nzchar(rscript)) rscript <- "C:/Program Files/R/R-4.5.2/bin/Rscript.exe"

  status <- system2(
    rscript,
    args = c("scripts/run_engagement.R", "--config", "engagements/sdb-rehearsal/engagement_config.json")
  )
  expect_equal(status, 0L)
})

test_that("SDB normalized loanbook has expected shape and currency", {
  skip_if_not(file.exists(normalized_loanbook_path),
              "SDB normalized loanbook not generated")

  nb <- readr::read_csv(normalized_loanbook_path, show_col_types = FALSE)

  expect_equal(ncol(nb), 13L,
               info = "normalized loanbook must carry the same 13 columns as MCB")
  expect_equal(nrow(nb), 24L,
               info = "SDB fixture yielded 24 clean intake rows")
  expect_true(all(nb$loan_size_outstanding_currency == "VND"),
              info = "all SDB loanbook money must stay raw VND")
})

test_that("SDB engagement priority has a rank-1 power borrower", {
  skip_if_not(file.exists(engagement_priority_path),
              "SDB engagement priority not generated")

  ep <- readr::read_csv(engagement_priority_path, show_col_types = FALSE)

  expect_gt(nrow(ep), 0L)
  expect_equal(ep$name_abcd[1], "Nghi Son Power LLC")
  expect_equal(ep$sector[1], "power")
  expect_equal(ep$composite_score[1], 1.0, tolerance = 0.005)
})

test_that("SDB engagement manifest reports success", {
  skip_if_not(file.exists(manifest_path),
              "SDB engagement manifest not generated")

  m <- jsonlite::read_json(manifest_path)

  expect_equal(m$status, "ok")
  expect_equal(m$bank_slug, "sdb-rehearsal")
  expect_gt(length(m$steps), 0L)
  expect_true(all(vapply(m$steps, function(s) s$status == "ok", logical(1))),
              info = "every orchestrator step must report ok")
})
