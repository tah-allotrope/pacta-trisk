library(testthat)

root <- project_root()
source(file.path(root, "tools", "verify_refactor.R"))

# --- Fixture helpers ----------------------------------------------------------
# Every inv_*() function is exercised against tempdir()-built fixtures, never
# against the live repo tree (except inv_sector_lists_agree(), which is
# expected to pass on the live repo today and exists to guard future drift).

.new_fixture_root <- function() {
  path <- file.path(tempdir(), paste0(
    "verify_invariants_", as.integer(Sys.time()), "_", sample.int(1e6, 1)
  ))
  dir.create(path, recursive = TRUE)
  path
}

.write_manifest <- function(root, snapshot_dir, sector, grid_available) {
  dir.create(file.path(root, snapshot_dir, "trisk"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    data.frame(sector = sector, grid_available = grid_available, stringsAsFactors = FALSE),
    file.path(root, snapshot_dir, "trisk", "manifest.csv"),
    row.names = FALSE
  )
}

.write_grid <- function(root, snapshot_dir, sector, company_id, npv_change_pct, pd_change_pct,
                         scenario_id = "s2028_d0.08_rf0.03_mp0.25_cNGFS_NetZero2050") {
  dir.create(file.path(root, snapshot_dir, "trisk", "grid", sector), recursive = TRUE, showWarnings = FALSE)
  arrow::write_parquet(
    data.frame(
      scenario_id = scenario_id,
      company_id = company_id,
      npv_change_pct = npv_change_pct,
      pd_change_pct = pd_change_pct,
      stringsAsFactors = FALSE
    ),
    file.path(root, snapshot_dir, "trisk", "grid", sector, "borrower_results.parquet")
  )
}

.write_company_summary <- function(root, snapshot_dir, sector, company_id, npv_change, pd_change) {
  dir.create(file.path(root, snapshot_dir, "trisk", sector), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    data.frame(company_id = company_id, npv_change = npv_change, pd_change = pd_change, stringsAsFactors = FALSE),
    file.path(root, snapshot_dir, "trisk", sector, "company_summary.csv"),
    row.names = FALSE
  )
}

.write_engagement_fixture <- function(root, slug, engagement_output_dir, data_source_values) {
  dir.create(file.path(root, "engagements", slug), recursive = TRUE, showWarnings = FALSE)
  cfg <- list(
    bank_name = "Test Bank",
    bank_slug = slug,
    paths = list(engagement_output_dir = engagement_output_dir)
  )
  writeLines(
    jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE),
    file.path(root, "engagements", slug, "engagement_config.json")
  )
  if (!is.null(data_source_values)) {
    dir.create(file.path(root, engagement_output_dir), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(
      data.frame(
        name_abcd = seq_along(data_source_values),
        data_source = data_source_values,
        stringsAsFactors = FALSE
      ),
      file.path(root, engagement_output_dir, "engagement_priority.csv"),
      row.names = FALSE
    )
  }
}

# --- INV-001: grid base cell vs base run --------------------------------------

test_that("inv_grid_matches_base_run passes when grid base cell equals base run", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest(fixture_root, "dashboard/data", "power", TRUE)
  .write_grid(fixture_root, "dashboard/data", "power", "X", -0.5, 0.1)
  .write_company_summary(fixture_root, "dashboard/data", "power", "X", -0.5, 0.1)

  result <- inv_grid_matches_base_run(fixture_root, snapshot_dir = "dashboard/data")
  expect_true(result$ok)
  expect_equal(length(result$detail), 0)
})

test_that("inv_grid_matches_base_run fails when npv_change diverges beyond tolerance", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest(fixture_root, "dashboard/data", "power", TRUE)
  .write_grid(fixture_root, "dashboard/data", "power", "X", -0.5, 0.1)
  .write_company_summary(fixture_root, "dashboard/data", "power", "X", -0.45, 0.1)

  result <- inv_grid_matches_base_run(fixture_root, snapshot_dir = "dashboard/data")
  expect_false(result$ok)
  expect_equal(length(result$detail), 1)
  expect_true(grepl("power/X", result$detail[1]))
})

