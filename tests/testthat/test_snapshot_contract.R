library(testthat)

test_that("TRISK snapshot contains all required sector files", {
  root <- project_root()
  sectors <- c("power", "cement", "steel")
  sector_files <- c(
    "assets.csv", "company_summary.csv", "company_trajectories_latest.csv",
    "financial_features.csv", "ngfs_carbon_price.csv", "npv_results_latest.csv",
    "params_latest.csv", "pd_results_latest.csv", "pd_summary.csv",
    "run_catalog.csv", "scenarios.csv", "sensitivity_results.csv",
    "sensitivity_summary.csv", "top_borrowers_alignment_trisk.csv"
  )
  grid_files <- c("scenarios.csv", "borrower_results.parquet", "grid_meta.json")

  manifest_path <- file.path(root, "dashboard", "data", "trisk", "manifest.csv")
  expect_true(file.exists(manifest_path), info = "manifest.csv must exist")

  manifest <- read.csv(manifest_path, stringsAsFactors = FALSE)
  expect_equal(nrow(manifest), 3, info = "manifest.csv should have 3 sectors")
  expect_true(all(manifest$grid_available), info = "grid_available should be TRUE for all sectors")

  for (sector in sectors) {
    sector_dir <- file.path(root, "dashboard", "data", "trisk", sector)
    for (f in sector_files) {
      expect_true(
        file.exists(file.path(sector_dir, f)),
        info = sprintf("Missing %s/%s", sector, f)
      )
    }
    for (f in grid_files) {
      expect_true(
        file.exists(file.path(root, "dashboard", "data", "trisk", "grid", sector, f)),
        info = sprintf("Missing grid/%s/%s", sector, f)
      )
    }
  }
})
