# tests/testthat/test_sdb_engagement.R
# Frozen golden assertions for the synthetic Saigon Delta Bank (SDB) rehearsal.
# These literals are taken from the committed artifacts under
# engagements/sdb-rehearsal/ after the PHASE-04 refreeze.

context("SDB engagement golden fixtures")

sdb_dir <- file.path(project_root(), "engagements", "sdb-rehearsal")
normalized_loanbook_path <- file.path(sdb_dir, "intake", "normalized_loanbook.csv")
engagement_priority_path <- file.path(sdb_dir, "output", "engagement", "engagement_priority.csv")
manifest_path <- file.path(sdb_dir, "pipeline_manifest.json")

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