test_that("inv_grid_matches_base_run tolerates sub-tolerance deltas", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest(fixture_root, "dashboard/data", "power", TRUE)
  .write_grid(fixture_root, "dashboard/data", "power", "X", -0.5, 0.1)
  .write_company_summary(fixture_root, "dashboard/data", "power", "X", -0.5000005, 0.1)

  result <- inv_grid_matches_base_run(fixture_root, snapshot_dir = "dashboard/data")
  expect_true(result$ok)
})

test_that("inv_grid_matches_base_run fails when company_id sets differ", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest(fixture_root, "dashboard/data", "power", TRUE)
  .write_grid(fixture_root, "dashboard/data", "power", "X", -0.5, 0.1)
  .write_company_summary(
    fixture_root, "dashboard/data", "power",
    c("X", "Y"), c(-0.5, -0.3), c(0.1, 0.05)
  )

  result <- inv_grid_matches_base_run(fixture_root, snapshot_dir = "dashboard/data")
  expect_false(result$ok)
  expect_true(any(grepl("Y", result$detail)))
})

test_that("inv_grid_matches_base_run skips sectors marked grid_available = FALSE", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_manifest(fixture_root, "dashboard/data", "power", FALSE)

  result <- inv_grid_matches_base_run(fixture_root, snapshot_dir = "dashboard/data")
  expect_true(result$ok)
  expect_equal(length(result$detail), 0)
})

# --- INV-002: scenario vintage single source ----------------------------------

test_that("inv_scenario_vintage_single_source flags byte-identical duplicates", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  dir.create(file.path(fixture_root, "data", "scenarios", "v1"), recursive = TRUE)
  writeLines("a,b\n1,2", file.path(fixture_root, "data", "foo.csv"))
  writeLines("a,b\n1,2", file.path(fixture_root, "data", "scenarios", "v1", "foo.csv"))

  result <- inv_scenario_vintage_single_source(fixture_root)
  expect_false(result$ok)
  expect_equal(length(result$detail), 1)
})

test_that("inv_scenario_vintage_single_source passes when content differs", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  dir.create(file.path(fixture_root, "data", "scenarios", "v1"), recursive = TRUE)
  writeLines("a,b\n1,2", file.path(fixture_root, "data", "foo.csv"))
  writeLines("a,b\n3,4", file.path(fixture_root, "data", "scenarios", "v1", "foo.csv"))

  result <- inv_scenario_vintage_single_source(fixture_root)
  expect_true(result$ok)
})

test_that("inv_scenario_vintage_single_source passes when data/scenarios does not exist", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  dir.create(file.path(fixture_root, "data"), recursive = TRUE)

  result <- inv_scenario_vintage_single_source(fixture_root)
  expect_true(result$ok)
})

# --- INV-003: engagement data_source provenance -------------------------------

test_that("inv_engagement_data_source passes when data_source matches bank_slug", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_engagement_fixture(fixture_root, "acme", "output/engagement", c("acme", "acme"))

  result <- inv_engagement_data_source(fixture_root)
  expect_true(result$ok)
})

test_that("inv_engagement_data_source fails when data_source leaks another engagement's provenance", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_engagement_fixture(fixture_root, "acme", "output/engagement", c("acme", "MCB_synthetic"))

  result <- inv_engagement_data_source(fixture_root)
  expect_false(result$ok)
  expect_true(any(grepl("MCB_synthetic", result$detail)))
})

test_that("inv_engagement_data_source skips engagements with no engagement_priority.csv yet", {
  fixture_root <- .new_fixture_root()
  on.exit(unlink(fixture_root, recursive = TRUE, force = TRUE))
  .write_engagement_fixture(fixture_root, "acme", "output/engagement", NULL)

  result <- inv_engagement_data_source(fixture_root)
  expect_true(result$ok)
})

# --- INV-004: sector list agreement (live repo) -------------------------------

test_that("inv_sector_lists_agree passes on the live repo", {
  result <- inv_sector_lists_agree(root)
  expect_true(result$ok)
  expect_equal(length(result$detail), 0)
})

# --- .md5_of() helper ----------------------------------------------------------

test_that(".md5_of returns NA for a nonexistent file", {
  expect_true(is.na(.md5_of(file.path(tempdir(), "definitely_does_not_exist_12345.csv"))))
})
